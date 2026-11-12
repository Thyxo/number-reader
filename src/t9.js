// T9-dekoder: tal tastet på telefonens numeriske blok → mest sandsynlige dansk ord/navn.
// Ingen DOM – testes med `npm test`.
import { CELEBS, FIRST, LAST, WORDS } from './words.js';

const GROUPS = {
  2: 'abcæåäáàâ', 3: 'defèéëê', 4: 'ghiíïî', 5: 'jkl', 6: 'mnoøöóô', 7: 'pqrsß', 8: 'tuvüúùû', 9: 'wxyzý',
};
const MAP = {};
for (const [d, letters] of Object.entries(GROUPS)) for (const ch of letters) if (ch !== ' ') MAP[ch] = d;

/** Bogstaver → cifre ("Kim Larsen" → "54652736"). Andre tegn springes over. */
export function toDigits(word) {
  let out = '';
  for (const ch of String(word).toLowerCase()) if (MAP[ch]) out += MAP[ch];
  return out;
}

const cap = (w) => w.charAt(0).toUpperCase() + w.slice(1);

// Point: højere = mere sandsynligt
const W = { custom: 2000, celeb: 1000, celebPart: 520, first: 470, last: 430, word: 300 };

export function buildIndex({ celebs = true, names = true, words = true, custom = [] } = {}) {
  const exact = new Map();  // cifre → [{text, score, kind}]
  const firstIdx = new Map(); // venstre del af "Fornavn Efternavn"
  const lastIdx = new Map();  // højre del
  const add = (map, digits, text, score, kind) => {
    if (digits.length < 2) return;
    let arr = map.get(digits);
    if (!arr) map.set(digits, (arr = []));
    const low = text.toLowerCase();
    const prev = arr.find((e) => e.text.toLowerCase() === low);
    if (prev) { if (score > prev.score) { prev.score = score; prev.kind = kind; prev.text = text; } return; }
    arr.push({ text, score, kind });
  };

  custom.forEach((c, i) => {
    const t = String(c).trim();
    if (!t) return;
    add(exact, toDigits(t), t, W.custom - i, 'custom');
    const parts = t.split(/\s+/);
    if (parts.length > 1) { add(firstIdx, toDigits(parts[0]), parts[0], W.custom - i, 'custom'); add(lastIdx, toDigits(parts.slice(1).join('')), parts.slice(1).join(' '), W.custom - i, 'custom'); }
  });

  if (celebs) {
    CELEBS.split('|').forEach((c, i) => {
      const s = W.celeb - i * 0.3;
      add(exact, toDigits(c), c, s, 'celeb');
      const parts = c.split(/\s+/);
      if (parts.length > 1) {
        const f = parts[0];
        const l = parts[parts.length - 1];
        add(exact, toDigits(f), f, W.celebPart - i * 0.1, 'celebPart');
        add(exact, toDigits(l), l, W.celebPart - i * 0.1, 'celebPart');
        add(firstIdx, toDigits(f), f, W.celebPart, 'celebPart');
        add(lastIdx, toDigits(l), l, W.celebPart, 'celebPart');
      }
    });
  }
  if (names) {
    FIRST.split(' ').forEach((n, i) => {
      const s = W.first - i * 0.4;
      add(exact, toDigits(n), n, s, 'first');
      add(firstIdx, toDigits(n), n, s, 'first');
      add(lastIdx, toDigits(n), n, s - 60, 'first'); // "Anne Marie", "Jens Peter"
    });
    LAST.split(' ').forEach((n, i) => {
      const s = W.last - i * 0.5;
      add(exact, toDigits(n), n, s, 'last');
      add(lastIdx, toDigits(n), n, s, 'last');
    });
  }
  if (words) {
    const list = WORDS.split(' ');
    const n = list.length;
    list.forEach((w, i) => {
      // Hyppige ord først; logaritmisk fald fra 300 til ca. 40
      const s = W.word * (1 - 0.87 * Math.log(i + 1) / Math.log(n));
      add(exact, toDigits(w), cap(w), s, 'word');
      if (w.length >= 3) add(lastIdx, toDigits(w), cap(w), s * 0.6, 'word');
    });
  }
  for (const m of [exact, firstIdx, lastIdx]) for (const arr of m.values()) arr.sort((a, b) => b.score - a.score);
  return { exact, firstIdx, lastIdx };
}

function decodeSegment(idx, s, max) {
  const out = [];
  for (const e of idx.exact.get(s) || []) out.push({ ...e });
  // To dele: "Mette" + "Jensen"
  if (s.length >= 4) {
    for (let i = 2; i <= s.length - 2; i++) {
      const L = idx.firstIdx.get(s.slice(0, i));
      const R = idx.lastIdx.get(s.slice(i));
      if (!L || !R) continue;
      for (const l of L.slice(0, 3)) {
        for (const r of R.slice(0, 3)) {
          if (l.kind === 'word' || l.text.includes('.')) continue;
          const text = `${l.text} ${r.text}`;
          const score = r.kind === 'word' ? Math.min(l.score, r.score) * 0.7 : Math.min(l.score, r.score) * 0.85 + 20;
          out.push({ text, score, kind: 'pair' });
        }
      }
    }
  }
  const seen = new Set();
  return out
    .sort((a, b) => b.score - a.score)
    .filter((e) => { const k = e.text.toLowerCase(); if (seen.has(k)) return false; seen.add(k); return true; })
    .slice(0, max);
}

/**
 * Dekod en talstreng. 0 og 1 har ingen bogstaver, så de tolkes som mellemrum.
 * Returnerer [{text, score, kind}] – bedste først.
 */
export function decode(idx, digits, max = 5) {
  const clean = String(digits).replace(/[^0-9]/g, '');
  const segs = clean.split(/[01]+/).filter(Boolean);
  if (!segs.length) return [];
  if (segs.length === 1) return decodeSegment(idx, segs[0], max);
  // Flere ord: kombinér de bedste bud for hvert ord
  const per = segs.map((s) => {
    const r = decodeSegment(idx, s, 3);
    return r.length ? r : [{ text: s, score: 0, kind: 'none' }];
  });
  let combos = [{ text: '', score: 0 }];
  for (const opts of per) {
    const next = [];
    for (const c of combos) for (const o of opts) next.push({ text: c.text ? `${c.text} ${o.text}` : o.text, score: c.score + o.score });
    combos = next.sort((a, b) => b.score - a.score).slice(0, 12);
  }
  // Står hele navnet i listen (fx "Kim Larsen" tastet med 0 som mellemrum), vinder det
  const whole = (idx.exact.get(segs.join('')) || []).filter((e) => e.kind === 'celeb' || e.kind === 'custom');
  const res = [...whole.map((e) => ({ ...e })), ...combos.map((c) => ({ ...c, score: c.score / per.length, kind: 'multi' }))];
  const seen = new Set();
  return res.filter((e) => { const k = e.text.toLowerCase(); if (seen.has(k)) return false; seen.add(k); return true; }).slice(0, max);
}
