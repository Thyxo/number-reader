// Hele appens tilstand: indstillinger, ordbog, resultat, numerisk blok, lommeregner, kamera, log.
// Svarer til src/app.js.
import Observation
import SwiftUI
import UIKit

struct ForceResult: Equatable {
    var y: String
    var label: String
    var x: String
    var a: String
    var neg: Bool
}

struct ScanResult: Equatable {
    var digits: String
    var src: String // kamera | tastet
    var cands: [Candidate]
    var pick: Int
    var force: ForceResult?
}

@MainActor
@Observable
final class AppState {
    var s = Settings.load()

    // ---------- ordbog ----------
    @ObservationIgnored let data: WordData = WordData.load(from: Bundle.main.url(forResource: "words", withExtension: "json"))
    @ObservationIgnored var index: T9Index?
    var indexReady = false

    // ---------- resultat ----------
    var cur: ScanResult?
    var typed = ""
    var scanning = false
    var lastRead = "–"
    var logs: [String] = []

    // ---------- skærme ----------
    var secretOpen = false
    var peekScreenOpen = false
    var debugOpen = false
    var historyOpen = false
    var menuOpen = false
    var insets = EdgeInsets()

    // ---------- lommeregner ----------
    @ObservationIgnored let calc = Calculator()
    var calcView = CalcView()
    var calcHistory: [HistoryItem] = []

    // ---------- kamera ----------
    @ObservationIgnored let scanner = Scanner()
    var debugFrames: [DebugFrame] = []
    @ObservationIgnored private var recent: [String] = []
    @ObservationIgnored private var scanStarted = Date()
    @ObservationIgnored private var timeoutWork: DispatchWorkItem?
    @ObservationIgnored private var found = false
    @ObservationIgnored var lastZoneToggle = Date.distantPast
    @ObservationIgnored private var psWork: DispatchWorkItem?

    init() {
        if let d = UserDefaults.standard.data(forKey: "nr.calc.history.v1"),
           let h = try? JSONDecoder().decode([HistoryItem].self, from: d) { calc.history = h }
        calcHistory = calc.history
        calcView = calc.view()
        scanner.onFrame = { [weak self] best, frame in self?.handleFrame(best, frame) }
        scanner.onStatus = { [weak self] st in self?.handleStatus(st) }
        rebuild()
        if s.autoScan { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.toggleScan() } }
    }

    // ---------- log ----------
    func log(_ msg: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        logs.append("\(f.string(from: Date()))  \(msg)")
        if logs.count > 80 { logs.removeFirst() }
    }

    // ---------- indstillinger ----------
    func bind<T>(_ kp: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { self.s[keyPath: kp] }, set: { v in self.update { $0[keyPath: kp] = v } })
    }

    func update(_ change: (inout Settings) -> Void) {
        let old = s
        var n = s
        change(&n)
        if n == old { return }
        s = n
        s.save()
        if old.dCelebs != n.dCelebs || old.dNames != n.dNames || old.dWords != n.dWords || old.custom != n.custom {
            rebuild()
        }
        if old.force != n.force || old.forceSrc != n.forceSrc || old.forceFmt != n.forceFmt || old.clockAdd != n.clockAdd || old.forceFixed != n.forceFixed {
            computeForce()
        }
    }

    func rebuild() {
        let s = self.s, data = self.data
        let custom = s.customLines.map { $0.components(separatedBy: "|")[0].trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        Task.detached(priority: .userInitiated) {
            let idx = T9Index(data: data, celebs: s.dCelebs, names: s.dNames, words: s.dWords, custom: custom)
            await MainActor.run {
                self.index = idx
                self.indexReady = true
                if let c = self.cur {
                    let p = c.pick
                    self.setResult(c.digits, src: c.src)
                    self.cur?.pick = min(p, max(0, (self.cur?.cands.count ?? 1) - 1))
                    self.computeForce()
                }
            }
        }
    }

    func decode(_ digits: String, max: Int = 5) -> [Candidate] { index?.decode(digits, max: max) ?? [] }

    // ---------- resultat ----------
    func setResult(_ digits: String, src: String) {
        let cands = decode(digits, max: 6)
        cur = ScanResult(digits: digits, src: src, cands: cands, pick: 0, force: nil)
        computeForce()
        log("\(src == "kamera" ? "Kamera" : "Tastet"): \(digits) → \(cands.prefix(3).map(\.text).joined(separator: ", ").isEmpty ? "(intet)" : cands.prefix(3).map(\.text).joined(separator: ", "))")
    }

    /// Regnemetoden: y − x = a (kun for tal læst med kameraet)
    func computeForce() {
        guard var c = cur else { return }
        c.force = nil
        if s.force && c.src == "kamera" {
            let t = Force.target(src: s.forceSrc, fmt: s.forceFmt, fixed: s.forceFixed, clockAdd: s.clockAdd,
                                 name: word, custom: s.customLines, bdays: data.bdays)
            let r = Force.solve(c.digits, t.y)
            c.force = ForceResult(y: t.y, label: t.label, x: c.digits, a: r.a, neg: r.neg)
            log("Regnemetode: y=\(t.y) (\(t.label)) − x=\(c.digits) → \(r.neg ? "x − " : "x + ")\(r.a)")
        }
        cur = c
    }

    /// Sæt mit tal (a) i nummerfeltet / lommeregneren
    @discardableResult
    func applyForce() -> Bool {
        guard let f = cur?.force else { return false }
        if s.mode == "calc" { calcEnter(f.a) } else { typed = f.a }
        return true
    }

    var word: String {
        guard let c = cur, c.pick < c.cands.count else { return "" }
        let t = c.cands[c.pick].text
        return t.contains("?") ? "" : t
    }

    func alts(_ n: Int) -> [String] {
        guard let c = cur else { return [] }
        return Array(c.cands.enumerated().filter { $0.offset != c.pick }.prefix(n).map(\.element.text))
    }

    func pick(_ i: Int) {
        guard cur != nil else { return }
        cur!.pick = i
        computeForce()
        if cur?.force != nil && cur?.src == "kamera" { applyForce() }
    }

    func clearResult() { cur = nil; typed = "" }

    // ---------- peek ----------
    var peekColor: Color {
        switch s.peekLevel { case 1: return Color(hex: 0x1c1c1c); case 3: return Color(hex: 0x5a5a5a); default: return Color(hex: 0x2e2e2e) }
    }

    /// Peek-teksten (svag tekst): ord + alternativer + "−" ved regnemetoden. nil = intet
    var peekParts: (main: String, alt: String)? {
        guard s.peekText, let c = cur else { return nil }
        let w = word
        let a = alts(s.peekAlts)
        var main = w.isEmpty ? c.digits : w
        var alt = (!w.isEmpty && !a.isEmpty) ? " · " + a.joined(separator: " · ") : ""
        if c.force?.neg == true { alt += " −" }
        if w.isEmpty { main = c.digits }
        return (main, alt)
    }

    /// Fanernes tekst (Opkald / Kontakter / Numerisk blok) – med navnet, når peek står i fanerne
    var tabLabels: [String] {
        var lab = ["Opkald", "Kontakter", "Numerisk blok"]
        guard s.peekWhere == "tabs", s.peekText, let c = cur else { return lab }
        let name = word.isEmpty ? c.digits : word
        let parts = name.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if let f = parts.first { lab[0] = f }
        if parts.count > 1 { lab[1] = parts.dropFirst().joined(separator: " ") }
        var third = ""
        if let f = c.force { third = (f.neg ? "−" : "") + f.y }
        else if let b = Force.birthdayOf(word, custom: s.customLines, bdays: data.bdays) { third = Force.fmtDate(b, s.forceFmt) }
        if s.tab3Peek && !third.isEmpty { if parts.count > 1 { lab[2] = third } else { lab[1] = third } }
        return lab
    }

    // ---------- peek-skærm ----------
    func openPeekScreen() {
        psWork?.cancel()
        peekScreenOpen = true
        if s.screenHold != "tap" {
            let w = DispatchWorkItem { [weak self] in self?.peekScreenOpen = false }
            psWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: w)
        }
    }
    func closePeekScreen() { psWork?.cancel(); peekScreenOpen = false }

    // ---------- kamera ----------
    var isRunning: Bool { scanner.active }

    func toggleScan() {
        if scanner.active || scanning { stopScan(); return }
        scanning = true
        found = false
        recent = []
        scanStarted = Date()
        scanner.start(ScanOptions(confirm: s.confirm, minLen: s.minLen, timeout: TimeInterval(s.timeout), region: s.region, debug: s.debug))
        timeoutWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.scanning else { return }
            self.log("Scanning stoppet (tid udløb)")
            self.finishScan()
        }
        timeoutWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(s.timeout), execute: w)
    }

    func stopScan() {
        guard scanning || scanner.active else { return }
        if !found { log("Scanning stoppet") }
        finishScan()
    }

    private func finishScan() {
        timeoutWork?.cancel()
        scanner.stop()
        scanning = false
    }

    private func handleStatus(_ st: String) {
        if st == "nocamera" {
            log("Intet kamera (adgang nægtet?)")
            timeoutWork?.cancel()
            scanning = false
        }
    }

    private func handleFrame(_ r: OCRBest?, _ frame: DebugFrame?) {
        guard scanning else { return }
        let accepted = r.map(isAccepted) ?? false
        if var f = frame {
            f.found = accepted
            debugFrames.append(f)
            if debugFrames.count > 15 { debugFrames.removeFirst() }
        }
        guard let r else { return }
        let d = r.digits
        lastRead = d
        if accepted {
            found = true
            Haptic.tap(.medium)
            setResult(d, src: "kamera")
            // Regnemetoden: mit tal (a) sættes ind. Ellers: vis det scannede tal, hvor telefonnummeret står
            if !applyForce() && s.showScanned { typed = d }
            finishScan()
        }
    }

    /// Samme tal læst `confirm` gange blandt de sidste 6 – eller sikker læsning af et kendt/eget navn
    private func isAccepted(_ r: OCRBest) -> Bool {
        recent.append(r.digits)
        if recent.count > 6 { recent.removeFirst() }
        let n = recent.filter { $0 == r.digits }.count
        if n >= s.confirm { return true }
        guard r.conf >= 85, let top = decode(r.digits, max: 1).first else { return false }
        return top.kind == "custom" || top.kind == "celeb"
    }

    // ---------- numerisk blok ----------
    func padPress(_ d: String) {
        if s.tones { Tones.shared.play(d) }
        if d == "*" { openPeekScreen(); return } // ✱ = peek-skærm (tastes ikke)
        if typed.count >= 40 { return }
        typed += d
        onTypedChange()
    }
    func padHoldZero() { typed = String(typed.dropLast()) + "+"; onTypedChange() }
    func padDelete() { typed = String(typed.dropLast()); onTypedChange() }

    func onTypedChange() {
        guard s.typedPeek else { return }
        let d = typed.filter { $0.isASCII && $0.isNumber }
        if d.count >= 2 { setResult(String(d), src: "tastet") }
    }

    // ---------- lommeregner ----------
    func calcPress(_ k: String) {
        calc.press(k)
        refreshCalc()
    }
    func refreshCalc() {
        calcView = calc.view()
        if calc.history != calcHistory {
            calcHistory = calc.history
            if let d = try? JSONEncoder().encode(Array(calc.history.suffix(100))) { UserDefaults.standard.set(d, forKey: "nr.calc.history.v1") }
        }
    }
    /// Sæt et tal i displayet, som om det var tastet (regnemetoden)
    func calcEnter(_ digits: String) {
        calc.press("clear"); calc.press("clear")
        for ch in digits where ch.isASCII && ch.isNumber { calc.press(String(ch)) }
        refreshCalc()
    }
    func calcInsert(_ v: Double) { calc.insertValue(v); refreshCalc() }
    func clearHistory() { calc.history = []; refreshCalc() }

    // ---------- skift ----------
    func setMode(_ m: String) {
        menuOpen = false
        historyOpen = false
        update { $0.mode = m }
    }

    // ---------- hemmeligt panel ----------
    /// tapTime = tidspunktet for 5. tryk
    func openSecret(tapTime: Date) {
        menuOpen = false
        // 5. tryk øverst til højre ramte også scan-feltet: fortryd det skift
        if abs(lastZoneToggle.timeIntervalSince(tapTime)) < 0.1 { toggleScan() }
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3)) { secretOpen = true }
    }
    func closeSecret() { withAnimation(.easeIn(duration: 0.22)) { secretOpen = false } }

    func zoneTap() {
        lastZoneToggle = Date()
        toggleScan()
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: alpha)
    }
}
