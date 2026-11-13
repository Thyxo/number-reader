// Peek-skærm (✱) og debug-visningen (hvad kameraet ser).
import SwiftUI

struct PeekScreen: View {
    @Environment(AppState.self) private var app
    var body: some View {
        let white = app.s.screenColor == "white"
        GeometryReader { geo in
            VStack(spacing: 18) {
                Text(app.word.isEmpty ? (app.cur?.digits ?? "") : app.word)
                    .font(.system(size: min(64, max(34, geo.size.width * 0.13)), weight: .bold))
                    .kerning(-0.01 * 50)
                    .multilineTextAlignment(.center)
                if app.s.screenAlts {
                    let a = app.alts(3)
                    if !a.isEmpty {
                        Text(a.joined(separator: "\n"))
                            .font(.system(size: 18))
                            .lineSpacing(9)
                            .multilineTextAlignment(.center)
                            .opacity(0.5)
                    }
                }
            }
            .padding(24)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .foregroundColor(white ? .black : .white)
        .background((white ? Color.white : Color.black).ignoresSafeArea())
        .contentShape(Rectangle())
        .onPress { app.closePeekScreen() }
    }
}

struct DebugScreen: View {
    @Environment(AppState.self) private var app
    @State private var idx = -1 // -1 = følg nyeste

    var body: some View {
        let frames = app.debugFrames
        let i = frames.isEmpty ? -1 : (idx < 0 ? frames.count - 1 : min(idx, frames.count - 1))
        let f: DebugFrame? = i >= 0 ? frames[i] : nil
        VStack(spacing: 0) {
            // ---------- titel + knapper ----------
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.map { "DEBUG: " + ($0.best?.digits ?? "–") + ($0.found ? "  ✓" : "") } ?? "DEBUG")
                        .font(.system(size: 19, weight: .bold)).kerning(0.2).lineLimit(1)
                    subtitle(f)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x8e8e93))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                dbgButton(system: "camera", color: app.scanning ? Color(hex: 0xff453a) : Color(hex: 0x6fa8ff)) {
                    idx = -1; app.toggleScan()
                }
                dbgButton(system: "trash", color: Color(hex: 0xff453a)) { app.debugFrames.removeAll(); idx = -1 }
                Button { app.debugOpen = false } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 34, height: 34).background(Circle().fill(Color(hex: 0x2c2c2e)))
                }
            }
            .padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 10)

            // ---------- billedet ----------
            ZStack {
                Color(hex: 0x111111)
                if let f {
                    DebugImage(frame: f)
                } else {
                    Text("Ingen billeder endnu.\nTryk på kameraet for at scanne.")
                        .multilineTextAlignment(.center).lineSpacing(6)
                        .font(.system(size: 15)).foregroundColor(Color(hex: 0x8e8e93))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 20).onEnded { v in
                // Swipe mellem billederne
                let n = frames.count
                guard n > 0, abs(v.translation.width) >= 30 else { return }
                let cur = idx < 0 ? n - 1 : idx
                let j = max(0, min(n - 1, cur + (v.translation.width < 0 ? 1 : -1)))
                idx = j == n - 1 ? -1 : j
            })

            // ---------- linjer ----------
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let f {
                        if f.lines.isEmpty {
                            Text("Ingen tekst fundet i billedet").foregroundColor(Color(hex: 0x636366))
                        }
                        ForEach(f.lines) { l in
                            let isBest = f.best?.lineID == l.id
                            Text("\(isBest ? "▶ " : "· ")\(l.text.isEmpty ? "(tom)" : l.text)  \(Int(l.confidence.rounded()))%")
                                .foregroundColor(isBest ? Color(hex: 0x30d158) : (l.confidence < 45 ? Color(hex: 0x636366) : Color(hex: 0xaeaeb2)))
                        }
                    }
                }
                .font(.system(size: 12.5, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.top, 8)
            }
            .frame(maxHeight: 150)
            .fixedSize(horizontal: false, vertical: true)

            // ---------- prikker ----------
            HStack(spacing: 6) {
                ForEach(Array(frames.enumerated()), id: \.element.id) { j, fr in
                    Circle().fill(j == i ? Color.white : fr.found ? Color(hex: 0x30d158) : Color(hex: 0x48484a)).frame(width: 6, height: 6)
                }
            }
            .padding(.top, 10).padding(.bottom, 12)
        }
        .foregroundColor(.white)
        .background(Color.black.ignoresSafeArea())
    }

    private func subtitle(_ f: DebugFrame?) -> Text {
        guard let f else { return Text(app.scanning ? "Scanner …" : "") }
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss dd/MM/yy"
        let hl = "\(f.strat) · \(f.ms) ms" + (f.best.map { " · \(Int($0.conf.rounded()))%" } ?? "")
        return Text("\(df.string(from: f.t)) · ")
            + Text(hl).foregroundColor(Color(hex: 0xff9f0a)).fontWeight(.semibold)
            + Text(" · \(f.vw)×\(f.vh)")
    }

    private func dbgButton(system: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 19)).foregroundColor(color).frame(width: 34, height: 34)
        }
    }
}

/// Billedet med grøn boks om det læste tal (med label) og orange bokse om de andre linjer
struct DebugImage: View {
    var frame: DebugFrame
    var body: some View {
        let w = CGFloat(frame.image.width), h = CGFloat(frame.image.height)
        Image(decorative: frame.image, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                Canvas { ctx, size in
                    let k = size.width / w * frame.k
                    let lw = max(2, size.width / 220)
                    for l in frame.lines {
                        let isBest = frame.best?.lineID == l.id
                        let r = CGRect(x: l.bbox.minX * k, y: l.bbox.minY * k, width: l.bbox.width * k, height: l.bbox.height * k)
                            .insetBy(dx: -lw * 3, dy: -lw * 3)
                        ctx.stroke(Path(r), with: .color(isBest ? Color(hex: 0x30d158) : Color(hex: 0xff9f0a, alpha: 0.7)), lineWidth: isBest ? lw * 1.6 : lw)
                        if isBest, let best = frame.best {
                            let fs = max(14, size.width / 28)
                            let text = ctx.resolve(Text(best.digits).font(.system(size: fs, weight: .semibold)).foregroundColor(.white))
                            let ts = text.measure(in: CGSize(width: 2000, height: 200))
                            let th = fs + 8
                            let bg = CGRect(x: r.midX - (ts.width + 12) / 2, y: r.minY - th - 4, width: ts.width + 12, height: th)
                            ctx.fill(Path(bg), with: .color(.black.opacity(0.75)))
                            ctx.draw(text, at: CGPoint(x: bg.midX, y: bg.midY), anchor: .center)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
