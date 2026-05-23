import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum RecordingFormat: String, CaseIterable {
    case mp4 = "MP4"
    case gif = "GIF"
}

enum RecordingFileNamer {
    static func nextURL(format: RecordingFormat) -> URL {
        // F7: Avoid force-unwrap; fall back to ~/Desktop if the URL list is empty.
        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        let folder = UserDefaults.standard.string(forKey: PreferenceKey.recordingSaveFolder.rawValue)
            ?? desktopPath
        let folderURL = URL(fileURLWithPath: folder, isDirectory: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let ext = format == .mp4 ? "mp4" : "gif"
        return folderURL.appendingPathComponent("InitialX-\(timestamp).\(ext)")
    }
}

enum RecordingExporter {
    static func convertMP4ToGIF(
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
        // P7: Cap decode resolution to maxHeight so Core Media never decodes a full 4K frame.
        generator.maximumSize = CGSize(width: 0, height: CGFloat(maxHeight))

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
                    let scaled = scaledImage(cgImage, maxHeight: maxHeight)
                    CGImageDestinationAddImage(destination, scaled, frameProperties as CFDictionary)
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

    private static func scaledImage(_ source: CGImage, maxHeight: Int) -> CGImage {
        let srcWidth = source.width
        let srcHeight = source.height
        guard srcHeight > maxHeight else { return source }
        let scale = Double(maxHeight) / Double(srcHeight)
        let targetWidth = Int(Double(srcWidth) * scale)
        let targetHeight = maxHeight
        let colorSpace = source.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = source.bitmapInfo
        guard let ctx = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: source.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return source }
        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return ctx.makeImage() ?? source
    }

    enum ExporterError: LocalizedError {
        case noFrames
        case gifDestinationFailed
        case gifFinalizeFailed

        var errorDescription: String? {
            switch self {
            case .noFrames: return "Recording produced no frames."
            case .gifDestinationFailed: return "Could not create GIF destination."
            case .gifFinalizeFailed: return "Could not finalize GIF."
            }
        }
    }
}
