// Number Reader – native iOS-version af webappen (numerisk blok + lommeregner der scanner T9-tal).
import AVFoundation
import SwiftUI

@main
struct NumberReaderApp: App {
    @State private var app = AppState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
                .persistentSystemOverlays(.automatic)
                .onChange(of: phase) { _, p in
                    // Stop kameraet når appen lægges væk
                    if p != .active && app.scanning { app.stopScan() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @State private var secretTaps: [Date] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if app.s.mode == "calc" { CalcScreen() } else { PadView() }

            if app.secretOpen {
                SecretPanel().transition(.move(edge: .bottom)).zIndex(40)
            }
            if app.debugOpen { DebugScreen().zIndex(80) }
            if app.peekScreenOpen { PeekScreen().zIndex(60) }
            // Lille søger (træning)
            if app.s.viewfinder && app.scanning {
                Viewfinder(session: app.scanner.session, topPad: 50 + max(0, 14 - app.insets.top)).zIndex(70)
            }
            TouchObserver(onTouchDown: secretTap, onInsets: { i in
                app.insets = EdgeInsets(top: i.top, leading: i.left, bottom: i.bottom, trailing: i.right)
            })
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
    }

    /// 5 hurtige tryk øverst til højre = hemmeligt panel
    private func secretTap(_ pt: CGPoint, _ size: CGSize) {
        if app.secretOpen || app.peekScreenOpen || app.debugOpen { return }
        let w = min(size.width, 480)
        let left = (size.width - w) / 2
        let inZone = pt.x > left + w * 0.62 && pt.y < w * 0.36
        if !inZone { secretTaps = []; return }
        let now = Date()
        secretTaps = secretTaps.filter { now.timeIntervalSince($0) < 2.5 }
        secretTaps.append(now)
        if secretTaps.count >= 5 {
            secretTaps = []
            app.menuOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) { app.openSecret(tapTime: now) }
        }
    }
}

/// Lille søger (træning) øverst til højre
struct Viewfinder: View {
    var session: AVCaptureSession
    var topPad: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        let blue = Color(hex: 0x0a84ff)
        return CameraPreview(session: session)
            .frame(width: 120, height: 160)
            .clipShape(shape)
            .overlay(shape.strokeBorder(blue, lineWidth: 2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 10)
            .padding(.top, topPad)
            .allowsHitTesting(false)
    }
}
