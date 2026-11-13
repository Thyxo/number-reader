// Kamera + tal-genkendelse med Apple Vision. Kameraet er usynligt, medmindre "Vis søger" er slået til.
// Erstatter src/ocr.js (Tesseract). Samme regler: højeste tal-linje vinder (klokken i statuslinjen
// ignoreres), samme tal skal læses `confirm` gange blandt de sidste 6, eller hurtig accept.
import AVFoundation
import CoreImage
import SwiftUI
import UIKit
import Vision

/// Én tekstlinje fundet af Vision. bbox i pixels i det analyserede billede (origo øverst til venstre).
struct OCRLine: Identifiable {
    let id = UUID()
    var text: String
    var confidence: Double // 0–100
    var bbox: CGRect
}

struct OCRBest {
    var digits: String
    var conf: Double
    var score: Double
    var lineID: UUID?
}

struct DebugFrame: Identifiable {
    let id = UUID()
    var t: Date
    var image: CGImage
    var k: CGFloat          // billedets skala i forhold til det analyserede udsnit
    var lines: [OCRLine]
    var best: OCRBest?
    var strat: String
    var ms: Int
    var vw: Int
    var vh: Int
    var found = false
}

/// Vælg den bedste talrække: telefonnummeret er den STØRSTE tekst på skærmen, så høje linjer
/// vinder over fx klokken i statuslinjen. Lav sikkerhed tæller ned. (pickLine i src/ocr.js)
func pickLine(_ lines: [OCRLine], minLen: Int) -> OCRBest? {
    var best: OCRBest?
    for ln in lines {
        let d = ln.text.filter { $0.isASCII && $0.isNumber }
        if d.count < minLen { continue }
        let h = ln.bbox.height
        let conf = ln.confidence
        if conf < 45 { continue }
        let score = h * (0.5 + conf / 200) + Double(d.count) * 0.5
        if best == nil || score > best!.score { best = OCRBest(digits: String(d), conf: conf, score: score, lineID: ln.id) }
    }
    return best
}

struct ScanOptions {
    var confirm = 2
    var minLen = 3
    var timeout: TimeInterval = 30
    var region = "center"
    var debug = true
}

final class Scanner: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "nr.session")
    private let videoQueue = DispatchQueue(label: "nr.video", qos: .userInitiated)
    private let ci = CIContext(options: [.cacheIntermediates: false])
    private var configured = false
    private let lock = NSLock()
    private var _active = false
    private var _opts = ScanOptions()

    // Kaldes på hovedtråden
    var onFrame: ((OCRBest?, DebugFrame?) -> Void)?
    var onStatus: ((String) -> Void)?

    var active: Bool { lock.lock(); defer { lock.unlock() }; return _active }
    private var opts: ScanOptions { lock.lock(); defer { lock.unlock() }; return _opts }

    func start(_ o: ScanOptions) {
        lock.lock(); _active = true; _opts = o; lock.unlock()
        let go = { [weak self] in
            guard let self else { return }
            self.sessionQueue.async {
                guard self.active else { return }
                if !self.configured && !self.configure() {
                    self.lock.lock(); self._active = false; self.lock.unlock()
                    DispatchQueue.main.async { self.onStatus?("nocamera") }
                    return
                }
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { self.onStatus?("scanning") }
            }
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: go()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                if ok { go() } else {
                    self.lock.lock(); self._active = false; self.lock.unlock()
                    DispatchQueue.main.async { self.onStatus?("nocamera") }
                }
            }
        default:
            lock.lock(); _active = false; lock.unlock()
            onStatus?("nocamera")
        }
    }

    func stop() {
        lock.lock(); _active = false; lock.unlock()
        sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configure() -> Bool {
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: dev) else { return false }
        session.beginConfiguration()
        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high
        guard session.canAddInput(input) else { session.commitConfiguration(); return false }
        session.addInput(input)
        let out = AVCaptureVideoDataOutput()
        out.alwaysDiscardsLateVideoFrames = true
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(out) else { session.commitConfiguration(); return false }
        session.addOutput(out)
        session.commitConfiguration()
        if (try? dev.lockForConfiguration()) != nil {
            if dev.isFocusModeSupported(.continuousAutoFocus) { dev.focusMode = .continuousAutoFocus }
            if dev.isAutoFocusRangeRestrictionSupported { dev.autoFocusRangeRestriction = .near }
            if dev.isExposureModeSupported(.continuousAutoExposure) { dev.exposureMode = .continuousAutoExposure }
            dev.unlockForConfiguration()
        }
        configured = true
        return true
    }

    // Ét billede ad gangen – sene billeder kasseres (alwaysDiscardsLateVideoFrames)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard active, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let o = opts
        let t0 = CACurrentMediaTime()
        // Portræt: bagkameraets billede er drejet
        let img = CIImage(cvPixelBuffer: pb).oriented(.right)
        let full = img.extent
        let vw = Int(full.width), vh = Int(full.height)
        // Udsnit: midten (standard) eller hele billedet
        let cw = o.region == "full" ? full.width : (full.width * 0.86).rounded()
        let ch = o.region == "full" ? full.height : (full.height * 0.46).rounded()
        let crop = CGRect(x: full.minX + ((full.width - cw) / 2).rounded(), y: full.minY + ((full.height - ch) / 2).rounded(), width: cw, height: ch)
        guard let cg = ci.createCGImage(img.cropped(to: crop), from: crop) else { return }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        try? handler.perform([req])
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        var lines: [OCRLine] = []
        for obs in req.results ?? [] {
            guard let top = obs.topCandidates(1).first else { continue }
            let bb = obs.boundingBox
            let r = CGRect(x: bb.minX * W, y: (1 - bb.maxY) * H, width: bb.width * W, height: bb.height * H)
            lines.append(OCRLine(text: top.string, confidence: Double(top.confidence) * 100, bbox: r))
        }
        // Øverst først (som Tesseracts rækkefølge)
        lines.sort { $0.bbox.minY < $1.bbox.minY }
        let best = pickLine(lines, minLen: o.minLen)
        let ms = Int((CACurrentMediaTime() - t0) * 1000)

        var frame: DebugFrame?
        if o.debug {
            let k = min(1, 900 / W)
            let src = CIImage(cgImage: cg).transformed(by: CGAffineTransform(scaleX: k, y: k))
            if let small = ci.createCGImage(src, from: src.extent) {
                frame = DebugFrame(t: Date(), image: small, k: k, lines: lines, best: best,
                                   strat: o.region == "full" ? "Vision · hele" : "Vision · midten", ms: ms, vw: vw, vh: vh)
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.active else { return }
            self.onFrame?(best, frame)
        }
    }
}

/// Lille søger-billede (Vis søger)
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
