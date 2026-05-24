import Foundation
import CryptoKit

// MARK: - PasteboardItem

/// A single entry in the clipboard history.
///
/// `Codable` for JSON persistence in
/// `~/Library/Application Support/Macaveli/PasteHistory/manifest.json`.
struct PasteboardItem: Identifiable, Codable, Equatable {

    // MARK: - Kind

    enum Kind: Codable, Equatable {
        /// Plain text, with an optional RTF payload preserved for faithful re-paste.
        case text(plain: String, rtf: Data?)
        /// An image stored as a PNG file under the `images/` subdirectory.
        /// `filename` is `<uuid>.png` — relative, never an absolute path.
        case image(filename: String)
    }

    // MARK: - Stored properties

    let id: UUID
    let kind: Kind
    /// Up to 200 characters of plain-text summary used for display and search.
    let preview: String
    /// Raw byte count: UTF-8 length for text, PNG file size for images.
    let byteSize: Int
    let createdAt: Date

    // MARK: - Content hash

    /// SHA-256 of the item's canonical content bytes.
    ///
    /// Text: UTF-8 bytes of `plain`.
    /// Image: PNG file bytes, loaded on demand.
    /// If the image file is missing the hash falls back to the item's id bytes
    /// so de-dup never crashes, and the missing-file case is treated as unique.
    var contentHash: String {
        switch kind {
        case .text(let plain, _):
            let data = Data(plain.utf8)
            return SHA256.hash(data: data).hexString

        case .image(let filename):
            let fm = FileManager.default
            guard
                let support = fm.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first
            else {
                return id.uuidString
            }
            let url = support
                .appendingPathComponent("Macaveli/PasteHistory/images")
                .appendingPathComponent(filename)
            guard
                fm.fileExists(atPath: url.path),
                let data = try? Data(contentsOf: url)
            else {
                // Stable per-id fallback — file missing but we must not crash.
                return SHA256.hash(data: Data(id.uuidString.utf8)).hexString
            }
            return SHA256.hash(data: data).hexString
        }
    }
}

// MARK: - SHA256Digest hex helper

private extension SHA256Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
