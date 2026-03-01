import SwiftUI

// MARK: - OnboardingView
// Multi-page onboarding explaining how Kai To Do works.
// Style inspired by TicBuddy: gradient backgrounds, spring animations, tap-to-advance.

struct OnboardingView: View {
    var isReplay: Bool = false
    let onComplete: () -> Void

    @State private var currentPage = 0

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                emoji: "✅",
                title: "Welcome to Kai To Do!",
                subtitle: "The to-do app that's actually fun.",
                bullets: [
                    "Keep track of everything on your plate",
                    "Share lists with family & friends",
                    "Celebrate every completed task 🎉"
                ],
                gradient: ["7161EF", "4834D4"],
                tapHint: "Tap anywhere to continue"
            ),
            OnboardingPage(
                emoji: "📝",
                title: "Creating a List",
                subtitle: "Lists are where the magic happens.",
                bullets: [
                    "Tap the + button at the bottom of the screen",
                    "Give your list a name and pick a color",
                    "Tap Create — and you're done!"
                ],
                gradient: ["FF8C42", "FF6B6B"],
                tapHint: "Tap anywhere to continue"
            ),
            OnboardingPage(
                emoji: "✔️",
                title: "Adding Tasks",
                subtitle: "Fill your list with things to get done.",
                bullets: [
                    "Open any list and tap Add a task",
                    "Type what you need to do and hit return",
                    "Tap the circle to check it off — confetti incoming! 🎊"
                ],
                gradient: ["4ECDC4", "2196A6"],
                tapHint: "Tap anywhere to continue"
            ),
            OnboardingPage(
                emoji: "👨‍👩‍👧",
                title: "Adding a Buddy",
                subtitle: "Lists are better together.",
                bullets: [
                    "Open a list and tap the share icon",
                    "Share the invite code with a friend or family member",
                    "They open Settings and tap Join a List",
                    "Now you're both on the same list! 🥳"
                ],
                gradient: ["F38181", "C0392B"],
                tapHint: "Tap anywhere to continue"
            ),
            OnboardingPage(
                emoji: "🚀",
                title: "You're All Set!",
                subtitle: "Time to get things done.",
                bullets: [
                    "Tap + to make your first list",
                    "Check off tasks as you go",
                    "Find Settings at the top right anytime"
                ],
                gradient: ["FFE66D", "FF8C42"],
                tapHint: isReplay ? "Tap to close" : "Tap to get started!"
            )
        ]
    }

    var body: some View {
        ZStack {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page, isLast: index == pages.count - 1) {
                        advancePage()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Custom page dots
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(.white.opacity(i == currentPage ? 1.0 : 0.4))
                            .frame(width: i == currentPage ? 10 : 7, height: i == currentPage ? 10 : 7)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 52)
            }
        }
        .ignoresSafeArea()
    }

    private func advancePage() {
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage += 1
            }
        } else {
            onComplete()
        }
    }
}

// MARK: - OnboardingPage Model

struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
    let bullets: [String]
    let gradient: [String]  // 2 hex strings
    let tapHint: String
}

// MARK: - OnboardingPageView

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLast: Bool
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: page.gradient.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero emoji
                Text(page.emoji)
                    .font(.system(size: 90))
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1), value: appeared)
                    .padding(.bottom, 28)

                // Title
                Text(page.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.45).delay(0.2), value: appeared)
                    .padding(.horizontal, 32)

                // Subtitle
                Text(page.subtitle)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.28), value: appeared)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // Bullet points
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(page.bullets.enumerated()), id: \.offset) { index, bullet in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.9))
                                .font(.system(size: 18))
                                .padding(.top, 1)

                            Text(bullet)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(appeared ? 1.0 : 0)
                        .offset(x: appeared ? 0 : -20)
                        .animation(.easeOut(duration: 0.4).delay(0.35 + Double(index) * 0.1), value: appeared)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 28)

                Spacer()

                // Tap hint
                Text(page.tapHint)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.85), value: appeared)
                    .padding(.bottom, 80) // room for page dots
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

#Preview {
    OnboardingView {
        print("onboarding done")
    }
}
