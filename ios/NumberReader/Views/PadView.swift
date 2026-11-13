// Numerisk blok (iOS Telefon, mørk tilstand). Mål i pt fra rigtige skærmbilleder (393 × 852 pt),
// skaleret med skærmbredden (p = 1 pt). Tal og tilføj-ikon måles fra toppen, resten fra bunden. Se pad.css.
import SwiftUI

/// Danske numre formateres i par, mens de tastes ("48 48 7"), op til 8 cifre – som på iPhone
func fmtNumber(_ s: String) -> String {
    func pairs(_ t: Substring) -> String {
        var out = ""
        for (i, c) in t.enumerated() { if i > 0 && i % 2 == 0 { out += " " }; out.append(c) }
        return out
    }
    let allDigits = s.allSatisfy { $0.isASCII && $0.isNumber }
    if allDigits && (1...8).contains(s.count) { return pairs(Substring(s)) }
    if s.hasPrefix("+45") && s.count == 11 && s.dropFirst(3).allSatisfy({ $0.isASCII && $0.isNumber }) { return "+45 " + pairs(s.dropFirst(3)) }
    return s
}

struct PadView: View {
    @Environment(AppState.self) private var app

    static let keys: [(d: String, letters: String)] = [
        ("1", ""), ("2", "ABC"), ("3", "DEF"), ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"), ("*", ""), ("0", "+"), ("#", ""),
    ]

    var body: some View {
        GeometryReader { geo in
            let W = min(geo.size.width, 480)
            let H = geo.size.height
            let p = W / 393
            let adj = CGFloat(app.s.vAdjust)
            ZStack(alignment: .topLeading) {
                Color.black

                // Tryk øverst (over nummeret) = start/stop scanning
                Color.clear
                    .frame(width: W, height: 165 * p)
                    .contentShape(Rectangle())
                    .onPress { app.zoneTap() }
                    .position(x: W / 2, y: 165 * p / 2)

                // Tastet nummer
                FitText(minScale: 0.55, alignment: .center, height: { _ in 36 * p * 1.15 }) { k in
                    Text(fmtNumber(app.typed))
                        .font(.system(size: 36 * p * k, weight: .regular))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
                .frame(width: W - 28 * p)
                .allowsHitTesting(false)
                .position(x: W / 2, y: 114 * p)

                if !app.typed.isEmpty {
                    AddContactIcon()
                        .frame(width: 27 * p, height: 27 * p)
                        .contentShape(Rectangle())
                        .position(x: 360 * p, y: 81 * p)
                }

                // Taster: Ø 77 pt, kolonner 102 pt, rækker 95,8 pt; bund 222,5 pt over skærmens bund
                let gridTop = H - 222.5 * p - adj - (4 * 77 + 3 * 18.8) * p
                ForEach(Array(PadView.keys.enumerated()), id: \.offset) { i, k in
                    let col = CGFloat(i % 3), row = CGFloat(i / 3)
                    PadKey(d: k.d, letters: k.letters, p: p)
                        .position(x: (94.5 + col * 102) * p, y: gridTop + (38.5 + row * 95.8) * p)
                }

                CallButton(p: p)
                    .position(x: 196.5 * p, y: H - 164 * p - adj)

                if !app.typed.isEmpty {
                    DeleteButton(p: p)
                        .position(x: 296.5 * p, y: H - 164 * p - adj)
                }

                TabBar(p: p)
                    .frame(width: W - 42 * p, height: 61 * p)
                    .position(x: W / 2, y: H - 21 * p - 30.5 * p)

                // Peek over home-baren
                PeekLine(size: 10.5 * p, showText: app.s.peekWhere != "tabs")
                    .frame(width: W * 0.7, height: 11 * p)
                    .position(x: W / 2, y: H - 9 * p - 5.5 * p)
            }
            .frame(width: W, height: H)
            .position(x: geo.size.width / 2, y: H / 2)
        }
        .ignoresSafeArea()
        .background(Color.black)
    }
}

/// Svag peek-tekst (pad: over home-baren · lommeregner: mellem ikonerne)
struct PeekLine: View {
    @Environment(AppState.self) private var app
    var size: CGFloat
    var showText = true

    var body: some View {
        let parts = showText ? app.peekParts : nil
        var t = Text("")
        if let parts {
            t = Text(parts.main).fontWeight(.medium) + Text(parts.alt).fontWeight(.regular).foregroundColor(app.peekColor.opacity(0.75))
        }
        if app.scanning && app.s.peekText { t = t + Text("·") }
        return t
            .font(.system(size: size))
            .kerning(size * 0.02)
            .foregroundColor(app.peekColor)
            .lineLimit(1)
            .truncationMode(.tail)
            .allowsHitTesting(false)
    }
}

struct PadKey: View {
    @Environment(AppState.self) private var app
    var d: String
    var letters: String
    var p: CGFloat
    @State private var hold: DispatchWorkItem?

    var body: some View {
        GlassKey(size: 77 * p, shadow: (10 * p, 5 * p), onDown: down, onUp: { hold?.cancel() }) {
            ZStack {
                Circle().fill(Color(hex: 0x121212))
                Circle().strokeBorder(Color(hex: 0x2d2d2d), lineWidth: 0.9 * p)
            }
        } label: {
            label
        }
    }

    @ViewBuilder private var label: some View {
        if d == "*" {
            VBShape(vb: CGSize(width: 20, height: 20)) { p in
                p.line(10, 2.2, 10, 17.8); p.line(3.25, 6.1, 16.75, 13.9); p.line(3.25, 13.9, 16.75, 6.1)
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5 * 20.5 / 20 * p, lineCap: .butt))
            .frame(width: 20.5 * p, height: 20.5 * p)
        } else if d == "#" {
            VBShape(vb: CGSize(width: 22, height: 24)) { p in
                p.line(7.6, 2.5, 7.6, 21.5); p.line(14.4, 2.5, 14.4, 21.5); p.line(2.4, 8.4, 19.6, 8.4); p.line(2.4, 15.6, 19.6, 15.6)
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2.6 * 1.104 * p, lineCap: .butt))
            .frame(width: 24.5 * p, height: 26.5 * p)
        } else {
            VStack(spacing: 0) {
                Text(d)
                    .font(.system(size: 37 * p, weight: .regular))
                    .frame(height: 34 * p)
                    .padding(.top, -4 * p)
                if d == "0" {
                    Text("+")
                        .font(.system(size: 17 * p, weight: .semibold))
                        .frame(height: 17 * p)
                        .padding(.top, -0.5 * p)
                        .padding(.bottom, -3 * p)
                } else {
                    Text(letters.isEmpty ? " " : letters)
                        .font(.system(size: 10.4 * p, weight: .bold))
                        .kerning(2.9 * p)
                        .padding(.leading, 2.9 * p)
                        .frame(height: 10.4 * p)
                        .padding(.top, 4.6 * p)
                        .opacity(letters.isEmpty ? 0 : 1)
                }
            }
            .foregroundColor(.white)
        }
    }

    private func down() {
        app.padPress(d)
        hold?.cancel()
        if d == "0" {
            // Hold 0 = +
            let w = DispatchWorkItem { app.padHoldZero() }
            hold = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: w)
        }
    }
}

struct CallButton: View {
    var p: CGFloat
    @State private var down = false
    var body: some View {
        ZStack {
            Circle().fill(down ? Color(hex: 0x4e9a4e) : Color(hex: 0x387837))
                .animation(down ? nil : .easeOut(duration: 0.5), value: down)
            Circle().strokeBorder(Color(hex: 0x59a55e), lineWidth: 1.33 * p)
            Circle().strokeBorder(Color(hex: 0x80d889), lineWidth: 0.67 * p)
            Image("Handset")
                .resizable()
                .interpolation(.high)
                .frame(width: 33.67 * p, height: 33.67 * p)
        }
        .frame(width: 77 * p, height: 77 * p)
        .contentShape(Circle())
        // Ring op: kort tryk-effekt, intet sker (som uden SIM)
        .onPress({ down = true }, up: { down = false })
    }
}

struct DeleteButton: View {
    @Environment(AppState.self) private var app
    var p: CGFloat
    @State private var down = false
    @State private var timer: Timer?
    @State private var delay: DispatchWorkItem?

    var body: some View {
        ZStack {
            VBShape(vb: CGSize(width: 34, height: 24)) { p in
                p.move(to: CGPoint(x: 11, y: 1.5))
                p.addLine(to: CGPoint(x: 30.5, y: 1.5))
                p.addArc(tangent1End: CGPoint(x: 33, y: 1.5), tangent2End: CGPoint(x: 33, y: 4), radius: 2.5)
                p.addLine(to: CGPoint(x: 33, y: 20))
                p.addArc(tangent1End: CGPoint(x: 33, y: 22.5), tangent2End: CGPoint(x: 30.5, y: 22.5), radius: 2.5)
                p.addLine(to: CGPoint(x: 11, y: 22.5))
                p.addLine(to: CGPoint(x: 1.6, y: 12))
                p.closeSubpath()
            }
            .fill(down ? Color(hex: 0x555555) : Color(hex: 0x2f2f31))
            VBShape(vb: CGSize(width: 34, height: 24)) { p in p.line(16.6, 7.6, 25.4, 16.4); p.line(25.4, 7.6, 16.6, 16.4) }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.4 * p, lineCap: .round))
        }
        .frame(width: 34 * p, height: 24 * p)
        .contentShape(Rectangle().inset(by: -10 * p))
        .onPress({
            // Slet: ét tegn, hold = slet løbende
            down = true
            app.padDelete()
            let w = DispatchWorkItem {
                timer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { t in
                    Task { @MainActor in
                        app.padDelete()
                        if app.typed.isEmpty { t.invalidate() }
                    }
                }
            }
            delay = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: w)
        }, up: {
            down = false
            delay?.cancel(); timer?.invalidate(); timer = nil
        })
    }
}

struct AddContactIcon: View {
    var body: some View {
        GeometryReader { g in
            let k = g.size.width / 30
            ZStack {
                VBShape(vb: CGSize(width: 30, height: 30)) { p in p.circle(18, 12.5, 10.6) }
                    .stroke(Color.white, lineWidth: 1.9 * k)
                VBShape(vb: CGSize(width: 30, height: 30)) { p in p.circle(18, 10, 3.6) }.fill(Color.white)
                VBShape(vb: CGSize(width: 30, height: 30)) { p in
                    p.move(to: CGPoint(x: 11.4, y: 19.6))
                    p.addCurve(to: CGPoint(x: 18, y: 15.7), control1: CGPoint(x: 12.7, y: 17), control2: CGPoint(x: 15.2, y: 15.7))
                    p.addCurve(to: CGPoint(x: 24.6, y: 19.6), control1: CGPoint(x: 20.8, y: 15.7), control2: CGPoint(x: 23.3, y: 17))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.9 * k, lineCap: .round))
                VBShape(vb: CGSize(width: 30, height: 30)) { p in p.circle(8.6, 20.6, 6.4) }.fill(Color.black)
                VBShape(vb: CGSize(width: 30, height: 30)) { p in
                    p.circle(8.6, 20.6, 5.4); p.line(8.6, 17.6, 8.6, 23.6); p.line(5.6, 20.6, 11.6, 20.6)
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.9 * k, lineCap: .round))
            }
        }
    }
}

struct TabBar: View {
    @Environment(AppState.self) private var app
    var p: CGFloat

    var body: some View {
        let labels = app.tabLabels
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                tab(labels[0], width: 80 * p, active: false) { RecentsIcon() }
                tab(labels[1], width: 82 * p, active: false) { ContactsIcon() }
                tab(labels[2], width: nil, active: true) {
                    VBShape(vb: CGSize(width: 26, height: 24)) { p in
                        for y in [4.0, 12, 20] { for x in [4.5, 13, 21.5] { p.circle(x, y, 3.3) } }
                    }
                    .fill(Color(hex: 0x4aa0f0))
                    .frame(width: 24.5 * p, height: 23 * p)
                }
            }
            .padding(3.5 * p)
            .frame(width: 280 * p, height: 61 * p)
            .background(Capsule().fill(Color(hex: 0x121212)))
            .overlay(Capsule().strokeBorder(Color(hex: 0x2b2b2b), lineWidth: 0.9 * p))
            .shadow(color: .black.opacity(0.4), radius: 9, y: 4)

            Spacer(minLength: 0)

            // Luppen = lommeregner
            Button { app.setMode("calc") } label: {
                VBShape(vb: CGSize(width: 24, height: 24)) { p in p.circle(10.2, 10.2, 7); p.line(15.4, 15.4, 21, 21) }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.3 * p, lineCap: .round))
                    .frame(width: 24 * p, height: 24 * p)
                    .frame(width: 61 * p, height: 61 * p)
                    .background(Circle().fill(Color(hex: 0x121212)))
                    .overlay(Circle().strokeBorder(Color(hex: 0x2b2b2b), lineWidth: 0.9 * p))
                    .shadow(color: .black.opacity(0.4), radius: 9, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func tab<I: View>(_ title: String, width: CGFloat?, active: Bool, @ViewBuilder icon: () -> I) -> some View {
        VStack(spacing: 2 * p) {
            icon().frame(width: 26.5 * p, height: 26.5 * p)
            Text(title)
                .font(.system(size: 10 * p, weight: .medium))
                .kerning(0.1 * p)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.top, 2 * p)
        .padding(.horizontal, 2 * p)
        .foregroundColor(active ? Color(hex: 0x4aa0f0) : .white)
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: .infinity)
        .background(active ? Capsule().fill(Color(hex: 0x2b2b2d)) : nil)
    }
}

/// Opkald-ikonet: fyldt cirkel med urvisere skåret ud
struct RecentsIcon: View {
    var body: some View {
        GeometryReader { g in
            let k = g.size.width / 28
            ZStack {
                VBShape(vb: CGSize(width: 28, height: 28)) { p in p.circle(14, 14, 11.5) }.fill(Color.white)
                VBShape(vb: CGSize(width: 28, height: 28)) { p in
                    p.move(to: CGPoint(x: 13.4, y: 7.4)); p.addLine(to: CGPoint(x: 13.4, y: 14.4)); p.addLine(to: CGPoint(x: 8.8, y: 14.4))
                }
                .stroke(Color(hex: 0x121212), style: StrokeStyle(lineWidth: 2.4 * k, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// Kontakter-ikonet: fyldt cirkel med person skåret ud
struct ContactsIcon: View {
    var body: some View {
        ZStack {
            VBShape(vb: CGSize(width: 28, height: 28)) { p in p.circle(14, 14, 11.5) }.fill(Color.white)
            VBShape(vb: CGSize(width: 28, height: 28)) { p in p.circle(14, 11, 4.2) }.fill(Color(hex: 0x121212))
            VBShape(vb: CGSize(width: 28, height: 28)) { p in
                p.move(to: CGPoint(x: 6.4, y: 22))
                p.addCurve(to: CGPoint(x: 14, y: 17.2), control1: CGPoint(x: 8.1, y: 18.7), control2: CGPoint(x: 10.8, y: 17.2))
                p.addCurve(to: CGPoint(x: 21.6, y: 22), control1: CGPoint(x: 17.2, y: 17.2), control2: CGPoint(x: 19.9, y: 18.7))
                p.addLine(to: CGPoint(x: 21.6, y: 28)); p.addLine(to: CGPoint(x: 6.4, y: 28)); p.closeSubpath()
            }
            .fill(Color(hex: 0x121212))
            .mask(VBShape(vb: CGSize(width: 28, height: 28)) { p in p.circle(14, 14, 11.5) }.fill(Color.white))
        }
    }
}
