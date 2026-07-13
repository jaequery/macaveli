// PasteView.swift
//
// SwiftUI clipboard-history panel — search, keyboard nav, paste on Enter.
//
// Requires macOS 14+ for `.onKeyPress`. Falls back to a local NSEvent
// monitor on older runtimes (the app targets macOS 13+; the monitor path
// ensures full keyboard control everywhere).

import SwiftUI
import AppKit
import ImageIO

// MARK: - PasteView

struct PasteView: View {

    @ObservedObject var manager = PasteManager.shared

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool
    @State private var showClearConfirm = false

    // Inline label editing: the id of the item whose label is being edited
    // (nil = not editing) plus the working text for that field.
    @State private var editingItemID: UUID? = nil
    @State private var editingText: String = ""

    // Whether the most recent selection change came from keyboard navigation.
    // Hover-driven changes must NOT auto-scroll: scrolling slides a different
    // row under the stationary cursor → onHover → another scroll → an endless
    // loop that makes item selection impossible. Every non-hover path sets this
    // true; only `onHover` sets it false.
    @State private var selectionViaKeyboard = true

    // Image preview (lightbox). `previewItem` is the image item being shown
    // (nil = closed); `previewZoom` is its scale relative to fit (1.0 = fit).
    // Zoom lives here — not inside the overlay — so the panel's key monitor and
    // the on-screen buttons drive the same value.
    @State private var previewItem: PasteboardItem? = nil
    @State private var previewZoom: CGFloat = 1

    // MARK: - Zoom bounds

    static let previewMinZoom: CGFloat = 0.25
    static let previewMaxZoom: CGFloat = 4.0

    // MARK: - Derived state

    private var filteredItems: [PasteboardItem] {
        guard !query.isEmpty else { return manager.items }
        let q = query.lowercased()
        return manager.items.filter { item in
            if item.preview.lowercased().contains(q) { return true }
            if let label = item.label, label.lowercased().contains(q) { return true }
            if case .image = item.kind, "image".contains(q) { return true }
            return false
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                itemList
                Divider()
                footer
            }

            // Lightbox: dims the list and shows a large, zoomable image.
            if let item = previewItem {
                ImagePreviewOverlay(
                    item: item,
                    zoom: previewZoom,
                    onZoomIn:  { zoomPreview(0.25) },
                    onZoomOut: { zoomPreview(-0.25) },
                    onFit:     { fitPreview() },
                    onClose:   { closePreview() }
                )
                .id(item.id)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        // Reset selection when query changes.
        .onChangeCompat(of: query) {
            selectionViaKeyboard = true
            selectedIndex = 0
        }
        // Clamp selection when item count changes.
        .onChangeCompat(of: manager.items.count) { clampSelection() }
        // Global key monitor for full keyboard control.
        .background(KeyboardHandler(
            isEditing:   { editingItemID != nil },
            isPreviewing: { previewItem != nil },
            onUp:        { moveSelection(-1) },
            onDown:      { moveSelection(1)  },
            onReturn:    { activateSelected() },
            onEscape:    { handleEscape() },
            onCmdNumber: { n in activateAtNumber(n) },
            onCmdF:      { searchFocused = true },
            onCmdDelete: { deleteSelected() },
            onCmdShiftDelete: { showClearConfirm = true },
            onCmdL:      { beginEditingSelected() },
            onPreviewZoomIn:    { zoomPreview(0.25) },
            onPreviewZoomOut:   { zoomPreview(-0.25) },
            onPreviewZoomReset: { fitPreview() }
        ))
        .confirmationDialog(
            "Clear all clipboard history? This cannot be undone.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) { manager.clearAll() }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search clipboard…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .accessibilityLabel("Search clipboard history")
                .onSubmit { activateSelected() }
                .onAppear {
                    // Auto-focus on first show — matches Spotlight / Raycast convention
                    // so the user can start typing immediately when the panel pops up.
                    DispatchQueue.main.async { searchFocused = true }
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            } else {
                // Right-aligned key hint in the style of Spotlight / Linear.
                HStack(spacing: 2) {
                    KeyCap(text: "⌃")
                    KeyCap(text: "⌘")
                    KeyCap(text: "P")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        )
    }

    // MARK: - Item list

    @ViewBuilder
    private var itemList: some View {
        let items = filteredItems
        if manager.items.isEmpty {
            emptyState
        } else if items.isEmpty {
            noResults
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            PasteRowView(
                                item: item,
                                position: index + 1,
                                isSelected: index == selectedIndex,
                                isEditing: editingItemID == item.id,
                                editingText: $editingText,
                                onCommitLabel: commitEditing,
                                onCancelLabel: cancelEditing,
                                onZoom: { openPreview(item) }
                            )
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                if editingItemID == nil { activateSelected() }
                            }
                            .onHover { hovering in
                                // Ignore hover while editing a label so the edit
                                // field keeps its row selected.
                                if hovering, editingItemID == nil {
                                    selectionViaKeyboard = false
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)
                // Auto-scroll selected row into view on keyboard navigation only.
                .onChangeCompat(of: selectedIndex) { newValue in
                    // Skip hover-driven changes: scrolling would slide another
                    // row under the cursor and re-trigger onHover → scroll loop.
                    guard selectionViaKeyboard else { return }
                    let bounded = max(0, min(newValue, items.count - 1))
                    if bounded < items.count {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            // anchor: nil scrolls the minimum needed to reveal an
                            // off-screen row and does nothing when it is already
                            // visible — no constant re-centering on every keypress.
                            proxy.scrollTo(items[bounded].id, anchor: nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty / no-results states

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No clipboard history yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private var noResults: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No matches for \u{201C}\(query)\u{201D}")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            FooterHint(keys: "↑↓", label: "navigate")
            FooterHint(keys: "↵", label: "paste")
            FooterHint(keys: "⌘1–9", label: "quick")
            FooterHint(keys: "⌘L", label: "label")
            FooterHint(keys: "⌘⌫", label: "delete")
            Spacer(minLength: 0)
            FooterHint(keys: "⎋", label: "close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Actions

    private func moveSelection(_ delta: Int) {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectionViaKeyboard = true
        selectedIndex = max(0, min(selectedIndex + delta, count - 1))
    }

    private func activateSelected() {
        let items = filteredItems
        guard !items.isEmpty, selectedIndex < items.count else { return }
        manager.activate(items[selectedIndex])
    }

    private func activateAtNumber(_ number: Int) {
        let items = filteredItems
        let idx   = number - 1     // 1-indexed input
        guard idx >= 0, idx < items.count else { return }
        manager.activate(items[idx])
    }

    private func deleteSelected() {
        let items = filteredItems
        guard !items.isEmpty, selectedIndex < items.count else { return }
        manager.delete(items[selectedIndex])
        clampSelection()
    }

    private func clampSelection() {
        let count = filteredItems.count
        selectionViaKeyboard = true
        if count == 0 {
            selectedIndex = 0
        } else {
            selectedIndex = min(selectedIndex, count - 1)
        }
    }

    // MARK: - Label editing

    private func beginEditingSelected() {
        let items = filteredItems
        guard !items.isEmpty, selectedIndex < items.count else { return }
        let item = items[selectedIndex]
        editingText = item.label ?? ""
        editingItemID = item.id
    }

    private func commitEditing() {
        guard let id = editingItemID else { return }
        manager.setLabel(editingText, for: id)
        editingItemID = nil
        editingText = ""
    }

    private func cancelEditing() {
        editingItemID = nil
        editingText = ""
    }

    /// Escape closes an open image preview first, then cancels an in-progress
    /// label edit, and only then closes the panel.
    private func handleEscape() {
        if previewItem != nil {
            closePreview()
        } else if editingItemID != nil {
            cancelEditing()
        } else {
            PasteManager.shared.hidePanel()
        }
    }

    // MARK: - Image preview

    /// Opens the lightbox for an image item, resetting zoom to fit.
    private func openPreview(_ item: PasteboardItem) {
        guard case .image = item.kind else { return }
        previewZoom = 1
        withAnimation(.easeOut(duration: 0.14)) { previewItem = item }
    }

    private func closePreview() {
        withAnimation(.easeIn(duration: 0.12)) { previewItem = nil }
    }

    /// Steps zoom by `delta`, clamped to the preview bounds.
    private func zoomPreview(_ delta: CGFloat) {
        previewZoom = min(Self.previewMaxZoom, max(Self.previewMinZoom, previewZoom + delta))
    }

    private func fitPreview() {
        previewZoom = 1
    }
}

// MARK: - PasteRowView

/// A single row in the clipboard-history list.
struct PasteRowView: View {

    let item: PasteboardItem
    let position: Int
    let isSelected: Bool
    var isEditing: Bool = false
    var editingText: Binding<String> = .constant("")
    var onCommitLabel: () -> Void = {}
    var onCancelLabel: () -> Void = {}
    var onZoom: () -> Void = {}

    @State private var isHovering = false
    @State private var imageDimensions: String? = nil
    @State private var thumbnail: NSImage? = nil
    @FocusState private var labelFieldFocused: Bool

    /// Displayed thumbnail edge, in points. Decoded at a Retina-safe pixel size.
    private let thumbSide: CGFloat = 28

    private var isImage: Bool {
        if case .image = item.kind { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            // Selection indicator bar
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 2)

            // Position badge
            Text("\(position)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                .frame(width: 16, alignment: .trailing)

            // Type slot: a real thumbnail for image items, the glyph for text.
            typeSlot

            // Preview text
            VStack(alignment: .leading, spacing: 1) {
                Text(displayText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Color.primary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Zoom button — image rows only. Reveals on hover or when selected;
            // keeps its slot at all times so the row layout never jitters.
            if isImage {
                zoomButton
            }

            // Custom label: inline editor while editing, otherwise a compact pill.
            // Stays on the same row — no extra line is added per item.
            if isEditing {
                TextField("Label", text: editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 140)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    )
                    .focused($labelFieldFocused)
                    .onAppear { DispatchQueue.main.async { labelFieldFocused = true } }
                    .onSubmit { onCommitLabel() }
                    .accessibilityLabel("Edit label")
            } else if let label = item.label, !label.isEmpty {
                LabelTag(text: label)
            }

            // Quick-paste badge for positions 1–9
            if position <= 9 {
                HStack(spacing: 2) {
                    KeyCap(text: "⌘")
                    KeyCap(text: "\(position)")
                }
                .opacity(isSelected ? 1 : 0.4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(rowBackground)
        .onHover { isHovering = $0 }
        .onAppear {
            resolveImageDimensions()
            loadThumbnail()
        }
        .accessibilityLabel(accessibilityRowLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Helpers

    /// The leading icon slot. Image rows show a decoded thumbnail (with a
    /// glyph-tile fallback while loading or on failure); text rows keep the
    /// original `doc.on.clipboard` glyph and 16pt frame, unchanged.
    @ViewBuilder
    private var typeSlot: some View {
        if isImage {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbSide, height: thumbSide)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    // Loading / fallback tile: the photo glyph on a faint fill.
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: thumbSide, height: thumbSide)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
        } else {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)
        }
    }

    /// The magnifier button shown on image rows. Hidden (and non-hittable) until
    /// the row is hovered or selected, so it never steals a paste-click from a
    /// row the user isn't pointing at. Being a `Button`, it consumes its own
    /// click and does not trigger the row's tap-to-paste gesture.
    private var zoomButton: some View {
        Button(action: onZoom) {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .opacity(isHovering || isSelected ? 1 : 0)
        .allowsHitTesting(isHovering || isSelected)
        .help("Zoom preview")
        .accessibilityLabel("Zoom image preview")
    }

    private var displayText: String {
        if case .image = item.kind {
            var parts: [String] = ["image"]
            if let dims = imageDimensions {
                parts.append(dims)
            }
            let kb = item.byteSize / 1024
            if kb > 0 {
                parts.append("\(kb) KB")
            } else {
                parts.append("\(item.byteSize) B")
            }
            return parts.joined(separator: " · ")
        }
        return item.preview
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
        } else if isHovering {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        } else {
            Color.clear
        }
    }

    private var accessibilityRowLabel: String {
        let labelPart = item.label.map { ", labeled \($0)" } ?? ""
        if isImage {
            return "Image item \(position): \(displayText)\(labelPart)"
        }
        return "Text item \(position): \(item.preview)\(labelPart)"
    }

    /// Reads image pixel dimensions without decoding the full PNG payload.
    /// Uses `CGImageSourceCopyPropertiesAtIndex` for cheap metadata access.
    private func resolveImageDimensions() {
        guard case .image(let filename) = item.kind, imageDimensions == nil else { return }
        guard let url = PasteManager.shared.imageURL(for: filename) else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        DispatchQueue.global(qos: .utility).async {
            guard
                let src  = CGImageSourceCreateWithURL(url as CFURL, nil),
                let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                let w    = props[kCGImagePropertyPixelWidth]  as? Int,
                let h    = props[kCGImagePropertyPixelHeight] as? Int
            else { return }
            let desc = "\(w)×\(h)"
            DispatchQueue.main.async { imageDimensions = desc }
        }
    }

    /// Loads a downsampled thumbnail for image items. Serves the id-keyed cache
    /// on a hit (no disk, no decode) so re-used rows during scroll never re-work;
    /// otherwise decodes off the main thread. A missing file or decode failure
    /// leaves `thumbnail` nil, so `typeSlot` shows the glyph fallback.
    private func loadThumbnail() {
        guard case .image(let filename) = item.kind, thumbnail == nil else { return }
        if let cached = ThumbnailCache.shared.cached(for: item.id) {
            thumbnail = cached
            return
        }
        guard let url = PasteManager.shared.imageURL(for: filename),
              FileManager.default.fileExists(atPath: url.path) else { return }
        // Decode at a Retina-safe pixel size (up to 3×) so the tile stays crisp.
        let maxPixel = thumbSide * 3
        ThumbnailCache.shared.thumbnail(for: item.id, url: url, maxPixel: maxPixel) { image in
            thumbnail = image
        }
    }
}

// MARK: - ThumbnailCache

/// Decodes and caches small downsampled thumbnails for image rows.
///
/// Decoding happens on a utility queue via `CGImageSourceCreateThumbnailAtIndex`
/// with `kCGImageSourceThumbnailMaxPixelSize`, so the full-res PNG is never
/// loaded into a row. Results are cached by item id (`NSCache`, auto-evicting
/// under memory pressure) so scrolling a long history never re-decodes.
final class ThumbnailCache {

    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.jaequery.Macaveli.thumbnails",
                                      qos: .utility,
                                      attributes: .concurrent)

    private init() {
        cache.countLimit = 256
    }

    /// Synchronous cache lookup; returns nil on a miss.
    func cached(for id: UUID) -> NSImage? {
        cache.object(forKey: id.uuidString as NSString)
    }

    /// Resolves a thumbnail for `id`, decoding off the main thread on a cache
    /// miss. `completion` is always invoked on the main thread; it receives nil
    /// when decoding fails (caller falls back to the glyph).
    func thumbnail(for id: UUID,
                   url: URL,
                   maxPixel: CGFloat,
                   completion: @escaping (NSImage?) -> Void) {
        if let hit = cached(for: id) {
            completion(hit)
            return
        }
        queue.async {
            let image = Self.makeThumbnail(url: url, maxPixel: maxPixel)
            if let image {
                self.cache.setObject(image, forKey: id.uuidString as NSString)
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private static func makeThumbnail(url: URL, maxPixel: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

// MARK: - ImagePreviewOverlay

/// Full-panel lightbox that shows a large, zoomable version of an image item.
///
/// Presented by `PasteView` when the user clicks a row's zoom button. A dark
/// scrim dims the list behind; the image is centered and scaled by `zoom`
/// (1.0 == fit-to-panel). A floating control pill drives zoom-in/out and fit.
/// It is dismissed by the close button, a tap on the scrim, or Escape — the
/// last handled by the panel's key monitor, which also routes the +/-/0 zoom
/// keys here while the preview is visible.
struct ImagePreviewOverlay: View {

    let item: PasteboardItem
    /// Scale relative to the fitted size. Owned by `PasteView` so the panel's
    /// keyboard monitor and the on-screen buttons drive one shared value.
    let zoom: CGFloat
    var onZoomIn:  () -> Void = {}
    var onZoomOut: () -> Void = {}
    var onFit:     () -> Void = {}
    var onClose:   () -> Void = {}

    @State private var image: NSImage? = nil
    @State private var pixelSize: CGSize? = nil
    @State private var loadFailed = false
    @State private var pan: CGSize = .zero
    @GestureState private var liveDrag: CGSize = .zero

    var body: some View {
        ZStack {
            // Scrim — a tap anywhere outside the image dismisses.
            Color.black.opacity(0.72)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            GeometryReader { geo in
                imageStage(in: geo.size)
            }
        }
        .overlay(alignment: .topLeading) { caption }
        .overlay(alignment: .topTrailing) { closeButton }
        .overlay(alignment: .bottom) { controls }
        .onAppear(perform: load)
        .onChangeCompat(of: zoom) { newValue in
            // Below fit there's nothing to pan to — recenter.
            if newValue <= 1 { pan = .zero }
        }
    }

    // MARK: Image stage

    @ViewBuilder
    private func imageStage(in size: CGSize) -> some View {
        if let image {
            let fitted  = fittedSize(aspect: pixelSize ?? image.size, in: availableSize(size))
            let display = CGSize(width: fitted.width * zoom, height: fitted.height * zoom)
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: max(1, display.width), height: max(1, display.height))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
                .offset(x: pan.width + liveDrag.width, y: pan.height + liveDrag.height)
                .gesture(panGesture(display: display, viewport: size))
                // Absorb taps on the image so they don't fall through to the
                // scrim (which would dismiss). Padding around it still does.
                .onTapGesture { }
                .frame(width: size.width, height: size.height, alignment: .center)
        } else if loadFailed {
            fallback(in: size)
        } else {
            ProgressView()
                .controlSize(.large)
                .frame(width: size.width, height: size.height)
        }
    }

    /// Drag-to-pan, active only when the image is larger than the viewport.
    /// A 6pt minimum distance keeps ordinary clicks flowing to `onTapGesture`.
    private func panGesture(display: CGSize, viewport: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($liveDrag) { value, state, _ in
                guard zoom > 1 else { return }
                state = value.translation
            }
            .onEnded { value in
                guard zoom > 1 else { return }
                let maxX = max(0, (display.width  - viewport.width)  / 2)
                let maxY = max(0, (display.height - viewport.height) / 2)
                pan = CGSize(
                    width:  min(maxX, max(-maxX, pan.width  + value.translation.width)),
                    height: min(maxY, max(-maxY, pan.height + value.translation.height))
                )
            }
    }

    // MARK: Chrome

    private var caption: some View {
        Text(captionText)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .padding(.top, 12)
            .padding(.leading, 14)
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.14)))
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.top, 11)
        .padding(.trailing, 12)
        .help("Close preview")
        .accessibilityLabel("Close image preview")
    }

    private var controls: some View {
        let pct = Int((zoom * 100).rounded())
        return HStack(spacing: 2) {
            controlButton("minus", action: onZoomOut,
                          disabled: zoom <= PasteView.previewMinZoom, label: "Zoom out")
            Text("\(pct)%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 52)
                .accessibilityLabel("Zoom \(pct) percent")
            controlButton("plus", action: onZoomIn,
                          disabled: zoom >= PasteView.previewMaxZoom, label: "Zoom in")
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 0.5, height: 20)
                .padding(.horizontal, 4)
            controlButton("arrow.up.left.and.arrow.down.right", action: onFit,
                          disabled: false, label: "Fit to window")
        }
        .padding(5)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        .padding(.bottom, 16)
    }

    private func controlButton(_ symbol: String,
                               action: @escaping () -> Void,
                               disabled: Bool,
                               label: String) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(disabled ? Color.white.opacity(0.3) : Color.white)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: Helpers

    private var captionText: String {
        var parts: [String] = []
        if let l = item.label, !l.isEmpty { parts.append(l) }
        if let px = pixelSize { parts.append("\(Int(px.width))×\(Int(px.height))") }
        let kb = item.byteSize / 1024
        parts.append(kb > 0 ? "\(kb) KB" : "\(item.byteSize) B")
        return parts.joined(separator: " · ")
    }

    private func fallback(in size: CGSize) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26, weight: .light))
            Text("Couldn't load image")
                .font(.system(size: 13))
        }
        .foregroundStyle(Color.white.opacity(0.7))
        .frame(width: size.width, height: size.height)
    }

    /// Available area for the image after reserving room for the top caption /
    /// close row and the bottom control pill.
    private func availableSize(_ size: CGSize) -> CGSize {
        CGSize(width:  max(1, size.width  - 48),
               height: max(1, size.height - 44 - 68))
    }

    /// Largest size with `aspect`'s ratio that fits inside `avail`.
    private func fittedSize(aspect: CGSize, in avail: CGSize) -> CGSize {
        guard aspect.width > 0, aspect.height > 0 else { return avail }
        let s = min(avail.width / aspect.width, avail.height / aspect.height)
        return CGSize(width: aspect.width * s, height: aspect.height * s)
    }

    /// Loads the full-resolution image off the main thread. Pixel dimensions are
    /// read cheaply from the file metadata for the caption and fit calculation.
    private func load() {
        guard case .image(let filename) = item.kind,
              let url = PasteManager.shared.imageURL(for: filename),
              FileManager.default.fileExists(atPath: url.path)
        else {
            loadFailed = true
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            var px: CGSize? = nil
            if let src   = CGImageSourceCreateWithURL(url as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
               let w     = props[kCGImagePropertyPixelWidth]  as? Int,
               let h     = props[kCGImagePropertyPixelHeight] as? Int {
                px = CGSize(width: w, height: h)
            }
            DispatchQueue.main.async {
                if let img {
                    self.image = img
                    self.pixelSize = px
                } else {
                    self.loadFailed = true
                }
            }
        }
    }
}

// MARK: - LabelTag

/// Compact inline pill showing an item's custom label. One line, tail-truncated.
private struct LabelTag: View {
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "tag.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
        )
        .frame(maxWidth: 160, alignment: .trailing)
        .accessibilityHidden(true)
    }
}

// MARK: - Footer helpers

/// One entry in the footer hint strip.
private struct FooterHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Text(keys)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - KeyboardHandler (NSEvent local monitor fallback)

/// A zero-size background view that installs a local NSEvent key-down monitor.
///
/// We use the monitor approach instead of `.onKeyPress` (macOS 14+) because the
/// panel often receives events before SwiftUI's focus engine is fully settled.
/// The monitor fires first for any key-down in the panel's key window context.
private struct KeyboardHandler: NSViewRepresentable {

    var isEditing:         () -> Bool
    var isPreviewing:      () -> Bool = { false }
    var onUp:              () -> Void
    var onDown:            () -> Void
    var onReturn:          () -> Void
    var onEscape:          () -> Void
    var onCmdNumber:       (Int) -> Void
    var onCmdF:            () -> Void
    var onCmdDelete:       () -> Void
    var onCmdShiftDelete:  () -> Void
    var onCmdL:            () -> Void
    var onPreviewZoomIn:    () -> Void = {}
    var onPreviewZoomOut:   () -> Void = {}
    var onPreviewZoomReset: () -> Void = {}

    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlerView()
        view.handlers = self
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyHandlerView)?.handlers = self
    }

    // MARK: - NSView subclass

    final class KeyHandlerView: NSView {
        var handlers: KeyboardHandler?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                return self?.handle(event: event)
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil { removeMonitor() }
        }

        private func removeMonitor() {
            if let m = monitor { NSEvent.removeMonitor(m) }
            monitor = nil
        }

        private func handle(event: NSEvent) -> NSEvent? {
            guard let h = handlers else { return event }
            let cmd    = event.modifierFlags.contains(.command)
            let shift  = event.modifierFlags.contains(.shift)
            let keyCode = event.keyCode

            // While the image preview is open, the overlay owns the keyboard:
            // Esc closes it, +/-/0 drive zoom, and every other key is swallowed
            // so the list behind the scrim never reacts.
            if h.isPreviewing() {
                switch keyCode {
                case 53:      h.onEscape()            // Escape
                case 24, 69:  h.onPreviewZoomIn()     // = / + (main & keypad)
                case 27, 78:  h.onPreviewZoomOut()    // - / _ (main & keypad)
                case 29, 82:  h.onPreviewZoomReset()  // 0 (main & keypad) → fit
                default:      break
                }
                return nil
            }

            // While editing a label, the focused TextField owns the keyboard.
            // Only intercept Escape (to cancel); pass everything else through so
            // typing, cursor keys, and Return (→ commit via onSubmit) reach it.
            if h.isEditing() {
                if keyCode == 53 {
                    h.onEscape()
                    return nil
                }
                return event
            }

            // ↑
            if keyCode == 126 && !cmd {
                h.onUp()
                return nil
            }
            // ↓
            if keyCode == 125 && !cmd {
                h.onDown()
                return nil
            }
            // Return / Enter
            if (keyCode == 36 || keyCode == 76) && !cmd {
                h.onReturn()
                return nil
            }
            // Escape
            if keyCode == 53 {
                h.onEscape()
                return nil
            }
            // ⌘1–⌘9
            if cmd && !shift {
                let numMap: [UInt16: Int] = [
                    18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
                    22: 6, 26: 7, 28: 8, 25: 9
                ]
                if let n = numMap[keyCode] {
                    h.onCmdNumber(n)
                    return nil
                }
            }
            // ⌘F (keyCode 3 = ANSI F)
            if cmd && keyCode == 3 && !shift {
                h.onCmdF()
                return nil
            }
            // ⌘L (keyCode 37 = ANSI L) — add/edit the selected item's label
            if cmd && keyCode == 37 && !shift {
                h.onCmdL()
                return nil
            }
            // ⌘⇧⌫ before ⌘⌫ (forward delete = 117, delete = 51)
            if cmd && shift && keyCode == 51 {
                h.onCmdShiftDelete()
                return nil
            }
            // ⌘⌫
            if cmd && !shift && keyCode == 51 {
                h.onCmdDelete()
                return nil
            }

            return event
        }
    }
}

// MARK: - onChange compatibility shim

/// Dispatches to the two-argument form on macOS 14+ (non-deprecated) and to the
/// single-argument form on macOS 13 (the only form available there).
private extension View {
    /// Variant whose action receives the new value.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value) { newValue in action(newValue) }
        }
    }

    /// Variant whose action ignores the new value.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value) { _, _ in action() }
        } else {
            self.onChange(of: value) { _ in action() }
        }
    }
}

// MARK: - Preview

#Preview("PasteView") {
    PasteView()
        .frame(width: 560, height: 440)
}
