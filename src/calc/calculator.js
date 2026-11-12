// Lommeregner-motor uden DOM. UI'et kalder press(key) og tegner getView().
import { MAX_INPUT_DIGITS, countDigits, formatInput, formatNumber, opGlyph } from './format.js';
import { evaluate, numValue, planForce } from './force.js';
import { DEFAULTS, resolveTarget } from './settings.js';

const isOp = (k) => k === '+' || k === '-' || k === '×' || k === '÷';
const MAX_LOG = 150;

function newCalcState(continued = false) {
  return { continued, stream: null, followUp: false, target: null };
}

function tokenKey(t) {
  if (t.t === 'o') return t.op;
  const v = t.fixed !== undefined ? 'f' + t.fixed : t.text;
  return (t.neg ? '-' : '') + v + (t.pct ? '%' : '');
}

export function renderToken(tok, wrapNeg) {
  if (tok.t === 'o') return opGlyph(tok.op);
  let s;
  if (tok.fixed !== undefined) {
    const v = tok.neg ? -tok.fixed : tok.fixed;
    s = formatNumber(v);
  } else {
    s = formatInput(tok.text || '0', tok.neg);
  }
  if (tok.pct) s += '%';
  if (wrapNeg && s.startsWith('-')) s = '(' + s + ')';
  return s;
}

export function renderTokens(tokens) {
  const wrap = tokens.length > 1;
  return tokens.map((t) => ({ kind: t.t === 'o' ? 'op' : 'num', text: renderToken(t, wrap) }));
}

export const tokensText = (tokens) => renderTokens(tokens).map((p) => p.text).join('');

export class Calculator {
  constructor({ settings = {}, now = () => new Date(), onLog = null } = {}) {
    this.settings = { ...DEFAULTS, ...settings };
    this.now = now;
    this.onLog = onLog;
    this.logs = [];
    this.history = [];
    this.forceRt = { hits: 0, manualArmed: false, memory: new Map() };
    this.repeat = null;
    this.reset();
  }

  // ---------- offentlig API ----------

  press(key) {
    if (/^[0-9]$/.test(key)) this.digit(key);
    else if (key === ',') this.comma();
    else if (isOp(key)) this.operator(key);
    else if (key === '=') this.equals();
    else if (key === 'pm') this.plusMinus();
    else if (key === 'pct') this.percent();
    else if (key === 'clear') this.clear();
    else if (key === 'back') this.back();
  }

  pressAll(seq) {
    for (const k of seq) this.press(k);
    return this;
  }

  setSettings(patch) {
    const before = this.settings;
    this.settings = { ...this.settings, ...patch };
    if (patch.uses !== undefined || (patch.enabled && !before.enabled)) this.forceRt.hits = 0;
  }

  panic() {
    this.settings = { ...this.settings, enabled: false };
    this.forceRt = { hits: 0, manualArmed: false, memory: new Map() };
    if (this.calc.stream) this.calc.stream = null;
    this.calc.followUp = false;
    this.log('PANIK: force slået fra – almindelig lommeregner');
  }

  armManual() {
    this.forceRt.manualArmed = true;
    this.log('Manuel trigger: næste tal streames');
  }

  resetHits() {
    this.forceRt.hits = 0;
    this.log('Tæller nulstillet');
  }

  target() {
    return resolveTarget(this.settings, this.now());
  }

  forceArmed() {
    const s = this.settings;
    if (!s.enabled) return false;
    if (s.uses > 0 && this.forceRt.hits >= s.uses) return false;
    if (s.trigger === 'manual' && !this.forceRt.manualArmed) return false;
    return true;
  }

  getView() {
    const v = { error: this.error, clearLabel: this.clearLabel(), activeOp: null, expr: null, main: null, armed: this.forceArmed() };
    if (this.error) {
      v.main = [{ kind: 'num', text: 'Fejl' }];
      if (this.resultTokens) v.expr = renderTokens(this.resultTokens);
    } else if (this.phase === 'result') {
      v.main = [{ kind: 'num', text: formatNumber(this.result) }];
      v.expr = renderTokens(this.resultTokens);
    } else if (!this.tokens.length) {
      v.main = [{ kind: 'num', text: '0' }];
    } else {
      v.main = renderTokens(this.tokens);
      const last = this.tokens[this.tokens.length - 1];
      if (last.t === 'o') v.activeOp = last.op;
    }
    return v;
  }

  // Ren tekst af det store display (til kopiering)
  displayValue() {
    if (this.error) return 'Fejl';
    if (this.phase === 'result') return formatNumber(this.result);
    const last = this.tokens[this.tokens.length - 1];
    if (!last) return '0';
    if (this.tokens.length === 1 && last.t === 'n') return renderToken(last, false);
    return tokensText(this.tokens);
  }

  // Indsæt et tal (fra udklipsholderen) som aktuelt tal
  insertValue(v) {
    if (!Number.isFinite(v)) return;
    if (this.phase === 'result' || this.error) this.newCalc();
    const last = this.tokens[this.tokens.length - 1];
    const tok = { t: 'n', fixed: Math.abs(v), neg: v < 0 };
    if (last && last.t === 'n') this.tokens[this.tokens.length - 1] = tok;
    else this.tokens.push(tok);
  }

  // ---------- intern tilstand ----------

  reset() {
    this.tokens = [];
    this.phase = 'input';
    this.result = 0;
    this.resultTokens = null;
    this.error = false;
    this.calc = newCalcState();
  }

  newCalc(continued = false) {
    this.tokens = [];
    this.phase = 'input';
    this.resultTokens = null;
    this.error = false;
    this.calc = newCalcState(continued);
  }

  clearLabel() {
    return !this.tokens.length && this.phase === 'input' && !this.error ? 'AC' : 'C';
  }

  log(msg) {
    const entry = { t: this.now().toISOString(), msg };
    this.logs.push(entry);
    if (this.logs.length > MAX_LOG) this.logs.shift();
    if (this.onLog) this.onLog(entry);
  }

  lastToken() {
    return this.tokens[this.tokens.length - 1];
  }

  // Sørger for at sidste token er et redigerbart tal; returnerer det
  editableNumber() {
    if (this.error || this.phase === 'result') this.newCalc();
    let last = this.lastToken();
    if (last && last.t === 'n' && last.fixed !== undefined) {
      this.newCalc();
      last = undefined;
    }
    if (!last || last.t === 'o') {
      last = { t: 'n', text: '', neg: false, pct: false };
      this.tokens.push(last);
    }
    return last;
  }

  isStreaming(tok) {
    return this.calc.stream && this.calc.stream.tok === tok;
  }

  digit(d) {
    const tok = this.editableNumber();
    if (tok.pct) return;
    if (!tok.checked) this.maybeStartStream(tok);
    if (this.isStreaming(tok)) return this.reveal(d);
    if (countDigits(tok.text) >= MAX_INPUT_DIGITS) return;
    if (tok.text === '0') tok.text = d;
    else tok.text += d;
  }

  comma() {
    const tok = this.editableNumber();
    if (tok.pct) return;
    if (!tok.checked) this.maybeStartStream(tok);
    if (this.isStreaming(tok)) return this.reveal(',');
    if (tok.text.includes(',')) return;
    tok.text = (tok.text === '' ? '0' : tok.text) + ',';
  }

  reveal(key) {
    const st = this.calc.stream;
    const units = st.plan.units;
    if (st.pos >= units.length) return; // som når man rammer max cifre
    const next = units[st.pos];
    if (key === ',' && !next.startsWith(',')) {
      this.log('Komma trykket under talstrøm – ignoreret');
      return;
    }
    st.pos++;
    st.typed++;
    st.tok.text = units.slice(0, st.pos).join('');
  }

  maybeStartStream(tok) {
    tok.checked = true;
    if (this.settings.display === 'typed') return; // ingen talstrøm: vis præcis det tastede
    const idx = this.tokens.indexOf(tok);
    const numIndex = this.tokens.slice(0, idx).filter((t) => t.t === 'n').length;
    const opTok = idx > 0 ? this.tokens[idx - 1] : null;
    const prefix = idx > 1 ? this.tokens.slice(0, idx - 1) : [];
    const key = prefix.map(tokenKey).join('|') + '#' + (opTok ? opTok.op : '');
    const s = this.settings;
    let plan = null;
    let source = null;
    let target = null;

    if (this.forceArmed()) {
      const fu = this.calc.followUp && this.calc.stream && numIndex === this.calc.stream.numIndex + 1;
      let position = fu;
      if (!this.calc.stream) {
        if (s.trigger === 'nth') position = numIndex === Math.max(1, s.nth) - 1;
        else if (s.trigger === 'afterEquals') position = this.calc.continued && numIndex === 1;
        else if (s.trigger === 'manual') position = true;
      }
      if (!position) return;
      target = this.calc.target ?? this.target();
      plan = planForce({ prefix, op: opTok ? opTok.op : null, target, tokenNeg: tok.neg, allowSwap: s.allowSwap });
      source = fu ? 'followUp' : 'armed';
      if (fu && plan.score >= 300) {
        this.log(`Fortsat regning: ingen troværdig talstrøm (${plan.notes.join(', ')})`);
        this.calc.followUp = false;
        return;
      }
    } else if (this.forceRt.memory.size) {
      const mem = this.forceRt.memory.get(key);
      if (!mem) return;
      plan = mem.plan;
      target = mem.target;
      source = 'replay';
    } else {
      return;
    }

    if (!plan.ok) {
      this.log(`Talstrøm opgivet ved tal nr. ${numIndex + 1}: ${plan.notes.join(', ')}`);
      return;
    }
    if (opTok && plan.op !== opTok.op) {
      this.log(`Operator skiftet ${opGlyph(opTok.op)} → ${opGlyph(plan.op)} (eneste troværdige løsning)`);
      opTok.op = plan.op;
    }
    tok.neg = plan.neg;
    this.calc.target = target;
    this.calc.followUp = false;
    this.calc.stream = { tok, plan, pos: 0, typed: 0, numIndex, key, source };
    this.log(`Talstrøm startet på tal nr. ${numIndex + 1} → ${plan.text}${plan.notes.length ? ' (' + plan.notes.join(', ') + ')' : ''}${source === 'replay' ? ' [gentagelse]' : ''}`);
  }

  operator(op) {
    if (this.error) return;
    if (this.phase === 'result') {
      const r = this.result;
      this.newCalc(true);
      this.tokens.push({ t: 'n', fixed: r, neg: false, pct: false, checked: true });
    }
    if (!this.tokens.length) this.tokens.push({ t: 'n', text: '0', neg: false, pct: false, checked: true });
    const last = this.lastToken();
    if (last.t === 'o') { last.op = op; return; }
    if (this.isStreaming(last) && this.calc.stream.pos > 0) this.calc.followUp = true;
    this.tokens.push({ t: 'o', op });
  }

  plusMinus() {
    if (this.error) return;
    if (this.phase === 'result') {
      const r = -this.result;
      this.newCalc(true);
      this.tokens.push({ t: 'n', fixed: r, neg: false, pct: false, checked: true });
      return;
    }
    const last = this.lastToken();
    if (!last || last.t === 'o') {
      this.tokens.push({ t: 'n', text: '', neg: true, pct: false });
      return;
    }
    last.neg = !last.neg;
  }

  percent() {
    if (this.error) return;
    if (this.phase === 'result') {
      const r = this.result;
      this.newCalc(true);
      this.tokens.push({ t: 'n', fixed: r, neg: false, pct: true, checked: true });
      return;
    }
    const last = this.lastToken();
    if (last && last.t === 'n') last.pct = true;
  }

  back() {
    if (this.error) return this.clear();
    if (this.phase === 'result') return;
    const last = this.lastToken();
    if (!last) return;
    if (last.t === 'o') {
      this.tokens.pop();
      if (this.calc.stream && this.lastToken() === this.calc.stream.tok) this.calc.followUp = false;
      return;
    }
    if (last.pct) { last.pct = false; return; }
    if (this.isStreaming(last)) {
      const st = this.calc.stream;
      st.pos = Math.max(0, st.pos - 1);
      last.text = st.plan.units.slice(0, st.pos).join('');
      if (st.pos === 0) { this.tokens.pop(); this.calc.stream = null; }
      return;
    }
    if (last.fixed !== undefined) { this.tokens.pop(); return; }
    last.text = last.text.slice(0, -1);
    if (last.text === '') this.tokens.pop();
  }

  clear() {
    this.reset();
    this.repeat = null;
  }

  // Afslutter force ved "=". Returnerer målet hvis det skal vises, ellers null.
  // "Som tastet": regnestykket røres ikke, kun resultatet bliver målet.
  finalizeTyped() {
    const s = this.settings;
    const nums = this.tokens.filter((t) => t.t === 'n');
    const key = 'typed:' + this.tokens.map(tokenKey).join('|');
    let replay = null;
    if (this.forceArmed()) {
      const enough = nums.length >= Math.max(1, s.nth) || (s.lateFix && nums.length >= 2);
      const ok = s.trigger === 'nth' ? enough
        : s.trigger === 'afterEquals' ? this.calc.continued && nums.length >= 2
        : nums.length >= 1; // manuel
      if (!ok) return null;
    } else {
      replay = this.forceRt.memory.get(key);
      if (!replay) return null;
    }
    const target = replay ? replay.target : (this.calc.target ?? this.target());
    if (replay) {
      this.log(`Gentagelse: ${tokensText(this.tokens)} giver igen ${formatNumber(target)}`);
    } else {
      this.forceRt.hits++;
      this.forceRt.manualArmed = false;
      this.forceRt.memory.set(key, { target });
      const left = s.uses > 0 ? Math.max(0, s.uses - this.forceRt.hits) : '∞';
      this.log(`RAMT ${formatNumber(target)} – regnestykket vist som tastet: ${tokensText(this.tokens)} (ærligt: ${formatNumber(evaluate(this.tokens))}) – ${left} tilbage`);
    }
    return { value: target };
  }

  finalizeForce() {
    if (this.settings.display === 'typed') return this.finalizeTyped();
    const st = this.calc.stream;
    const s = this.settings;
    const nums = this.tokens.filter((t) => t.t === 'n');
    const last = this.lastToken();
    let engaged = false;

    if (st) {
      engaged = true;
      if (st.tok === last && st.pos < st.plan.units.length) {
        this.log(`Talstrøm fuldført ved = (${st.typed} af ${st.plan.units.length} cifre tastet)`);
        st.pos = st.plan.units.length;
        st.tok.text = st.plan.text;
      }
    } else if (this.forceArmed() && s.lateFix && nums.length >= 2 && last.t === 'n' && last.fixed === undefined) {
      const ok = s.trigger === 'nth' || (s.trigger === 'afterEquals' && this.calc.continued) || s.trigger === 'manual';
      engaged = ok;
    }
    if (!engaged) return null;

    const target = this.calc.target ?? this.target();
    const tol = 1e-6 * Math.max(1, Math.abs(target));
    const v = evaluate(this.tokens);
    let ok = formatNumber(v) === formatNumber(target);
    if (!ok && st && st.tok === last && !st.tok.pct && Math.abs(v - target) <= tol) {
      ok = true;
      this.log(`Afrundet resultat ${formatNumber(v)} vist som ${formatNumber(target)}`);
    }
    let fixedKey = st ? st.key : null;
    let fixedPlan = st ? st.plan : null;
    if (!ok && s.lateFix && last.t === 'n' && last.fixed === undefined && this.tokens.length >= 3) {
      const idx = this.tokens.length - 1;
      const prefix = this.tokens.slice(0, idx - 1);
      const opTok = this.tokens[idx - 1];
      const typedOp = opTok.op;
      const plan = planForce({ prefix, op: opTok.op, target, tokenNeg: false, allowSwap: s.allowSwap });
      if (plan.ok && plan.score < 300) {
        this.log(`Sidste tal rettet ved = : ${tokensText([last])} → ${plan.text}${plan.notes.length ? ' (' + plan.notes.join(', ') + ')' : ''}`);
        if (plan.op !== opTok.op) opTok.op = plan.op;
        last.text = plan.text;
        last.neg = plan.neg;
        last.pct = false;
        ok = true;
        fixedKey = prefix.map(tokenKey).join('|') + '#' + typedOp;
        fixedPlan = plan;
      } else {
        this.log(`Kunne ikke ramme ${formatNumber(target)} troværdigt (${plan.notes ? plan.notes.join(', ') : '-'}) – viser ærligt resultat`);
      }
    } else if (!ok) {
      this.log(`Ramte ikke ${formatNumber(target)} – viser ærligt resultat ${formatNumber(v)}`);
    }
    if (!ok) return null;

    if (!st || st.source !== 'replay') {
      this.forceRt.hits++;
      this.forceRt.manualArmed = false;
      if (fixedKey && fixedPlan) this.forceRt.memory.set(fixedKey, { plan: fixedPlan, target });
      const left = s.uses > 0 ? Math.max(0, s.uses - this.forceRt.hits) : '∞';
      this.log(`RAMT ${formatNumber(target)} (${tokensText(this.tokens)}) – ${left} tilbage`);
    } else {
      this.log(`Gentagelse ramte ${formatNumber(target)} igen`);
    }
    return { value: target };
  }

  equals() {
    if (this.error) return;
    if (this.phase === 'result') {
      if (!this.repeat) return;
      const a = this.result;
      const toks = [{ t: 'n', fixed: a }, { t: 'o', op: this.repeat.op }, { t: 'n', fixed: this.repeat.operand }];
      this.finish(toks, evaluate(toks));
      return;
    }
    if (!this.tokens.length) return;
    if (this.lastToken().t === 'o') this.tokens.pop();
    const forced = this.finalizeForce();
    const value = forced ? forced.value : evaluate(this.tokens);
    let lastOpIdx = -1;
    for (let i = this.tokens.length - 1; i >= 0; i--) if (this.tokens[i].t === 'o') { lastOpIdx = i; break; }
    if (lastOpIdx >= 0) {
      const lastNum = this.tokens[lastOpIdx + 1];
      let operand = numValue(lastNum);
      if (lastNum.pct) operand /= 100;
      this.repeat = { op: this.tokens[lastOpIdx].op, operand };
    } else {
      this.repeat = null;
    }
    this.finish(this.tokens.map((t) => ({ ...t })), value);
  }

  finish(tokens, value) {
    this.resultTokens = tokens;
    this.tokens = [];
    this.calc = newCalcState();
    this.phase = 'result';
    if (!Number.isFinite(value)) {
      this.error = true;
      this.result = 0;
    } else {
      this.result = value === 0 ? 0 : value;
    }
    this.history.push({ expr: tokensText(tokens), result: this.error ? 'Fejl' : formatNumber(this.result) });
    if (this.history.length > 100) this.history.shift();
  }
}
