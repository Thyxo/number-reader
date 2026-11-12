// Regnemetoden: y − x = a. x = tilskuerens tal (scannet), y = det tvungne tal, a = mit tal.
// Tilskueren regner bagefter x + a på lommeregneren og får y (fx personens fødselsdag).
// Er x større end y, bliver a negativt: så vises |a|, og regnestykket er x − a.
// Ingen DOM – testes med `npm test`.
import { BDAYS } from './words.js';

const pad = (n) => String(n).padStart(2, '0');

/** "1946-06-14" / "14.06.1946" / "14-6-46" → {d, m, y} eller null */
export function parseDate(s) {
  s = String(s || '').trim();
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (m) return { y: +m[1], m: +m[2], d: +m[3] };
  m = s.match(/^(\d{1,2})[./ -](\d{1,2})[./ -](\d{2,4})$/);
  if (m) return { d: +m[1], m: +m[2], y: +m[3] };
  m = s.match(/^(\d{2})(\d{2})(\d{2}|\d{4})$/);
  if (m) return { d: +m[1], m: +m[2], y: +m[3] };
  return null;
}

/** Dato som tal-streng i valgt format: ddmmyy · ddmmyyyy · yyyymmdd · ddmm */
export function fmtDate({ d, m, y }, fmt = 'ddmmyy') {
  if (fmt === 'ddmmyyyy') return pad(d) + pad(m) + String(y).padStart(4, '0');
  if (fmt === 'yyyymmdd') return String(y).padStart(4, '0') + pad(m) + pad(d);
  if (fmt === 'ddmm') return pad(d) + pad(m);
  return pad(d) + pad(m) + pad(y % 100);
}

/** Fødselsdag for et navn: egne navne ("Navn | 14.06.1946") vinder over listen. */
export function birthdayOf(name, custom = []) {
  if (!name) return null;
  const low = name.toLowerCase();
  for (const line of custom) {
    const [n, d] = String(line).split('|').map((x) => x.trim());
    if (d && n.toLowerCase() === low) return parseDate(d);
  }
  for (const [n, d] of Object.entries(BDAYS)) if (n.toLowerCase() === low) return parseDate(d);
  return null;
}

/**
 * Find y. src: birthday | today | clock | fixed. Fødselsdag uden kendt dato falder tilbage til
 * det faste tal, ellers dagens dato. Returnerer {y, label}.
 */
export function target({ src = 'birthday', fmt = 'ddmmyy', fixed = '', clockAdd = 0, name = '', custom = [], now = new Date() } = {}) {
  const fixedDigits = String(fixed).replace(/\D/g, '');
  if (src === 'birthday') {
    const b = birthdayOf(name, custom);
    if (b) return { y: fmtDate(b, fmt), label: 'fødselsdag' };
    if (fixedDigits) return { y: fixedDigits, label: 'fast tal (ingen fødselsdag)' };
    return { y: fmtDate({ d: now.getDate(), m: now.getMonth() + 1, y: now.getFullYear() }, fmt), label: 'dato i dag (ingen fødselsdag)' };
  }
  if (src === 'today') return { y: fmtDate({ d: now.getDate(), m: now.getMonth() + 1, y: now.getFullYear() }, fmt), label: 'dato i dag' };
  if (src === 'clock') {
    const t = new Date(now.getTime() + (Number(clockAdd) || 0) * 60000);
    return { y: pad(t.getHours()) + pad(t.getMinutes()), label: 'klokken' };
  }
  return { y: fixedDigits || '0', label: 'fast tal' };
}

/** a = y − x med store tal. Returnerer {a: '123', neg: bool} – neg = regnestykket er x − a. */
export function solve(x, y) {
  const X = BigInt(String(x).replace(/\D/g, '') || '0');
  const Y = BigInt(String(y).replace(/\D/g, '') || '0');
  const a = Y - X;
  return { a: (a < 0n ? -a : a).toString(), neg: a < 0n };
}
