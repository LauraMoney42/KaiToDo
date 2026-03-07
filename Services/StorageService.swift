import Foundation
import CloudKit

@Observable
class StorageService {
    static let shared = StorageService()

    private let listsKey = "kaitodo.lists"
    private let profileKey = "kaitodo.profile"
    private let zoneChangeTokensKey = "kaitodo.zoneChangeTokens"
    private let dbChangeTokensKey = "kaitodo.dbChangeTokens"

    private init() {}

    // MARK: - Lists

    func saveLists(_ lists: [TodoList]) {
        // SYNCHRONOUS write — ensures data hits UserDefaults before returning.
        // Previously dispatched to a background queue, but force-quit killed the async
        // work before UserDefaults.set() executed → data loss (kai-persist-001).
        // UserDefaults is memory-mapped; encoding + writing a few KB is <1ms on-device.
        guard let data = try? JSONEncoder().encode(lists) else { return }
        UserDefaults.standard.set(data, forKey: listsKey)
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

    // MARK: - Change Tokens (Phase 3: Delta Sync)

    /// Persist a zone-level change token for incremental sync.
    func saveChangeToken(_ token: CKServerChangeToken, forZone zoneName: String) {
        var tokens = loadAllZoneTokenData()
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            tokens[zoneName] = data
        }
        UserDefaults.standard.set(tokens, forKey: zoneChangeTokensKey)
    }

    /// Load a previously stored zone-level change token. Returns nil for initial full fetch.
    func loadChangeToken(forZone zoneName: String) -> CKServerChangeToken? {
        let tokens = loadAllZoneTokenData()
        guard let data = tokens[zoneName] else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    /// Clear a zone's change token (e.g. on token expiry).
    func clearChangeToken(forZone zoneName: String) {
        var tokens = loadAllZoneTokenData()
        tokens.removeValue(forKey: zoneName)
        UserDefaults.standard.set(tokens, forKey: zoneChangeTokensKey)
    }

    /// Persist a database-level change token.
    func saveDatabaseChangeToken(_ token: CKServerChangeToken, forDatabase dbName: String) {
        var tokens = loadAllDBTokenData()
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            tokens[dbName] = data
        }
        UserDefaults.standard.set(tokens, forKey: dbChangeTokensKey)
    }

    /// Load a previously stored database-level change token.
    func loadDatabaseChangeToken(forDatabase dbName: String) -> CKServerChangeToken? {
        let tokens = loadAllDBTokenData()
        guard let data = tokens[dbName] else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func loadAllZoneTokenData() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: zoneChangeTokensKey) as? [String: Data] ?? [:]
    }

    private func loadAllDBTokenData() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: dbChangeTokensKey) as? [String: Data] ?? [:]
    }
}
