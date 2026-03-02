import Foundation

@Observable
class StorageService {
    static let shared = StorageService()

    private let listsKey = "kaitodo.lists"
    private let profileKey = "kaitodo.profile"

    private init() {}

    // MARK: - Lists

    func saveLists(_ lists: [TodoList]) {
        // Encode JSON on a background thread — avoids blocking the main thread on every tap/toggle.
        // UserDefaults.standard.set() is thread-safe per Apple docs.
        let key = listsKey
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(lists) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadLists() -> [TodoList] {
        guard let data = UserDefaults.standard.data(forKey: listsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([TodoList].self, from: data)
        } catch {
            print("Failed to load lists: \(error)")
            return []
        }
    }

    // MARK: - Profile

    func saveProfile(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: profileKey)
        } catch {
            print("Failed to save profile: \(error)")
        }
    }

    func loadProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: profileKey) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            print("Failed to load profile: \(error)")
            return nil
        }
    }

    func clearProfile() {
        UserDefaults.standard.removeObject(forKey: profileKey)
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: listsKey)
        UserDefaults.standard.removeObject(forKey: profileKey)
    }
}
