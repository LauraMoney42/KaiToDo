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
    /// Fractional index for synced task ordering. Tasks are sorted by this value.
    /// Nil for pre-migration data — normalized to sequential integers on load.
    var sortOrder: Double?

    init(
        id: UUID = UUID(),
        cloudRecordID: String? = nil,
        text: String,
        isCompleted: Bool = false,
        completedBy: String? = nil,
        completedByName: String? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        sortOrder: Double? = nil
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
        self.sortOrder = sortOrder
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

// MARK: - Fractional Indexing

enum FractionalIndex {
    /// Midpoint between two values
    static func between(_ a: Double, _ b: Double) -> Double {
        (a + b) / 2.0
    }

    /// Value before the first item
    static func before(_ first: Double) -> Double {
        first - 1.0
    }

    /// Value after the last item
    static func after(_ last: Double) -> Double {
        last + 1.0
    }

    /// Gap below which we re-normalize to avoid floating-point precision issues
    static let minGap: Double = 1e-10

    /// Assign sequential integer sort orders (1.0, 2.0, 3.0, ...) to tasks
    /// that have nil sortOrder, preserving their current array position.
    static func normalizeIfNeeded(_ tasks: inout [TodoTask]) {
        let needsNormalization = tasks.contains { $0.sortOrder == nil }
        guard needsNormalization else { return }
        for i in tasks.indices {
            tasks[i].sortOrder = Double(i + 1)
        }
    }

    /// Re-normalize all sort orders to integer spacing when gaps get too small.
    static func renormalize(_ tasks: inout [TodoTask]) {
        for i in tasks.indices {
            tasks[i].sortOrder = Double(i + 1)
        }
    }
}
