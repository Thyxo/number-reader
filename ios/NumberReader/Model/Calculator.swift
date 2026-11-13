// Lommeregner-motor uden UI. UI'et kalder press(key) og tegner view().
// Port af src/calc/calculator.js. Webappen kører motoren med force slået fra
// (settings.enabled = false), så talstrøm/force-grenene er udeladt – resten er 1:1.
import Foundation

struct CalcToken: Equatable, Codable {
    enum Kind: String, Codable { case n, o }
    var t: Kind
    var op: String = ""        // kun for t == .o
    var text: String = ""      // tastet tekst ("5634,")
    var fixed: Double? = nil   // fast værdi (resultat / indsat)
    var neg = false
    var pct = false

    static func num(_ text: String = "", neg: Bool = false) -> CalcToken { CalcToken(t: .n, text: text, neg: neg) }
    static func fixedNum(_ v: Double, neg: Bool = false, pct: Bool = false) -> CalcToken { CalcToken(t: .n, fixed: v, neg: neg, pct: pct) }
    static func oper(_ op: String) -> CalcToken { CalcToken(t: .o, op: op) }
}

struct CalcPart: Equatable { var kind: String; var text: String } // kind: num | op

struct CalcView: Equatable {
    var error = false
    var clearLabel = "AC"
    var activeOp: String? = nil
    var expr: [CalcPart]? = nil
    var main: [CalcPart] = []
}

struct HistoryItem: Codable, Equatable { var expr: String; var result: String }

enum CalcMath {
    static func numValue(_ tok: CalcToken) -> Double {
        let v = tok.fixed ?? CalcFormat.parseInput(tok.text)
        return tok.neg ? -v : v
    }

    /// Almindeligt regnehierarki (× og ÷ før + og −) og iPhone-procent:
    /// "a + b%" = a + a·b/100, "a × b%" = a · b/100.
    static func evaluate(_ tokens: [CalcToken]) -> Double {
        var sum = 0.0
        var term: Double? = nil
        var op: String? = nil
        for tok in tokens {
            if tok.t == .o { op = tok.op; continue }
            var v = numValue(tok)
            if tok.pct {
                if (op == "+" || op == "-"), let t = term { v = (sum + t) * v / 100 } else { v = v / 100 }
            }
            guard let t = term else { term = v; continue }
            switch op {
            case "+": sum += t; term = v
            case "-": sum += t; term = -v
            case "×": term = t * v
            case "÷": term = v == 0 ? .nan : t / v
            default: break
            }
        }
        return term == nil ? 0 : sum + term!
    }

    static func renderToken(_ tok: CalcToken, wrapNeg: Bool) -> String {
        if tok.t == .o { return CalcFormat.opGlyph(tok.op) }
        var s: String
        if let f = tok.fixed { s = CalcFormat.formatNumber(tok.neg ? -f : f) }
        else { s = CalcFormat.formatInput(tok.text.isEmpty ? "0" : tok.text, neg: tok.neg) }
        if tok.pct { s += "%" }
        if wrapNeg && s.hasPrefix("-") { s = "(" + s + ")" }
        return s
    }

    static func renderTokens(_ tokens: [CalcToken]) -> [CalcPart] {
        let wrap = tokens.count > 1
        return tokens.map { CalcPart(kind: $0.t == .o ? "op" : "num", text: renderToken($0, wrapNeg: wrap)) }
    }

    static func tokensText(_ tokens: [CalcToken]) -> String { renderTokens(tokens).map(\.text).joined() }
}

final class Calculator {
    var history: [HistoryItem] = []
    private(set) var tokens: [CalcToken] = []
    private var phase = "input" // input | result
    private var result = 0.0
    private var resultTokens: [CalcToken]? = nil
    private var error = false
    private var repeatOp: (op: String, operand: Double)? = nil

    private static func isOp(_ k: String) -> Bool { ["+", "-", "×", "÷"].contains(k) }

    // ---------- offentlig API ----------
    func press(_ key: String) {
        if key.count == 1, let c = key.first, c.isASCII, c.isNumber { digit(key) }
        else if key == "," { comma() }
        else if Calculator.isOp(key) { operator_(key) }
        else if key == "=" { equals() }
        else if key == "pm" { plusMinus() }
        else if key == "pct" { percent() }
        else if key == "clear" { clear() }
        else if key == "back" { back() }
    }

    func view() -> CalcView {
        var v = CalcView(error: error, clearLabel: clearLabel())
        if error {
            v.main = [CalcPart(kind: "num", text: "Fejl")]
            if let r = resultTokens { v.expr = CalcMath.renderTokens(r) }
        } else if phase == "result" {
            v.main = [CalcPart(kind: "num", text: CalcFormat.formatNumber(result))]
            v.expr = CalcMath.renderTokens(resultTokens ?? [])
        } else if tokens.isEmpty {
            v.main = [CalcPart(kind: "num", text: "0")]
        } else {
            v.main = CalcMath.renderTokens(tokens)
            if let last = tokens.last, last.t == .o { v.activeOp = last.op }
        }
        return v
    }

    /// Ren tekst af det store display (til kopiering)
    func displayValue() -> String {
        if error { return "Fejl" }
        if phase == "result" { return CalcFormat.formatNumber(result) }
        guard let last = tokens.last else { return "0" }
        if tokens.count == 1 && last.t == .n { return CalcMath.renderToken(last, wrapNeg: false) }
        return CalcMath.tokensText(tokens)
    }

    /// Indsæt et tal (fra udklipsholderen / historikken) som aktuelt tal
    func insertValue(_ v: Double) {
        guard v.isFinite else { return }
        if phase == "result" || error { newCalc() }
        let tok = CalcToken.fixedNum(abs(v), neg: v < 0)
        if let last = tokens.last, last.t == .n { tokens[tokens.count - 1] = tok } else { tokens.append(tok) }
    }

    // ---------- intern tilstand ----------
    private func reset() { tokens = []; phase = "input"; result = 0; resultTokens = nil; error = false }
    private func newCalc() { tokens = []; phase = "input"; resultTokens = nil; error = false }
    private func clearLabel() -> String { tokens.isEmpty && phase == "input" && !error ? "AC" : "C" }

    /// Sørger for at sidste token er et redigerbart tal; returnerer dets indeks
    private func editableNumber() -> Int {
        if error || phase == "result" { newCalc() }
        if let last = tokens.last, last.t == .n, last.fixed != nil { newCalc() }
        if tokens.last == nil || tokens.last!.t == .o { tokens.append(.num()) }
        return tokens.count - 1
    }

    private func digit(_ d: String) {
        let i = editableNumber()
        if tokens[i].pct { return }
        if CalcFormat.countDigits(tokens[i].text) >= CalcFormat.maxInputDigits { return }
        if tokens[i].text == "0" { tokens[i].text = d } else { tokens[i].text += d }
    }

    private func comma() {
        let i = editableNumber()
        if tokens[i].pct || tokens[i].text.contains(",") { return }
        tokens[i].text = (tokens[i].text.isEmpty ? "0" : tokens[i].text) + ","
    }

    private func operator_(_ op: String) {
        if error { return }
        if phase == "result" {
            let r = result
            newCalc()
            tokens.append(.fixedNum(r))
        }
        if tokens.isEmpty { tokens.append(.num("0")) }
        if tokens[tokens.count - 1].t == .o { tokens[tokens.count - 1].op = op; return }
        tokens.append(.oper(op))
    }

    private func plusMinus() {
        if error { return }
        if phase == "result" {
            let r = -result
            newCalc()
            tokens.append(.fixedNum(r))
            return
        }
        guard let last = tokens.last, last.t == .n else { tokens.append(.num("", neg: true)); return }
        tokens[tokens.count - 1].neg.toggle()
    }

    private func percent() {
        if error { return }
        if phase == "result" {
            let r = result
            newCalc()
            tokens.append(.fixedNum(r, pct: true))
            return
        }
        if let last = tokens.last, last.t == .n { tokens[tokens.count - 1].pct = true }
    }

    private func back() {
        if error { return clear() }
        if phase == "result" { return }
        guard let last = tokens.last else { return }
        if last.t == .o { tokens.removeLast(); return }
        if last.pct { tokens[tokens.count - 1].pct = false; return }
        if last.fixed != nil { tokens.removeLast(); return }
        tokens[tokens.count - 1].text = String(last.text.dropLast())
        if tokens[tokens.count - 1].text.isEmpty { tokens.removeLast() }
    }

    func clear() { reset(); repeatOp = nil }

    private func equals() {
        if error { return }
        if phase == "result" {
            guard let r = repeatOp else { return }
            let toks: [CalcToken] = [.fixedNum(result), .oper(r.op), .fixedNum(r.operand)]
            finish(toks, CalcMath.evaluate(toks))
            return
        }
        if tokens.isEmpty { return }
        if tokens[tokens.count - 1].t == .o { tokens.removeLast() }
        let value = CalcMath.evaluate(tokens)
        if let lastOpIdx = tokens.lastIndex(where: { $0.t == .o }) {
            let lastNum = tokens[lastOpIdx + 1]
            var operand = CalcMath.numValue(lastNum)
            if lastNum.pct { operand /= 100 }
            repeatOp = (tokens[lastOpIdx].op, operand)
        } else {
            repeatOp = nil
        }
        finish(tokens, value)
    }

    private func finish(_ toks: [CalcToken], _ value: Double) {
        resultTokens = toks
        tokens = []
        phase = "result"
        if !value.isFinite { error = true; result = 0 } else { result = value == 0 ? 0 : value }
        history.append(HistoryItem(expr: CalcMath.tokensText(toks), result: error ? "Fejl" : CalcFormat.formatNumber(result)))
        if history.count > 100 { history.removeFirst() }
    }
}
