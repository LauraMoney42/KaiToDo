import Foundation

struct Participant: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    let joinedAt: Date

    init(id: String, name: String, joinedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.joinedAt = joinedAt
    }
}

struct TodoList: Identifiable, Codable, Equatable {
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
        inviteCode: String? = nil
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
