import AVFoundation
import CoreVideo
import os

private let camLog = Logger(subsystem: "com.jaequery.Macaveli", category: "camera")

/// Owns the camera capture session that feeds both the on-screen positioning
/// bubble (`CameraOverlayWindow`, via `previewLayer`) and the recorder's
/// frame compositor (via `latestPixelBuffer()`).
///
/// Thread model: `AVCaptureSession` start/stop and the published `previewLayer`
/// are touched on the main thread. Frames arrive on `sampleQueue` and are
/// stashed into `_latest` under `lock`; the recorder reads them from its writer
/// queue. `@unchecked Sendable` because that partitioning is enforced by hand.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    static let shared = CameraManager()

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "com.jaequery.Macaveli.camera.samples", qos: .userInitiated)

    private let lock = NSLock()
    private var _latest: CVPixelBuffer?

    private(set) var isRunning = false
    private var configured = false

    private override init() {}

    /// Preview layer bound to the live session, for the overlay bubble.
    /// Lazily created on the main thread.
    private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    /// Current camera authorization status.
    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Requests camera access if not yet determined; `completion` fires with the
    /// final granted state on the main thread.
    static func requestAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { completion(true) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            DispatchQueue.main.async { completion(false) }
        }
    }

    /// Configures (once) and starts the capture session. No-op if already
    /// running or if access has not been granted.
    func start() {
        guard Self.isAuthorized else {
            camLog.error("camera start skipped — not authorized")
            return
        }
        guard !isRunning else { return }

        if !configured { configureSession() }
        guard configured else { return }

        // startRunning blocks; keep it off the main thread.
        sampleQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
        isRunning = true
        camLog.log("camera session started")
    }

    /// Stops the session and clears the last frame so a stale image can't leak
    /// into the next recording.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        sampleQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
        lock.lock()
        _latest = nil
        lock.unlock()
        camLog.log("camera session stopped")
    }

    /// The most recent camera frame (BGRA), or nil if none has arrived yet.
    func latestPixelBuffer() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return _latest
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            camLog.error("camera configure failed — no usable default video device")
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
        configured = true
        camLog.log("camera session configured device=\(device.localizedName, privacy: .public)")
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock()
        _latest = pixelBuffer
        lock.unlock()
    }
}
