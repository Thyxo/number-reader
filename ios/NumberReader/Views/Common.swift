// Fælles byggesten: tegninger fra webappens SVG'er, tekst der krymper for at passe, flow-layout,
// og en usynlig "lytter" der ser alle tryk (til 5 hurtige tryk øverst til højre).
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// En form tegnet i et SVG-viewBox og skaleret ensartet (som preserveAspectRatio="meet").
struct VBShape: Shape {
    var vb: CGSize
    var build: (inout Path) -> Void
    func path(in rect: CGRect) -> Path {
        var p = Path()
        build(&p)
        let k = min(rect.width / vb.width, rect.height / vb.height)
        let dx = rect.minX + (rect.width - vb.width * k) / 2
        let dy = rect.minY + (rect.height - vb.height * k) / 2
        return p.applying(CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: dx, ty: dy))
    }
}

extension Path {
    mutating func line(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) {
        move(to: CGPoint(x: x0, y: y0)); addLine(to: CGPoint(x: x1, y: y1))
    }
    mutating func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
    }
}

/// Tekst på én linje, der krymper til `minScale` og ellers glider ud mod `alignment`-siden.
struct FitText<Content: View>: View {
    var minScale: CGFloat
    var alignment: Alignment = .trailing
    var fade: CGFloat = 0           // bredde på udtoningen i venstre side ved overløb
    var height: (CGFloat) -> CGFloat
    @ViewBuilder var content: (CGFloat) -> Content // scale → view
    @State private var natural: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let avail = geo.size.width
            let scale = (natural > avail && avail > 0) ? max(minScale, avail / natural) : 1
            let overflow = natural * scale > avail + 0.5
            content(scale)
                .fixedSize()
                .frame(width: avail, height: geo.size.height, alignment: alignment)
                .mask {
                    if overflow && fade > 0 {
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: min(1, fade / max(avail, 1)))],
                                       startPoint: .leading, endPoint: .trailing)
                    } else { Rectangle() }
                }
                .clipped()
        }
        .frame(height: height(fitScale))
        .background(
            content(1).fixedSize().hidden()
                .background(GeometryReader { g in Color.clear.preference(key: WidthKey.self, value: g.size.width) })
        )
        .onPreferenceChange(WidthKey.self) { natural = $0 }
        .background(GeometryReader { g in Color.clear.preference(key: AvailKey.self, value: g.size.width) })
        .onPreferenceChange(AvailKey.self) { avail = $0 }
    }
    @State private var avail: CGFloat = 0
    private var fitScale: CGFloat { (natural > avail && avail > 0) ? max(minScale, avail / natural) : 1 }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct AvailKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Flow-layout (knapper der ombrydes)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, w: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            w = max(w, x - spacing)
        }
        return CGSize(width: proposal.width ?? w, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// Ser alle tryk i vinduet uden at tage dem (som en capture-lytter på document i webappen).
struct TouchObserver: UIViewRepresentable {
    var onTouchDown: (CGPoint, CGSize) -> Void
    var onInsets: (UIEdgeInsets) -> Void = { _ in }

    final class Recognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
        var handler: ((CGPoint, CGSize) -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let w = view, let t = touches.first { handler?(t.location(in: w), w.bounds.size) }
            state = .failed
        }
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
    }

    final class HostView: UIView {
        let rec = Recognizer()
        var onInsets: ((UIEdgeInsets) -> Void)?
        private var lastInsets: UIEdgeInsets?
        override func layoutSubviews() { super.layoutSubviews(); reportInsets() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); reportInsets() }
        private func reportInsets() {
            guard let w = window, w.safeAreaInsets != lastInsets else { return }
            lastInsets = w.safeAreaInsets
            let i = w.safeAreaInsets
            DispatchQueue.main.async { self.onInsets?(i) }
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportInsets()
            guard let w = window, rec.view !== w else { return }
            rec.cancelsTouchesInView = false
            rec.delaysTouchesBegan = false
            rec.delaysTouchesEnded = false
            rec.delegate = rec
            w.addGestureRecognizer(rec)
        }
    }

    func makeUIView(context: Context) -> HostView {
        let v = HostView()
        v.isUserInteractionEnabled = false
        v.rec.handler = onTouchDown
        v.onInsets = onInsets
        return v
    }
    func updateUIView(_ v: HostView, context: Context) { v.rec.handler = onTouchDown; v.onInsets = onInsets }
}

/// Trykket "fra første berøring" (som pointerdown) + slip.
struct PressGesture: ViewModifier {
    var onDown: () -> Void
    var onUp: () -> Void = {}
    @State private var down = false
    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !down { down = true; onDown() } }
                .onEnded { _ in down = false; onUp() }
        )
    }
}
extension View {
    func onPress(_ down: @escaping () -> Void, up: @escaping () -> Void = {}) -> some View {
        modifier(PressGesture(onDown: down, onUp: up))
    }
}
