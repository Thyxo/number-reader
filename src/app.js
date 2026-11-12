import { buildIndex, decode, toDigits } from './t9.js';
import { startScan, stopScan, isRunning, warmUp, setViewfinder, setDebug, getDebugFrames, clearDebugFrames, onDebugFrame } from './ocr.js';
import { initCalc } from './calcui.js';
import { target, solve, birthdayOf, fmtDate } from './force.js';

const $ = (s) => document.querySelector(s);
const body = document.body;

// ---------- indstillinger ----------
const KEY = 'nr.settings.v1';
const DEFAULTS = {
  mode: 'pad',          // pad | calc
  peekText: true,       // svag tekst (over home-baren / mellem ikonerne)
  peekLevel: 2,         // 1 næsten usynlig · 2 svag · 3 tydelig
  peekAlts: 0,          // antal alternativer i peek-teksten
  screenColor: 'black', // peek-skærm: black | white
  screenHold: '2',      // '2' = 2 sek. · 'tap' = til der trykkes
  screenAlts: true,     // alternativer på peek-skærmen
  autoScan: false,      // start kameraet når appen åbner
  confirm: 2,           // samme tal læst så mange gange
  minLen: 3,
  timeout: 30,
  region: 'center',
  viewfinder: false,
  dCelebs: true,
  dNames: true,
  dWords: true,
  custom: '',
  tones: true,
  typedPeek: true,      // tal tastet på blokken dekodes også
  showScanned: true,    // vis det scannede tal i nummerfeltet
  vAdjust: 0,
  peekWhere: 'tabs',    // numerisk blok: tabs = navnet i fanernes tekst · line = over home-baren
  tab3Peek: true,       // fødselsdag / mål (y) i 3. fane
  force: false,         // regnemetoden y − x = a
  forceSrc: 'birthday', // birthday | today | clock | fixed
  forceFmt: 'ddmmyy',
  clockAdd: 2,
  forceFixed: '',
  debug: true,          // gem de sidste billeder til debug-visningen
};
let S = { ...DEFAULTS };
try { S = { ...DEFAULTS, ...JSON.parse(localStorage.getItem(KEY) || '{}') }; } catch { /* privat */ }
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch { /* ok */ } };

// ---------- log ----------
const logs = [];
function log(msg) {
  const d = new Date();
  logs.push(`${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}  ${msg}`);
  if (logs.length > 80) logs.shift();
  if (!$('#secret').hidden) $('#s-log').textContent = logs.slice().reverse().join('\n');
}

// ---------- ordbog ----------
let index = null;
function rebuild() {
  index = buildIndex({
    celebs: S.dCelebs, names: S.dNames, words: S.dWords,
    custom: customLines().map((x) => x.split('|')[0].trim()).filter(Boolean),
  });
}
const customLines = () => S.custom.split('\n').map((x) => x.trim()).filter(Boolean);

// ---------- resultat ----------
// cur = { digits, src: 'kamera'|'tastet', cands: [...], pick: index }
let cur = null;
function setResult(digits, src) {
  const cands = decode(index, digits, 6);
  cur = { digits, src, cands, pick: 0 };
  computeForce();
  log(`${src === 'kamera' ? 'Kamera' : 'Tastet'}: ${digits} → ${cands.slice(0, 3).map((c) => c.text).join(', ') || '(intet)'}`);
  renderPeek();
  if (!$('#secret').hidden) syncPanel();
}
// Regnemetoden: y − x = a (kun for tal læst med kameraet)
function computeForce() {
  if (!cur) return;
  cur.force = null;
  if (!S.force || cur.src !== 'kamera') return;
  const t = target({ src: S.forceSrc, fmt: S.forceFmt, fixed: S.forceFixed, clockAdd: S.clockAdd, name: word(), custom: customLines() });
  cur.force = { ...t, x: cur.digits, ...solve(cur.digits, t.y) };
  log(`Regnemetode: y=${t.y} (${t.label}) − x=${cur.digits} → ${cur.force.neg ? 'x − ' : 'x + '}${cur.force.a}`);
}
// Sæt mit tal (a) i nummerfeltet / lommeregneren
function applyForce() {
  if (!cur || !cur.force) return false;
  if (S.mode === 'calc') calcUi.enter(cur.force.a);
  else { typed = cur.force.a; renderPad(); }
  return true;
}
const word = () => {
  const c = cur && cur.cands[cur.pick];
  return c && !c.text.includes('?') ? c.text : '';
};
function alts(n) {
  if (!cur) return [];
  return cur.cands.filter((_, i) => i !== cur.pick).slice(0, n).map((c) => c.text);
}

let scanning = false;
function renderPeek() {
  body.dataset.peek = String(S.peekLevel);
  let txt = '';
  if (S.peekText && cur) {
    const w = word();
    const a = alts(Number(S.peekAlts));
    txt = w ? esc(w) + (a.length ? ` <span class="alt">· ${a.map(esc).join(' · ')}</span>` : '') : esc(cur.digits);
    if (cur.force && cur.force.neg) txt += ' <span class="alt">−</span>'; // regnemetoden: x − a
  }
  const tabs = S.peekWhere === 'tabs';
  $('#pad-peek').innerHTML = tabs ? '' : txt;
  $('#calc-peek').innerHTML = txt;
  for (const el of [$('#pad-peek'), $('#calc-peek')]) el.classList.toggle('scan', scanning && S.peekText);
  // Navnet i fanernes tekst (Opkald / Kontakter / Numerisk blok)
  const lab = ['Opkald', 'Kontakter', 'Numerisk blok'];
  if (tabs && S.peekText && cur) {
    const name = word() || cur.digits;
    const parts = name.split(/\s+/);
    lab[0] = parts[0];
    if (parts.length > 1) lab[1] = parts.slice(1).join(' ');
    let third = '';
    if (cur.force) third = (cur.force.neg ? '−' : '') + cur.force.y;
    else { const b = birthdayOf(word(), customLines()); if (b) third = fmtDate(b, S.forceFmt); }
    if (S.tab3Peek && third) { if (parts.length > 1) lab[2] = third; else lab[1] = third; }
  }
  lab.forEach((t, i) => { $('#tab' + (i + 1)).textContent = t; });
}
const esc = (s) => String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

// ---------- peek-skærm ----------
const ps = $('#peek-screen');
let psTimer = null;
function openPeekScreen() {
  clearTimeout(psTimer);
  ps.classList.toggle('white', S.screenColor === 'white');
  $('#ps-word').textContent = word() || (cur ? cur.digits : '');
  $('#ps-alt').innerHTML = S.screenAlts ? alts(3).map(esc).join('<br>') : '';
  ps.hidden = false;
  if (S.screenHold !== 'tap') psTimer = setTimeout(closePeekScreen, 2000);
}
function closePeekScreen() { clearTimeout(psTimer); ps.hidden = true; }
ps.addEventListener('pointerdown', (e) => { e.preventDefault(); closePeekScreen(); });

// ---------- kamera ----------
let ocrState = '–';
function setOcr(st) {
  ocrState = { loading: 'Henter …', ready: 'Klar', error: 'Fejl ved hentning' }[st] || st;
  if (!$('#secret').hidden) $('#s-ocr').textContent = ocrState;
}
function toggleScan() {
  if (isRunning()) { stopScan(); return; }
  scanning = true;
  renderPeek();
  syncScanBtn();
  let found = false;
  startScan({
    confirm: Number(S.confirm),
    minLen: Number(S.minLen),
    timeout: Number(S.timeout) * 1000,
    region: S.region,
    viewfinder: S.viewfinder,
    onRead: (d) => { const el = $('#s-lastread'); if (el) el.textContent = d; },
    quickAccept: (d) => {
      const top = decode(index, d, 1)[0];
      return !!top && ['custom', 'celeb'].includes(top.kind);
    },
    onFound: (d) => {
      found = true;
      if (navigator.vibrate) navigator.vibrate(25);
      setResult(d, 'kamera');
      // Regnemetoden: mit tal (a) sættes ind. Ellers: vis det scannede tal, hvor telefonnummeret står
      if (!applyForce() && S.showScanned) { typed = d; renderPad(); }
    },
    onStatus: (st) => {
      if (st === 'nocamera') log('Intet kamera (adgang nægtet?)');
      if (st === 'timeout') log('Scanning stoppet (tid udløb)');
      if (st === 'stopped' || st === 'nocamera') {
        scanning = false;
        if (!found && st === 'stopped') log('Scanning stoppet');
        renderPeek();
        syncScanBtn();
        if (!dbg.hidden) drawDebug();
      }
    },
  }).catch((e) => { log('Fejl: ' + e.message); scanning = false; renderPeek(); syncScanBtn(); });
}
function syncScanBtn() {
  const b = $('#s-scan');
  b.textContent = isRunning() || scanning ? 'Stop scanning' : 'Scan nu';
  b.classList.toggle('on', isRunning() || scanning);
}

// ---------- numerisk blok ----------
let typed = '';
const elNum = $('#pd-num');
const elDel = $('#pd-del');
const elAdd = $('#pd-add');

function fmtNumber(s) {
  // Danske numre formateres i par, mens de tastes ("48 48 7"), op til 8 cifre – som på iPhone
  if (/^\d{1,8}$/.test(s)) return s.replace(/(\d\d)(?=\d)/g, '$1 ');
  if (/^\+45\d{8}$/.test(s)) return '+45 ' + s.slice(3).replace(/(\d\d)(?=\d)/g, '$1 ');
  return s;
}
function renderPad() {
  elNum.textContent = fmtNumber(typed);
  elNum.style.fontSize = '';
  const avail = elNum.clientWidth;
  if (elNum.scrollWidth > avail && avail) {
    const base = parseFloat(getComputedStyle(elNum).fontSize);
    elNum.style.fontSize = Math.max(base * 0.55, base * (avail / elNum.scrollWidth)) - 0.5 + 'px';
  }
  elDel.hidden = !typed;
  elAdd.hidden = !typed;
}
function onTypedChange() {
  renderPad();
  if (!S.typedPeek) return;
  const d = typed.replace(/[^0-9]/g, '');
  if (d.length >= 2) setResult(d, 'tastet');
}

// DTMF-toner
let actx = null;
const DTMF = { 1: [697, 1209], 2: [697, 1336], 3: [697, 1477], 4: [770, 1209], 5: [770, 1336], 6: [770, 1477], 7: [852, 1209], 8: [852, 1336], 9: [852, 1477], '*': [941, 1209], 0: [941, 1336], '#': [941, 1477] };
function tone(k) {
  if (!S.tones || !DTMF[k]) return;
  try {
    actx = actx || new (window.AudioContext || window.webkitAudioContext)();
    if (actx.state === 'suspended') actx.resume();
    const t = actx.currentTime;
    const g = actx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.08, t + 0.01);
    g.gain.setValueAtTime(0.08, t + 0.13);
    g.gain.linearRampToValueAtTime(0, t + 0.16);
    g.connect(actx.destination);
    for (const f of DTMF[k]) {
      const o = actx.createOscillator();
      o.frequency.value = f;
      o.connect(g);
      o.start(t);
      o.stop(t + 0.17);
    }
  } catch { /* ingen lyd */ }
}

let holdTimer = null;
let heldPlus = false;
$('#pd-keys').addEventListener('pointerdown', (e) => {
  const k = e.target.closest('.pk');
  if (!k) return;
  e.preventDefault();
  try { k.setPointerCapture(e.pointerId); } catch { /* ok */ }
  padDrag = { k, x: e.clientX, y: e.clientY };
  k.classList.add('pressed');
  const d = k.dataset.d;
  tone(d);
  if (d === '*') { openPeekScreen(); return; } // ✱ = peek-skærm (tastes ikke)
  if (typed.length >= 40) return;
  typed += d;
  heldPlus = false;
  if (d === '0') {
    clearTimeout(holdTimer);
    holdTimer = setTimeout(() => { typed = typed.slice(0, -1) + '+'; heldPlus = true; onTypedChange(); }, 650);
  }
  onTypedChange();
});
// Strækker sig mod fingeren ved træk (samme som lommeregneren)
let padDrag = null;
$('#pd-keys').addEventListener('pointermove', (e) => {
  if (!padDrag) return;
  const b = padDrag.k;
  const size = b.offsetWidth;
  const lim = (v) => Math.max(-0.6, Math.min(0.6, v / size));
  const nx = lim(e.clientX - padDrag.x);
  const ny = lim(e.clientY - padDrag.y);
  const ax = Math.abs(nx);
  const ay = Math.abs(ny);
  b.classList.add('drag');
  b.style.setProperty('--tx', nx * 0.3 * size + 'px');
  b.style.setProperty('--ty', ny * 0.3 * size + 'px');
  const sx = 1.19 + 0.25 * ax - 0.28 * ay;
  const sy = 1.19 + 0.25 * ay - 0.28 * ax;
  const m = Math.min(sx, sy);
  b.style.setProperty('--s', m.toFixed(3));
  b.style.setProperty('--ex', (sx / m).toFixed(3));
  b.style.setProperty('--ey', (sy / m).toFixed(3));
});
const releasePad = () => {
  clearTimeout(holdTimer);
  padDrag = null;
  document.querySelectorAll('.pk.pressed').forEach((k) => {
    k.classList.remove('pressed', 'drag');
    ['--tx', '--ty', '--s', '--ex', '--ey'].forEach((v) => k.style.removeProperty(v));
  });
};
document.addEventListener('pointerup', releasePad);
document.addEventListener('pointercancel', releasePad);
$('#pd-keys').addEventListener('contextmenu', (e) => e.preventDefault());

// Slet: ét tegn, hold = slet løbende, langt hold = slet alt
let delTimer = null;
let delRepeat = null;
elDel.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  typed = typed.slice(0, -1);
  onTypedChange();
  delTimer = setTimeout(() => {
    delRepeat = setInterval(() => {
      typed = typed.slice(0, -1);
      onTypedChange();
      if (!typed) clearInterval(delRepeat);
    }, 110);
  }, 500);
});
const stopDel = () => { clearTimeout(delTimer); clearInterval(delRepeat); };
['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => elDel.addEventListener(ev, stopDel));

// Ring op: kort tryk-effekt, intet sker (som uden SIM)
$('#pd-call').addEventListener('click', () => {});

// Tryk øverst (over nummeret) = start/stop scanning
$('#pd-display').addEventListener('pointerdown', (e) => {
  toggleScan();
});

// Tastatur på computer
document.addEventListener('keydown', (e) => {
  if (S.mode !== 'pad' || e.target.closest('input, textarea, select') || !$('#secret').hidden) return;
  if (/^[0-9#]$/.test(e.key)) { typed += e.key; tone(e.key); onTypedChange(); }
  else if (e.key === '*') openPeekScreen();
  else if (e.key === 'Backspace') { typed = typed.slice(0, -1); onTypedChange(); }
  else if (e.key === 'Escape') { typed = ''; onTypedChange(); }
});

// ---------- lommeregner ----------
const calcUi = initCalc({ onArmTap: toggleScan, isSecretOpen: () => !$('#secret').hidden });

// Hurtigt skift: luppen på blokken = lommeregner · hold på uret i lommeregneren = blokken
$('#pd-search').addEventListener('click', () => update({ mode: 'calc' }));
let histHold = null;
let histHeld = false;
$('#btn-history').addEventListener('pointerdown', () => {
  histHeld = false;
  clearTimeout(histHold);
  histHold = setTimeout(() => { histHeld = true; if (navigator.vibrate) navigator.vibrate(10); update({ mode: 'pad' }); }, 600);
});
['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => $('#btn-history').addEventListener(ev, () => clearTimeout(histHold)));
$('#btn-history').addEventListener('click', (e) => { if (histHeld) { e.stopImmediatePropagation(); histHeld = false; } }, true);

// ---------- tilstand ----------
function applyMode() {
  body.dataset.mode = S.mode;
  document.title = S.mode === 'calc' ? 'Lommeregner' : 'Telefon';
  if (S.mode === 'calc') calcUi.render(); else renderPad();
}

// ---------- hemmelig gestus: 5 hurtige tryk øverst til højre ----------
let secretTaps = [];
document.addEventListener('pointerdown', (e) => {
  if (!$('#secret').hidden || !ps.hidden || !dbg.hidden) return;
  const w = Math.min(innerWidth, 480);
  const left = (innerWidth - w) / 2;
  const inZone = e.clientX > left + w * 0.62 && e.clientY < w * 0.36;
  if (!inZone) { secretTaps = []; return; }
  const now = performance.now();
  secretTaps = secretTaps.filter((t) => now - t < 2500);
  secretTaps.push(now);
  if (secretTaps.length >= 5) {
    secretTaps = [];
    e.preventDefault();
    e.stopPropagation();
    calcUi.closeMenu();
    setTimeout(openSecret, 170);
  }
}, true);

// ---------- panel ----------
const secret = $('#secret');
function openSecret() {
  syncPanel();
  secret.hidden = false;
  secret.classList.remove('out');
}
function closeSecret() {
  secret.classList.add('out');
  setTimeout(() => { secret.hidden = true; secret.classList.remove('out'); applyMode(); }, 220);
}
$('#secret-done').addEventListener('click', closeSecret);

const KIND = { custom: 'egen', celeb: 'kendt', celebPart: 'kendt', first: 'navn', last: 'efternavn', word: 'ord', pair: 'navn', multi: 'flere ord' };
function syncPanel() {
  secret.querySelectorAll('[data-s]').forEach((el) => {
    const v = S[el.dataset.s];
    if (el.type === 'checkbox') el.checked = !!v;
    else el.value = String(v);
  });
  secret.querySelectorAll('[data-s-seg] button').forEach((b) => {
    b.classList.toggle('on', String(S[b.parentElement.dataset.sSeg]) === b.dataset.v);
  });
  $('#s-custom').value = S.custom;
  $('#s-word').textContent = word() || (cur ? '(intet ord)' : '–');
  $('#s-src').textContent = cur ? (cur.src === 'kamera' ? 'Læst med kameraet' : 'Tastet på blokken') : 'Intet læst endnu';
  $('#s-digits').textContent = cur ? cur.digits : '';
  $('#s-cands').innerHTML = cur
    ? cur.cands.map((c, i) => `<button data-i="${i}" class="${i === cur.pick ? 'on' : ''}">${esc(c.text)}<span class="k">${KIND[c.kind] || ''}</span></button>`).join('')
    : '';
  $('#s-ocr').textContent = ocrState;
  $('#sum-peek').textContent = `${S.screenColor === 'white' ? 'Hvid' : 'Sort'} · ${S.screenHold === 'tap' ? 'til tryk' : '2 sek.'}`;
  $('#sum-cam').textContent = `${S.confirm}× · ${S.region === 'full' ? 'hele' : 'midten'}${S.autoScan ? ' · auto' : ''}`;
  $('#sum-dict').textContent = [S.dCelebs && 'Kendte', S.dNames && 'Navne', S.dWords && 'Ord'].filter(Boolean).join(' · ') || 'Kun egne';
  const f = cur && cur.force;
  $('#s-force').hidden = !f;
  if (f) $('#s-force').innerHTML = `Mit tal: <b>${esc(f.a)}</b><br>${f.neg ? 'Dit tal <b>−</b> mit tal' : 'Dit tal + mit tal'} = ${esc(f.y)} <span style="opacity:.6">(${esc(f.label)})</span>`;
  $('#sum-force').textContent = S.force ? ({ birthday: 'Fødselsdag', today: 'Dato i dag', clock: 'Klokken', fixed: 'Fast tal' }[S.forceSrc] || '') : 'Fra';
  $('#s-screen').textContent = 'Skærm: ' + calcUi.screenInfo();
  $('#s-log').textContent = logs.slice().reverse().join('\n') || '(tom)';
  syncScanBtn();
}

function update(patch) {
  S = { ...S, ...patch };
  save();
  if (['dCelebs', 'dNames', 'dWords', 'custom'].some((k) => k in patch)) {
    rebuild();
    if (cur) { const p = cur.pick; setResult(cur.digits, cur.src); cur.pick = Math.min(p, Math.max(0, cur.cands.length - 1)); }
  }
  if (['force', 'forceSrc', 'forceFmt', 'clockAdd', 'forceFixed'].some((k) => k in patch) && cur) computeForce();
  if ('debug' in patch) setDebug(S.debug);
  if ('vAdjust' in patch) calcUi.fixHeight(S.vAdjust);
  if ('viewfinder' in patch) setViewfinder(S.viewfinder && isRunning());
  if ('mode' in patch) applyMode();
  renderPeek();
  syncPanel();
}

secret.addEventListener('change', (e) => {
  const el = e.target.closest('[data-s]');
  if (!el) return;
  const k = el.dataset.s;
  let v = el.type === 'checkbox' ? el.checked : el.value;
  if (['peekLevel', 'peekAlts', 'confirm', 'minLen', 'timeout', 'vAdjust', 'clockAdd'].includes(k)) v = Number(v) || 0;
  update({ [k]: v });
});
secret.querySelectorAll('[data-s-seg] button').forEach((b) => b.addEventListener('click', () => {
  update({ [b.parentElement.dataset.sSeg]: b.dataset.v });
}));
$('#s-cands').addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (!b || !cur) return;
  cur.pick = Number(b.dataset.i);
  computeForce();
  if (cur.force && cur.src === 'kamera') applyForce();
  renderPeek();
  syncPanel();
});
$('#s-custom').addEventListener('change', (e) => update({ custom: e.target.value }));
$('#s-scan').addEventListener('click', () => {
  if (isRunning() || scanning) { stopScan(); return; }
  closeSecret();
  setTimeout(toggleScan, 250);
});
$('#s-debug').addEventListener('click', () => { closeSecret(); setTimeout(openDebug, 230); });
$('#s-peek').addEventListener('click', () => { closeSecret(); setTimeout(openPeekScreen, 250); });
$('#s-clear').addEventListener('click', () => { cur = null; typed = ''; renderPad(); renderPeek(); syncPanel(); });
$('#t-digits').addEventListener('input', (e) => {
  const r = decode(index, e.target.value, 5);
  $('#t-digits-out').textContent = r.map((c) => c.text).join(' · ') || '–';
});
$('#t-word').addEventListener('input', (e) => {
  $('#t-word-out').textContent = toDigits(e.target.value) || '–';
});

// Sektioner: husk hvilke der er åbne
const OPEN_KEY = 'nr.open.v1';
let openSecs = {};
try { openSecs = JSON.parse(localStorage.getItem(OPEN_KEY) || '{}'); } catch { openSecs = {}; }
secret.querySelectorAll('details[data-sec]').forEach((d) => {
  if (d.dataset.sec in openSecs) d.open = openSecs[d.dataset.sec];
  d.addEventListener('toggle', () => {
    openSecs[d.dataset.sec] = d.open;
    try { localStorage.setItem(OPEN_KEY, JSON.stringify(openSecs)); } catch { /* ok */ }
  });
});

// ---------- debug: se hvad kameraet ser ----------
const dbg = $('#debug');
const dbgCanvas = $('#dbg-canvas');
let dbgIdx = -1;      // -1 = følg nyeste
const dbgImg = new Image();
const p2 = (n) => String(n).padStart(2, '0');
function drawDebug() {
  const frames = getDebugFrames();
  $('#dbg-empty').hidden = frames.length > 0;
  dbgCanvas.hidden = !frames.length;
  $('#dbg-dots').innerHTML = frames.map((f, i) => `<i class="${i === (dbgIdx < 0 ? frames.length - 1 : dbgIdx) ? 'on' : f.found ? 'found' : ''}"></i>`).join('');
  $('#dbg-scan').classList.toggle('live', isRunning());
  if (!frames.length) { $('#dbg-title').textContent = 'DEBUG'; $('#dbg-sub').textContent = isRunning() ? 'Scanner …' : ''; $('#dbg-lines').innerHTML = ''; return; }
  const i = dbgIdx < 0 ? frames.length - 1 : Math.min(dbgIdx, frames.length - 1);
  const f = frames[i];
  const d = new Date(f.t);
  $('#dbg-title').textContent = 'DEBUG: ' + (f.best ? f.best.digits : '–') + (f.found ? '  ✓' : '');
  $('#dbg-sub').innerHTML = `${p2(d.getHours())}:${p2(d.getMinutes())}:${p2(d.getSeconds())} ${p2(d.getDate())}/${p2(d.getMonth() + 1)}/${p2(d.getFullYear() % 100)} · <span class="hl">${esc(f.strat)} · ${f.ms} ms${f.best ? ' · ' + Math.round(f.best.conf) + '%' : ''}</span> · ${f.vw}×${f.vh}`;
  $('#dbg-lines').innerHTML = f.lines.length
    ? f.lines.map((l) => { const isBest = f.best && f.best.bbox === l.bbox; return `<div class="${isBest ? 'ok' : (l.confidence < 45 ? 'low' : '')}">${isBest ? '▶ ' : '· '}${esc(l.text || '(tom)')}  ${Math.round(l.confidence)}%</div>`; }).join('')
    : '<div class="low">Ingen tekst fundet i billedet</div>';
  dbgImg.onload = () => {
    dbgCanvas.width = f.w; dbgCanvas.height = f.h;
    const c = dbgCanvas.getContext('2d');
    c.drawImage(dbgImg, 0, 0, f.w, f.h);
    const lw = Math.max(2, f.w / 220);
    c.font = `600 ${Math.max(14, f.w / 28)}px -apple-system, system-ui, sans-serif`;
    for (const l of f.lines) {
      if (!l.bbox) continue;
      const isBest = f.best && f.best.bbox === l.bbox;
      const x = l.bbox.x0 * f.k; const y = l.bbox.y0 * f.k;
      const w = (l.bbox.x1 - l.bbox.x0) * f.k; const h = (l.bbox.y1 - l.bbox.y0) * f.k;
      c.lineWidth = isBest ? lw * 1.6 : lw;
      c.strokeStyle = isBest ? '#30d158' : 'rgba(255,159,10,.7)';
      c.strokeRect(x - lw * 3, y - lw * 3, w + lw * 6, h + lw * 6);
      if (isBest) {
        const label = f.best.digits;
        const tw = c.measureText(label).width + 12;
        const th = Math.max(14, f.w / 28) + 8;
        c.fillStyle = 'rgba(0,0,0,.75)';
        c.fillRect(x + w / 2 - tw / 2, y - lw * 3 - th - 4, tw, th);
        c.fillStyle = '#fff';
        c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText(label, x + w / 2, y - lw * 3 - th / 2 - 4);
      }
    }
  };
  dbgImg.src = f.img;
}
function openDebug() { dbgIdx = -1; dbg.hidden = false; drawDebug(); }
function closeDebug() { dbg.hidden = true; }
onDebugFrame(() => { if (!dbg.hidden && dbgIdx < 0) drawDebug(); });
$('#dbg-close').addEventListener('click', closeDebug);
$('#dbg-clear').addEventListener('click', () => { clearDebugFrames(); dbgIdx = -1; drawDebug(); });
$('#dbg-scan').addEventListener('click', () => { dbgIdx = -1; toggleScan(); setTimeout(drawDebug, 50); });
// Swipe mellem billederne
let dbgSwipe = null;
$('#dbg-stage').addEventListener('pointerdown', (e) => { dbgSwipe = e.clientX; });
$('#dbg-stage').addEventListener('pointerup', (e) => {
  if (dbgSwipe == null) return;
  const dx = e.clientX - dbgSwipe;
  dbgSwipe = null;
  const n = getDebugFrames().length;
  if (!n || Math.abs(dx) < 30) return;
  const i = dbgIdx < 0 ? n - 1 : dbgIdx;
  const j = Math.max(0, Math.min(n - 1, i + (dx < 0 ? 1 : -1)));
  dbgIdx = j === n - 1 ? -1 : j;
  drawDebug();
});

// ---------- start ----------
setDebug(S.debug);
rebuild();
calcUi.fixHeight(S.vAdjust);
applyMode();
renderPeek();
window.addEventListener('resize', () => { if (S.mode === 'pad') renderPad(); });
document.addEventListener('gesturestart', (e) => e.preventDefault());
document.addEventListener('dblclick', (e) => e.preventDefault());

// Forvarm OCR-motoren lidt efter start, så første scanning er hurtig
setTimeout(() => warmUp(setOcr).catch(() => log('OCR-motoren kunne ikke hentes')), 1200);
if (S.autoScan) setTimeout(toggleScan, 400);

// Stop kameraet når appen lægges væk
document.addEventListener('visibilitychange', () => { if (document.hidden && isRunning()) stopScan(); });

if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
}
