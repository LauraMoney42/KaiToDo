import SwiftUI

/// KindCode branded launch splash — shown for ~2s on cold start, then fades out.
/// Background matches iOS dark mode so it looks consistent regardless of system setting.
/// Reuse this pattern across all KindCode Swift apps.
struct KindCodeSplashView: View {
    @Binding var isShowing: Bool
    @State private var opacity: Double = 1.0
    // Start at 1.0 — no animation so there's zero visual jump from system launch screen
    @State private var logoScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dark background — matches iOS dark mode system color
            Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
                .ignoresSafeArea()

            // Layout matches TicBuddy/Intervals KindCode splash standard:
            // 260pt logo, 32pt spacing, centered
            VStack(spacing: 32) {
                // KindCode logo — 260pt to match KindCode app standard
                Image("KindCodeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)

                // Full phrase tappable → kindcode.us. Single Button avoids split-text
                // alignment issues. LinearGradient renders correctly on Button label
                // (unlike Link which overrides foregroundStyle with system tint).
                Button {
                    if let url = URL(string: "https://kindcode.us") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Created by KindCode")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.655, green: 0.953, blue: 0.816), // #a7f3d0 light mint
                                    Color(red: 0.204, green: 0.831, blue: 0.600)  // #34d399 KindCode green
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(0.6)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(opacity)
        .onAppear {
            // Fade out after 4 seconds — long enough to feel substantial after the
            // system launch screen (UILaunchScreen) dismisses during binary load.
            // User perceives one continuous dark→logo reveal, not two separate screens.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isShowing = false
                }
            }
        }
    }
}

#Preview {
    KindCodeSplashView(isShowing: .constant(true))
}
