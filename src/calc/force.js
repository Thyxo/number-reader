// Force-motoren: udregner hvilket tal der skal "streames" ind, så udtrykket rammer målet.
import { MAX_DIGITS, MAX_INPUT_DIGITS, formatNumber, parseInput } from './format.js';

export const OPS = ['+', '-', '×', '÷'];

export function numValue(tok) {
  const v = tok.fixed !== undefined ? tok.fixed : parseInput(tok.text);
  return tok.neg ? -v : v;
}

// Evaluerer tokens med almindelig regnehierarki (× og ÷ før + og −) og iPhone-procent:
// "a + b%" = a + a·b/100, "a × b%" = a · b/100.
export function evaluate(tokens) {
  let sum = 0;
  let term = null;
  let op = null;
  for (const tok of tokens) {
    if (tok.t === 'o') { op = tok.op; continue; }
    let v = numValue(tok);
    if (tok.pct) {
      if ((op === '+' || op === '-') && term !== null) v = (sum + term) * v / 100;
      else v = v / 100;
    }
    if (term === null) term = v;
    else if (op === '+') { sum += term; term = v; }
    else if (op === '-') { sum += term; term = -v; }
    else if (op === '×') term *= v;
    else if (op === '÷') term = v === 0 ? NaN : term / v;
  }
  return term === null ? 0 : sum + term;
}

// Tal -> indtastningstekst med højst `maxDigits` cifre ("1952,05")
export function represent(v, maxDigits = MAX_DIGITS) {
  const neg = v < 0;
  const abs = Math.abs(v);
  if (!Number.isFinite(abs) || abs >= 1e21) return null;
  const intDigits = abs < 1 ? 1 : String(Math.trunc(abs)).length;
  const decimals = Math.min(20, Math.max(0, maxDigits - intDigits));
  let fixed = abs.toFixed(decimals);
  if (fixed.includes('.')) fixed = fixed.replace(/\.?0+$/, '');
  const rounded = Number(fixed);
  const text = fixed.replace('.', ',');
  const dec = text.includes(',') ? text.split(',')[1].length : 0;
  return {
    text,
    neg: neg && rounded !== 0,
    value: neg ? -rounded : rounded,
    intDigits: String(Math.trunc(rounded)).length,
    decimals: dec,
  };
}

// "58,79" -> ["5","8",",7","9"]: kommaet følger med det næste ciffer, så ét tryk = ét nyt ciffer.
export function toUnits(text) {
  const units = [];
  for (let i = 0; i < text.length; i++) {
    if (text[i] === ',' && i + 1 < text.length) { units.push(',' + text[i + 1]); i++; }
    else units.push(text[i]);
  }
  return units;
}

function solveFor(prefix, op, target) {
  const f = (x) => evaluate(op
    ? [...prefix, { t: 'o', op }, { t: 'n', fixed: x }]
    : [{ t: 'n', fixed: x }]);
  if (op === '÷') {
    // f(x) = a + b/x
    const f1 = f(1), f2 = f(2);
    const b = 2 * (f1 - f2), a = f1 - b;
    if (!Number.isFinite(b) || b === 0 || target === a) return null;
    return { v: b / (target - a), f };
  }
  // f(x) = a + b·x
  const f0 = f(0), f1 = f(1);
  const b = f1 - f0, a = f0;
  if (!Number.isFinite(b) || b === 0) return null;
  return { v: (target - a) / b, f };
}

/**
 * Finder det mest troværdige tal x, så `prefix op x` = target.
 * Lav score = mere troværdigt. Score >= 1000 betyder "umuligt/mistænkeligt".
 */
export function planForce({ prefix = [], op = null, target, tokenNeg = false, maxDigits = MAX_DIGITS, allowSwap = true }) {
  const ops = op === null ? [null] : allowSwap ? [op, ...OPS.filter((o) => o !== op)] : [op];
  const targetText = formatNumber(target);
  const tol = 1e-6 * Math.max(1, Math.abs(target));
  let best = null;
  for (const o of ops) {
    const sol = solveFor(prefix, o, target);
    if (!sol || !Number.isFinite(sol.v)) continue;
    const rep = represent(sol.v, maxDigits);
    if (!rep) continue;
    const check = sol.f(rep.value);
    const exact = formatNumber(check) === targetText;
    const close = Math.abs(check - target) <= tol;
    const notes = [];
    let score = 0;
    if (o !== op) { score += 100; notes.push(`operator skiftet ${op} → ${o}`); }
    if (rep.neg !== tokenNeg) { score += 1000; notes.push('kræver fortegnsskift'); }
    if (rep.value === 0) { score += 500; notes.push('tallet bliver 0'); }
    if ((o === '×' || o === '÷') && Math.abs(rep.value) === 1) { score += 300; notes.push('tallet bliver 1'); }
    if (rep.value !== 0 && Math.abs(rep.value) < 1) { score += 80; notes.push('tallet starter med 0,'); }
    if (!exact) { score += 20; notes.push('afrundet (resultatet vises som målet)'); }
    if (!close) { score += 2000; notes.push('for stor afrundingsfejl'); }
    if (rep.intDigits > MAX_INPUT_DIGITS) { score += 400; notes.push(`over ${MAX_INPUT_DIGITS} cifre`); }
    score += rep.decimals * 2;
    const cand = {
      ok: true, op: o, value: rep.value, text: rep.text, neg: rep.neg,
      units: toUnits(rep.text), exact, close, score, notes, check,
    };
    if (!best || cand.score < best.score) best = cand;
  }
  if (!best) return { ok: false, score: Infinity, notes: ['ingen løsning (fx division med 0)'] };
  if (best.score >= 1000) best.ok = false;
  return best;
}
