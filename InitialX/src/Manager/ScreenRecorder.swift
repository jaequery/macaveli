import AVFoundation
import Cocoa
import ScreenCaptureKit
import UserNotifications

/// `ScreenRecorder` is `@unchecked Sendable` because access is partitioned
/// across:
/// - Main thread (or `@MainActor` Tasks): `lifecycleState`, `isRecording`,
///   `isConverting`, `outputMP4URL`, `gifAutoStopItem`.
/// - `writerQueue` (serial): `assetWriter`, `videoInput`, `systemAudioInput`,
///   `micAudioInput`, `sessionStarted`, `sessionStartPTS`, `micStartPTS`.
/// - SCStream/AVCaptureSession callback queue (always `writerQueue` here):
///   reads `assetWriter`, `*Input`, `sessionStarted*` / `micStartPTS`.
///
/// New mutable state MUST be classified into one of these partitions and
/// `teardown()` MUST clear it.
final class ScreenRecorder: NSObject, ObservableObject, SCStreamOutput, SCStreamDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    static let shared = ScreenRecorder()

    // P2: Lifecycle state replaces raw boolean to prevent re-entry during async teardown.
    private enum LifecycleState { case idle, starting, recording, stopping }
    private var lifecycleState: LifecycleState = .idle {
        didSet {
            let recording = lifecycleState == .recording
            if isRecording != recording {
                isRecording = recording
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var isConverting = false

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var micAudioInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var outputMP4URL: URL?

    // P1: Timestamps for mic clock remapping.
    private var sessionStartPTS: CMTime?
    private var micStartPTS: CMTime?

    private var micSession: AVCaptureSession?
    private var micOutput: AVCaptureAudioDataOutput?

    // P3: Work item for GIF max-duration auto-stop.
    private var gifAutoStopItem: DispatchWorkItem?

    private let writerQueue = DispatchQueue(label: "com.jaequery.InitialX.recorder.writer", qos: .userInitiated)

    private override init() {}

    func toggle() {
        switch lifecycleState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .starting, .stopping:
            postNotification(title: "Screen Recording", body: "Recording is finishing up — try again in a moment.")
        }
    }

    private func startRecording() {
        // F5: Request notification auth lazily — only when the user actually starts recording.
        ensureNotificationAuth()

        guard checkPermissions() else { return }
        lifecycleState = .starting

        Task { @MainActor in
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
                    postNotification(title: "Screen Recording", body: "Could not find the primary display.")
                    self.lifecycleState = .idle
                    return
                }

                let ownWindows = content.windows.filter {
                    $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
                }

                let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                // P6: 30 fps as per spec.
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.queueDepth = 8
                config.capturesAudio = true
                config.sampleRate = 48000
                config.channelCount = 2
                // P8: Explicit pixel format and cursor visibility.
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = true

                let mp4URL = RecordingFileNamer.nextURL(format: .mp4)
                self.outputMP4URL = mp4URL

                try self.setupAssetWriter(outputURL: mp4URL, display: display)
                self.setupMicCapture()

                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.writerQueue)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.writerQueue)
                self.stream = stream

                try await stream.startCapture()

                self.lifecycleState = .recording

                // P3: Schedule auto-stop for GIF max duration.
                let currentFormat = self.recordingFormat()
                if currentFormat == .gif {
                    let maxSeconds = UserDefaults.standard.integer(forKey: PreferenceKey.recordingGifMaxSeconds.rawValue)
                    let effectiveMax = maxSeconds > 0 ? maxSeconds : 30
                    let item = DispatchWorkItem { [weak self] in
                        guard let self, self.lifecycleState == .recording, self.recordingFormat() == .gif else { return }
                        self.postNotification(
                            title: "Screen Recording",
                            body: "GIF max duration of \(effectiveMax) seconds reached."
                        )
                        self.stopRecording()
                    }
                    self.gifAutoStopItem = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(effectiveMax), execute: item)
                }
            } catch {
                // F6: Sanitize error messages to avoid leaking file paths.
                postNotification(title: "Screen Recording Failed", body: sanitizedBody(for: error))
                self.lifecycleState = .idle
            }
        }
    }

    /// Shared teardown helper called by both `stopRecording` (clean path) and
    /// `didStopWithError` (error path). Finalizes the AVAssetWriter, stops the
    /// mic session, nils all writer state, and optionally deletes the partial
    /// output file.
    ///
    /// - Parameters:
    ///   - deletePartialFile: When `true`, removes `outputMP4URL` after
    ///     `finishWriting` completes (used on the error path).
    ///   - completionBody: When non-nil, posts a "Screen Recording Stopped"
    ///     notification with this body after teardown (used on the error path).
    ///
    /// - Returns: The captured `outputMP4URL` before it is nilled, so the
    ///   success path in `stopRecording` can continue GIF conversion.
    @discardableResult
    private func teardown(deletePartialFile: Bool, completionBody: String?) async -> URL? {
        // Cancel the GIF auto-stop timer.
        gifAutoStopItem?.cancel()
        gifAutoStopItem = nil

        // Stop the mic capture session.
        micSession?.stopRunning()
        micSession = nil
        micOutput = nil

        // Capture and nil out the stream reference so no more frames arrive.
        let capturedStream = self.stream
        self.stream = nil
        try? await capturedStream?.stopCapture()

        // Finalize the asset writer on writerQueue.
        await withCheckedContinuation { continuation in
            self.writerQueue.async {
                guard let writer = self.assetWriter else {
                    continuation.resume()
                    return
                }
                self.videoInput?.markAsFinished()
                self.systemAudioInput?.markAsFinished()
                self.micAudioInput?.markAsFinished()
                writer.finishWriting {
                    continuation.resume()
                }
            }
        }

        // Capture outputMP4URL before clearing writer state.
        let capturedMP4URL = self.outputMP4URL

        // Clear all writer state on writerQueue.
        self.writerQueue.sync {
            self.assetWriter = nil
            self.videoInput = nil
            self.systemAudioInput = nil
            self.micAudioInput = nil
            self.sessionStarted = false
            // P1: Clear timing anchors on stop.
            self.sessionStartPTS = nil
            self.micStartPTS = nil
        }

        // Optionally delete the partial file (error path only).
        if deletePartialFile, let url = capturedMP4URL {
            try? FileManager.default.removeItem(at: url)
        }

        // F2: Transition to idle on main thread so @Published isRecording fires correctly.
        await MainActor.run {
            self.outputMP4URL = nil
            self.lifecycleState = .idle
        }

        // Post error notification if requested.
        if let body = completionBody {
            postNotification(title: "Screen Recording Stopped", body: body)
        }

        return capturedMP4URL
    }

    private func stopRecording() {
        lifecycleState = .stopping

        Task {
            let mp4URL = await teardown(deletePartialFile: false, completionBody: nil)

            let format = self.recordingFormat()
            guard let mp4URL else {
                // No output file; lifecycle already set to idle in teardown.
                return
            }

            if format == .gif {
                await MainActor.run { self.isConverting = true }
                let gifURL = mp4URL.deletingLastPathComponent()
                    .appendingPathComponent(mp4URL.deletingPathExtension().lastPathComponent)
                    .appendingPathExtension("gif")

                let gifMaxHeight = UserDefaults.standard.integer(forKey: PreferenceKey.recordingGifMaxHeight.rawValue)
                let effectiveMaxHeight = gifMaxHeight > 0 ? gifMaxHeight : 720

                await withCheckedContinuation { continuation in
                    RecordingExporter.convertMP4ToGIF(
                        input: mp4URL,
                        output: gifURL,
                        fps: 15,
                        maxHeight: effectiveMaxHeight
                    ) { result in
                        switch result {
                        case .success(let url):
                            try? FileManager.default.removeItem(at: mp4URL)
                            self.postNotification(title: "Recording Saved", body: url.lastPathComponent)
                        case .failure(let error):
                            // F6: Sanitize GIF export error messages.
                            self.postNotification(title: "GIF Export Failed", body: self.sanitizedBody(for: error))
                        }
                        continuation.resume()
                    }
                }
                await MainActor.run {
                    self.isConverting = false
                    // lifecycleState was already set to .idle in teardown; this is a no-op
                    // but kept explicit for clarity.
                    self.lifecycleState = .idle
                }
            } else {
                postNotification(title: "Recording Saved", body: mp4URL.lastPathComponent)
                // lifecycleState already set to .idle in teardown.
            }
        }
    }

    private func setupAssetWriter(outputURL: URL, display: SCDisplay) throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: display.width,
            AVVideoHeightKey: display.height
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192000
        ]
        let sysAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        sysAudioInput.expectsMediaDataInRealTime = true

        let micAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        micAudioInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(vInput),
              writer.canAdd(sysAudioInput),
              writer.canAdd(micAudioInput) else {
            throw RecorderError.cannotAddInputs
        }

        writer.add(vInput)
        writer.add(sysAudioInput)
        writer.add(micAudioInput)
        writer.startWriting()

        self.assetWriter = writer
        self.videoInput = vInput
        self.systemAudioInput = sysAudioInput
        self.micAudioInput = micAudioInput
        self.sessionStarted = false
    }

    private func setupMicCapture() {
        // F3: Best-effort mic — bail silently if not authorized.
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        guard let micDevice = AVCaptureDevice.default(for: .audio) else { return }
        let session = AVCaptureSession()
        do {
            let input = try AVCaptureDeviceInput(device: micDevice)
            guard session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: writerQueue)
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)

            micSession = session
            micOutput = output
            session.startRunning()
        } catch {
            print("Mic capture setup failed: \(error)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let writer = assetWriter, writer.status == .writing else { return }

        switch type {
        case .screen:
            guard let statusAttachment = CMGetAttachment(
                sampleBuffer,
                key: SCStreamFrameInfo.status as CFString,
                attachmentModeOut: nil
            ) as? Int,
                  let frameStatus = SCFrameStatus(rawValue: statusAttachment),
                  frameStatus == .complete else { return }

            if !sessionStarted {
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startSession(atSourceTime: pts)
                sessionStarted = true
                // P1: Capture the session start PTS for mic clock remapping.
                sessionStartPTS = pts
            }

            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }

        case .audio:
            if !sessionStarted { return }
            if systemAudioInput?.isReadyForMoreMediaData == true {
                systemAudioInput?.append(sampleBuffer)
            }

        case .microphone:
            // Mic audio is handled via AVCaptureSession / captureOutput(_:didOutput:from:).
            break

        @unknown default:
            break
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard sessionStarted,
              let writer = assetWriter,
              writer.status == .writing,
              micAudioInput?.isReadyForMoreMediaData == true else { return }

        // P1: Retime mic samples to the writer's session clock.
        guard let anchor = sessionStartPTS else { return }
        let micPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if micStartPTS == nil {
            micStartPTS = micPTS
        }
        let micOffset = CMTimeSubtract(micPTS, micStartPTS!)
        let targetPTS = CMTimeAdd(anchor, micOffset)

        if let retimed = retimedSample(sampleBuffer, to: targetPTS) {
            micAudioInput?.append(retimed)
        }
    }

    // P1: Helper to produce a copy of a sample buffer with a new presentation timestamp.
    private func retimedSample(_ sample: CMSampleBuffer, to time: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sample),
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )
        var out: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sample,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &out
        )
        return status == noErr ? out : nil
    }

    // F1 + F2: Error path now delegates to teardown, which handles all resource
    // cleanup and posts to main before mutating @Published state.
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task {
            // F6: Sanitize error body to avoid leaking file paths.
            await teardown(deletePartialFile: true, completionBody: sanitizedBody(for: error))
        }
    }

    // F3: Mic is now best-effort. Screen recording permission is the only hard gate.
    private func checkPermissions() -> Bool {
        guard PermissionsManager.hasScreenRecordingPermission() else {
            PermissionsManager.requestScreenRecordingPermission()
            postNotification(
                title: "Screen Recording Permission Required",
                body: "Grant Screen Recording access in System Settings, then relaunch InitialX."
            )
            PermissionsManager.openPreferences(at: .screenRecording)
            return false
        }

        // If mic is undetermined, trigger the system prompt but proceed regardless.
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            PermissionsManager.requestMicrophonePermission { _ in }
        } else if micStatus == .denied || micStatus == .restricted {
            postNotification(
                title: "Screen Recording",
                body: "Recording without microphone — grant Microphone access in System Settings to include mic audio."
            )
        }

        return true
    }

    private func recordingFormat() -> RecordingFormat {
        let raw = UserDefaults.standard.string(forKey: PreferenceKey.recordingFormat.rawValue) ?? ""
        return RecordingFormat(rawValue: raw) ?? .mp4
    }

    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // F5: Lazy notification auth — only requested on first recording attempt.
    private func ensureNotificationAuth() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    // F6: Sanitize error bodies so system errors with POSIX paths are not exposed.
    private func sanitizedBody(for error: Error) -> String {
        if let recorderError = error as? RecorderError {
            return recorderError.errorDescription ?? "Unknown error."
        }
        if let exporterError = error as? RecordingExporter.ExporterError {
            return exporterError.errorDescription ?? "Unknown error."
        }
        return "An error occurred. See Console for details."
    }

    enum RecorderError: LocalizedError {
        case cannotAddInputs

        var errorDescription: String? {
            "Cannot add inputs to AVAssetWriter."
        }
    }
}
