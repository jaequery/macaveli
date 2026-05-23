import SwiftUI

extension Bundle {
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as! String
    }
}

struct InfoView: View {
    private var version: String? = nil

    init(hasPermissions: Bool = false) {
        self.version = Bundle.main.buildNumber
    }

    var body: some View {
        Group {
            VStack {
                HStack(alignment: .bottom) {
                    Text("InitialX").font(.headline)
                    if version != nil {
                        Text("v" + version!).font(.subheadline)
                    }
                }.padding(.bottom)

                Text("Made with 🩵 by")

                Button(action: {
                    guard let url = URL(string: "https://jaequery.dev") else {
                        print("Invalid URL")
                        return
                    }
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text("Jae Lee")
                }).buttonStyle(.link)
                
                Button(action: {
                    guard let url = URL(string: "https://x.com/jaequery") else {
                        print("Invalid URL")
                        return
                    }
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text("Follow me on X")
                }).buttonStyle(.link)

                Button(action: {
                    guard let url = URL(string: "https://github.com/jaequery/InitialX") else {
                        print("Invalid URL")
                        return
                    }
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text("Go to Open Source Project")
                })
                .padding(.top)
            }
        }.padding()

        Divider()

        HStack {
            Button(action: {
                NSApplication.shared.terminate(0)
            }, label: {
                HStack {
                    Text("Quit")
                    Text("⌘+Q").foregroundStyle(.secondary).font(.subheadline)
                }
            })
            .keyboardShortcut("Q", modifiers: .command)

            Spacer()

            CheckUpdatesButton(label: "Check for updates").buttonStyle(.borderedProminent)
        }.padding()
    }
}

#Preview {
    InfoView().frame(width: MAIN_WINDOW_WIDTH)
}
