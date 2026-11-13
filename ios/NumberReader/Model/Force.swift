// Regnemetoden: y − x = a. x = tilskuerens tal (scannet), y = det tvungne tal, a = mit tal.
// Tilskueren regner bagefter x + a på lommeregneren og får y (fx personens fødselsdag).
// Er x større end y, bliver a negativt: så vises |a|, og regnestykket er x − a.
// Præcis port af src/force.js. Store tal regnes som strenge (ingen Int-grænse).
import Foundation

struct DMY: Equatable { var d: Int; var m: Int; var y: Int }

enum Force {
    private static func pad(_ n: Int) -> String { n < 10 && n >= 0 ? "0\(n)" : "\(n)" }
    private static func pad4(_ n: Int) -> String { String(repeating: "0", count: max(0, 4 - String(n).count)) + String(n) }

    private static func match(_ pattern: String, _ s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<m.numberOfRanges).map { ns.substring(with: m.range(at: $0)) }
    }

    /// "1946-06-14" / "14.06.1946" / "14-6-46" / "140646" → DMY eller nil
    static func parseDate(_ input: String?) -> DMY? {
        let s = (input ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let m = match("^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$", s) { return DMY(d: Int(m[2])!, m: Int(m[1])!, y: Int(m[0])!) }
        if let m = match("^([0-9]{1,2})[./ -]([0-9]{1,2})[./ -]([0-9]{2,4})$", s) { return DMY(d: Int(m[0])!, m: Int(m[1])!, y: Int(m[2])!) }
        if let m = match("^([0-9]{2})([0-9]{2})([0-9]{2}|[0-9]{4})$", s) { return DMY(d: Int(m[0])!, m: Int(m[1])!, y: Int(m[2])!) }
        return nil
    }

    /// Dato som tal-streng i valgt format: ddmmyy · ddmmyyyy · yyyymmdd · ddmm
    static func fmtDate(_ b: DMY, _ fmt: String = "ddmmyy") -> String {
        switch fmt {
        case "ddmmyyyy": return pad(b.d) + pad(b.m) + pad4(b.y)
        case "yyyymmdd": return pad4(b.y) + pad(b.m) + pad(b.d)
        case "ddmm": return pad(b.d) + pad(b.m)
        default: return pad(b.d) + pad(b.m) + pad(b.y % 100)
        }
    }

    /// Fødselsdag for et navn: egne navne ("Navn | 14.06.1946") vinder over listen.
    static func birthdayOf(_ name: String, custom: [String], bdays: [String: String]) -> DMY? {
        if name.isEmpty { return nil }
        let low = name.lowercased()
        for line in custom {
            let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count > 1, !parts[1].isEmpty, parts[0].lowercased() == low { return parseDate(parts[1]) }
        }
        for (n, d) in bdays.sorted(by: { $0.key < $1.key }) where n.lowercased() == low { return parseDate(d) }
        return nil
    }

    struct Target: Equatable { var y: String; var label: String }

    /// Find y. src: birthday | today | clock | fixed. Fødselsdag uden kendt dato falder tilbage til
    /// det faste tal, ellers dagens dato.
    static func target(src: String = "birthday", fmt: String = "ddmmyy", fixed: String = "", clockAdd: Int = 0,
                       name: String = "", custom: [String] = [], bdays: [String: String] = [:], now: Date = Date()) -> Target {
        let fixedDigits = fixed.filter { $0.isASCII && $0.isNumber }
        let cal = Calendar.current
        let today = DMY(d: cal.component(.day, from: now), m: cal.component(.month, from: now), y: cal.component(.year, from: now))
        if src == "birthday" {
            if let b = birthdayOf(name, custom: custom, bdays: bdays) { return Target(y: fmtDate(b, fmt), label: "fødselsdag") }
            if !fixedDigits.isEmpty { return Target(y: fixedDigits, label: "fast tal (ingen fødselsdag)") }
            return Target(y: fmtDate(today, fmt), label: "dato i dag (ingen fødselsdag)")
        }
        if src == "today" { return Target(y: fmtDate(today, fmt), label: "dato i dag") }
        if src == "clock" {
            let t = now.addingTimeInterval(Double(clockAdd) * 60)
            return Target(y: pad(cal.component(.hour, from: t)) + pad(cal.component(.minute, from: t)), label: "klokken")
        }
        return Target(y: fixedDigits.isEmpty ? "0" : fixedDigits, label: "fast tal")
    }

    // ---------- store tal som strenge ----------
    private static func norm(_ s: String) -> [UInt8] {
        let d = s.utf8.filter { $0 >= 48 && $0 <= 57 }.map { $0 - 48 }
        let t = Array(d.drop(while: { $0 == 0 }))
        return t.isEmpty ? [0] : t
    }
    private static func less(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        a.count != b.count ? a.count < b.count : a.lexicographicallyPrecedes(b)
    }
    /// a − b for a ≥ b (begge uden foranstillede nuller)
    private static func sub(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: a.count)
        var borrow = 0
        for i in 0..<a.count {
            let ai = Int(a[a.count - 1 - i])
            let bi = i < b.count ? Int(b[b.count - 1 - i]) : 0
            var v = ai - bi - borrow
            borrow = v < 0 ? 1 : 0
            if v < 0 { v += 10 }
            r[a.count - 1 - i] = UInt8(v)
        }
        let t = Array(r.drop(while: { $0 == 0 }))
        return t.isEmpty ? [0] : t
    }
    static func add(_ x: String, _ y: String) -> String {
        let a = norm(x), b = norm(y)
        var r: [UInt8] = []
        var carry = 0
        for i in 0..<max(a.count, b.count) {
            let v = (i < a.count ? Int(a[a.count - 1 - i]) : 0) + (i < b.count ? Int(b[b.count - 1 - i]) : 0) + carry
            r.append(UInt8(v % 10)); carry = v / 10
        }
        if carry > 0 { r.append(UInt8(carry)) }
        return String(r.reversed().map { Character(String($0)) })
    }

    /// a = y − x med store tal. neg = regnestykket er x − a.
    static func solve(_ x: String, _ y: String) -> (a: String, neg: Bool) {
        let X = norm(x), Y = norm(y)
        let neg = less(Y, X)
        let d = neg ? sub(X, Y) : sub(Y, X)
        return (String(d.map { Character(String($0)) }), neg)
    }
}
