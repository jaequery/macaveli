import AVFoundation
import Cocoa
import ScreenCaptureKit
import UserNotifications
import os

private let mLog = Logger(subsystem: "com.jaequery.Macaveli", category: "recorder")

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
    private enum LifecycleState { case idle, countingDown, starting, recording, stopping }
    private var lifecycleState: LifecycleState = .idle {
        didSet {
            let recording = lifecycleState == .recording
            if isRecording != recording {
                isRecording = recording
            }
            if recording {
                recordingStartedAt = Date()
            } else if lifecycleState == .idle {
                recordingStartedAt = nil
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var isConverting = false
    @Published private(set) var recordingStartedAt: Date?

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

    private let writerQueue = DispatchQueue(label: "com.jaequery.Macaveli.recorder.writer", qos: .userInitiated)

    // Diagnostics: counts every SCStream frame callback. Reset on recording
    // start. Used only for logging.
    private static var frameCallbackCounter = 0

    // Demo Mode: cursor position samples captured during recording, used by
    // the post-process pass to auto-zoom/pan toward the cursor. Time is
    // seconds-since-recording-start; coords are in the *video* pixel space.
    struct CursorSample {
        let time: Double
        let x: Double
        let y: Double
    }
    private var cursorSamples: [CursorSample] = []
    private var cursorSampler: DispatchSourceTimer?
    private var recordingWallStart: Date?
    private var captureDisplayPointHeight: Int = 0  // for Y-flip
    private var captureScaleFactor: Double = 2.0    // for points→pixels
    private var captureVideoWidth: Int = 0
    private var captureVideoHeight: Int = 0

    // Demo Mode: timestamps (seconds-since-start) of mouse-down events. Used
    // by the post-process pass to trigger a brief "punch zoom" around clicks
    // — the signature professional screen-recorder effect.
    private var clickTimes: [Double] = []
    private var clickMonitor: Any?

    private override init() {}

    func toggle() {
        switch lifecycleState {
        case .idle:
            startRecording()
        case .countingDown:
            // Hotkey pressed during countdown → cancel.
            CountdownOverlay.shared.cancel()
            lifecycleState = .idle
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

        // macOS 14+: go straight to the picker. The countdown runs AFTER the
        // user picks what to share (see SCContentSharingPickerObserver below),
        // so they can pick → compose during 3-2-1 → recording starts. Showing
        // the countdown before the picker would just stall the picker.
        if #available(macOS 14, *) {
            beginCapture()
            return
        }

        // macOS 13 fallback: no picker, so the countdown still runs first.
        // Stored as Int seconds; 0 = disabled. Default 3 when key never set.
        let raw = UserDefaults.standard.object(forKey: PreferenceKey.recordingCountdownSeconds.rawValue) as? Int
        let countdownSeconds = raw ?? 3

        guard countdownSeconds > 0 else {
            beginCapture()
            return
        }

        lifecycleState = .countingDown
        CountdownOverlay.shared.show(seconds: countdownSeconds) { [weak self] in
            guard let self else { return }
            // If the user (or another path) reset state during the countdown,
            // bail without starting capture.
            guard self.lifecycleState == .countingDown else { return }
            self.beginCapture()
        }
    }

    // Bundles everything the SCStream startup path needs, regardless of where
    // the SCContentFilter came from (system picker vs. legacy auto-pick).
    fileprivate struct StreamSetup {
        let filter: SCContentFilter
        let width: Int        // pixels
        let height: Int       // pixels
        let pointHeight: Int  // points — basis for cursor Y-flip in Demo Mode
        let scale: Double     // points → pixels factor
    }

    private func beginCapture() {
        lifecycleState = .starting
        Self.frameCallbackCounter = 0

        // macOS 14+: hand control to SCContentSharingPicker. The user picks
        // what to share via Apple's system UI, so we never "bypass the system
        // private window picker" — no scary privacy dialog on macOS 15+.
        if #available(macOS 14, *) {
            presentContentPicker()
            return
        }

        // macOS 13 fallback: build the filter ourselves (always the main
        // display, excluding our own windows). This path doesn't trigger the
        // bypass dialog because macOS 15 doesn't run there.
        Task { @MainActor in
            do {
                let setup = try await self.buildLegacySetup()
                await self.startStream(with: setup)
            } catch {
                // F6: Sanitize error messages to avoid leaking file paths.
                postNotification(title: "Screen Recording Failed", body: sanitizedBody(for: error))
                self.lifecycleState = .idle
            }
        }
    }

    @MainActor
    private func buildLegacySetup() async throws -> StreamSetup {
        let content = try await SCShareableContent.current
        mLog.log("SCShareableContent: displays=\(content.displays.count, privacy: .public) windows=\(content.windows.count, privacy: .public) applications=\(content.applications.count, privacy: .public)")
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
            throw RecorderError.noPrimaryDisplay
        }
        mLog.log("using display \(display.displayID, privacy: .public) size=\(display.width, privacy: .public)x\(display.height, privacy: .public)")

        let ownWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

        // P9: SCDisplay.width/height are POINTS, SCStreamConfiguration is PIXELS.
        // Multiply by the screen scale or the Retina capture comes out at half
        // native resolution (the "blurry MP4" symptom).
        let scale = Int(NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }?.backingScaleFactor ?? 2.0)

        return StreamSetup(
            filter: filter,
            width: display.width * scale,
            height: display.height * scale,
            pointHeight: display.height,
            scale: Double(scale)
        )
    }

    @available(macOS 14, *)
    private func presentContentPicker() {
        let picker = SCContentSharingPicker.shared
        picker.add(self)
        picker.maximumStreamCount = 1

        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = [.singleDisplay, .singleWindow, .multipleApplications]
        // Hide our own UI (countdown overlay, menubar popover) from the picker
        // selection list — the user shouldn't be able to pick Macaveli itself.
        if let bundleID = Bundle.main.bundleIdentifier {
            config.excludedBundleIDs = [bundleID]
        }
        picker.defaultConfiguration = config

        picker.isActive = true
        picker.present()
    }

    @available(macOS 14, *)
    fileprivate func detachPicker() {
        let picker = SCContentSharingPicker.shared
        picker.isActive = false
        picker.remove(self)
    }

    @MainActor
    fileprivate func startStream(with setup: StreamSetup) async {
        do {
            mLog.log("starting stream \(setup.width, privacy: .public)x\(setup.height, privacy: .public) (scale=\(setup.scale, privacy: .public))")

            let fps = Self.preferredFps()
            let config = SCStreamConfiguration()
            config.width = setup.width
            config.height = setup.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(fps))
            config.queueDepth = 8
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            // P8: Explicit pixel format and cursor visibility.
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = true

            let mp4URL = RecordingFileNamer.nextURL(format: .mp4)
            self.outputMP4URL = mp4URL

            try self.setupAssetWriter(outputURL: mp4URL, width: setup.width, height: setup.height, fps: fps)
            self.setupMicCapture()

            let stream = SCStream(filter: setup.filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.writerQueue)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.writerQueue)
            self.stream = stream

            try await stream.startCapture()
            mLog.log("stream.startCapture returned successfully; awaiting frames…")

            self.lifecycleState = .recording

            // Demo Mode cursor sampling — accurate when the user picks the
            // entire screen; offset by the picked window's origin when they
            // pick a window (acceptable trade-off; the auto-zoom still tracks
            // the cursor's motion).
            self.captureDisplayPointHeight = setup.pointHeight
            self.captureScaleFactor = setup.scale
            self.captureVideoWidth = setup.width
            self.captureVideoHeight = setup.height
            self.startCursorSampling()
            self.startClickTracking()

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
        // Stop cursor sampling first so we don't capture spurious samples
        // after the user has hit stop.
        await MainActor.run {
            self.stopCursorSampling()
            self.stopClickTracking()
        }

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

        // Finalize the asset writer on writerQueue. Returns true iff a writing
        // session actually ran (at least one complete frame arrived).
        let hadSession: Bool = await withCheckedContinuation { continuation in
            self.writerQueue.async {
                guard let writer = self.assetWriter else {
                    mLog.error("teardown: no AVAssetWriter")
                    continuation.resume(returning: false)
                    return
                }
                let sessionRan = self.sessionStarted
                self.videoInput?.markAsFinished()
                self.systemAudioInput?.markAsFinished()
                self.micAudioInput?.markAsFinished()
                // F10: No session ever started → cancel; AVAssetWriter deletes
                // the 0-byte placeholder for us.
                guard sessionRan else {
                    mLog.error("teardown: cancelling — no session ever started (no .complete frames received)")
                    writer.cancelWriting()
                    continuation.resume(returning: false)
                    return
                }
                writer.finishWriting {
                    mLog.log("finishWriting status=\(writer.status.rawValue, privacy: .public) error=\(String(describing: writer.error), privacy: .public)")
                    continuation.resume(returning: true)
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
            self.sessionStartPTS = nil
            self.micStartPTS = nil
        }

        // Decide whether to KEEP the output file.
        //  - Error path (deletePartialFile=true): always delete.
        //  - No session: file was already cancelled by AVAssetWriter.
        //  - Session ran: keep the file, even if AVAssetWriter reported a
        //    non-.completed status — the partial MP4 is almost always playable.
        let url = capturedMP4URL
        let fileExists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let fileSize = url.flatMap { Self.fileSize(at: $0) } ?? 0
        mLog.log("teardown result hadSession=\(hadSession, privacy: .public) url=\(url?.path ?? "nil", privacy: .public) exists=\(fileExists, privacy: .public) size=\(fileSize, privacy: .public)")

        let shouldDelete = deletePartialFile || (!hadSession)
        if shouldDelete, let url = capturedMP4URL {
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

        // Return nil only when there's nothing usable to surface to the caller.
        if shouldDelete { return nil }
        // Also nil out if the file genuinely doesn't exist or is empty — at
        // that point there's nothing the caller can reveal or convert.
        guard fileExists && fileSize > 0 else { return nil }
        return capturedMP4URL
    }

    private static func fileSize(at url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.size] as? Int64
    }

    private func stopRecording() {
        lifecycleState = .stopping

        Task {
            let mp4URL = await teardown(deletePartialFile: false, completionBody: nil)

            let format = self.recordingFormat()
            guard let mp4URL else {
                // F10: Writer produced no usable file (stop pressed before any
                // complete frame, or AVAssetWriter failure). teardown already
                // cleared lifecycle.
                postNotification(
                    title: "Screen Recording Failed",
                    body: "Recording was too short to save. Try holding the recording for at least a second."
                )
                return
            }

            if format == .gif {
                await MainActor.run { self.isConverting = true }

                // Demo Mode for GIF: bake the auto-zoom into the source MP4 so
                // the GIF that ffmpeg generates from it inherits the effect.
                let demoOnGif = UserDefaults.standard.bool(forKey: PreferenceKey.recordingDemoMode.rawValue)
                let gifSamples = self.cursorSamples
                let gifClicks = self.clickTimes
                self.cursorSamples.removeAll()
                self.clickTimes.removeAll()
                mLog.log("GIF stop: demoOn=\(demoOnGif, privacy: .public) samples=\(gifSamples.count, privacy: .public) clicks=\(gifClicks.count, privacy: .public) video=\(self.captureVideoWidth, privacy: .public)x\(self.captureVideoHeight, privacy: .public)")
                if demoOnGif {
                    await withCheckedContinuation { continuation in
                        RecordingExporter.applyDemoMode(
                            input: mp4URL,
                            videoWidth: self.captureVideoWidth,
                            videoHeight: self.captureVideoHeight,
                            cursorSamples: gifSamples,
                            clickTimes: gifClicks
                        ) { _ in continuation.resume() }
                    }
                }

                let gifURL = mp4URL.deletingLastPathComponent()
                    .appendingPathComponent(mp4URL.deletingPathExtension().lastPathComponent)
                    .appendingPathExtension("gif")

                let gifMaxHeight = UserDefaults.standard.integer(forKey: PreferenceKey.recordingGifMaxHeight.rawValue)
                let effectiveMaxHeight = gifMaxHeight > 0 ? gifMaxHeight : 1080

                let gifFps = Self.preferredGifFps()
                await withCheckedContinuation { continuation in
                    RecordingExporter.convertMP4ToGIF(
                        input: mp4URL,
                        output: gifURL,
                        fps: gifFps,
                        maxHeight: effectiveMaxHeight
                    ) { result in
                        switch result {
                        case .success(let url):
                            try? FileManager.default.removeItem(at: mp4URL)
                            self.postNotification(title: "Recording Saved", body: url.lastPathComponent)
                            Self.revealInFinder(url: url)
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
                let demoOn = UserDefaults.standard.bool(forKey: PreferenceKey.recordingDemoMode.rawValue)
                let optimizeOn = UserDefaults.standard.bool(forKey: PreferenceKey.recordingOptimizeMP4.rawValue)
                let samples = self.cursorSamples
                let clicks = self.clickTimes
                self.cursorSamples.removeAll()
                self.clickTimes.removeAll()

                if demoOn || optimizeOn {
                    await MainActor.run { self.isConverting = true }
                }

                // Demo Mode: re-encode with auto-zoom toward cursor path.
                if demoOn {
                    await withCheckedContinuation { continuation in
                        RecordingExporter.applyDemoMode(
                            input: mp4URL,
                            videoWidth: self.captureVideoWidth,
                            videoHeight: self.captureVideoHeight,
                            cursorSamples: samples,
                            clickTimes: clicks
                        ) { _ in continuation.resume() }
                    }
                }

                // Optional optimize-for-sharing pass.
                if optimizeOn {
                    await withCheckedContinuation { continuation in
                        RecordingExporter.optimizeMP4(input: mp4URL) { _ in continuation.resume() }
                    }
                }

                postNotification(title: "Recording Saved", body: mp4URL.lastPathComponent)
                Self.revealInFinder(url: mp4URL)

                if demoOn || optimizeOn {
                    await MainActor.run {
                        self.isConverting = false
                        self.lifecycleState = .idle
                    }
                }
            }
        }
    }

    // MARK: - Cursor sampling (Demo Mode)

    private func startCursorSampling() {
        cursorSamples.removeAll(keepingCapacity: true)
        recordingWallStart = Date()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33))
        timer.setEventHandler { [weak self] in
            self?.sampleCursor()
        }
        timer.resume()
        cursorSampler = timer
    }

    private func stopCursorSampling() {
        cursorSampler?.cancel()
        cursorSampler = nil
        recordingWallStart = nil
    }

    private func startClickTracking() {
        clickTimes.removeAll(keepingCapacity: true)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self, let start = self.recordingWallStart else { return }
            self.clickTimes.append(Date().timeIntervalSince(start))
        }
    }

    private func stopClickTracking() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        clickMonitor = nil
    }

    private func sampleCursor() {
        guard let start = recordingWallStart else { return }
        // NSEvent.mouseLocation: screen points, bottom-left origin.
        let loc = NSEvent.mouseLocation
        let pointHeight = Double(captureDisplayPointHeight)
        let scale = captureScaleFactor
        // Flip to top-left origin, then convert points → video pixels.
        let pixelX = loc.x * scale
        let pixelY = (pointHeight - loc.y) * scale
        let t = Date().timeIntervalSince(start)
        cursorSamples.append(CursorSample(time: t, x: pixelX, y: pixelY))
    }

    /// Reads the user-selected quality preset, defaulting to `.high`.
    private static func preferredQuality() -> RecordingQuality {
        let raw = UserDefaults.standard.string(forKey: PreferenceKey.recordingQuality.rawValue) ?? ""
        return RecordingQuality(rawValue: raw) ?? .defaultValue
    }

    /// Reads the user-selected fps, defaulting to 30.
    private static func preferredFps() -> Int {
        let raw = UserDefaults.standard.integer(forKey: PreferenceKey.recordingFps.rawValue)
        return RecordingFps(rawValue: raw)?.rawValue ?? RecordingFps.defaultValue.rawValue
    }

    /// Reads the user-selected GIF fps, defaulting to 15.
    private static func preferredGifFps() -> Int {
        let raw = UserDefaults.standard.integer(forKey: PreferenceKey.recordingGifFps.rawValue)
        return GifFps(rawValue: raw)?.rawValue ?? GifFps.defaultValue.rawValue
    }

    /// Reveals the saved recording in Finder. Uses `activateFileViewerSelecting`
    /// so Finder opens the containing folder AND highlights the new file.
    private static func revealInFinder(url: URL) {
        DispatchQueue.main.async {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func setupAssetWriter(outputURL: URL, width: Int, height: Int, fps: Int) throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // P10: Explicit H.264 bitrate derived from the user-selected quality
        // preset. The default AVAssetWriter bitrate is too low for screen
        // content, which is why text/UI looked soft in earlier versions.
        let quality = Self.preferredQuality()
        let bitsPerSecond = Double(width * height * fps) * quality.bitsPerPixelPerSecond
        let bitrate = max(4_000_000, min(80_000_000, Int(bitsPerSecond)))
        mLog.log("encoding \(width, privacy: .public)x\(height, privacy: .public)@\(fps, privacy: .public) quality=\(quality.rawValue, privacy: .public) bitrate=\(bitrate / 1_000_000, privacy: .public)Mbps")

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: fps * 2,
                AVVideoExpectedSourceFrameRateKey: fps
            ]
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
            mLog.error("mic capture setup failed: \(String(describing: error), privacy: .public)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        Self.frameCallbackCounter += 1
        if Self.frameCallbackCounter == 1 || Self.frameCallbackCounter % 30 == 0 {
            mLog.log("frame callback #\(Self.frameCallbackCounter, privacy: .public) type=\(type.rawValue, privacy: .public) dataReady=\(CMSampleBufferDataIsReady(sampleBuffer), privacy: .public) writerStatus=\(self.assetWriter?.status.rawValue ?? -1, privacy: .public)")
        }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let writer = assetWriter, writer.status == .writing else { return }

        switch type {
        case .screen:
            // SCStream delivers SCStreamFrameInfo.status on the FIRST SAMPLE's
            // attachment dictionary (via CMSampleBufferGetSampleAttachmentsArray),
            // NOT as a buffer-level attachment (CMGetAttachment). Using the wrong
            // API silently returns nil and every frame gets rejected — which is
            // exactly what was happening before this fix.
            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first else {
                if Self.frameCallbackCounter <= 3 {
                    mLog.log("screen frame #\(Self.frameCallbackCounter, privacy: .public) no attachments array")
                }
                return
            }
            let statusValue = (attachments[SCStreamFrameInfo.status] as? Int)
                ?? (attachments[SCStreamFrameInfo.status] as? NSNumber)?.intValue
            if Self.frameCallbackCounter <= 3 {
                mLog.log("screen frame #\(Self.frameCallbackCounter, privacy: .public) status=\(statusValue ?? -1, privacy: .public)")
            }
            guard let statusValue,
                  let frameStatus = SCFrameStatus(rawValue: statusValue),
                  frameStatus == .complete else {
                return
            }

            if !sessionStarted {
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startSession(atSourceTime: pts)
                sessionStarted = true
                sessionStartPTS = pts
                mLog.log("first frame received, session started at pts=\(CMTimeGetSeconds(pts), privacy: .public)s")
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
                body: "Grant Screen Recording access in System Settings, then relaunch Macaveli."
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
        case noPrimaryDisplay

        var errorDescription: String? {
            switch self {
            case .cannotAddInputs:
                return "Cannot add inputs to AVAssetWriter."
            case .noPrimaryDisplay:
                return "Could not find the primary display."
            }
        }
    }
}

// MARK: - SCContentSharingPickerObserver (macOS 14+)

@available(macOS 14, *)
extension ScreenRecorder: SCContentSharingPickerObserver {
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        detachPicker()

        // filter.contentRect is in POINTS; multiply by pointPixelScale for the
        // SCStreamConfiguration pixel dimensions.
        let scale = Double(filter.pointPixelScale)
        let setup = StreamSetup(
            filter: filter,
            width: Int(filter.contentRect.width * CGFloat(scale)),
            height: Int(filter.contentRect.height * CGFloat(scale)),
            pointHeight: Int(filter.contentRect.height),
            scale: scale
        )

        DispatchQueue.main.async {
            // Now that the user has chosen what to share, run the countdown
            // (if configured) and *then* start the stream — giving them a
            // moment to compose the screen before frames hit disk.
            let raw = UserDefaults.standard.object(forKey: PreferenceKey.recordingCountdownSeconds.rawValue) as? Int
            let countdownSeconds = raw ?? 3

            guard countdownSeconds > 0 else {
                Task { @MainActor in
                    await self.startStream(with: setup)
                }
                return
            }

            self.lifecycleState = .countingDown
            CountdownOverlay.shared.show(seconds: countdownSeconds) { [weak self] in
                guard let self else { return }
                // Bail if the user cancelled during countdown — `toggle()`
                // would have flipped lifecycleState to .idle.
                guard self.lifecycleState == .countingDown else { return }
                self.lifecycleState = .starting
                Task { @MainActor in
                    await self.startStream(with: setup)
                }
            }
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        detachPicker()
        Task { @MainActor in
            self.lifecycleState = .idle
        }
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        detachPicker()
        postNotification(title: "Screen Recording Failed", body: sanitizedBody(for: error))
        Task { @MainActor in
            self.lifecycleState = .idle
        }
    }
}
