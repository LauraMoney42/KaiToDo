import SwiftUI

struct ContentView: View {
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(\.scenePhase) private var scenePhase

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
        .task {
            await requestNotificationPermission()
        }
        // MARK: - kai-sync-001: Foreground sync
        // When app enters foreground, sync shared lists with CloudKit in case other participants
        // made changes while this user was away. Debounced to 5s to avoid hammering CloudKit.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                listsViewModel.syncWhenForeground()
            }
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
