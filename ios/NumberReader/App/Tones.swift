// DTMF-tastetoner som på Telefon-appen (samme frekvenser og forløb som tone() i src/app.js).
import AVFoundation
import UIKit

final class Tones {
    static let shared = Tones()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var ready = false

    private static let dtmf: [String: (Double, Double)] = [
        "1": (697, 1209), "2": (697, 1336), "3": (697, 1477), "4": (770, 1209), "5": (770, 1336), "6": (770, 1477),
        "7": (852, 1209), "8": (852, 1336), "9": (852, 1477), "*": (941, 1209), "0": (941, 1336), "#": (941, 1477),
    ]

    private func setup() -> Bool {
        if ready { return true }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        let rate = 44100.0
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return false }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: fmt)
        let n = Int(rate * 0.17)
        for (k, f) in Tones.dtmf {
            guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n)) else { continue }
            buf.frameLength = AVAudioFrameCount(n)
            let p = buf.floatChannelData![0]
            for i in 0..<n {
                let t = Double(i) / rate
                // 0 → 0,08 på 10 ms, hold til 130 ms, ned til 0 ved 160 ms
                let g = t < 0.01 ? 0.08 * t / 0.01 : t < 0.13 ? 0.08 : t < 0.16 ? 0.08 * (0.16 - t) / 0.03 : 0
                p[i] = Float(g * (sin(2 * .pi * f.0 * t) + sin(2 * .pi * f.1 * t)))
            }
            buffers[k] = buf
        }
        do { try engine.start() } catch { return false }
        ready = true
        return true
    }

    func play(_ key: String) {
        guard setup(), let b = buffers[key] else { return }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(b, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }
}

enum Haptic {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
