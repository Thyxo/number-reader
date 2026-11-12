// Kamera + tal-genkendelse. Videoen er usynlig (1 px), medmindre "Vis søger" er slået til.
// Bruger browserens egen TextDetector, hvis den findes (hurtigst), ellers Tesseract (vendor/).

const VENDOR = new URL('../vendor/', import.meta.url).href;

let worker = null;
let workerPromise = null;
let stream = null;
let video = null;
let running = false;
let frame = 0;

// ---------- debug: de sidste billeder appen har set, med fundne linjer ----------
let debugOn = true;
const debugFrames = [];
const debugListeners = new Set();
export function setDebug(on) { debugOn = !!on; }
export const getDebugFrames = () => debugFrames;
export function clearDebugFrames() { debugFrames.length = 0; debugListeners.forEach((f) => f()); }
export function onDebugFrame(fn) { debugListeners.add(fn); return () => debugListeners.delete(fn); }
function pushDebug(f) {
  debugFrames.push(f);
  if (debugFrames.length > 15) debugFrames.shift();
  debugListeners.forEach((fn) => fn(f));
}
const STRAT_NAME = (st) => `${st.prep ? (st.flip ? 'vendt' : 'kontrast') : 'rå'} · PSM ${st.psm}${st.big ? ' · stor' : ''}`;

function loadScript(src) {
  return new Promise((res, rej) => {
    if (window.Tesseract) return res();
    const s = document.createElement('script');
    s.src = src;
    s.onload = res;
    s.onerror = () => rej(new Error('Kunne ikke hente ' + src));
    document.head.appendChild(s);
  });
}

/** Start OCR-motoren i baggrunden, så første scanning er hurtig. */
export function warmUp(onStatus = () => {}) {
  if (workerPromise) return workerPromise;
  onStatus('loading');
  workerPromise = (async () => {
    await loadScript(VENDOR + 'tesseract.min.js');
    const w = await window.Tesseract.createWorker('eng', 1, {
      workerPath: VENDOR + 'worker.min.js',
      corePath: VENDOR,
      langPath: VENDOR + 'lang',
      gzip: true,
      cacheMethod: 'write',
      workerBlobURL: false,
    });
    await w.setParameters({
      tessedit_char_whitelist: '0123456789',
      tessedit_pageseg_mode: '6',
    });
    worker = w;
    onStatus('ready');
    return w;
  })().catch((e) => { workerPromise = null; onStatus('error'); throw e; });
  return workerPromise;
}

export const isRunning = () => running;

function ensureVideo() {
  if (video) return video;
  video = document.createElement('video');
  video.id = 'cam';
  video.setAttribute('playsinline', '');
  video.setAttribute('muted', '');
  video.muted = true;
  video.autoplay = true;
  document.body.appendChild(video);
  return video;
}

export function setViewfinder(on) {
  ensureVideo().classList.toggle('show', !!on);
}

// Gråtone + kontrast. Mørk skærm med lys tekst (fx en iPhone i mørk tilstand) vendes,
// så Tesseract altid får mørk tekst på lys baggrund. flip = prøv den modsatte polaritet.
function prepare(canvas, ctx, flip) {
  const { width: w, height: h } = canvas;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  const hist = new Uint32Array(256);
  for (let i = 0; i < d.length; i += 4) {
    const g = (d[i] * 77 + d[i + 1] * 150 + d[i + 2] * 29) >> 8;
    d[i] = g;
    hist[g]++;
  }
  const total = w * h;
  let acc = 0; let lo = 0; let hi = 255; let med = 128;
  for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc >= total * 0.02) { lo = v; break; } }
  acc = 0;
  for (let v = 255; v >= 0; v--) { acc += hist[v]; if (acc >= total * 0.02) { hi = v; break; } }
  acc = 0;
  for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc >= total / 2) { med = v; break; } }
  let invert = med < 110;
  if (flip) invert = !invert;
  const span = Math.max(30, hi - lo);
  for (let i = 0; i < d.length; i += 4) {
    let g = ((d[i] - lo) * 255) / span;
    g = g < 0 ? 0 : g > 255 ? 255 : g;
    if (invert) g = 255 - g;
    d[i] = d[i + 1] = d[i + 2] = g;
  }
  ctx.putImageData(img, 0, 0);
}

/** Find den længste række cifre i teksten (mellemrum inde i et tal tæller med). */
export function pickDigits(text, minLen = 3) {
  let best = '';
  for (const line of String(text).split(/\n+/)) {
    for (const run of line.match(/[0-9][0-9 \-.()]*[0-9]|[0-9]/g) || []) {
      const d = run.replace(/[^0-9]/g, '');
      if (d.length > best.length) best = d;
    }
  }
  return best.length >= minLen ? best : '';
}

const STRATS = [
  { prep: true, flip: false, psm: '6' },
  { prep: false, psm: '6' },
  { prep: true, flip: false, psm: '11', big: true },
  { prep: true, flip: true, psm: '6' },
  { prep: false, psm: '11' },
  { prep: true, flip: false, psm: '6', big: true },
];
let lastPsm = '6';

const canvas = typeof document !== 'undefined' ? document.createElement('canvas') : null;

// Vælg den bedste talrække blandt Tesseracts linjer: telefonnummeret er den STØRSTE tekst på
// skærmen, så høje linjer vinder over fx klokken i statuslinjen. Lav sikkerhed tæller ned.
export function pickLine(lines, minLen = 3) {
  let best = null;
  for (const ln of lines) {
    const d = String(ln.text || '').replace(/[^0-9]/g, '');
    if (d.length < minLen) continue;
    const h = ln.bbox ? ln.bbox.y1 - ln.bbox.y0 : 1;
    const conf = Number(ln.confidence) || 0;
    if (conf < 45) continue;
    const score = h * (0.5 + conf / 200) + d.length * 0.5;
    if (!best || score > best.score) best = { digits: d, conf, score, bbox: ln.bbox };
  }
  return best;
}

function linesOf(data) {
  const out = [];
  for (const b of data.blocks || []) for (const p of b.paragraphs || []) for (const l of p.lines || []) out.push(l);
  return out;
}

async function readFrame(opts) {
  const t0 = performance.now();
  const vw = video.videoWidth;
  const vh = video.videoHeight;
  if (!vw || !vh) return null;
  // Udsnit: midten (standard) eller hele billedet
  const cw = opts.region === 'full' ? vw : Math.round(vw * 0.86);
  const ch = opts.region === 'full' ? vh : Math.round(vh * 0.46);
  const sx = Math.round((vw - cw) / 2);
  const sy = Math.round((vh - ch) / 2);

  if ('TextDetector' in window && opts.native !== false) {
    try {
      const det = new window.TextDetector();
      const blocks = await det.detect(video);
      const lines = blocks.map((b) => ({ text: b.rawValue, confidence: 90, bbox: { x0: b.boundingBox.x, x1: b.boundingBox.x + b.boundingBox.width, y0: b.boundingBox.y, y1: b.boundingBox.y + b.boundingBox.height } }));
      const best = pickLine(lines, opts.minLen);
      if (debugOn) {
        const k = Math.min(1, 900 / vw);
        canvas.width = Math.round(vw * k); canvas.height = Math.round(vh * k);
        const c2 = canvas.getContext('2d');
        c2.drawImage(video, 0, 0, canvas.width, canvas.height);
        pushDebug({ t: Date.now(), img: canvas.toDataURL('image/jpeg', 0.7), w: canvas.width, h: canvas.height, k, lines, best, strat: 'TextDetector', ms: Math.round(performance.now() - t0), vw, vh });
      }
      if (best) return best;
    } catch { /* falder tilbage til Tesseract */ }
  }

  // Skift strategi fra billede til billede – forskellige skærme, afstande og lys læses bedst forskelligt
  const st = STRATS[frame % STRATS.length];
  const scale = Math.min(st.big ? 1.6 : 1, (st.big ? 1700 : 1100) / cw);
  canvas.width = Math.round(cw * scale);
  canvas.height = Math.round(ch * scale);
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(video, sx, sy, cw, ch, 0, 0, canvas.width, canvas.height);
  const raw = debugOn ? canvas.toDataURL('image/jpeg', 0.7) : null;
  if (st.prep) prepare(canvas, ctx, st.flip);
  const w = worker || (await warmUp());
  if (st.psm !== lastPsm) { await w.setParameters({ tessedit_pageseg_mode: st.psm }); lastPsm = st.psm; }
  const { data } = await w.recognize(canvas, {}, { text: true, blocks: true });
  if (window.__ocrDebug) window.__ocrDebug.push({ text: data.text, img: canvas.toDataURL('image/png') });
  const lines = linesOf(data);
  let best = pickLine(lines, opts.minLen);
  if (!best) { const d = pickDigits(data.text, opts.minLen); if (d) best = { digits: d, conf: 50 }; }
  if (debugOn) {
    pushDebug({
      t: Date.now(), img: raw, w: canvas.width, h: canvas.height, k: 1,
      lines: lines.map((l) => ({ text: l.text.trim(), confidence: l.confidence, bbox: l.bbox })),
      best, strat: STRAT_NAME(st), ms: Math.round(performance.now() - t0), vw, vh,
    });
  }
  return best;
}

/**
 * Start scanning. onRead(digits) kaldes for hver læsning, onFound(digits) når samme tal er læst
 * `confirm` gange blandt de sidste 6 læsninger – eller med det samme, hvis læsningen er sikker
 * (conf ≥ 85) og quickAccept(digits) siger god (fx et kendt navn).
 */
export async function startScan({ onFound, onRead = () => {}, onStatus = () => {}, quickAccept = () => false, confirm = 2, minLen = 3, timeout = 25000, region = 'center', viewfinder = false } = {}) {
  if (running) return;
  running = true;
  frame = 0;
  onStatus('starting');
  warmUp().catch(() => {});
  try {
    ensureVideo();
    setViewfinder(viewfinder);
    stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } },
    });
    video.srcObject = stream;
    await video.play().catch(() => {});
  } catch (e) {
    running = false;
    onStatus('nocamera');
    stopScan();
    return;
  }
  onStatus('scanning');
  const started = performance.now();
  const recent = [];
  while (running) {
    if (performance.now() - started > timeout) { onStatus('timeout'); break; }
    let r = null;
    try { r = await readFrame({ region, minLen }); } catch { r = null; }
    frame++;
    if (!running) break;
    if (r) {
      const d = r.digits;
      onRead(d);
      recent.push(d);
      if (recent.length > 6) recent.shift();
      const n = recent.filter((x) => x === d).length;
      if (n >= confirm || (r.conf >= 85 && quickAccept(d))) {
        const last = debugFrames[debugFrames.length - 1];
        if (last && last.best && last.best.digits === d) last.found = true;
        onFound(d);
        break;
      }
    } else {
      await new Promise((r) => setTimeout(r, 60));
    }
  }
  stopScan();
  onStatus('stopped');
}

export function stopScan() {
  running = false;
  if (stream) { stream.getTracks().forEach((t) => t.stop()); stream = null; }
  if (video) { video.srcObject = null; }
}
