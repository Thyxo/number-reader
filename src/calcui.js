// Lommeregner-UI – taget fra Thyxo/Calcplus (src/app.js) uden force, Noter+-forbindelse og panel.
import { Calculator } from './calc/calculator.js';
import { parseDisplay } from './calc/format.js';

const $ = (sel) => document.querySelector(sel);

export function initCalc({ onArmTap = () => {}, isSecretOpen = () => false } = {}) {
  const app = $('#app');
  const elMain = $('#main');
  const elExpr = $('#expr');
  const elClear = $('#key-clear .txt');

  const calc = new Calculator({ settings: { enabled: false } });

  // ---------- historik (gemmes lokalt som på iPhone) ----------
  const HKEY = 'nr.calc.history.v1';
  try { calc.history = JSON.parse(localStorage.getItem(HKEY) || '[]'); } catch { calc.history = []; }
  const saveHistory = () => { try { localStorage.setItem(HKEY, JSON.stringify(calc.history.slice(-100))); } catch { /* ok */ } };

  const esc = (s) => s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  const partsHTML = (parts) => '<span class="inner">' + parts.map((p) => `<span class="${p.kind}">${esc(p.text)}</span>`).join('') + '</span>';

  function fit(line, minScale) {
    line.style.fontSize = '';
    line.classList.remove('overflow');
    const inner = line.firstElementChild;
    if (!inner) return;
    const avail = line.clientWidth;
    const w = inner.getBoundingClientRect().width;
    if (w <= avail || !avail) return;
    const base = parseFloat(getComputedStyle(line).fontSize);
    const scale = Math.max(minScale, avail / w);
    line.style.fontSize = base * scale - 0.01 + 'px';
    if (inner.getBoundingClientRect().width > avail + 0.5) line.classList.add('overflow');
  }

  let lastHistLen = calc.history.length;
  function render() {
    const v = calc.getView();
    elMain.innerHTML = partsHTML(v.main);
    elExpr.innerHTML = v.expr ? partsHTML(v.expr) : '';
    fit(elMain, 0.76);
    if (v.expr) fit(elExpr, 0.6);
    elClear.textContent = v.clearLabel;
    document.querySelectorAll('.key.op').forEach((b) => b.classList.toggle('active', v.activeOp === b.dataset.key));
    if (calc.history.length !== lastHistLen) { lastHistLen = calc.history.length; saveHistory(); }
  }

  function pressKey(k) {
    calc.press(k);
    render();
  }

  const pressedEls = new Set();
  const drags = new Map();
  function press(el) { el.classList.add('pressed'); pressedEls.add(el); }
  function resetStretch(el) {
    el.classList.remove('drag');
    ['--tx', '--ty', '--s', '--ex', '--ey'].forEach((p) => el.style.removeProperty(p));
  }
  function releaseAll() {
    pressedEls.forEach((el) => { el.classList.remove('pressed'); resetStretch(el); });
    pressedEls.clear();
    drags.clear();
  }
  document.addEventListener('pointerup', releaseAll);
  document.addEventListener('pointercancel', releaseAll);

  $('#keypad').addEventListener('pointerdown', (e) => {
    const btn = e.target.closest('.key');
    if (!btn) return;
    e.preventDefault();
    hideBubble();
    try { btn.setPointerCapture(e.pointerId); } catch { /* ok */ }
    drags.set(e.pointerId, { btn, x: e.clientX, y: e.clientY });
    press(btn);
    pressKey(btn.dataset.key);
  });

  // Knappen strækker sig mod fingeren, når man trækker
  $('#keypad').addEventListener('pointermove', (e) => {
    const d = drags.get(e.pointerId);
    if (!d) return;
    const size = d.btn.offsetWidth;
    const lim = (v) => Math.max(-0.6, Math.min(0.6, v / size));
    const nx = lim(e.clientX - d.x);
    const ny = lim(e.clientY - d.y);
    const ax = Math.abs(nx);
    const ay = Math.abs(ny);
    d.btn.classList.add('drag');
    d.btn.style.setProperty('--tx', nx * 0.3 * size + 'px');
    d.btn.style.setProperty('--ty', ny * 0.3 * size + 'px');
    const sx = 1.19 + 0.25 * ax - 0.28 * ay;
    const sy = 1.19 + 0.25 * ay - 0.28 * ax;
    const k = Math.min(sx, sy);
    d.btn.style.setProperty('--s', k.toFixed(3));
    d.btn.style.setProperty('--ex', (sx / k).toFixed(3));
    d.btn.style.setProperty('--ey', (sy / k).toFixed(3));
  });
  $('#keypad').addEventListener('contextmenu', (e) => e.preventDefault());

  const KEYMAP = { '*': '×', x: '×', X: '×', '/': '÷', ':': '÷', '+': '+', '-': '-', Enter: '=', '=': '=', Backspace: 'back', Escape: 'clear', Delete: 'clear', '%': 'pct', ',': ',', '.': ',' };
  document.addEventListener('keydown', (e) => {
    if (document.body.dataset.mode !== 'calc') return;
    if (e.target.closest('input, select, textarea')) return;
    if (isSecretOpen() || !$('#history').hidden) return;
    const k = /^[0-9]$/.test(e.key) ? e.key : KEYMAP[e.key];
    if (!k) return;
    e.preventDefault();
    const btn = document.querySelector(`.key[data-key="${CSS.escape(k)}"]`);
    if (btn) { press(btn); setTimeout(releaseAll, 90); }
    pressKey(k);
  });

  // ---------- display: swipe for at slette, hold for at kopiere ----------
  const bubble = $('#copy-bubble');
  let dGesture = null;
  $('#display').addEventListener('pointerdown', (e) => {
    hideBubble();
    dGesture = { x: e.clientX, y: e.clientY, swiped: false, timer: setTimeout(showBubble, 520) };
  });
  $('#display').addEventListener('pointermove', (e) => {
    if (!dGesture) return;
    const dx = e.clientX - dGesture.x;
    const dy = e.clientY - dGesture.y;
    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) clearTimeout(dGesture.timer);
    if (!dGesture.swiped && Math.abs(dx) > 34 && Math.abs(dy) < 40) {
      dGesture.swiped = true;
      calc.press('back');
      render();
    }
  });
  const endDisplay = () => { if (dGesture) clearTimeout(dGesture.timer); dGesture = null; };
  $('#display').addEventListener('pointerup', endDisplay);
  $('#display').addEventListener('pointercancel', endDisplay);

  function showBubble() {
    const r = elMain.firstElementChild.getBoundingClientRect();
    bubble.hidden = false;
    const bw = bubble.offsetWidth;
    const left = Math.max(8, Math.min(window.innerWidth - bw - 8, r.right - r.width / 2 - bw / 2));
    bubble.style.left = left + 'px';
    bubble.style.top = Math.max(8, r.top - bubble.offsetHeight - 6) + 'px';
  }
  function hideBubble() { bubble.hidden = true; }
  bubble.addEventListener('pointerdown', async (e) => {
    e.preventDefault();
    e.stopPropagation();
    const act = e.target.closest('button')?.dataset.act;
    hideBubble();
    if (act === 'copy') {
      const text = calc.displayValue().replace(/\.(?=\d{3})/g, '');
      try { await navigator.clipboard.writeText(text); } catch { /* ingen adgang */ }
    } else if (act === 'paste') {
      try {
        const v = parseDisplay(await navigator.clipboard.readText());
        if (Number.isFinite(v)) { calc.insertValue(v); render(); }
      } catch { /* ingen adgang */ }
    }
  });
  document.addEventListener('pointerdown', (e) => { if (!bubble.hidden && !bubble.contains(e.target) && !e.target.closest('#display')) hideBubble(); });

  // ---------- menu ----------
  const menu = $('#mode-menu');
  const scrim = $('#menu-scrim');
  function openMenu() { menu.hidden = false; scrim.hidden = false; menu.classList.remove('out'); }
  function closeMenu() {
    if (menu.hidden) return;
    menu.classList.add('out');
    scrim.hidden = true;
    setTimeout(() => { menu.hidden = true; menu.classList.remove('out'); }, 160);
  }
  $('#btn-mode').addEventListener('click', () => (menu.hidden ? openMenu() : closeMenu()));
  scrim.addEventListener('pointerdown', (e) => { e.preventDefault(); closeMenu(); });
  menu.addEventListener('click', () => closeMenu());
  document.querySelectorAll('.round-btn').forEach((b) => b.addEventListener('pointerdown', () => press(b)));

  // ---------- historik ----------
  const hist = $('#history');
  $('#btn-history').addEventListener('click', () => { openSheet(hist); renderHistory(); });
  function renderHistory() {
    const list = $('#history-list');
    const items = calc.history.slice().reverse();
    $('#history-empty').hidden = items.length > 0;
    list.innerHTML = items.map((h, i) => `<li data-i="${i}"><div class="h-expr">${esc(h.expr)}</div><div class="h-res">${esc(h.result)}</div></li>`).join('');
  }
  $('#history-list').addEventListener('click', (e) => {
    const li = e.target.closest('li');
    if (!li) return;
    const h = calc.history.slice().reverse()[Number(li.dataset.i)];
    const v = parseDisplay(h.result);
    if (Number.isFinite(v)) { calc.insertValue(v); render(); }
    closeSheet(hist);
  });
  $('#history-clear').addEventListener('click', () => { calc.history = []; lastHistLen = -1; render(); renderHistory(); });
  $('#history-done').addEventListener('click', () => closeSheet(hist));
  function openSheet(el) { el.hidden = false; el.classList.remove('out'); }
  function closeSheet(el) {
    el.classList.add('out');
    setTimeout(() => { el.hidden = true; el.classList.remove('out'); }, 220);
  }

  // Tryk mellem de to runde knapper = start/stop scanning
  $('#arm-zone').addEventListener('pointerdown', () => onArmTap());

  // ---------- højde: iOS-fejl i hjemmeskærm-apps ----------
  // Fra hjemmeskærmen (black-translucent + viewport-fit=cover) bliver siden ca. 59 pt (statuslinjen)
  // for lav, og iOS melder det ikke altid i innerHeight. Derfor får html, body og alle faste lag
  // ALTID skærmens fulde højde i px, når appen kører fra hjemmeskærmen i portræt (som Stopwatchplus).
  const isStandalone = () => navigator.standalone === true || matchMedia('(display-mode: standalone)').matches;
  let heightFixed = false;
  let vAdjust = 0;
  const LAYERS = ['#app', '#pad', '#secret', '#history', '#peek-screen', '#menu-scrim', '#debug'];
  function fixHeight(adj = vAdjust) {
    vAdjust = Number(adj) || 0;
    heightFixed = isStandalone() && innerHeight > innerWidth && screen.height >= innerHeight;
    const h = heightFixed ? screen.height + 'px' : '';
    document.documentElement.style.height = h;
    for (const el of [document.body, ...LAYERS.map((q) => $(q))]) {
      if (!el) continue;
      el.style.height = h;
      el.style.bottom = heightFixed ? 'auto' : '';
    }
    for (const el of [app, $('#pad')]) el.style.setProperty('--v-adjust', vAdjust + 'px');
  }
  const refit = () => { fixHeight(); render(); };
  window.addEventListener('resize', refit);
  window.addEventListener('orientationchange', () => setTimeout(refit, 300));
  window.addEventListener('pageshow', refit);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refit(); });
  // iOS kan ændre højden lige efter start uden at sende resize
  [100, 400, 1000, 2500].forEach((ms) => setTimeout(refit, ms));

  function screenInfo() {
    const probe = document.createElement('div');
    probe.style.cssText = 'position:fixed;top:env(safe-area-inset-top);bottom:env(safe-area-inset-bottom)';
    document.body.appendChild(probe);
    const st = getComputedStyle(probe);
    const shown = document.body.dataset.mode === 'calc' ? app : $('#pad');
    const info = `skærm ${screen.width}×${screen.height} · vindue ${innerWidth}×${innerHeight} · app ${Math.round(shown.getBoundingClientRect().height)} · safe ${parseFloat(st.top) || 0}/${parseFloat(st.bottom) || 0} · ${isStandalone() ? 'hjemmeskærm' : 'browser'} · ${heightFixed ? 'højde RETTET' : 'ikke rettet'}`;
    probe.remove();
    return info;
  }

  if (document.fonts && document.fonts.ready) document.fonts.ready.then(render);
  render();
  // Sæt et tal i displayet, som om det var tastet (regnemetoden)
  function enter(digits) {
    calc.press('clear'); calc.press('clear');
    for (const d of String(digits)) if (/\d/.test(d)) calc.press(d);
    render();
  }

  return { render, closeMenu, fixHeight, screenInfo, enter };
}
