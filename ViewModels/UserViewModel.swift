import Foundation
import SwiftUI

@Observable
class UserViewModel {
    var profile: UserProfile?
    var isOnboarding: Bool = false

    private let storage = StorageService.shared

    init() {
        loadProfile()
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
