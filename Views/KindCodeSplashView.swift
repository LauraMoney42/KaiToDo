import SwiftUI

/// KindCode branded launch splash — shown for ~2s on cold start, then fades out.
/// Background matches iOS dark mode so it looks consistent regardless of system setting.
/// Reuse this pattern across all KindCode Swift apps.
struct KindCodeSplashView: View {
    @Binding var isShowing: Bool
    @State private var opacity: Double = 1.0
    @State private var logoScale: CGFloat = 0.85

    var body: some View {
        ZStack {
            // Dark background — matches iOS dark mode system color
            Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // KindCode logo (transparent PNG)
                Image("KindCodeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .scaleEffect(logoScale)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.1),
                        value: logoScale
                    )

                // Brand tagline
                Text("Created by KindCode")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kaiPurple)
                    .tracking(0.5)

                Spacer()

                // Website link
                Link("kindcode.us", destination: URL(string: "https://kindcode.us")!)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 40)
            }
        }
        .opacity(opacity)
        .onAppear {
            // Pop logo in
            logoScale = 1.0

            // Fade out after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
