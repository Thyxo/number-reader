// Talformatering efter dansk standard: "." som tusindtalsseparator og "," som decimaltegn.

// Cifre man kan taste i ét tal. iPhone-appen tillader lange tal (teksten krymper og glider ud
// til venstre); 16 er grænsen for hvad JavaScript kan regne præcist med.
export const MAX_INPUT_DIGITS = 16;
// Talstrømmen holder sig til 9 betydende cifre i decimaltal, så tallet ser "tastet" ud.
export const MAX_DIGITS = 9;

const OP_GLYPH = { '+': '+', '-': '−', '×': '×', '÷': '÷' };
export const opGlyph = (op) => OP_GLYPH[op] ?? op;

export function groupInt(intStr) {
  return intStr.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

// "1234,5" -> 1234.5
export function parseInput(text) {
  if (!text || text === ',') return 0;
  const v = parseFloat(text.replace(',', '.'));
  return Number.isNaN(v) ? 0 : v;
}

export function countDigits(text) {
  return (text.match(/\d/g) || []).length;
}

// Indtastet tekst ("5634,") -> visningstekst ("5.634,")
export function formatInput(text, neg = false) {
  const [i, d] = (text || '0').split(',');
  let s = groupInt(i === '' ? '0' : i);
  if (text.includes(',')) s += ',' + (d ?? '');
  return (neg ? '-' : '') + s;
}

function trimZeros(s) {
  return s.includes('.') ? s.replace(/\.?0+$/, '') : s;
}

// Udfolder "1.23e-7" til "0.000000123"
function expand(str) {
  if (!/e/i.test(str)) return str;
  const [mant, expStr] = str.toLowerCase().split('e');
  const exp = parseInt(expStr, 10);
  const neg = mant.startsWith('-');
  const [ip, fp = ''] = mant.replace('-', '').split('.');
  const digits = ip + fp;
  let point = ip.length + exp;
  let out;
  if (point <= 0) out = '0.' + '0'.repeat(-point) + digits;
  else if (point >= digits.length) out = digits + '0'.repeat(point - digits.length);
  else out = digits.slice(0, point) + '.' + digits.slice(point);
  return (neg ? '-' : '') + out;
}

// Plain tal-streng uden gruppering, punktum som decimal ("1234.5"), afrundet til 12 betydende cifre.
export function plainNumber(v) {
  if (!Number.isFinite(v)) return 'NaN';
  if (v === 0) return '0';
  const abs = Math.abs(v);
  let s = Number.isInteger(abs) && abs < 1e16 ? String(abs) : trimZeros(expand(abs.toPrecision(12)));
  return (v < 0 ? '-' : '') + s;
}

// Resultat til visning: "1.234.567,89", "1,234568e16", "Fejl"
export function formatNumber(v) {
  if (!Number.isFinite(v)) return 'Fejl';
  if (v === 0) return '0';
  const abs = Math.abs(v);
  const sign = v < 0 ? '-' : '';
  if (abs >= 1e16 || abs < 1e-9) {
    let [m, e] = abs.toExponential(8).split('e');
    m = trimZeros(m);
    return sign + m.replace('.', ',') + 'e' + parseInt(e, 10);
  }
  const s = plainNumber(abs);
  const [ip, fp] = s.split('.');
  return sign + groupInt(ip) + (fp ? ',' + fp : '');
}

// Visningstekst -> tal (til "Indsæt"): accepterer "1.234,5", "1234.5", "1234,5"
export function parseDisplay(str) {
  let s = String(str).trim().replace(/\s/g, '').replace('−', '-');
  if (!s) return NaN;
  if (s.includes(',')) s = s.replace(/\./g, '').replace(',', '.');
  else if (/^\-?\d{1,3}(\.\d{3})+$/.test(s)) s = s.replace(/\./g, '');
  const v = Number(s);
  return Number.isFinite(v) ? v : NaN;
}
