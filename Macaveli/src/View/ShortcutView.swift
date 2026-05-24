// ShortcutView.swift
import SwiftUI
import ShortcutRecorder

struct ShortcutNSView: NSViewRepresentable {
    @Binding var shortcut: Shortcut?
    
    func makeNSView(context: Context) -> RecorderControl {
        let recorder = RecorderControl()
        recorder.delegate = context.coordinator
        recorder.allowsModifierFlagsOnlyShortcut = true
        return recorder
    }
    
    func updateNSView(_ nsView: RecorderControl, context: Context) {
        nsView.objectValue = shortcut
        nsView.translatesAutoresizingMaskIntoConstraints = false
        
        // Force width/height
        //        NSLayoutConstraint.activate([
        //            nsView.widthAnchor.constraint(equalToConstant: 100),
        //            nsView.heightAnchor.constraint(equalToConstant: 20)
        //        ])
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, RecorderControlDelegate {
        var parent: ShortcutNSView
        
        init(_ parent: ShortcutNSView) {
            self.parent = parent
        }
        
        func shortcutRecorderDidEndRecording(_ recorder: RecorderControl) {
            parent.shortcut = recorder.objectValue
        }
    }
}

struct ShortcutView: View {
    @State private var shortcut: UserShortcut
    @AppStorage(PreferenceKey.requireMouseClick.rawValue) var requireMouseClick = false
    @State private var hovering = false

    init(type: ShortcutType) {
        let loadedShortcut = ShortcutsManager.shared.load(for: type) ?? UserShortcut(type: type, mouseButton: .none)
        self.shortcut = loadedShortcut
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Image(systemName: actionIcon())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(shortcut.type.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 70, alignment: .leading)
                ShortcutNSView(shortcut: $shortcut.shortcut)
                    .onChange(of: shortcut.shortcut, perform: {
                        newValue in
                        if (newValue == nil) {
                            ShortcutsManager.shared.delete(for: shortcut.type)
                        } else {
                            ShortcutsManager.shared.save(shortcut)
                        }
                    })
                Button {
                    shortcut.shortcut = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle().fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .opacity(shortcut.shortcut == nil ? 0.0 : 1.0)
                .help("Clear shortcut")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(hovering ? Color.primary.opacity(0.05) : Color.clear)
            )
            .onHover { hovering = $0 }
            if requireMouseClick && shortcut.type.isMouseDriven {
                HStack {
                    Image(systemName: "magicmouse.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 18)

                    Text("Click")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack {
                        ForEach(Array(MouseButton.allCases), id: \.self) { mouseButton in
                            let selected = mouseButton == shortcut.mouseButton
                            let color: Color = selected ? .teal : .primary.opacity(0.8)
                            UIButton(action: {
                                shortcut.mouseButton = mouseButton
                                ShortcutsManager.shared.save(shortcut)
                            }, plain: !selected, background: color, label: {
                                if mouseButton != .none {
                                    Image(systemName: clickIcon(mouseButton))
                                }
                                Text(mouseButton.rawValue).font(.caption)
                            }, backgroundHover: .teal.opacity(0.2))
                        }
                    }
                }
                .onAppear {
                    // this is needed when we update the mouse to .none from PreferencesView
                    loadShortcutFromStorage()
                }
            }
        }
    }
    
    private func loadShortcutFromStorage() {
        let loadedShortcut = ShortcutsManager.shared.load(for: self.shortcut.type) ?? UserShortcut(type: self.shortcut.type, mouseButton: .none)
        self.shortcut = loadedShortcut
    }
    
    private func actionIcon() -> String {
        switch(self.shortcut.type) {
        case .move: return "macwindow.and.cursorarrow"
        case .resize: return "macwindow.badge.plus"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .center: return "rectangle.center.inset.filled"
        case .leftHalf: return "rectangle.lefthalf.inset.filled"
        case .rightHalf: return "rectangle.righthalf.inset.filled"
        case .record: return "record.circle"
        }
    }
    
    private func clickIcon(_ clickType: MouseButton) -> String {
        switch(clickType) {
        case .left: return "capsule.lefthalf.filled"
        case .right: return "capsule.righthalf.filled"
        case .none: return ""
        }
    }
}

#Preview {
    VStack {
        ShortcutView(type: .move)
        ShortcutView(type: .resize)
    }.frame(width: MAIN_WINDOW_WIDTH).padding()
}
