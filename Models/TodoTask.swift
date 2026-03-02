import Foundation

struct TodoTask: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    /// CloudKit record name — set after first save to CloudKit, used to UPDATE rather than insert on
    /// subsequent syncs. Without this, every toggle creates a duplicate task record in CloudKit.
    var cloudRecordID: String?
    var text: String
    var isCompleted: Bool
    var completedBy: String?
    var completedByName: String?
    var completedAt: Date?
    let createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        cloudRecordID: String? = nil,
        text: String,
        isCompleted: Bool = false,
        completedBy: String? = nil,
        completedByName: String? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.cloudRecordID = cloudRecordID
        self.text = text
        self.isCompleted = isCompleted
        self.completedBy = completedBy
        self.completedByName = completedByName
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    mutating func complete(by userID: String, name: String) {
        isCompleted = true
        completedBy = userID
        completedByName = name
        completedAt = Date()
        modifiedAt = Date()
    }

    mutating func uncomplete() {
        isCompleted = false
        completedBy = nil
        completedByName = nil
        completedAt = nil
        modifiedAt = Date()
    }
}
