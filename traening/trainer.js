// Træningsside: flere iPhone-rammer med appens numeriske blok. Skriv ord/tal, eller tryk på tasterne.
import { buildIndex, decode, toDigits } from './t9.js';
import { CELEBS } from './words.js';

const $ = (s, r = document) => r.querySelector(s);
const STORE = 'nr-traening-v1';
const MAX_PHONES = 12;
const celebs = CELEBS.split('|');
const idx = buildIndex();

const state = { phones: [], size: 300, space0: false, next: 1 };
let uid = 0;

// ---------- lager ----------
function load() {
  try {
    const s = JSON.parse(localStorage.getItem(STORE) || 'null');
    if (s) {
      state.size = Math.min(460, Math.max(220, +s.size || 300));
      state.space0 = !!s.space0;
      state.phones = (s.phones || []).slice(0, MAX_PHONES).map((src) => ({ id: ++uid, src: String(src) }));
    }
  } catch { /* ingen lager */ }
  if (!state.phones.length) state.phones = [{ id: ++uid, src: '' }, { id: ++uid, src: '' }];
}
function save() {
  try { localStorage.setItem(STORE, JSON.stringify({ size: state.size, space0: state.space0, phones: state.phones.map((p) => p.src) })); } catch { /* ok */ }
}

// ---------- bogstaver/tal → tastet streng ----------
function toTyped(src) {
  let out = '';
  for (const ch of src) {
    if (/[0-9*#+]/.test(ch)) out += ch;
    else if (/\s/.test(ch)) { if (state.space0) out += '0'; }
    else out += toDigits(ch); // bogstav → 2–9 (ukendte tegn → '')
  }
  return out;
}
// Som på iPhone: danske numre i par, op til 8 cifre
function fmtNumber(s) {
  if (/^\d{1,8}$/.test(s)) return s.replace(/(\d\d)(?=\d)/g, '$1 ');
  if (/^\+45\d{8}$/.test(s)) return '+45 ' + s.slice(3).replace(/(\d\d)(?=\d)/g, '$1 ');
  return s;
}
const groups = (d) => d.replace(/(.{3})(?=.)/g, '$1 ');

// ---------- telefon-markup ----------
const KEYS = [
  ['1', '&nbsp;', 'blank'], ['2', 'ABC'], ['3', 'DEF'], ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
  ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
];
const keyHtml = KEYS.map(([d, l, c]) => `<button class="pk" data-d="${d}"><b>${d}</b><small class="${c || ''}">${l}</small></button>`).join('')
  + `<button class="pk" data-d="*" aria-label="Stjerne"><svg class="star" viewBox="0 0 20 20"><path d="M10 2.2v15.6M3.25 6.1l13.5 7.8M3.25 13.9l13.5-7.8"/></svg></button>`
  + `<button class="pk" data-d="0"><b>0</b><small class="plus">+</small></button>`
  + `<button class="pk" data-d="#" aria-label="Firkant"><svg class="hash" viewBox="0 0 22 24"><path d="M7.6 2.5v19M14.4 2.5v19M2.4 8.4h17.2M2.4 15.6h17.2"/></svg></button>`;

const cellHtml = (n) => `
<section class="cell">
  <div class="cell-head"><span>Telefon ${n}</span><button class="rm" title="Fjern telefon" aria-label="Fjern telefon">✕</button></div>
  <div class="phone">
    <i class="sb v1"></i><i class="sb v2"></i>
    <div class="screen">
      <div class="island"></div>
      <div class="status"><span class="time">9:41</span>
        <svg class="sig" viewBox="0 0 19 13"><rect x="0" y="8.5" width="3.2" height="4.5" rx="1"/><rect x="5" y="5.7" width="3.2" height="7.3" rx="1"/><rect x="10" y="2.8" width="3.2" height="10.2" rx="1"/><rect x="15" y="0" width="3.2" height="13" rx="1"/></svg>
        <svg class="wifi" viewBox="0 0 17 13"><path d="M8.5 2.6c2.4 0 4.6.9 6.3 2.5l1-1.1A10.6 10.6 0 0 0 8.5 1.1 10.6 10.6 0 0 0 1.2 4l1 1.1a8.9 8.9 0 0 1 6.3-2.5zm0 3.9c1.4 0 2.6.5 3.6 1.4l1-1.1a7.3 7.3 0 0 0-9.2 0l1 1.1c1-.9 2.200-1.400 3.600-1.400zm0 3.800c.7 0 1.300.3 1.800.7L8.500 12.500 6.700 11c.5-.4 1.100-.7 1.800-.7z"/></svg>
        <svg class="bat" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.6" fill="none" stroke="#fff" opacity=".4"/><rect x="2" y="2" width="20" height="9" rx="2.4"/><path d="M25 4.5v4c.8-.3 1.500-1.100 1.500-2s-.7-1.700-1.500-2z" opacity=".5"/></svg>
      </div>
      <section class="pd-display"><div class="pd-num"></div></section>
      <button class="pd-add" aria-label="Tilføj kontakt" hidden>
        <svg viewBox="0 0 30 30"><circle cx="18" cy="12.5" r="10.6" class="o"/><circle cx="18" cy="10" r="3.6" class="f"/><path d="M11.4 19.6c1.3-2.6 3.800-3.900 6.600-3.900s5.300 1.300 6.600 3.900" class="o"/><circle cx="8.6" cy="20.6" r="6.4" class="bg"/><circle cx="8.6" cy="20.6" r="5.4" class="o"/><path d="M8.6 17.6v6M5.6 20.6h6" class="o"/></svg>
      </button>
      <main class="pd-keys">${keyHtml}</main>
      <button class="pd-call" aria-label="Ring op"><img src="handset.png" alt="" draggable="false"></button>
      <button class="pd-del" aria-label="Slet" hidden><svg viewBox="0 0 34 24"><path class="f" d="M11 1.5h19.5a2.5 2.5 0 0 1 2.5 2.5v16a2.5 2.5 0 0 1-2.5 2.5H11L1.6 12z"/><path class="x" d="M16.6 7.6l8.8 8.8M25.4 7.6l-8.8 8.8"/></svg></button>
      <nav class="pd-tabbar">
        <div class="pd-tabs">
          <div class="pd-tab"><svg viewBox="0 0 28 28"><circle cx="14" cy="14" r="11.5" class="fill"/><path d="M13.4 7.4v7h-4.6" class="hand"/></svg><span>Opkald</span></div>
          <div class="pd-tab"><svg viewBox="0 0 28 28"><circle cx="14" cy="14" r="11.5" class="fill"/><circle cx="14" cy="11" r="4.2" class="cut"/><path d="M6.4 22c1.700-3.300 4.400-4.800 7.600-4.800s5.900 1.500 7.600 4.800a11.500 11.500 0 0 1-15.200 0z" class="cut"/></svg><span>Kontakter</span></div>
          <div class="pd-tab on"><svg viewBox="0 0 26 24" class="grid"><circle cx="4.5" cy="4" r="3.3"/><circle cx="13" cy="4" r="3.3"/><circle cx="21.5" cy="4" r="3.3"/><circle cx="4.5" cy="12" r="3.3"/><circle cx="13" cy="12" r="3.3"/><circle cx="21.5" cy="12" r="3.3"/><circle cx="4.5" cy="20" r="3.3"/><circle cx="13" cy="20" r="3.3"/><circle cx="21.5" cy="20" r="3.3"/></svg><span>Numerisk blok</span></div>
        </div>
        <div class="pd-search"><svg viewBox="0 0 24 24"><circle cx="10.2" cy="10.2" r="7"/><path d="M15.4 15.4l5.6 5.6"/></svg></div>
      </nav>
      <div class="home-bar"></div>
    </div>
  </div>
  <div class="ctrl">
    <input class="field" type="text" placeholder="Skriv ord eller tal, fx Kim Larsen" autocomplete="off" autocapitalize="off" spellcheck="false" maxlength="60">
    <div class="row"><button class="btn rnd">Tilfældig</button><button class="btn clr">Ryd</button></div>
    <div class="read"></div>
  </div>
</section>`;

// ---------- visning ----------
const stage = $('#stage');
const cells = new Map(); // id → element

function renderPhone(p, { keepInput = false } = {}) {
  const el = cells.get(p.id);
  if (!el) return;
  const typed = toTyped(p.src);
  const num = $('.pd-num', el);
  num.textContent = fmtNumber(typed);
  num.style.fontSize = '';
  const avail = num.clientWidth;
  if (num.scrollWidth > avail && avail) {
    const base = parseFloat(getComputedStyle(num).fontSize);
    num.style.fontSize = Math.max(base * 0.55, base * (avail / num.scrollWidth)) - 0.5 + 'px';
  }
  $('.pd-del', el).hidden = !typed;
  $('.pd-add', el).hidden = !typed;
  const inp = $('.field', el);
  if (!keepInput && inp.value !== p.src) inp.value = p.src;

  const read = $('.read', el);
  const d = typed.replace(/[^0-9]/g, '');
  if (!d) { read.innerHTML = '<span class="none">Skriv noget eller tryk på tasterne.</span>'; return; }
  const res = decode(idx, d, 4);
  const esc = (s) => s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  read.innerHTML = `<div class="digits">${groups(typed)}</div>`
    + (res.length
      ? `<div class="name">Appen læser: ${esc(res[0].text)}</div>${res.length > 1 ? `<div class="alt">Andre bud: ${res.slice(1).map((r) => esc(r.text)).join(' · ')}</div>` : ''}`
      : '<div class="none">Ingen ord matcher tallet</div>');
}
const renderAll = () => state.phones.forEach((p) => renderPhone(p));

function renumber() {
  state.phones.forEach((p, i) => { const h = $('.cell-head span', cells.get(p.id)); if (h) h.textContent = `Telefon ${i + 1}`; });
}

function addPhone(src = '', focus = true) {
  if (state.phones.length >= MAX_PHONES) return;
  const p = { id: ++uid, src };
  state.phones.push(p);
  mount(p);
  renumber();
  renderPhone(p);
  save();
  if (focus) $('.field', cells.get(p.id)).focus();
}
function mount(p) {
  const wrap = document.createElement('div');
  wrap.innerHTML = cellHtml(state.phones.indexOf(p) + 1).trim();
  const el = wrap.firstElementChild;
  el.dataset.id = p.id;
  cells.set(p.id, el);
  stage.appendChild(el);
}
function removePhone(id) {
  if (state.phones.length <= 1) { setSrc(state.phones[0], ''); return; }
  state.phones = state.phones.filter((p) => p.id !== id);
  cells.get(id)?.remove();
  cells.delete(id);
  renumber();
  save();
}
function setSrc(p, src, opts) { p.src = src; renderPhone(p, opts); save(); }
const rand = () => celebs[Math.floor(Math.random() * celebs.length)];

// ---------- hændelser ----------
const phoneOf = (t) => { const c = t.closest('.cell'); return c && state.phones.find((p) => p.id === +c.dataset.id); };

stage.addEventListener('input', (e) => {
  if (!e.target.classList.contains('field')) return;
  const p = phoneOf(e.target);
  if (p) setSrc(p, e.target.value, { keepInput: true });
});
stage.addEventListener('click', (e) => {
  const p = phoneOf(e.target);
  if (!p) return;
  if (e.target.closest('.rm')) removePhone(p.id);
  else if (e.target.closest('.rnd')) setSrc(p, rand());
  else if (e.target.closest('.clr')) setSrc(p, '');
});

// Tastetryk (samme Liquid Glass-fornemmelse som i appen)
let drag = null;
let holdTimer = null;
stage.addEventListener('pointerdown', (e) => {
  const k = e.target.closest('.pk');
  const del = e.target.closest('.pd-del');
  const p = phoneOf(e.target);
  if (!p || (!k && !del)) return;
  e.preventDefault();
  if (del) {
    setSrc(p, p.src.slice(0, -1));
    holdTimer = setTimeout(function rep() {
      if (!p.src) return;
      setSrc(p, p.src.slice(0, -1));
      holdTimer = setTimeout(rep, 110);
    }, 500);
    return;
  }
  try { k.setPointerCapture(e.pointerId); } catch { /* ok */ }
  drag = { k, x: e.clientX, y: e.clientY };
  k.classList.add('pressed');
  if (p.src.length < 60) setSrc(p, p.src + k.dataset.d);
});
stage.addEventListener('pointermove', (e) => {
  if (!drag) return;
  const b = drag.k;
  const size = b.offsetWidth;
  const lim = (v) => Math.max(-0.6, Math.min(0.6, v / size));
  const nx = lim(e.clientX - drag.x);
  const ny = lim(e.clientY - drag.y);
  const sx = 1.19 + 0.25 * Math.abs(nx) - 0.28 * Math.abs(ny);
  const sy = 1.19 + 0.25 * Math.abs(ny) - 0.28 * Math.abs(nx);
  const m = Math.min(sx, sy);
  b.style.setProperty('--tx', nx * 0.3 * size + 'px');
  b.style.setProperty('--ty', ny * 0.3 * size + 'px');
  b.style.setProperty('--s', m.toFixed(3));
  b.style.setProperty('--ex', (sx / m).toFixed(3));
  b.style.setProperty('--ey', (sy / m).toFixed(3));
});
const release = () => {
  clearTimeout(holdTimer);
  drag = null;
  document.querySelectorAll('.pk.pressed').forEach((k) => {
    k.classList.remove('pressed');
    ['--tx', '--ty', '--s', '--ex', '--ey'].forEach((v) => k.style.removeProperty(v));
  });
};
document.addEventListener('pointerup', release);
document.addEventListener('pointercancel', release);
stage.addEventListener('contextmenu', (e) => { if (e.target.closest('.pk')) e.preventDefault(); });

// Topbjælke
$('#add').addEventListener('click', () => addPhone());
$('#random-all').addEventListener('click', () => state.phones.forEach((p) => setSrc(p, rand())));
$('#clear-all').addEventListener('click', () => state.phones.forEach((p) => setSrc(p, '')));
$('#space0').addEventListener('change', (e) => { state.space0 = e.target.checked; save(); renderAll(); });
$('#size').addEventListener('input', (e) => { applySize(+e.target.value); save(); renderAll(); });
function applySize(v) { state.size = v; document.documentElement.style.setProperty('--W', v + 'px'); }

// ---------- start ----------
load();
$('#space0').checked = state.space0;
$('#size').value = state.size;
applySize(state.size);
state.phones.forEach((p) => mount(p));
renumber();
renderAll();
