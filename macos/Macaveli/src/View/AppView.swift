import SwiftUI

struct AppView: View {
    var body: some View {
        CheatsheetView()
    }
}

/// A small chevron-style logomark. Pure SwiftUI so it always renders sharp.
struct LogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("X")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 22, height: 22)
        .shadow(color: Color.accentColor.opacity(0.35), radius: 4, x: 0, y: 1)
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView().frame(width: MAIN_WINDOW_WIDTH, height: 520)
    }
}
