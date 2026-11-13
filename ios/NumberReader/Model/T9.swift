// T9-dekoder: tal tastet på telefonens numeriske blok → mest sandsynlige danske ord/navn.
// Præcis port af src/t9.js (samme point, samme rækkefølge). Ingen UIKit – kan testes på Linux.
import Foundation

/// Ordbogen fra words.json (genereres af ios/scripts/make-words-json.py fra src/words.js).
struct WordData: Codable {
    var celebs: [String]
    var first: [String]
    var last: [String]
    var bdays: [String: String]
    var words: [String]

    static let empty = WordData(celebs: [], first: [], last: [], bdays: [:], words: [])

    static func load(from url: URL?) -> WordData {
        guard let url, let data = try? Data(contentsOf: url),
              let w = try? JSONDecoder().decode(WordData.self, from: data) else { return .empty }
        return w
    }
}

enum T9 {
    static let groups: [(Character, String)] = [
        ("2", "abcæåäáàâ"), ("3", "defèéëê"), ("4", "ghiíïî"), ("5", "jkl"),
        ("6", "mnoøöóô"), ("7", "pqrsß"), ("8", "tuvüúùû"), ("9", "wxyzý"),
    ]
    static let map: [Unicode.Scalar: Character] = {
        var m: [Unicode.Scalar: Character] = [:]
        for (d, letters) in groups { for s in letters.unicodeScalars { m[s] = d } }
        return m
    }()

    /// Bogstaver → cifre ("Kim Larsen" → "546527736"). Andre tegn springes over.
    static func toDigits(_ word: String) -> String {
        var out = ""
        for s in word.lowercased().precomposedStringWithCanonicalMapping.unicodeScalars {
            if let d = map[s] { out.append(d) }
        }
        return out
    }
}

struct Candidate: Equatable {
    var text: String
    var score: Double
    var kind: String // custom · celeb · celebPart · first · last · word · pair · multi · none
}

/// Stabil sortering (som JavaScripts Array.sort) – højeste point først.
func stableSortDesc(_ a: [Candidate]) -> [Candidate] {
    a.enumerated().sorted { x, y in
        x.element.score != y.element.score ? x.element.score > y.element.score : x.offset < y.offset
    }.map(\.element)
}

private func jsCap(_ w: String) -> String {
    guard let f = w.first else { return w }
    return String(f).uppercased() + w.dropFirst()
}

final class T9Index {
    // Point: højere = mere sandsynligt
    static let W = (custom: 2000.0, celeb: 1000.0, celebPart: 520.0, first: 470.0, last: 430.0, word: 300.0)

    var exact: [String: [Candidate]] = [:]
    var firstIdx: [String: [Candidate]] = [:]  // venstre del af "Fornavn Efternavn"
    var lastIdx: [String: [Candidate]] = [:]   // højre del

    init(data: WordData, celebs: Bool = true, names: Bool = true, words: Bool = true, custom: [String] = []) {
        let W = T9Index.W
        func add(_ map: inout [String: [Candidate]], _ digits: String, _ text: String, _ score: Double, _ kind: String) {
            if digits.count < 2 { return }
            var arr = map[digits] ?? []
            let low = text.lowercased()
            if let i = arr.firstIndex(where: { $0.text.lowercased() == low }) {
                if score > arr[i].score { arr[i].score = score; arr[i].kind = kind; arr[i].text = text }
                map[digits] = arr
                return
            }
            arr.append(Candidate(text: text, score: score, kind: kind))
            map[digits] = arr
        }
        let ws = CharacterSet.whitespacesAndNewlines
        func split(_ s: String) -> [String] { s.components(separatedBy: ws).filter { !$0.isEmpty } }

        for (i, c) in custom.enumerated() {
            let t = c.trimmingCharacters(in: ws)
            if t.isEmpty { continue }
            let s = W.custom - Double(i)
            add(&exact, T9.toDigits(t), t, s, "custom")
            let parts = split(t)
            if parts.count > 1 {
                add(&firstIdx, T9.toDigits(parts[0]), parts[0], s, "custom")
                let rest = parts.dropFirst()
                add(&lastIdx, T9.toDigits(rest.joined()), rest.joined(separator: " "), s, "custom")
            }
        }
        if celebs {
            for (i, c) in data.celebs.enumerated() {
                let s = W.celeb - Double(i) * 0.3
                add(&exact, T9.toDigits(c), c, s, "celeb")
                let parts = split(c)
                if parts.count > 1 {
                    let f = parts[0], l = parts[parts.count - 1]
                    add(&exact, T9.toDigits(f), f, W.celebPart - Double(i) * 0.1, "celebPart")
                    add(&exact, T9.toDigits(l), l, W.celebPart - Double(i) * 0.1, "celebPart")
                    add(&firstIdx, T9.toDigits(f), f, W.celebPart, "celebPart")
                    add(&lastIdx, T9.toDigits(l), l, W.celebPart, "celebPart")
                }
            }
        }
        if names {
            for (i, n) in data.first.enumerated() {
                let s = W.first - Double(i) * 0.4
                let d = T9.toDigits(n)
                add(&exact, d, n, s, "first")
                add(&firstIdx, d, n, s, "first")
                add(&lastIdx, d, n, s - 60, "first") // "Anne Marie", "Jens Peter"
            }
            for (i, n) in data.last.enumerated() {
                let s = W.last - Double(i) * 0.5
                let d = T9.toDigits(n)
                add(&exact, d, n, s, "last")
                add(&lastIdx, d, n, s, "last")
            }
        }
        if words {
            let n = Double(data.words.count)
            for (i, w) in data.words.enumerated() {
                // Hyppige ord først; logaritmisk fald fra 300 til ca. 40
                let s = W.word * (1 - 0.87 * log(Double(i + 1)) / log(n))
                let d = T9.toDigits(w)
                add(&exact, d, jsCap(w), s, "word")
                if w.count >= 3 { add(&lastIdx, d, jsCap(w), s * 0.6, "word") }
            }
        }
        for k in exact.keys { exact[k] = stableSortDesc(exact[k]!) }
        for k in firstIdx.keys { firstIdx[k] = stableSortDesc(firstIdx[k]!) }
        for k in lastIdx.keys { lastIdx[k] = stableSortDesc(lastIdx[k]!) }
    }

    private func decodeSegment(_ s: String, _ max: Int) -> [Candidate] {
        var out: [Candidate] = exact[s] ?? []
        // To dele: "Mette" + "Jensen"
        let chars = Array(s)
        if chars.count >= 4 {
            for i in 2...(chars.count - 2) {
                guard let L = firstIdx[String(chars[0..<i])], let R = lastIdx[String(chars[i...])] else { continue }
                for l in L.prefix(3) {
                    for r in R.prefix(3) {
                        if l.kind == "word" || l.text.contains(".") { continue }
                        let score = r.kind == "word" ? min(l.score, r.score) * 0.7 : min(l.score, r.score) * 0.85 + 20
                        out.append(Candidate(text: "\(l.text) \(r.text)", score: score, kind: "pair"))
                    }
                }
            }
        }
        var seen = Set<String>()
        return Array(stableSortDesc(out).filter { seen.insert($0.text.lowercased()).inserted }.prefix(max))
    }

    /// Dekod en talstreng. 0 og 1 har ingen bogstaver, så de tolkes som mellemrum. Bedste først.
    func decode(_ digits: String, max: Int = 5) -> [Candidate] {
        let clean = String(digits.filter { $0.isASCII && $0.isNumber })
        let segs = clean.split(whereSeparator: { $0 == "0" || $0 == "1" }).map(String.init)
        if segs.isEmpty { return [] }
        if segs.count == 1 { return decodeSegment(segs[0], max) }
        // Flere ord: kombinér de bedste bud for hvert ord
        let per: [[Candidate]] = segs.map { s in
            let r = decodeSegment(s, 3)
            return r.isEmpty ? [Candidate(text: s, score: 0, kind: "none")] : r
        }
        var combos: [(text: String, score: Double)] = [("", 0)]
        for opts in per {
            var next: [Candidate] = []
            for c in combos { for o in opts { next.append(Candidate(text: c.text.isEmpty ? o.text : "\(c.text) \(o.text)", score: c.score + o.score, kind: "")) } }
            combos = stableSortDesc(next).prefix(12).map { ($0.text, $0.score) }
        }
        // Står hele navnet i listen (fx "Kim Larsen" tastet med 0 som mellemrum), vinder det
        let whole = (exact[segs.joined()] ?? []).filter { $0.kind == "celeb" || $0.kind == "custom" }
        let res = whole + combos.map { Candidate(text: $0.text, score: $0.score / Double(per.count), kind: "multi") }
        var seen = Set<String>()
        return Array(res.filter { seen.insert($0.text.lowercased()).inserted }.prefix(max))
    }
}
