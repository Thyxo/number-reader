import { buildIndex, decode, toDigits } from './t9.js';
import { startScan, stopScan, isRunning, warmUp, setViewfinder } from './ocr.js';
import { initCalc } from './calcui.js';

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
    custom: S.custom.split('\n').map((x) => x.trim()).filter(Boolean),
  });
}

// ---------- resultat ----------
// cur = { digits, src: 'kamera'|'tastet', cands: [...], pick: index }
let cur = null;
function setResult(digits, src) {
  const cands = decode(index, digits, 6);
  cur = { digits, src, cands, pick: 0 };
  log(`${src === 'kamera' ? 'Kamera' : 'Tastet'}: ${digits} → ${cands.slice(0, 3).map((c) => c.text).join(', ') || '(intet)'}`);
  renderPeek();
  if (!$('#secret').hidden) syncPanel();
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
  }
  for (const el of [$('#pad-peek'), $('#calc-peek')]) {
    el.innerHTML = txt;
    el.classList.toggle('scan', scanning && S.peekText);
  }
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
      // Vis det scannede tal, hvor telefonnummeret står – så man kan se, at det er læst rigtigt
      if (S.showScanned) { typed = d; renderPad(); }
    },
    onStatus: (st) => {
      if (st === 'nocamera') log('Intet kamera (adgang nægtet?)');
      if (st === 'timeout') log('Scanning stoppet (tid udløb)');
      if (st === 'stopped' || st === 'nocamera') {
        scanning = false;
        if (!found && st === 'stopped') log('Scanning stoppet');
        renderPeek();
        syncScanBtn();
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
const releasePad = () => {
  clearTimeout(holdTimer);
  document.querySelectorAll('.pk.pressed').forEach((k) => k.classList.remove('pressed'));
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

// ---------- tilstand ----------
function applyMode() {
  body.dataset.mode = S.mode;
  document.title = S.mode === 'calc' ? 'Lommeregner' : 'Telefon';
  if (S.mode === 'calc') calcUi.render(); else renderPad();
}

// ---------- hemmelig gestus: 5 hurtige tryk øverst til højre ----------
let secretTaps = [];
document.addEventListener('pointerdown', (e) => {
  if (!$('#secret').hidden || !ps.hidden) return;
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
  if (['peekLevel', 'peekAlts', 'confirm', 'minLen', 'timeout', 'vAdjust'].includes(k)) v = Number(v) || 0;
  update({ [k]: v });
});
secret.querySelectorAll('[data-s-seg] button').forEach((b) => b.addEventListener('click', () => {
  update({ [b.parentElement.dataset.sSeg]: b.dataset.v });
}));
$('#s-cands').addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (!b || !cur) return;
  cur.pick = Number(b.dataset.i);
  renderPeek();
  syncPanel();
});
$('#s-custom').addEventListener('change', (e) => update({ custom: e.target.value }));
$('#s-scan').addEventListener('click', () => {
  if (isRunning() || scanning) { stopScan(); return; }
  closeSecret();
  setTimeout(toggleScan, 250);
});
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

// ---------- start ----------
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
