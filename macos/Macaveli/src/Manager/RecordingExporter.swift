import AVFoundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import os

private let eLog = Logger(subsystem: "com.jaequery.Macaveli", category: "exporter")

enum RecordingFormat: String, CaseIterable {
    case mp4 = "MP4"
    case gif = "GIF"
}

enum RecordingFileNamer {
    static func nextURL(format: RecordingFormat) -> URL {
        let folderURL = resolveSaveFolder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let ext = format == .mp4 ? "mp4" : "gif"
        let target = folderURL.appendingPathComponent("Macaveli-\(timestamp).\(ext)")
        eLog.log("recording target \(target.path, privacy: .public)")
        return target
    }

    /// Resolves the save folder to a real, writable directory. Handles the
    /// case where the AppStorage default is an empty string (which used to
    /// short-circuit the nil-coalesce fallback and produce an invalid path).
    private static func resolveSaveFolder() -> URL {
        let fm = FileManager.default
        let desktopURL = fm.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")

        let raw = UserDefaults.standard.string(forKey: PreferenceKey.recordingSaveFolder.rawValue) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return desktopURL }

        // Expand a leading ~ if the user (or some import) stored an abbreviated path.
        let expanded = (trimmed as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
            eLog.error("saveFolder \(expanded, privacy: .public) is not a directory; falling back to Desktop")
            return desktopURL
        }
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
}

enum RecordingExporter {
    /// Locates the ffmpeg binary bundled inside the .app at
    /// `Contents/Resources/ffmpeg`. Returns nil if it's missing (e.g. an
    /// out-of-Xcode debug build before fetch-ffmpeg.sh ran). Callers fall back
    /// to the AVFoundation path when nil.
    static func bundledFFmpegURL() -> URL? {
        guard let url = Bundle.main.url(forResource: "ffmpeg", withExtension: nil),
              FileManager.default.isExecutableFile(atPath: url.path) else {
            return nil
        }
        return url
    }

    /// Runs ffmpeg and returns both exit code and full stderr. Use this when
    /// you need to log stderr regardless of exit code (e.g., to diagnose a
    /// filter that "succeeded" but produced no visible effect).
    private static func runFFmpegCapturingStderr(_ ffmpeg: URL, args: [String]) -> (exitCode: Int32, stderr: String) {
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = args
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: data, encoding: .utf8) ?? "<binary stderr>"
            return (process.terminationStatus, stderr)
        } catch {
            return (-1, "launch failed: \(error.localizedDescription)")
        }
    }

    /// Runs ffmpeg synchronously with the given arguments. Returns the exit
    /// code; stderr is collected and logged on non-zero exit.
    @discardableResult
    private static func runFFmpeg(_ ffmpeg: URL, args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = args
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: data, encoding: .utf8) ?? "<no stderr>"
                eLog.error("ffmpeg exit=\(process.terminationStatus, privacy: .public) stderr=\(stderr, privacy: .public)")
            }
            return process.terminationStatus
        } catch {
            eLog.error("ffmpeg launch failed: \(error.localizedDescription, privacy: .public)")
            return -1
        }
    }

    static func convertMP4ToGIF(
        input: URL,
        output: URL,
        fps: Int,
        maxHeight: Int,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Preferred path: ffmpeg with a two-pass palettegen + paletteuse filter
        // graph. This is the gold-standard for high-quality GIF (used by Kap,
        // Gifski-equivalents, etc.). Generates an optimal 256-color palette
        // from the source frames then uses dithering to remap each frame to
        // it — massively reduces banding vs the default CG/ImageIO encoder.
        if let ffmpeg = bundledFFmpegURL() {
            ffmpegConvertMP4ToGIF(
                ffmpeg: ffmpeg,
                input: input,
                output: output,
                fps: fps,
                maxHeight: maxHeight,
                completion: completion
            )
            return
        }
        eLog.log("bundled ffmpeg not found, falling back to CoreImage GIF encoder")
        coreImageConvertMP4ToGIF(
            input: input,
            output: output,
            fps: fps,
            maxHeight: maxHeight,
            completion: completion
        )
    }

    /// ffmpeg-backed GIF conversion. Uses palettegen → paletteuse with
    /// Sierra-Lite dithering for very high quality 256-color output.
    private static func ffmpegConvertMP4ToGIF(
        ffmpeg: URL,
        input: URL,
        output: URL,
        fps: Int,
        maxHeight: Int,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let palette = FileManager.default.temporaryDirectory
                .appendingPathComponent("macaveli-palette-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: palette) }

            // Pass 1: generate optimal palette from the input frames.
            let scaleFilter = "scale=-1:\(maxHeight):flags=lanczos"
            let paletteFilters = "fps=\(fps),\(scaleFilter),palettegen=stats_mode=diff"
            let p1 = runFFmpeg(ffmpeg, args: [
                "-y", "-loglevel", "error",
                "-i", input.path,
                "-vf", paletteFilters,
                palette.path
            ])
            guard p1 == 0 else {
                completion(.failure(ExporterError.gifFinalizeFailed))
                return
            }

            // Pass 2: use the palette to encode the GIF with dithering.
            let useFilters = "fps=\(fps),\(scaleFilter)[x];[x][1:v]paletteuse=dither=sierra2_4a"
            let p2 = runFFmpeg(ffmpeg, args: [
                "-y", "-loglevel", "error",
                "-i", input.path,
                "-i", palette.path,
                "-lavfi", useFilters,
                output.path
            ])
            guard p2 == 0 else {
                try? FileManager.default.removeItem(at: output)
                completion(.failure(ExporterError.gifFinalizeFailed))
                return
            }
            eLog.log("ffmpeg GIF produced \(output.lastPathComponent, privacy: .public)")
            completion(.success(output))
        }
    }

    /// Legacy CoreImage-based encoder used only when bundled ffmpeg is missing.
    /// Keeps the app functional for debug builds before fetch-ffmpeg.sh has run.
    private static func coreImageConvertMP4ToGIF(
        input: URL,
        output: URL,
        fps: Int,
        maxHeight: Int,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let asset = AVURLAsset(url: input)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)

                // F4: Cap frame count to avoid OOM on long recordings (max 40 s @ fps).
                let rawFrameCount = Int(durationSeconds * Double(fps))
                let frameCount = min(rawFrameCount, 600)
                guard frameCount > 0 else {
                    completion(.failure(ExporterError.noFrames))
                    return
                }

                var times: [CMTime] = []
                for i in 0..<frameCount {
                    let seconds = Double(i) / Double(fps)
                    times.append(CMTime(seconds: seconds, preferredTimescale: 600))
                }

                guard let destination = CGImageDestinationCreateWithURL(
                    output as CFURL,
                    UTType.gif.identifier as CFString,
                    frameCount,
                    nil
                ) else {
                    completion(.failure(ExporterError.gifDestinationFailed))
                    return
                }

                let gifProperties: [String: Any] = [
                    kCGImagePropertyGIFLoopCount as String: 0
                ]
                CGImageDestinationSetProperties(destination, [
                    kCGImagePropertyGIFDictionary as String: gifProperties
                ] as CFDictionary)

                let delayTime = 1.0 / Double(fps)
                // F8: Set both delay keys for broadest browser/viewer compatibility.
                let frameProperties: [String: Any] = [
                    kCGImagePropertyGIFDictionary as String: [
                        kCGImagePropertyGIFDelayTime as String: delayTime,
                        kCGImagePropertyGIFUnclampedDelayTime as String: delayTime
                    ]
                ]

                // F4: Add each frame to the destination immediately after decode to avoid
                // accumulating all decoded images in memory at once.
                for time in times {
                    let result = try await generator.image(at: time)
                    let cgImage = result.image
                    let processed = Self.sharpDownsample(
                        cgImage,
                        maxHeight: maxHeight,
                        context: ciContext,
                        colorSpace: colorSpace
                    )
                    CGImageDestinationAddImage(destination, processed, frameProperties as CFDictionary)
                }

                guard CGImageDestinationFinalize(destination) else {
                    completion(.failure(ExporterError.gifFinalizeFailed))
                    return
                }

                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Downsamples `source` to `maxHeight` via CoreImage's Lanczos filter, then
    /// applies a mild unsharp mask. This gives noticeably sharper output than a
    /// plain CGContext draw — important because GIF's 256-color quantization
    /// then compounds any softness in the input.
    private static func sharpDownsample(
        _ source: CGImage,
        maxHeight: Int,
        context: CIContext,
        colorSpace: CGColorSpace
    ) -> CGImage {
        let srcHeight = source.height
        let scale = srcHeight > maxHeight ? CGFloat(maxHeight) / CGFloat(srcHeight) : 1.0

        var ciImage = CIImage(cgImage: source)

        if scale < 1.0 {
            let lanczos = CIFilter.lanczosScaleTransform()
            lanczos.inputImage = ciImage
            lanczos.scale = Float(scale)
            lanczos.aspectRatio = 1.0
            if let scaled = lanczos.outputImage {
                ciImage = scaled
            }
        }

        // Mild sharpening to counteract the blur introduced by downsampling and
        // GIF palette quantization. Keep this conservative — too much sharpening
        // creates "ringing" halos around edges in 256-color GIFs.
        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = ciImage
        sharpen.radius = 1.2
        sharpen.intensity = 0.35
        if let sharpened = sharpen.outputImage {
            ciImage = sharpened
        }

        let extent = ciImage.extent
        if let rendered = context.createCGImage(ciImage, from: extent, format: .RGBA8, colorSpace: colorSpace) {
            return rendered
        }
        return source
    }

    /// Re-encodes the MP4 at `input` to a smaller, shareable file. Prefers
    /// bundled ffmpeg (libx264 -crf 28 -preset slow + faststart) which gives
    /// the best size/quality tradeoff. Falls back to AVAssetExportSession when
    /// ffmpeg isn't bundled.
    static func optimizeMP4(input: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let beforeSize = (try? FileManager.default.attributesOfItem(atPath: input.path))?[.size] as? Int64 ?? 0
        eLog.log("optimize start input=\(input.path, privacy: .public) size=\(beforeSize, privacy: .public)")

        if let ffmpeg = bundledFFmpegURL() {
            ffmpegOptimizeMP4(ffmpeg: ffmpeg, input: input, beforeSize: beforeSize, completion: completion)
            return
        }
        eLog.log("bundled ffmpeg not found, falling back to AVAssetExportSession")

        let asset = AVURLAsset(url: input)

        // Pick the best preset that's actually compatible with this asset.
        // `AVAssetExportSession(asset:presetName:)` silently returns nil if a
        // preset isn't supported — that was a likely source of "optimize does
        // nothing" reports.
        let candidatePresets: [String] = [
            AVAssetExportPreset1920x1080,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPresetPassthrough
        ]
        let availablePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let chosenPreset = candidatePresets.first(where: { availablePresets.contains($0) })

        guard let chosenPreset else {
            eLog.error("optimize failed: no compatible export preset (asset reports \(availablePresets.count, privacy: .public) presets)")
            completion(.failure(ExporterError.exportSessionUnavailable))
            return
        }
        eLog.log("optimize using preset \(chosenPreset, privacy: .public)")

        guard let session = AVAssetExportSession(asset: asset, presetName: chosenPreset) else {
            eLog.error("optimize failed: AVAssetExportSession init returned nil for preset \(chosenPreset, privacy: .public)")
            completion(.failure(ExporterError.exportSessionUnavailable))
            return
        }

        let tempURL = input.deletingLastPathComponent()
            .appendingPathComponent("optimize-\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        session.outputURL = tempURL
        session.outputFileType = .mp4
        // Enables MP4 faststart (moov atom at the front) for quick playback in
        // chat apps and browsers.
        session.shouldOptimizeForNetworkUse = true

        session.exportAsynchronously {
            let status = session.status
            switch status {
            case .completed:
                let afterSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path))?[.size] as? Int64 ?? 0
                eLog.log("optimize done status=completed beforeSize=\(beforeSize, privacy: .public) afterSize=\(afterSize, privacy: .public)")
                do {
                    // Swap optimized file in place of the original.
                    _ = try FileManager.default.replaceItemAt(input, withItemAt: tempURL)
                    completion(.success(input))
                } catch {
                    eLog.error("optimize swap failed: \(error.localizedDescription, privacy: .public)")
                    try? FileManager.default.removeItem(at: tempURL)
                    completion(.failure(error))
                }
            case .failed:
                eLog.error("optimize failed: \(String(describing: session.error), privacy: .public)")
                try? FileManager.default.removeItem(at: tempURL)
                completion(.failure(session.error ?? ExporterError.optimizeFailed))
            case .cancelled:
                eLog.error("optimize cancelled")
                try? FileManager.default.removeItem(at: tempURL)
                completion(.failure(ExporterError.optimizeFailed))
            default:
                eLog.error("optimize ended in unexpected status \(status.rawValue, privacy: .public)")
                try? FileManager.default.removeItem(at: tempURL)
                completion(.failure(session.error ?? ExporterError.optimizeFailed))
            }
        }
    }

    /// ffmpeg-backed optimization: libx264 CRF mode tuned for screen content,
    /// width capped at 2560 (preserves Retina detail), AAC audio at 128k, and
    /// faststart so the file plays instantly in browsers and chat apps.
    private static func ffmpegOptimizeMP4(
        ffmpeg: URL,
        input: URL,
        beforeSize: Int64,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tempURL = input.deletingLastPathComponent()
                .appendingPathComponent("optimize-\(UUID().uuidString)")
                .appendingPathExtension("mp4")

            // Screen-content settings (not natural-video defaults):
            //   -crf 20             20 keeps text/UI edges crisp; the libx264
            //                       default of 23–28 visibly softens screen caps.
            //   -tune animation     preserves flat color regions and sharp
            //                       edges — closest x264 tune for screen UI.
            //   scale … 2560        cap *width* at 2560 so Retina captures
            //                       (~2880–3456 wide) keep most of their detail
            //                       while still shrinking 5K displays.
            //   yuv420p             kept for universal player compat; the
            //                       remaining softness is from chroma subsampling.
            let exitCode = runFFmpeg(ffmpeg, args: [
                "-y", "-loglevel", "error",
                "-i", input.path,
                "-vf", "scale='min(2560,iw)':'-2':force_original_aspect_ratio=decrease",
                "-c:v", "libx264",
                "-preset", "slow",
                "-tune", "animation",
                "-crf", "20",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac",
                "-b:a", "128k",
                "-movflags", "+faststart",
                tempURL.path
            ])

            guard exitCode == 0 else {
                try? FileManager.default.removeItem(at: tempURL)
                completion(.failure(ExporterError.optimizeFailed))
                return
            }

            let afterSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path))?[.size] as? Int64 ?? 0
            eLog.log("ffmpeg optimize done before=\(beforeSize, privacy: .public) after=\(afterSize, privacy: .public)")

            do {
                _ = try FileManager.default.replaceItemAt(input, withItemAt: tempURL)
                completion(.success(input))
            } catch {
                eLog.error("ffmpeg optimize swap failed: \(error.localizedDescription, privacy: .public)")
                try? FileManager.default.removeItem(at: tempURL)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Demo Mode (cursor-following auto-zoom)

    struct CursorSamplePoint {
        let time: Double
        let x: Double
        let y: Double
    }

    /// Re-encodes `input` with a Screen-Studio-style auto-zoom:
    ///   • Cosine ease-in-out between cursor keyframes (no robotic linear lerp)
    ///   • Wide smoothing window so micro-movements don't drag the camera
    ///   • Click-triggered "punch zoom" — briefly tightens the crop around each
    ///     mouse-down, then eases back. This is the distinctive pro-tool feel.
    /// Replaces the file in place on success.
    static func applyDemoMode(
        input: URL,
        videoWidth: Int,
        videoHeight: Int,
        cursorSamples: [ScreenRecorder.CursorSample],
        clickTimes: [Double],
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let ffmpeg = bundledFFmpegURL() else {
            eLog.log("demo mode: ffmpeg not bundled, skipping")
            completion(.success(input))
            return
        }
        guard !cursorSamples.isEmpty else {
            eLog.log("demo mode: no cursor samples captured, skipping")
            completion(.success(input))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Sparse keyframes (every 2s) + wide smoothing window (2s) give
            // the camera a "weighty" feel — small flicks of the cursor don't
            // throw the framing around. This is what makes the result feel
            // intentional rather than tracker-y.
            let keyframes = smoothedKeyframes(cursorSamples, intervalSeconds: 2.0, windowSeconds: 2.0)
            guard keyframes.count >= 2 else {
                eLog.log("demo mode: not enough motion to zoom, skipping")
                completion(.success(input))
                return
            }

            // ffmpeg's `crop` filter has FIXED w/h evaluated once at init —
            // can't vary zoom over time. So we use `zoompan` instead, which
            // re-evaluates z, x, y per frame.
            //
            // Effect: first 1.5s shows the FULL frame (zoom = 1.0); then ease
            // smoothly up to 1.25× while panning to follow the cursor. This
            // is the "establishing shot → close-up" intro that pro tools do.
            let targetZoom: Double = 1.25
            let introSeconds: Double = 1.5

            let cxExpr = buildEasedExpression(keyframes: keyframes, axis: .x)
            let cyExpr = buildEasedExpression(keyframes: keyframes, axis: .y)

            // Intro zoom: 1.0 → targetZoom over `introSeconds`, cosine ease.
            //   ease(t) = 0.5 - 0.5*cos(PI * t / introSeconds), clamped to 1.
            //   zoom(t) = 1.0 + (targetZoom - 1.0) * ease(t)
            let zoomDelta = targetZoom - 1.0
            let zExpr = "if(lt(time,\(introSeconds)),1.0+\(zoomDelta)*(0.5-0.5*cos(PI*time/\(introSeconds))),\(targetZoom))"

            // x and y in zoompan are crop-window top-left in INPUT pixels.
            // Variables `iw`/`ih` are input dimensions; `zoom` is the just-
            // computed z value (zoompan evaluates z first, then x, then y).
            // Crop window is `iw/zoom × ih/zoom`. Center on cursor, then
            // clamp to keep the window inside the input frame.
            let xExpr = "max(0,min(iw*(1-1/zoom),(\(cxExpr))-iw/(2*zoom)))"
            let yExpr = "max(0,min(ih*(1-1/zoom),(\(cyExpr))-ih/(2*zoom)))"

            // zoompan: d=1 → one output frame per input frame; s=WxH → output
            // dimensions match input so the encoder sees a stable stream;
            // fps=30 locks the output framerate.
            let filter = "zoompan=z='\(zExpr)':x='\(xExpr)':y='\(yExpr)':d=1:s=\(videoWidth)x\(videoHeight):fps=30"

            eLog.log("demo mode samples=\(cursorSamples.count, privacy: .public) clicks=\(clickTimes.count, privacy: .public) keyframes=\(keyframes.count, privacy: .public)")
            eLog.log("demo mode video=\(videoWidth, privacy: .public)x\(videoHeight, privacy: .public) targetZoom=\(targetZoom, privacy: .public)x intro=\(introSeconds, privacy: .public)s")
            eLog.log("demo mode filter=\(filter, privacy: .public)")

            let tempURL = input.deletingLastPathComponent()
                .appendingPathComponent("demo-\(UUID().uuidString)")
                .appendingPathExtension("mp4")

            let inputSize = (try? FileManager.default.attributesOfItem(atPath: input.path))?[.size] as? Int64 ?? 0

            let result = runFFmpegCapturingStderr(ffmpeg, args: [
                "-y", "-loglevel", "info",
                "-i", input.path,
                "-vf", filter,
                "-c:v", "libx264",
                "-preset", "fast",
                "-crf", "22",
                "-pix_fmt", "yuv420p",
                "-c:a", "copy",
                "-movflags", "+faststart",
                tempURL.path
            ])

            guard result.exitCode == 0 else {
                // os_log truncates at ~1KB, but ffmpeg's error is at the END
                // of stderr (after the version banner). Keep the tail.
                let stderr = result.stderr
                let tail = String(stderr.suffix(1500))
                // Also dump the full stderr to a temp file so we always have it.
                let dump = FileManager.default.temporaryDirectory
                    .appendingPathComponent("macaveli-ffmpeg-error-\(UUID().uuidString).log")
                try? stderr.write(to: dump, atomically: true, encoding: .utf8)
                eLog.error("demo mode ffmpeg failed exit=\(result.exitCode, privacy: .public) fullStderrDump=\(dump.path, privacy: .public)")
                eLog.error("demo mode ffmpeg stderr tail=\(tail, privacy: .public)")
                try? FileManager.default.removeItem(at: tempURL)
                completion(.failure(ExporterError.optimizeFailed))
                return
            }

            let afterSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path))?[.size] as? Int64 ?? 0
            eLog.log("demo mode encode done before=\(inputSize, privacy: .public) after=\(afterSize, privacy: .public)")

            do {
                _ = try FileManager.default.replaceItemAt(input, withItemAt: tempURL)
                eLog.log("demo mode applied targetZoom=\(targetZoom, privacy: .public)x intro=\(introSeconds, privacy: .public)s keyframes=\(keyframes.count, privacy: .public) clicks=\(clickTimes.count, privacy: .public)")
                completion(.success(input))
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                completion(.failure(error))
            }
        }
    }

    private enum AxisKind { case x, y }

    /// Downsamples the raw 30Hz cursor stream into ~1 keyframe/sec with a
    /// moving-average smoothing window. Reduces jitter and keeps the ffmpeg
    /// filter expression manageable.
    private static func smoothedKeyframes(
        _ samples: [ScreenRecorder.CursorSample],
        intervalSeconds: Double,
        windowSeconds: Double
    ) -> [CursorSamplePoint] {
        guard let last = samples.last else { return [] }
        let totalDuration = last.time
        var keyframes: [CursorSamplePoint] = []
        var t = 0.0
        while t <= totalDuration {
            let lo = t - windowSeconds / 2
            let hi = t + windowSeconds / 2
            let window = samples.filter { $0.time >= lo && $0.time <= hi }
            if !window.isEmpty {
                let avgX = window.reduce(0.0) { $0 + $1.x } / Double(window.count)
                let avgY = window.reduce(0.0) { $0 + $1.y } / Double(window.count)
                keyframes.append(CursorSamplePoint(time: t, x: avgX, y: avgY))
            }
            t += intervalSeconds
        }
        return keyframes
    }

    /// Builds an ffmpeg expression for the cursor's position (x or y, in video
    /// pixels) at the current time. Uses cosine ease-in-out between keyframes
    /// so the camera accelerates and decelerates smoothly — the single biggest
    /// visual difference between "linear lerp tracking" and "professional pan".
    ///
    /// IMPORTANT: this is consumed inside ffmpeg's `zoompan` filter, whose
    /// time variable is `time` (NOT `t`). zoompan defines `time`/`out_time`/`ot`
    /// but does NOT expose a plain `t`, so use `time` here.
    private static func buildEasedExpression(
        keyframes: [CursorSamplePoint],
        axis: AxisKind
    ) -> String {
        func value(_ k: CursorSamplePoint) -> Double {
            axis == .x ? k.x : k.y
        }

        // Build nested `if(between(time,a,b), ease, ...)` so each segment
        // between two keyframes uses easeInOutSine:
        //   u = (time - t0) / dt
        //   eased = 0.5 - 0.5 * cos(PI * u)
        //   value = v0 + (v1 - v0) * eased
        var expr = String(format: "%.1f", value(keyframes.last!))
        for i in stride(from: keyframes.count - 1, through: 1, by: -1) {
            let prev = keyframes[i - 1]
            let curr = keyframes[i]
            let t0 = prev.time
            let t1 = curr.time
            let v0 = value(prev)
            let v1 = value(curr)
            let dt = max(0.001, t1 - t0)
            let seg = String(
                format: "(%.1f+(%.1f)*(0.5-0.5*cos(PI*(time-%.3f)/%.3f)))",
                v0, v1 - v0, t0, dt
            )
            expr = "if(between(time,\(String(format: "%.3f", t0)),\(String(format: "%.3f", t1))),\(seg),\(expr))"
        }
        return expr
    }

    enum ExporterError: LocalizedError {
        case noFrames
        case gifDestinationFailed
        case gifFinalizeFailed
        case exportSessionUnavailable
        case optimizeFailed

        var errorDescription: String? {
            switch self {
            case .noFrames: return "Recording produced no frames."
            case .gifDestinationFailed: return "Could not create GIF destination."
            case .gifFinalizeFailed: return "Could not finalize GIF."
            case .exportSessionUnavailable: return "Could not create export session."
            case .optimizeFailed: return "Could not optimize the recording."
            }
        }
    }
}
