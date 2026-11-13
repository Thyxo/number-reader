// Hemmeligt panel (5 hurtige tryk øverst til højre): overblik + sektionerne Peek, Regnemetode,
// Kamera, Ordbog og Andet – som i index.html.
import SwiftUI
import UIKit

private let blue = Color(hex: 0x0a84ff)
private let gray = Color(hex: 0x8d8d92)
private let card = Color(hex: 0x1c1c1e)
private let field = Color(hex: 0x2c2c2e)

struct SecretPanel: View {
    @Environment(AppState.self) private var app
    @State private var open: [String: Bool] = SecretPanel.loadOpen()
    @State private var customDraft = ""
    @State private var testDigits = ""
    @State private var testWord = ""
    @FocusState private var customFocused: Bool

    static let openKey = "nr.open.v1"
    static func loadOpen() -> [String: Bool] {
        (UserDefaults.standard.dictionary(forKey: openKey) as? [String: Bool]) ?? ["peek": true]
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(left: nil, title: "Indstillinger", right: "OK", tint: blue, onRight: { commitCustom(); app.closeSecret() })
                .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x1f1f1f)).frame(height: 0.5) }
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    Seg(options: [("pad", "Numerisk blok"), ("calc", "Lommeregner")], value: app.bind(\.mode), big: true)
                        .padding(.bottom, 10)
                    peekSection
                    forceSection
                    camSection
                    dictSection
                    miscSection
                    Text("Åbn: 5 hurtige tryk øverst til højre · Peek-skærm: ✱ · Scan: tryk øverst · Lommeregner: luppen · Tilbage: hold på uret")
                        .font(.system(size: 12)).foregroundColor(Color(hex: 0x636366))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.top, 14)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundColor(.white)
        .background(Color.black.ignoresSafeArea())
        .onAppear { customDraft = app.s.custom }
        .onChange(of: customFocused) { _, f in if !f { commitCustom() } }
    }

    private func commitCustom() { if customDraft != app.s.custom { app.update { $0.custom = customDraft } } }

    // ---------- overblik ----------
    private var hero: some View {
        let cur = app.cur
        return VStack(alignment: .leading, spacing: 0) {
            Text(cur == nil ? "Intet læst endnu" : (cur!.src == "kamera" ? "Læst med kameraet" : "Tastet på blokken"))
                .font(.system(size: 13)).foregroundColor(gray)
            Text(app.word.isEmpty ? (cur == nil ? "–" : "(intet ord)") : app.word)
                .font(.system(size: 32, weight: .bold)).monospacedDigit().lineLimit(1).truncationMode(.tail)
            if let cur { Text(cur.digits).font(.system(size: 13)).monospacedDigit().foregroundColor(gray).padding(.top, 2) }
            if let cur, !cur.cands.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(cur.cands.enumerated()), id: \.offset) { i, c in
                        Button { app.pick(i) } label: {
                            (Text(c.text) + Text(" " + (SecretPanel.kind[c.kind] ?? "")).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.6)))
                                .font(.system(size: 14))
                                .foregroundColor(i == cur.pick ? .white : Color(hex: 0xe5e5ea))
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 14).fill(i == cur.pick ? blue : field))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            }
            GeometryReader { g in
                let on = app.scanning
                let unit = (g.size.width - 16) / 3.2
                HStack(spacing: 8) {
                    heroButton(on ? "Stop scanning" : "Scan nu", fg: .white, bg: on ? Color(hex: 0xff453a) : blue) {
                        if on { app.stopScan() } else { app.closeSecret(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { app.toggleScan() } }
                    }
                    .frame(width: unit * 1.4)
                    heroButton("Vis peek", fg: blue, bg: field) {
                        app.closeSecret(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { app.openPeekScreen() }
                    }
                    .frame(width: unit)
                    heroButton("Ryd", fg: blue, bg: field) { app.clearResult() }
                        .frame(width: unit * 0.8)
                }
            }
            .frame(height: 42)
            .padding(.top, 12)
            if let f = cur?.force {
                forceText(f)
                    .font(.system(size: 13.5)).monospacedDigit().lineSpacing(4)
                    .foregroundColor(Color(hex: 0xd1f5da))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x30d158, alpha: 0.12)))
                    .padding(.top, 10)
            }
            Button {
                app.closeSecret(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) { app.debugOpen = true }
            } label: {
                Text("Debug – se hvad kameraet ser").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: 0xe5e5ea))
                    .frame(maxWidth: .infinity).padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(field))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(stops: [.init(color: Color(hex: 0x0a84ff, alpha: 0.14), location: 0), .init(color: card, location: 0.7)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0x0a84ff, alpha: 0.45), lineWidth: 1))
        )
        .padding(.top, 12).padding(.bottom, 10)
    }

    private func forceText(_ f: ForceResult) -> Text {
        var t = Text("Mit tal: ")
        t = t + Text(f.a).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
        if f.neg {
            t = t + Text("\nDit tal ") + Text("−").bold().foregroundColor(.white) + Text(" mit tal")
        } else {
            t = t + Text("\nDit tal + mit tal")
        }
        t = t + Text(" = \(f.y) ")
        t = t + Text("(\(f.label))").foregroundColor(Color(hex: 0xd1f5da).opacity(0.6))
        return t
    }

    static let kind = ["custom": "egen", "celeb": "kendt", "celebPart": "kendt", "first": "navn", "last": "efternavn", "word": "ord", "pair": "navn", "multi": "flere ord"]

    private func heroButton(_ t: String, fg: Color, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 15, weight: .semibold)).foregroundColor(fg).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(bg))
        }
        .buttonStyle(.plain)
    }

    // ---------- sektioner ----------
    private var peekSection: some View {
        PSection(id: "peek", title: "Peek", icon: "eye", color: Color(hex: 0xbf5af2),
                summary: "\(app.s.screenColor == "white" ? "Hvid" : "Sort") · \(app.s.screenHold == "tap" ? "til tryk" : "2 sek.")", open: $open) {
            Note("Numerisk blok: hvor står navnet?")
            Seg(options: [("tabs", "I fanerne"), ("line", "Over home-baren")], value: app.bind(\.peekWhere))
            PGroup(spacing: true) {
                ToggleRow("Peek-tekst", app.bind(\.peekText))
                PickRow("Styrke", app.bind(\.peekLevel), [(1, "Næsten usynlig"), (2, "Svag"), (3, "Tydelig")])
                ToggleRow("Fødselsdag/mål i 3. fane", app.bind(\.tab3Peek))
                PickRow("Alternativer i teksten", app.bind(\.peekAlts), [(0, "Ingen"), (1, "1"), (2, "2")])
            }
            Note("Peek-skærm (tryk ✱ på den numeriske blok)")
            Seg(options: [("black", "Sort"), ("white", "Hvid")], value: app.bind(\.screenColor))
            Seg(options: [("2", "2 sek."), ("tap", "Til tryk")], value: app.bind(\.screenHold)).padding(.top, 10)
            PGroup(spacing: true) { ToggleRow("Vis alternativer", app.bind(\.screenAlts)) }
        }
    }

    private var forceSection: some View {
        let src = ["birthday": "Fødselsdag", "today": "Dato i dag", "clock": "Klokken", "fixed": "Fast tal"]
        return PSection(id: "force", title: "Regnemetode", icon: "plus", color: Color(hex: 0x30d158),
                       summary: app.s.force ? (src[app.s.forceSrc] ?? "") : "Fra", open: $open) {
            PGroup {
                ToggleRow("Regnemetode (y − x = a)", app.bind(\.force))
                PickRow("Tvunget tal (y)", app.bind(\.forceSrc), [("birthday", "Personens fødselsdag"), ("today", "Dato i dag"), ("clock", "Klokken"), ("fixed", "Fast tal")])
                PickRow("Datoformat", app.bind(\.forceFmt), [("ddmmyy", "DDMMÅÅ (140646)"), ("ddmmyyyy", "DDMMÅÅÅÅ (14061946)"), ("yyyymmdd", "ÅÅÅÅMMDD (19460614)"), ("ddmm", "DDMM (1406)")])
                IntRow("Klokken + minutter", app.bind(\.clockAdd))
                TextRow("Fast tal / reserve", app.bind(\.forceFixed), placeholder: "fx 2100", numeric: true)
            }
            Note("Når tilskuerens tal (x) scannes, regnes mit tal a = y − x ud og sættes i nummerfeltet (eller lommeregneren). Bagefter: x + a på lommeregneren = y. Står der **−** i peeket, er x større end y: så er det x − a. Fødselsdage: ~470 kendte er indbygget, egne navne skrives \"Navn | 14.06.1946\" under Ordbog.")
            Note("Skift hurtigt: tryk på søg-knappen (luppen) på den numeriske blok = lommeregner. Hold på ur-knappen i lommeregneren = tilbage til blokken.")
        }
    }

    private var camSection: some View {
        PSection(id: "cam", title: "Kamera", icon: "camera", color: Color(hex: 0x0a84ff),
                summary: "\(app.s.confirm)× · \(app.s.region == "full" ? "hele" : "midten")\(app.s.autoScan ? " · auto" : "")", open: $open) {
            PGroup {
                ToggleRow("Start scanning når appen åbner", app.bind(\.autoScan))
                PickRow("Bekræft læsning", app.bind(\.confirm), [(1, "1 gang (hurtigst)"), (2, "2 gange (sikrest)")])
                PickRow("Mindst antal cifre", app.bind(\.minLen), [(2, "2"), (3, "3"), (4, "4"), (5, "5"), (6, "6")])
                PickRow("Stop efter", app.bind(\.timeout), [(15, "15 sek."), (30, "30 sek."), (60, "1 min.")])
            }
            Seg(options: [("center", "Midten af billedet"), ("full", "Hele billedet")], value: app.bind(\.region)).padding(.top, 10)
            PGroup(spacing: true) {
                ToggleRow("Vis søger (træning)", app.bind(\.viewfinder))
                ToggleRow("Gem debug-billeder", app.bind(\.debug))
                InfoRow("OCR-motor", "Apple Vision")
                InfoRow("Sidst læst", app.lastRead)
            }
            Note("Start: tryk øverst på skærmen (numerisk blok: over tallet · lommeregner: mellem de to runde knapper). Tryk igen = stop.")
        }
    }

    private var dictSection: some View {
        PSection(id: "dict", title: "Ordbog", icon: "book", color: Color(hex: 0xff9f0a),
                summary: [app.s.dCelebs ? "Kendte" : nil, app.s.dNames ? "Navne" : nil, app.s.dWords ? "Ord" : nil].compactMap { $0 }.joined(separator: " · ").ifEmpty("Kun egne"),
                open: $open) {
            PGroup {
                ToggleRow("Kendte personer", app.bind(\.dCelebs))
                ToggleRow("Fornavne og efternavne", app.bind(\.dNames))
                ToggleRow("Danske ord (25.000)", app.bind(\.dWords))
            }
            Note("Egne navne – én pr. linje, vinder altid")
            ZStack(alignment: .topLeading) {
                if customDraft.isEmpty {
                    Text("fx Bedstemor Inge | 03.04.1950\nFido").foregroundColor(Color(hex: 0x636366)).padding(.horizontal, 17).padding(.vertical, 18)
                }
                TextEditor(text: $customDraft)
                    .focused($customFocused)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(size: 16))
                    .frame(minHeight: 100)
                    .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(field))
            Note("Test")
            PGroup {
                HStack {
                    Text("Tal")
                    TextField("fx 546527736", text: $testDigits).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(gray)
                }.rowStyle()
                HStack {
                    Text("Bliver")
                    Spacer()
                    Text(app.decode(testDigits, max: 5).map(\.text).joined(separator: " · ").ifEmpty("–")).font(.system(size: 14)).foregroundColor(gray).multilineTextAlignment(.trailing)
                }.rowStyle()
                HStack {
                    Text("Ord")
                    TextField("fx Kim Larsen", text: $testWord).autocorrectionDisabled().textInputAutocapitalization(.never).multilineTextAlignment(.trailing).foregroundColor(gray)
                }.rowStyle()
                HStack {
                    Text("Tastes som")
                    Spacer()
                    Text(T9.toDigits(testWord).ifEmpty("–")).fontWeight(.semibold).monospacedDigit()
                }.rowStyle(last: true)
            }
        }
    }

    private var miscSection: some View {
        PSection(id: "misc", title: "Andet", icon: "gearshape", color: Color(hex: 0x8e8e93), summary: "", open: $open) {
            PGroup {
                ToggleRow("Tastetoner (numerisk blok)", app.bind(\.tones))
                ToggleRow("Tastede tal på blokken peekes", app.bind(\.typedPeek))
                ToggleRow("Vis scannet tal i nummerfeltet", app.bind(\.showScanned))
                IntRow("Lodret justering (pt)", app.bind(\.vAdjust))
            }
            Note(screenInfo)
            Note("Log")
            Text(app.logs.reversed().joined(separator: "\n").ifEmpty("(tom)"))
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(Color(hex: 0xc7c7cc))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(field))
        }
    }

    private var screenInfo: String {
        let b = UIScreen.main.bounds
        let i = app.insets
        return "Skærm: \(Int(b.width))×\(Int(b.height)) pt · skala \(Int(UIScreen.main.scale)) · safe \(Int(i.top))/\(Int(i.bottom)) · iOS \(UIDevice.current.systemVersion) · \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"
    }
}

extension String {
    func ifEmpty(_ s: String) -> String { isEmpty ? s : self }
}

private extension View {
    func rowStyle(last: Bool = false) -> some View {
        self.font(.system(size: 16))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color(hex: 0x3a3a3c)).frame(height: 1) } }
    }
}

// ---------- byggesten ----------
private struct PSection<Content: View>: View {
    var id: String
    var title: String
    var icon: String
    var color: Color
    var summary: String
    @Binding var open: [String: Bool]
    @ViewBuilder var content: () -> Content

    var body: some View {
        let isOpen = open[id] ?? false
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { open[id] = !isOpen }
                UserDefaults.standard.set(open, forKey: SecretPanel.openKey)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 8).fill(color))
                    Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    Text(summary).font(.system(size: 15)).foregroundColor(gray).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing).opacity(isOpen ? 0 : 1)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: 0x636366))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 8)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                Rectangle().fill(field).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 0) { content() }.padding(10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(card))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 8)
    }
}

private struct PGroup<Content: View>: View {
    var spacing = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 12).fill(field))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, spacing ? 10 : 0)
    }
}

private struct Note: View {
    var text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(LocalizedStringKey(text)).font(.system(size: 12.5)).foregroundColor(gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.top, 12).padding(.bottom, 6)
    }
}

private struct Seg<V: Hashable>: View {
    var options: [(V, String)]
    @Binding var value: V
    var big = false
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                let on = o.0 == value
                Button { value = o.0 } label: {
                    Text(o.1).font(.system(size: big ? 15 : 14, weight: on ? .semibold : .regular))
                        .foregroundColor(on ? .white : Color(hex: 0xdddddd))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).padding(.vertical, big ? 10 : 7).padding(.horizontal, 4)
                        .background(RoundedRectangle(cornerRadius: 7).fill(on ? Color(hex: 0x636366) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9).fill(field))
    }
}

private struct ToggleRow: View {
    var title: String
    @Binding var on: Bool
    init(_ t: String, _ b: Binding<Bool>) { title = t; _on = b }
    var body: some View {
        Toggle(isOn: $on) { Text(title) }.tint(Color(hex: 0x30d158)).rowStyle()
    }
}

private struct PickRow<V: Hashable>: View {
    var title: String
    @Binding var value: V
    var options: [(V, String)]
    init(_ t: String, _ b: Binding<V>, _ o: [(V, String)]) { title = t; _value = b; options = o }
    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                    Button { value = o.0 } label: { if o.0 == value { Label(o.1, systemImage: "checkmark") } else { Text(o.1) } }
                }
            } label: {
                Text(options.first(where: { $0.0 == value })?.1 ?? "").foregroundColor(blue).lineLimit(1)
            }
        }
        .rowStyle()
    }
}

private struct IntRow: View {
    var title: String
    @Binding var value: Int
    init(_ t: String, _ b: Binding<Int>) { title = t; _value = b }
    var body: some View {
        HStack {
            Text(title)
            TextField("0", value: $value, format: .number.grouping(.never))
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing).foregroundColor(gray)
        }
        .rowStyle()
    }
}

private struct TextRow: View {
    var title: String
    @Binding var value: String
    var placeholder: String
    var numeric: Bool
    init(_ t: String, _ b: Binding<String>, placeholder: String, numeric: Bool = false) { title = t; _value = b; self.placeholder = placeholder; self.numeric = numeric }
    var body: some View {
        HStack {
            Text(title)
            TextField(placeholder, text: $value)
                .keyboardType(numeric ? .numberPad : .default)
                .multilineTextAlignment(.trailing).foregroundColor(gray)
        }
        .rowStyle()
    }
}

private struct InfoRow: View {
    var title: String
    var value: String
    init(_ t: String, _ v: String) { title = t; value = v }
    var body: some View {
        HStack { Text(title); Spacer(); Text(value).font(.system(size: 14)).foregroundColor(gray) }.rowStyle()
    }
}
