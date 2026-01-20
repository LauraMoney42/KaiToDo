import SwiftUI

struct ContentView: View {
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(ListsViewModel.self) private var listsViewModel

    var body: some View {
        Group {
            if userViewModel.isOnboarding {
                NicknameSetupView()
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut, value: userViewModel.isOnboarding)
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
