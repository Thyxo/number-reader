// Lommeregner (fra Thyxo/Calcplus): u = 1 % af skærmbredden. Se styles.css og src/calcui.js.
import SwiftUI
import UIKit

struct CalcScreen: View {
    @Environment(AppState.self) private var app
    @State private var bubble = false
    @State private var mainWidth: CGFloat = 0

    static let rows: [[String]] = [
        ["back", "clear", "pct", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "-"], ["1", "2", "3", "+"], ["pm", "0", ",", "="],
    ]

    var body: some View {
        GeometryReader { geo in
            let W = min(geo.size.width, 480)
            let u = W / 100
            let safeTop = max(app.insets.top, 14)
            let safeBottom = max(app.insets.bottom, 14)
            VStack(spacing: 0) {
                topBar(u: u, safeTop: safeTop)
                display(u: u)
                keypad(u: u)
            }
            .padding(.top, safeTop)
            .padding(.bottom, safeBottom + 7.2 * u + CGFloat(app.s.vAdjust))
            .frame(width: W, height: geo.size.height)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .overlay(alignment: .topLeading) {
                if bubble { copyBubble(u: u, W: W, geo: geo) }
            }
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .overlay { if app.menuOpen { ModeMenu() } }
        .overlay { if app.historyOpen { HistorySheet().transition(.move(edge: .bottom)) } }
        .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3), value: app.historyOpen)
    }

    // ---------- top ----------
    private func topBar(u: CGFloat, safeTop: CGFloat) -> some View {
        ZStack {
            // Tryk mellem de to runde knapper = start/stop scanning (feltet går helt op til skærmkanten)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: 64 * u, height: 11 * u + safeTop + 6 * u)
                .offset(y: (-safeTop + 6 * u) / 2)
                .onPress { app.zoneTap() }
            // Peek-tekst øverst mellem ikonerne
            PeekLine(size: 13)
                .frame(width: 64 * u, height: 16)
            HStack {
                HistoryButton(u: u)
                Spacer()
                RoundButton(u: u, glyph: "g-calc") { app.menuOpen.toggle() }
            }
            .padding(.horizontal, 4.12 * u)
        }
        .frame(height: 11 * u)
        .zIndex(2)
    }

    // ---------- display ----------
    private func display(u: CGFloat) -> some View {
        let v = app.calcView
        return VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)
            if let e = v.expr, !e.isEmpty {
                FitText(minScale: 0.6, fade: 4 * u, height: { 7.4 * u * 1.2 * $0 }) { k in
                    parts(e, size: 7.4 * u * k, kern: -0.01, opColor: nil).foregroundColor(Color(hex: 0x8d8d92))
                }
            }
            FitText(minScale: 0.76, fade: 4 * u, height: { 16.4 * u * 1.16 * $0 }) { k in
                parts(v.main, size: 16.4 * u * k, kern: -0.03, opColor: Color(hex: 0x808080)).foregroundColor(.white)
                    .background(GeometryReader { g in Color.clear.onAppear { mainWidth = g.size.width }.onChange(of: g.size.width) { _, w in mainWidth = w } })
            }
        }
        .padding(.leading, 3.9 * u)
        .padding(.trailing, 4.4 * u)
        .padding(.bottom, 2.2 * u)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(displayGesture)
    }

    private func parts(_ ps: [CalcPart], size: CGFloat, kern: CGFloat, opColor: Color?) -> Text {
        ps.reduce(Text("")) { acc, p in
            var t = Text(p.text)
            if p.kind == "op", let c = opColor { t = t.foregroundColor(c) }
            return acc + t
        }
        .font(.system(size: size, weight: .regular))
        .monospacedDigit()
        .kerning(size * kern)
    }

    // Swipe for at slette, hold for at kopiere
    @State private var gStart: Date?
    @State private var gSwiped = false
    @State private var gMoved = false
    @State private var gTimer: DispatchWorkItem?
    private var displayGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if gStart == nil {
                    gStart = Date(); gSwiped = false; gMoved = false; bubble = false
                    let w = DispatchWorkItem { bubble = true }
                    gTimer = w
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.52, execute: w)
                }
                let dx = v.translation.width, dy = v.translation.height
                if abs(dx) > 8 || abs(dy) > 8 { gTimer?.cancel() }
                if !gSwiped && abs(dx) > 34 && abs(dy) < 40 {
                    gSwiped = true
                    app.calcPress("back")
                }
            }
            .onEnded { _ in gTimer?.cancel(); gStart = nil }
    }

    private func copyBubble(u: CGFloat, W: CGFloat, geo: GeometryProxy) -> some View {
        // Over det store tal, centreret på tallet
        let keypadH = 5 * 21.3 * u + 4 * 2.17 * u
        let bottomPad = max(app.insets.bottom, 14) + 7.2 * u + CGFloat(app.s.vAdjust)
        let mainTop = geo.size.height - bottomPad - keypadH - 2.2 * u - 16.4 * u * 1.16
        let cx = (geo.size.width - W) / 2 + W - 4.4 * u - min(mainWidth, W - 8.3 * u) / 2
        return HStack(spacing: 0) {
            Button("Kopiér") {
                UIPasteboard.general.string = app.calc.displayValue().replacingOccurrences(of: "\\.(?=\\d{3})", with: "", options: .regularExpression)
                bubble = false
            }
            .padding(.vertical, 10).padding(.horizontal, 14)
            Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1)
            Button("Indsæt") {
                let v = CalcFormat.parseDisplay(UIPasteboard.general.string ?? "")
                if v.isFinite { app.calcInsert(v) }
                bubble = false
            }
            .padding(.vertical, 10).padding(.horizontal, 14)
        }
        .font(.system(size: 15))
        .foregroundColor(.white)
        .fixedSize()
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0x3a3a3c)))
        .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
        .position(x: max(70, min(geo.size.width - 70, cx)), y: max(30, mainTop - 26))
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    // ---------- tastatur ----------
    private func keypad(u: CGFloat) -> some View {
        VStack(spacing: 2.17 * u) {
            ForEach(CalcScreen.rows, id: \.self) { row in
                HStack(spacing: 2.17 * u) {
                    ForEach(row, id: \.self) { k in CalcKey(k: k, u: u, onDown: { bubble = false }) }
                }
            }
        }
        .padding(.horizontal, 4.12 * u)
    }
}

struct CalcKey: View {
    @Environment(AppState.self) private var app
    var k: String
    var u: CGFloat
    var onDown: () -> Void

    static let glyph: [String: String] = [
        "back": "g-back", "pct": "g-pct", "÷": "g-div", "×": "g-mul", "-": "g-sub", "+": "g-add", "=": "g-eq", "pm": "g-pm", ",": "g-comma",
    ]

    var body: some View {
        let isOp = ["÷", "×", "-", "+", "="].contains(k)
        let isFn = ["back", "clear", "pct"].contains(k)
        let active = isOp && app.calcView.activeOp == k
        GlassKey(size: 21.3 * u, shadow: (2.5 * u, 1.2 * u), onDown: { onDown(); app.calcPress(k) }, onUp: {}) {
            ZStack {
                if active {
                    Capsule().fill(Color.white)
                } else if isOp {
                    Capsule().fill(LinearGradient(stops: [.init(color: Color(hex: 0xff9400), location: 0), .init(color: Color(hex: 0xff9400), location: 0.55),
                                                          .init(color: Color(hex: 0xfb8e00), location: 0.8), .init(color: Color(hex: 0xf68a02), location: 1)],
                                                  startPoint: .top, endPoint: .bottom))
                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                } else if isFn {
                    Capsule().fill(Color(hex: 0x5e5e5e))
                    Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                } else {
                    Capsule().fill(LinearGradient(stops: [.init(color: Color(hex: 0x2a2a2a), location: 0), .init(color: Color(hex: 0x313131), location: 0.3),
                                                          .init(color: Color(hex: 0x343434), location: 0.55), .init(color: Color(hex: 0x323232), location: 1)],
                                                  startPoint: .top, endPoint: .bottom))
                    Capsule().strokeBorder(Color.white.opacity(0.045), lineWidth: 1)
                }
            }
            .animation(.easeOut(duration: 0.25), value: active)
        } label: {
            Group {
                if let g = CalcKey.glyph[k] {
                    Image(g).resizable().renderingMode(.template).frame(width: 14.3 * u, height: 14.3 * u)
                } else if k == "clear" {
                    Text(app.calcView.clearLabel).font(.system(size: 8.6 * u)).kerning(-0.01 * 8.6 * u)
                } else {
                    Text(k).font(.system(size: 9 * u))
                }
            }
            .foregroundColor(active ? Color(hex: 0xff9400) : .white)
        }
    }
}

struct RoundButton: View {
    var u: CGFloat
    var glyph: String
    var action: () -> Void
    @State private var down = false
    var body: some View {
        Image(glyph).resizable().renderingMode(.template)
            .frame(width: 7.8 * u, height: 7.8 * u)
            .foregroundColor(Color(hex: 0xf2f2f2))
            .frame(width: 11 * u, height: 11 * u)
            .background(Circle().fill(down ? Color(hex: 0x2a2a2a) : Color(hex: 0x131313)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.075), lineWidth: 1))
            .animation(down ? nil : .easeOut(duration: 0.3), value: down)
            .contentShape(Circle())
            .onTapGesture { action() }
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in down = true }.onEnded { _ in down = false })
    }
}

/// Ur-knappen: tryk = historik · hold = tilbage til den numeriske blok
struct HistoryButton: View {
    @Environment(AppState.self) private var app
    var u: CGFloat
    @State private var down = false
    @State private var held = false
    @State private var work: DispatchWorkItem?
    var body: some View {
        Image("g-clock").resizable().renderingMode(.template)
            .frame(width: 7.8 * u, height: 7.8 * u)
            .foregroundColor(Color(hex: 0xf2f2f2))
            .frame(width: 11 * u, height: 11 * u)
            .background(Circle().fill(down ? Color(hex: 0x2a2a2a) : Color(hex: 0x131313)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.075), lineWidth: 1))
            .animation(down ? nil : .easeOut(duration: 0.3), value: down)
            .contentShape(Circle())
            .onPress({
                down = true; held = false
                let w = DispatchWorkItem { held = true; Haptic.tap(.light); app.setMode("pad") }
                work = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
            }, up: {
                down = false
                work?.cancel()
                if !held { app.historyOpen = true }
                held = false
            })
    }
}

/// Menu (Almindelig / Videnskabelig / Matematiknoter / Konverter)
struct ModeMenu: View {
    @Environment(AppState.self) private var app
    @State private var shown = false
    var body: some View {
        GeometryReader { geo in
            let W = min(geo.size.width, 480)
            let u = W / 100
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001).ignoresSafeArea().onPress { close() }
                VStack(spacing: 0) {
                    item("Almindelig", "g-m-basic", check: true, u: u)
                    item("Videnskabelig", "g-m-sci", check: false, u: u)
                    item("Matematiknoter", "g-m-notes", check: false, u: u)
                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                        .padding(.vertical, 2.75 * u).padding(.leading, 5.74 * u).padding(.trailing, 5.96 * u)
                    item("Konverter", "g-m-conv", check: false, u: u)
                }
                .padding(.vertical, 2.5 * u)
                .frame(width: 63.2 * u)
                .background(
                    RoundedRectangle(cornerRadius: 7 * u, style: .continuous).fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 7 * u, style: .continuous).fill(Color(red: 22 / 255, green: 21 / 255, blue: 19 / 255).opacity(0.88)))
                        .overlay(RoundedRectangle(cornerRadius: 7 * u, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
                )
                .shadow(color: .black.opacity(0.6), radius: 20, y: 12)
                .scaleEffect(shown ? 1 : 0.35, anchor: UnitPoint(x: 0.92, y: 0.06))
                .opacity(shown ? 1 : 0)
                .padding(.top, max(0, 14 - geo.safeAreaInsets.top))
                .padding(.trailing, (geo.size.width - W) / 2 + 3.8 * u)
            }
        }
        .onAppear { withAnimation(.timingCurve(0.2, 0.9, 0.3, 1.15, duration: 0.26)) { shown = true } }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.16)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { app.menuOpen = false }
    }

    private func item(_ title: String, _ icon: String, check: Bool, u: CGFloat) -> some View {
        Button { close() } label: {
            HStack(spacing: 0) {
                Image("g-m-check").resizable().renderingMode(.template)
                    .frame(width: 4.77 * u, height: 4.77 * u).opacity(check ? 1 : 0)
                    .padding(.leading, 4.5 * u)
                Image(icon).resizable().renderingMode(.template)
                    .frame(width: 6.93 * u, height: 6.93 * u)
                    .padding(.leading, 1.06 * u)
                Text(title).font(.system(size: 4.6 * u)).kerning(-0.01 * 4.6 * u)
                    .padding(.leading, 2.83 * u)
                Spacer(minLength: 0)
            }
            .foregroundColor(Color(hex: 0xf4f4f4))
            .frame(height: 10.6 * u)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuItemStyle())
    }
}

struct MenuItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Color.white.opacity(0.08) : Color.clear)
    }
}

/// Historik (gemmes lokalt som på iPhone)
struct HistorySheet: View {
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(left: "Ryd", title: "Historik", right: "OK", tint: Color(hex: 0xff9f0a),
                        onLeft: { app.clearHistory() }, onRight: { app.historyOpen = false })
            let items = Array(app.calcHistory.reversed())
            if items.isEmpty {
                Text("Ingen historik").foregroundColor(Color(hex: 0x8d8d92)).padding(.top, 200)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, h in
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(h.expr).font(.system(size: 17)).foregroundColor(Color(hex: 0x8d8d92))
                                Text(h.result).font(.system(size: 28))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x1f1f1f)).frame(height: 1) }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let v = CalcFormat.parseDisplay(h.result)
                                if v.isFinite { app.calcInsert(v) }
                                app.historyOpen = false
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .foregroundColor(.white)
        .background(Color.black.ignoresSafeArea())
    }
}

struct SheetHeader: View {
    var left: String?
    var title: String
    var right: String
    var tint: Color
    var onLeft: () -> Void = {}
    var onRight: () -> Void
    var body: some View {
        ZStack {
            Text(title).font(.system(size: 17, weight: .semibold))
            HStack {
                if let left { Button(left, action: onLeft).foregroundColor(tint) }
                Spacer()
                Button(action: onRight) { Text(right).fontWeight(.semibold) }.foregroundColor(tint)
            }
            .font(.system(size: 17))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}
