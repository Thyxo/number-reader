// Liquid Glass-tryk (iOS 26): tasten vokser 1,19×, får et lyst overlay, kaster skygge og strækker sig
// mod fingeren ved træk. Slip = fjedrer tilbage. Samme tal som pointermove-koden i src/app.js / calcui.js.
import SwiftUI

struct GlassKey<Background: View, Label: View>: View {
    var size: CGFloat
    var shadow: (radius: CGFloat, y: CGFloat)
    var onDown: () -> Void
    var onUp: () -> Void = {}
    @ViewBuilder var background: () -> Background
    @ViewBuilder var label: () -> Label

    @State private var pressed = false
    @State private var drag = CGSize.zero
    @State private var dragging = false

    var body: some View {
        let lim: (CGFloat) -> CGFloat = { max(-0.6, min(0.6, $0 / size)) }
        let nx = dragging ? lim(drag.width) : 0
        let ny = dragging ? lim(drag.height) : 0
        let ax = abs(nx), ay = abs(ny)
        let sx = pressed ? (dragging ? 1.19 + 0.25 * ax - 0.28 * ay : 1.19) : 1
        let sy = pressed ? (dragging ? 1.19 + 0.25 * ay - 0.28 * ax : 1.19) : 1
        let m = min(sx, sy)
        let ex = sx / m, ey = sy / m
        let tx = pressed ? nx * 0.3 * size : 0
        let ty = pressed ? ny * 0.3 * size : 0
        let anim: Animation = pressed
            ? (dragging ? .linear(duration: 0.07) : .timingCurve(0.2, 0.9, 0.3, 1.12, duration: 0.17))
            : .timingCurve(0.3, 1.45, 0.5, 1, duration: 0.55)

        ZStack {
            background()
            // lyst overlay: lysest i midten
            Capsule()
                .fill(RadialGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.35),
                                             .init(color: .white.opacity(0.84), location: 1)],
                                     center: UnitPoint(x: 0.52, y: 0.5), startRadius: 0, endRadius: size * 0.72))
                .opacity(pressed ? (dragging ? 0.19 : 0.31) : 0)
                .animation(pressed ? (dragging ? .easeOut(duration: 0.25) : .linear(duration: 0.06)) : .easeOut(duration: 0.45), value: pressed)
                .animation(.easeOut(duration: 0.25), value: dragging)
            if pressed {
                Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
            label()
        }
        .frame(width: size * ex, height: size * ey)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(pressed ? 0.55 : 0), radius: shadow.radius, y: shadow.y)
        .scaleEffect(m)
        .offset(x: tx, y: ty)
        .animation(anim, value: pressed)
        .animation(anim, value: drag)
        .frame(width: size, height: size)
        .zIndex(pressed ? 3 : 0)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !pressed { pressed = true; dragging = false; drag = .zero; onDown(); return }
                    if v.translation != .zero { dragging = true; drag = v.translation }
                }
                .onEnded { _ in
                    pressed = false; dragging = false; drag = .zero
                    onUp()
                }
        )
    }
}
