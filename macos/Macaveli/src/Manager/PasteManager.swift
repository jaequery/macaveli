import AppKit
import Foundation
import os.log

// MARK: - PastePanelHost protocol

/// Thin bridge between `PasteManager` and the concrete `PasteWindowController`
/// that lives in the View layer. Defined here so the Manager has zero UI imports.
protocol PastePanelHost: AnyObject {
    func toggle()
    func show()
    func hide()
}

// MARK: - PasteManager

/// Singleton that owns the clipboard history.
///
/// Responsibilities:
/// - Poll `NSPasteboard.general.changeCount` every 0.5 s and capture new items.
/// - Maintain `@Published var items` (newest first).
/// - Persist history to Application Support as `manifest.json` + PNG blobs.
/// - Expose `togglePanel()` / `showPanel()` / `hidePanel()` via a weak
///   `PastePanelHost` so the View layer can be wired in without a hard import.
/// - `activate(_:)` writes the selected item back to the pasteboard, restores
///   focus to the previously-focused app, and dispatches a synthetic ⌘V.
final class PasteManager: ObservableObject {

    // MARK: Singleton

    static let shared = PasteManager()

    // MARK: Published state

    @Published var items: [PasteboardItem] = []

    // MARK: Panel host wiring

    /// Set by the UI layer at launch so `togglePanel()` can lazily create the host.
    var makePanelHost: (() -> PastePanelHost)?

    /// Weak reference to the live panel host. Lazily populated on first `togglePanel()`.
    weak var panelHost: PastePanelHost?

    // MARK: Private state

    private var lastChangeCount: Int = 0
    private var pollingTimer: Timer?
    /// PID of the app that was frontmost when the panel was last shown.
    private var prevFrontmostPID: pid_t = 0

    // MARK: Storage

    private let storageQueue = DispatchQueue(label: "com.macaveli.pastemanager.storage", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    private lazy var pasteHistoryDir: URL = {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return support.appendingPathComponent("Macaveli/PasteHistory")
    }()

    private var imagesDir: URL { pasteHistoryDir.appendingPathComponent("images") }
    private var manifestURL: URL { pasteHistoryDir.appendingPathComponent("manifest.json") }

    private let logger = Logger(subsystem: "com.macaveli", category: "PasteManager")

    // MARK: - Init

    private init() {
        createStorageDirsIfNeeded()
        loadManifest()
        // Snapshot the current changeCount so we do not immediately re-capture
        // whatever is already in the pasteboard at launch.
        lastChangeCount = NSPasteboard.general.changeCount
        startPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        let current = pb.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        capture(pb: pb)
    }

    // MARK: - Capture

    private func capture(pb: NSPasteboard) {
        // Honor the nspasteboard.org privacy opt-out used by password managers:
        // if the pasteboard carries ConcealedType, do not record this entry.
        if pb.types?.map(\.rawValue).contains("org.nspasteboard.ConcealedType") == true {
            return
        }

        let id = UUID()
        let now = Date()
        let kind: PasteboardItem.Kind

        if let nsImage = NSImage(pasteboard: pb) {
            guard let pngData = pngData(from: nsImage) else { return }
            let filename = "\(id.uuidString).png"
            let fileURL = imagesDir.appendingPathComponent(filename)
            do {
                try pngData.write(to: fileURL, options: .atomic)
            } catch {
                logger.error("PasteManager: failed to write image \(filename): \(error.localizedDescription)")
                return
            }
            let preview = "Image (\(byteCountString(pngData.count)))"
            let item = PasteboardItem(
                id: id,
                kind: .image(filename: filename),
                preview: preview,
                byteSize: pngData.count,
                createdAt: now
            )
            addOrPromote(item)

        } else if let rtfData = pb.data(forType: .rtf) {
            let plain = pb.string(forType: .string) ?? ""
            let preview = String(plain.prefix(200))
            let byteSize = plain.utf8.count
            let item = PasteboardItem(
                id: id,
                kind: .text(plain: plain, rtf: rtfData),
                preview: preview,
                byteSize: byteSize,
                createdAt: now
            )
            addOrPromote(item)

        } else if let plain = pb.string(forType: .string), !plain.isEmpty {
            let preview = String(plain.prefix(200))
            let byteSize = plain.utf8.count
            let item = PasteboardItem(
                id: id,
                kind: .text(plain: plain, rtf: nil),
                preview: preview,
                byteSize: byteSize,
                createdAt: now
            )
            addOrPromote(item)
        }
        // File URLs and other unrecognised types are intentionally ignored.
    }

    /// Inserts `newItem` into the front of `items`, de-duping against existing entries.
    ///
    /// - If `items.first` has the same content hash: no-op (identical consecutive copy).
    /// - If a *non-first* item matches: move it to front; persist.
    /// - Otherwise: prepend and evict beyond the history cap.
    private func addOrPromote(_ newItem: PasteboardItem) {
        let hash = newItem.contentHash

        // De-dup: identical to the current top — ignore entirely.
        if let first = items.first, first.contentHash == hash {
            return
        }

        // De-dup: exists but not at front — promote to front.
        if let existingIndex = items.firstIndex(where: { $0.contentHash == hash }) {
            let existing = items.remove(at: existingIndex)
            items.insert(existing, at: 0)
            scheduleSave()
            return
        }

        // New item: prepend.
        items.insert(newItem, at: 0)

        // Evict beyond the history cap.
        let cap = historyCap()
        if items.count > cap {
            let evicted = items.suffix(from: cap)
            for item in evicted {
                deleteImageFile(for: item)
            }
            items = Array(items.prefix(cap))
        }

        scheduleSave()
    }

    // MARK: - Panel host

    func togglePanel() {
        if panelHost == nil {
            panelHost = makePanelHost?()
        }
        guard let host = panelHost else {
            logger.debug("PasteManager: togglePanel called but no panelHost is wired.")
            return
        }
        host.toggle()
    }

    func showPanel() {
        if panelHost == nil {
            panelHost = makePanelHost?()
        }
        guard let host = panelHost else {
            logger.debug("PasteManager: showPanel called but no panelHost is wired.")
            return
        }
        host.show()
    }

    func hidePanel() {
        panelHost?.hide()
    }

    // MARK: - Previous frontmost app

    /// Records the currently-frontmost application PID.
    /// Must be called *before* the panel activates so we can restore focus later.
    func recordCurrentFrontmost() {
        prevFrontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
    }

    // MARK: - Activate (paste) an item

    func activate(_ item: PasteboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.kind {
        case .text(let plain, let rtfData):
            var types: [NSPasteboard.PasteboardType] = [.string]
            if rtfData != nil { types.append(.rtf) }
            pb.declareTypes(types, owner: nil)
            pb.setString(plain, forType: .string)
            if let rtfData = rtfData {
                pb.setData(rtfData, forType: .rtf)
            }

        case .image(let filename):
            let fileURL = imagesDir.appendingPathComponent(filename)
            guard
                FileManager.default.fileExists(atPath: fileURL.path),
                let image = NSImage(contentsOfFile: fileURL.path)
            else {
                logger.error("PasteManager: image file missing for activation: \(filename)")
                return
            }
            pb.writeObjects([image])
        }

        hidePanel()

        let pid = prevFrontmostPID
        guard pid != 0 else {
            logger.debug("PasteManager: no previous frontmost PID recorded; skipping focus restore.")
            return
        }

        // Restore focus to the previously-focused app, then send ⌘V after a
        // short delay so the focus change settles before the keystroke arrives.
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let src = CGEventSource(stateID: .hidSystemState)
            guard
                let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
                let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            else {
                return
            }
            down.flags = .maskCommand
            up.flags   = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Delete / clear

    func delete(_ item: PasteboardItem) {
        deleteImageFile(for: item)
        items.removeAll { $0.id == item.id }
        scheduleSave()
    }

    func clearAll() {
        for item in items {
            deleteImageFile(for: item)
        }
        items.removeAll()
        scheduleSave()
    }

    // MARK: - Persistence

    private func createStorageDirsIfNeeded() {
        let fm = FileManager.default
        for dir in [pasteHistoryDir, imagesDir] {
            if !fm.fileExists(atPath: dir.path) {
                do {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                } catch {
                    logger.error("PasteManager: could not create directory \(dir.path): \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadManifest() {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return }
        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([PasteboardItem].self, from: data)
        } catch {
            logger.error("PasteManager: manifest parse failed — starting empty. \(error.localizedDescription)")
            items = []
        }
    }

    /// Debounces actual disk writes: re-arms a 1s work item on every mutation.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveManifestNow()
        }
        saveWorkItem = work
        storageQueue.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func saveManifestNow() {
        let snapshot = items
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            logger.error("PasteManager: failed to save manifest: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func historyCap() -> Int {
        let stored = UserDefaults.standard.integer(forKey: "pasteHistorySize")
        return stored > 0 ? stored : 100
    }

    private func deleteImageFile(for item: PasteboardItem) {
        guard case .image(let filename) = item.kind else { return }
        let url = imagesDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    /// Converts an `NSImage` to PNG `Data`. Returns `nil` if encoding fails.
    private func pngData(from image: NSImage) -> Data? {
        guard
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let mutableData = NSMutableData()
        guard
            let dest = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil)
        else { return nil }

        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }

        return mutableData as Data
    }

    private func byteCountString(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }
}
