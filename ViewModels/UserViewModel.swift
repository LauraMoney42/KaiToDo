import Foundation
import SwiftUI

@Observable
class UserViewModel {
    var profile: UserProfile?
    // Default true — assume new user until async load confirms a profile exists.
    // Prevents a brief HomeView flash for new users before the async load resolves.
    // The 2-second splash window covers the gap; both states settle before ContentView mounts.
    var isOnboarding: Bool = true

    private let storage = StorageService.shared

    init() {
        // Async load — same pattern as ListsViewModel to avoid blocking the main thread
        // during @State initialisation and delaying the first render (splash screen).
        Task { @MainActor [weak self] in
            guard let self else { return }
            let loaded = await Task.detached(priority: .userInitiated) {
                StorageService.shared.loadProfile()
            }.value
            self.profile = loaded
            self.isOnboarding = loaded == nil
        }
    }

    var isLoggedIn: Bool {
        profile != nil
    }

    var userID: String {
        profile?.userID ?? ""
    }

    var nickname: String {
        profile?.nickname ?? ""
    }

    // MARK: - Profile Operations

    func loadProfile() {
        profile = storage.loadProfile()
        isOnboarding = profile == nil
    }

    func createProfile(nickname: String) {
        let newProfile = UserProfile(nickname: nickname)
        profile = newProfile
        storage.saveProfile(newProfile)
        isOnboarding = false
    }

    func updateNickname(_ nickname: String) {
        guard var currentProfile = profile else { return }
        currentProfile.nickname = nickname
        profile = currentProfile
        storage.saveProfile(currentProfile)
    }

    func updateDeviceToken(_ token: String) {
        guard var currentProfile = profile else { return }
        currentProfile.deviceToken = token
        profile = currentProfile
        storage.saveProfile(currentProfile)
    }

    func logout() {
        profile = nil
        storage.clearProfile()
        isOnboarding = true
    }
}
