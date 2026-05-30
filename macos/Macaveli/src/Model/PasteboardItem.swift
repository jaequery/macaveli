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
    /// SHA-256 of the canonical content bytes (UTF-8 text or PNG image data).
    /// Computed once at capture time and persisted so de-dup never re-reads disk.
    let contentHash: String
    /// Optional short user-assigned label for quick identification.
    /// `nil` means no label. Mutable so the manager can edit/remove it in place.
    var label: String?

    // MARK: - Init

    init(id: UUID, kind: Kind, preview: String, byteSize: Int, createdAt: Date, contentHash: String, label: String? = nil) {
        self.id = id
        self.kind = kind
        self.preview = preview
        self.byteSize = byteSize
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.label = label
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, kind, preview, byteSize, createdAt, contentHash, label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,   forKey: .id)
        kind      = try c.decode(Kind.self,   forKey: .kind)
        preview   = try c.decode(String.self, forKey: .preview)
        byteSize  = try c.decode(Int.self,    forKey: .byteSize)
        createdAt = try c.decode(Date.self,   forKey: .createdAt)
        // Legacy manifests predate labels — absent key decodes to nil.
        label     = try c.decodeIfPresent(String.self, forKey: .label)
        // Legacy manifests (pre-hash-caching) don't carry contentHash. Synthesise
        // a stable per-id hash so legacy items remain unique under de-dup — they
        // won't collide with each other, and a fresh copy of the same content
        // simply creates a new entry alongside the legacy one.
        if let stored = try c.decodeIfPresent(String.self, forKey: .contentHash) {
            contentHash = stored
        } else {
            contentHash = SHA256.hash(data: Data(id.uuidString.utf8)).hexString
        }
    }

    // MARK: - Hash helpers

    /// SHA-256 of UTF-8-encoded text. Used by the manager at capture time.
    static func hash(for text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).hexString
    }

    /// SHA-256 of arbitrary bytes (e.g. PNG image data). Used by the manager.
    static func hash(for data: Data) -> String {
        SHA256.hash(data: data).hexString
    }
}

// MARK: - SHA256Digest hex helper

private extension SHA256Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
