import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct Participant: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    let joinedAt: Date

    init(id: String, name: String, joinedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.joinedAt = joinedAt
    }
}

struct TodoList: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String
    var tasks: [TodoTask]

    // Sharing
    var cloudRecordID: String?
    var isShared: Bool
    var shareType: ShareType
    var ownerID: String?
    var ownerName: String?
    var participants: [Participant]
    var inviteCode: String?

    // CKShare + Private DB zone metadata (Phase 2 migration)
    var zoneID: String?                     // CKRecordZone.ID.zoneName, e.g. "KaiList-{UUID}"
    var zoneOwnerName: String?              // CKRecordZone.ID.ownerName
    var shareRecordName: String?            // CKShare record name for managing the share
    var shareURL: String?                   // CKShare.url for participant acceptance
    var isMigratedToPrivateDB: Bool = false // false = legacy public DB, true = new private DB

    // ⭐ Gold Star rewards — persisted via Codable, synced via CloudKit on shared lists
    var starCount: Int          // earned stars (increments when all tasks completed)
    var starGoal: Int?          // target star count to earn the reward (nil = no goal set)
    var rewardText: String?     // reward description, e.g. "🍕 Pizza night!"
    var rewardGiven: Bool       // true once the parent marks the reward as given

    enum ShareType: String, Codable {
        case local
        case owned
        case participant
    }

    init(
        id: UUID = UUID(),
        name: String,
        color: String,
        tasks: [TodoTask] = [],
        cloudRecordID: String? = nil,
        isShared: Bool = false,
        shareType: ShareType = .local,
        ownerID: String? = nil,
        ownerName: String? = nil,
        participants: [Participant] = [],
        inviteCode: String? = nil,
        zoneID: String? = nil,
        zoneOwnerName: String? = nil,
        shareRecordName: String? = nil,
        shareURL: String? = nil,
        isMigratedToPrivateDB: Bool = false,
        starCount: Int = 0,
        starGoal: Int? = nil,
        rewardText: String? = nil,
        rewardGiven: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.tasks = tasks
        self.cloudRecordID = cloudRecordID
        self.isShared = isShared
        self.shareType = shareType
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.participants = participants
        self.inviteCode = inviteCode
        self.zoneID = zoneID
        self.zoneOwnerName = zoneOwnerName
        self.shareRecordName = shareRecordName
        self.shareURL = shareURL
        self.isMigratedToPrivateDB = isMigratedToPrivateDB
        self.starCount = starCount
        self.starGoal = starGoal
        self.rewardText = rewardText
        self.rewardGiven = rewardGiven
    }

    // Custom Decodable to handle backward compatibility — isMigratedToPrivateDB
    // and rewardGiven are non-optional Bools that don't exist in older persisted data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decode(String.self, forKey: .color)
        tasks = try c.decode([TodoTask].self, forKey: .tasks)
        cloudRecordID = try c.decodeIfPresent(String.self, forKey: .cloudRecordID)
        isShared = try c.decodeIfPresent(Bool.self, forKey: .isShared) ?? false
        shareType = try c.decodeIfPresent(ShareType.self, forKey: .shareType) ?? .local
        ownerID = try c.decodeIfPresent(String.self, forKey: .ownerID)
        ownerName = try c.decodeIfPresent(String.self, forKey: .ownerName)
        participants = try c.decodeIfPresent([Participant].self, forKey: .participants) ?? []
        inviteCode = try c.decodeIfPresent(String.self, forKey: .inviteCode)
        zoneID = try c.decodeIfPresent(String.self, forKey: .zoneID)
        zoneOwnerName = try c.decodeIfPresent(String.self, forKey: .zoneOwnerName)
        shareRecordName = try c.decodeIfPresent(String.self, forKey: .shareRecordName)
        shareURL = try c.decodeIfPresent(String.self, forKey: .shareURL)
        isMigratedToPrivateDB = try c.decodeIfPresent(Bool.self, forKey: .isMigratedToPrivateDB) ?? false
        starCount = try c.decodeIfPresent(Int.self, forKey: .starCount) ?? 0
        starGoal = try c.decodeIfPresent(Int.self, forKey: .starGoal)
        rewardText = try c.decodeIfPresent(String.self, forKey: .rewardText)
        rewardGiven = try c.decodeIfPresent(Bool.self, forKey: .rewardGiven) ?? false
    }

    var completedTaskCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    var totalTaskCount: Int {
        tasks.count
    }

    var completionProgress: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }

    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Transferable (drag-to-reorder support)

extension TodoList: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: TodoList.self, contentType: .kaiToDoList)
    }
}

extension UTType {
    /// Custom UTType for TodoList drag-and-drop within KaiToDo.
    static let kaiToDoList = UTType(exportedAs: "com.kindcode.kaitodo.list")
}
