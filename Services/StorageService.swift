import Foundation

@Observable
class StorageService {
    static let shared = StorageService()

    private let listsKey = "kaitodo.lists"
    private let profileKey = "kaitodo.profile"

    private init() {}

    // MARK: - Lists

    func saveLists(_ lists: [TodoList]) {
        do {
            let data = try JSONEncoder().encode(lists)
            UserDefaults.standard.set(data, forKey: listsKey)
        } catch {
            print("Failed to save lists: \(error)")
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
