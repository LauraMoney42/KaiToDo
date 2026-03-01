import SwiftUI

struct ContentView: View {
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(ListsViewModel.self) private var listsViewModel

    @AppStorage("kaiColorScheme") private var colorSchemeRaw: String = "system"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        Group {
            if userViewModel.isOnboarding {
                // New user: nickname setup first, then onboarding
                NicknameSetupView()
            } else if !hasSeenOnboarding {
                // First launch after profile created: show onboarding
                OnboardingView {
                    hasSeenOnboarding = true
                }
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut, value: userViewModel.isOnboarding)
        .animation(.easeInOut, value: hasSeenOnboarding)
        .preferredColorScheme(resolvedColorScheme)
        .overlay {
            if listsViewModel.showingConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .task {
            await requestNotificationPermission()
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil // follows system
        }
    }

    private func requestNotificationPermission() async {
        do {
            let _ = try await NotificationService.shared.requestAuthorization()
        } catch {
            print("Failed to request notification permission: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .environment(ListsViewModel())
        .environment(UserViewModel())
}
