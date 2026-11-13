// Volumenknapperne som fjernbetjening: op = start scanning, ned = stop.
// Lytter på lydstyrken (AVAudioSession.outputVolume) og sætter den straks tilbage, så telefonens
// lydstyrke ikke ændrer sig. Et usynligt MPVolumeView skjuler iOS' lydstyrke-boble.
import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

final class VolumeButtons: NSObject {
    static let shared = VolumeButtons()

    var onUp: () -> Void = {}
    var onDown: () -> Void = {}
    var enabled = true { didSet { if enabled { start() } } }

    private var observation: NSKeyValueObservation?
    private var baseline: Float = 0.5
    private var ignoreUntil = Date.distantPast
    weak var volumeView: MPVolumeView?

    func start() {
        guard observation == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        baseline = session.outputVolume
        // Helt oppe/nede kan knappen ikke mærkes – flyt et trin væk fra kanten
        if baseline >= 0.99 { setVolume(0.9375) } else if baseline <= 0.01 { setVolume(0.0625) }
        observation = session.observe(\.outputVolume, options: [.new, .old]) { [weak self] _, change in
            guard let self, let new = change.newValue else { return }
            DispatchQueue.main.async { self.changed(to: new) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// Kaldes når det usynlige MPVolumeView er på plads
    func attach(_ v: MPVolumeView) {
        volumeView = v
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let cur = AVAudioSession.sharedInstance().outputVolume
            if cur >= 0.99 { self.setVolume(0.9375) } else if cur <= 0.01 { self.setVolume(0.0625) } else { self.baseline = cur }
        }
    }

    @objc private func becameActive() {
        try? AVAudioSession.sharedInstance().setActive(true)
        baseline = AVAudioSession.sharedInstance().outputVolume
    }

    private func changed(to v: Float) {
        guard enabled, UIApplication.shared.applicationState == .active else { baseline = v; return }
        if Date() < ignoreUntil { return }
        if abs(v - baseline) < 0.001 { return }
        let up = v > baseline
        setVolume(baseline) // sæt lydstyrken tilbage
        if up { onUp() } else { onDown() }
    }

    private func setVolume(_ v: Float) {
        baseline = v
        ignoreUntil = Date().addingTimeInterval(0.15)
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { slider.setValue(v, animated: false) }
    }
}

/// Usynligt MPVolumeView: skjuler lydstyrke-boblen og bruges til at sætte lydstyrken tilbage
struct VolumeHUDHider: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let host = UIView(frame: .zero)
        let v = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 10, height: 10))
        v.alpha = 0.01
        v.isUserInteractionEnabled = false
        host.addSubview(v)
        VolumeButtons.shared.attach(v)
        return host
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
