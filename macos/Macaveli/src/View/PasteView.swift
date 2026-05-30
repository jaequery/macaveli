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
        VStack(spacing: 0) {
            searchBar
            Divider()
            itemList
            Divider()
            footer
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
            onUp:        { moveSelection(-1) },
            onDown:      { moveSelection(1)  },
            onReturn:    { activateSelected() },
            onEscape:    { handleEscape() },
            onCmdNumber: { n in activateAtNumber(n) },
            onCmdF:      { searchFocused = true },
            onCmdDelete: { deleteSelected() },
            onCmdShiftDelete: { showClearConfirm = true },
            onCmdL:      { beginEditingSelected() }
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
                                onCancelLabel: cancelEditing
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

    /// Escape cancels an in-progress label edit; otherwise it closes the panel.
    private func handleEscape() {
        if editingItemID != nil {
            cancelEditing()
        } else {
            PasteManager.shared.hidePanel()
        }
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

    @State private var isHovering = false
    @State private var imageDimensions: String? = nil
    @FocusState private var labelFieldFocused: Bool

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

            // Type icon
            Image(systemName: isImage ? "photo" : "doc.on.clipboard")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)

            // Preview text
            VStack(alignment: .leading, spacing: 1) {
                Text(displayText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Color.primary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        .onAppear { resolveImageDimensions() }
        .accessibilityLabel(accessibilityRowLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Helpers

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
    var onUp:              () -> Void
    var onDown:            () -> Void
    var onReturn:          () -> Void
    var onEscape:          () -> Void
    var onCmdNumber:       (Int) -> Void
    var onCmdF:            () -> Void
    var onCmdDelete:       () -> Void
    var onCmdShiftDelete:  () -> Void
    var onCmdL:            () -> Void

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
