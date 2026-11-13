// Talformatering efter dansk standard: "." som tusindtalsseparator og "," som decimaltegn.
// Port af src/calc/format.js.
import Foundation

enum CalcFormat {
    /// Cifre man kan taste i ét tal (som i iPhone-appen).
    static let maxInputDigits = 16
    static let maxDigits = 9

    static func opGlyph(_ op: String) -> String { op == "-" ? "−" : op }

    static func groupInt(_ s: String) -> String {
        let chars = Array(s)
        var out = ""
        for (i, c) in chars.enumerated() {
            let left = chars.count - i
            if i > 0, left % 3 == 0, chars[i - 1].isNumber, c.isNumber { out.append(".") }
            out.append(c)
        }
        return out
    }

    /// "1234,5" → 1234.5
    static func parseInput(_ text: String) -> Double {
        if text.isEmpty || text == "," { return 0 }
        return jsParseFloat(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Som JavaScripts parseFloat: læs det længste gyldige tal i starten
    static func jsParseFloat(_ s: String) -> Double? {
        var t = Substring(s.trimmingCharacters(in: .whitespaces))
        var lead = ""
        if let f = t.first, f == "-" || f == "+" { lead = String(f); t = t.dropFirst() }
        var num = ""
        var dot = false
        for c in t {
            if c.isASCII && c.isNumber { num.append(c) } else if c == "." && !dot { dot = true; num.append(c) } else { break }
        }
        if num.isEmpty || num == "." { return nil }
        return Double(lead + (num.hasSuffix(".") ? String(num.dropLast()) : num))
    }

    static func countDigits(_ text: String) -> Int { text.filter { $0.isASCII && $0.isNumber }.count }

    /// Indtastet tekst ("5634,") → visningstekst ("5.634,")
    static func formatInput(_ text: String, neg: Bool = false) -> String {
        let src = text.isEmpty ? "0" : text
        let parts = src.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let i = parts[0]
        var s = groupInt(i.isEmpty ? "0" : i)
        if text.contains(",") { s += "," + (parts.count > 1 ? parts[1] : "") }
        return (neg ? "-" : "") + s
    }

    private static func trimZeros(_ s: String) -> String {
        guard s.contains(".") else { return s }
        var t = s
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t
    }

    /// Udfolder "1.23e-7" til "0.000000123"
    private static func expand(_ str: String) -> String {
        let low = str.lowercased()
        guard let eIdx = low.firstIndex(of: "e") else { return str }
        let mant = String(low[..<eIdx])
        let exp = Int(low[low.index(after: eIdx)...].replacingOccurrences(of: "+", with: "")) ?? 0
        let neg = mant.hasPrefix("-")
        let m = mant.replacingOccurrences(of: "-", with: "")
        let mp = m.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let ip = mp[0], fp = mp.count > 1 ? mp[1] : ""
        let digits = ip + fp
        let point = ip.count + exp
        var out: String
        if point <= 0 { out = "0." + String(repeating: "0", count: -point) + digits }
        else if point >= digits.count { out = digits + String(repeating: "0", count: point - digits.count) }
        else { out = String(digits.prefix(point)) + "." + String(digits.dropFirst(point)) }
        return (neg ? "-" : "") + out
    }

    /// JS toPrecision(12) – kun brugt via expand(), så eksponentform er fin
    private static func precision12(_ v: Double) -> String { String(format: "%.11e", v) }

    /// Tal uden gruppering, punktum som decimal ("1234.5"), afrundet til 12 betydende cifre.
    static func plainNumber(_ v: Double) -> String {
        if !v.isFinite { return "NaN" }
        if v == 0 { return "0" }
        let a = abs(v)
        let s: String
        if a == a.rounded() && a < 1e16 { s = String(format: "%.0f", a) }
        else { s = trimZeros(expand(precision12(a))) }
        return (v < 0 ? "-" : "") + s
    }

    /// Resultat til visning: "1.234.567,89", "1,234568e16", "Fejl"
    static func formatNumber(_ v: Double) -> String {
        if !v.isFinite { return "Fejl" }
        if v == 0 { return "0" }
        let a = abs(v)
        let sign = v < 0 ? "-" : ""
        if a >= 1e16 || a < 1e-9 {
            let parts = String(format: "%.8e", a).split(separator: "e").map(String.init)
            let m = trimZeros(parts[0])
            let e = Int(parts[1].replacingOccurrences(of: "+", with: "")) ?? 0
            return sign + m.replacingOccurrences(of: ".", with: ",") + "e" + String(e)
        }
        let s = plainNumber(a)
        let p = s.split(separator: ".", maxSplits: 1).map(String.init)
        return sign + groupInt(p[0]) + (p.count > 1 ? "," + p[1] : "")
    }

    /// Visningstekst → tal (til "Indsæt"): accepterer "1.234,5", "1234.5", "1234,5"
    static func parseDisplay(_ str: String) -> Double {
        var s = str.trimmingCharacters(in: .whitespacesAndNewlines).filter { !$0.isWhitespace }
        s = s.replacingOccurrences(of: "−", with: "-")
        if s.isEmpty { return .nan }
        if s.contains(",") {
            s = s.replacingOccurrences(of: ".", with: "")
            if let r = s.range(of: ",") { s.replaceSubrange(r, with: ".") }
        } else if s.range(of: "^-?[0-9]{1,3}(\\.[0-9]{3})+$", options: .regularExpression) != nil {
            s = s.replacingOccurrences(of: ".", with: "")
        }
        guard let v = Double(s), v.isFinite else { return .nan }
        return v
    }
}
