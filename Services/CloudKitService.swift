import Foundation
import CloudKit

actor CloudKitService {
    static let shared = CloudKitService()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase

    // Record Types
    private let sharedListType = "SharedList"
    private let sharedTaskType = "SharedTask"
    private let userProfileType = "UserProfile"
    private let invitationType = "Invitation"

    private init() {
        container = CKContainer(identifier: "iCloud.com.kaitodo.app")
        privateDatabase = container.privateCloudDatabase
        publicDatabase = container.publicCloudDatabase
    }

    // MARK: - Account Status

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func fetchUserRecordID() async throws -> CKRecord.ID {
        try await container.userRecordID()
    }

    // MARK: - Schema Initialization
    // CloudKit auto-creates schema in Development when you save records
    // This function creates and deletes sample records to initialize the schema

    func initializeSchema() async throws {
        print("🔧 Initializing CloudKit schema...")

        // 1. Create SharedList record
        let listRecord = CKRecord(recordType: sharedListType)
        listRecord["name"] = "_schema_init"
        listRecord["color"] = "000000"
        listRecord["ownerID"] = "_init"
        listRecord["ownerName"] = "_init"
        listRecord["inviteCode"] = "XXXXXX"
        listRecord["participants"] = ["_init"]

        let savedList = try await publicDatabase.save(listRecord)
        print("✓ SharedList schema created")

        // 2. Create SharedTask record (with reference to list)
        let taskRecord = CKRecord(recordType: sharedTaskType)
        taskRecord["listID"] = CKRecord.Reference(recordID: savedList.recordID, action: .deleteSelf)
        taskRecord["text"] = "_schema_init"
        taskRecord["isCompleted"] = 0 as Int64
        taskRecord["completedBy"] = "_init"
        taskRecord["completedByName"] = "_init"
        taskRecord["completedAt"] = Date()

        let savedTask = try await publicDatabase.save(taskRecord)
        print("✓ SharedTask schema created")

        // 3. Create Invitation record
        let inviteRecord = CKRecord(recordType: invitationType)
        inviteRecord["code"] = "XXXXXX"
        inviteRecord["listID"] = CKRecord.Reference(recordID: savedList.recordID, action: .deleteSelf)
        inviteRecord["createdAt"] = Date()

        let savedInvite = try await publicDatabase.save(inviteRecord)
        print("✓ Invitation schema created")

        // 4. Create UserProfile record
        let profileRecord = CKRecord(recordType: userProfileType)
        profileRecord["nickname"] = "_schema_init"
        profileRecord["deviceToken"] = "_init"

        let savedProfile = try await publicDatabase.save(profileRecord)
        print("✓ UserProfile schema created")

        // 5. Clean up - delete the test records
        try await publicDatabase.deleteRecord(withID: savedTask.recordID)
        try await publicDatabase.deleteRecord(withID: savedInvite.recordID)
        try await publicDatabase.deleteRecord(withID: savedList.recordID)
        try await publicDatabase.deleteRecord(withID: savedProfile.recordID)

        print("✅ CloudKit schema initialized successfully!")
        print("   You can now see the record types in CloudKit Dashboard")
    }

    // MARK: - User Profile

    func saveUserProfile(_ profile: UserProfile) async throws {
        let record = CKRecord(recordType: userProfileType)
        record["nickname"] = profile.nickname
        record["deviceToken"] = profile.deviceToken

        try await publicDatabase.save(record)
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        let predicate = NSPredicate(format: "creatorUserRecordID == %@", CKRecord.ID(recordName: userID))
        let query = CKQuery(recordType: userProfileType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query)

        for (_, result) in results {
            if case .success(let record) = result {
                return UserProfile(
                    userID: userID,
                    nickname: record["nickname"] as? String ?? "",
                    deviceToken: record["deviceToken"] as? String
                )
            }
        }
        return nil
    }

    // MARK: - Shared Lists

    func saveSharedList(_ list: TodoList, ownerID: String, ownerName: String) async throws -> CKRecord {
        let record = CKRecord(recordType: sharedListType)
        record["name"] = list.name
        record["color"] = list.color
        record["ownerID"] = ownerID
        record["ownerName"] = ownerName
        record["inviteCode"] = list.inviteCode

        return try await publicDatabase.save(record)
    }

    func fetchSharedList(byInviteCode code: String) async throws -> (record: CKRecord, tasks: [TodoTask])? {
        let predicate = NSPredicate(format: "inviteCode == %@", code)
        let query = CKQuery(recordType: sharedListType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query)

        for (_, result) in results {
            if case .success(let record) = result {
                let tasks = try await fetchTasks(forListID: record.recordID)
                return (record, tasks)
            }
        }
        return nil
    }

    func updateSharedList(_ record: CKRecord, with list: TodoList) async throws {
        record["name"] = list.name
        record["color"] = list.color
        try await publicDatabase.save(record)
    }

    // MARK: - Tasks

    func saveTask(_ task: TodoTask, listRecordID: CKRecord.ID) async throws -> CKRecord {
        let record = CKRecord(recordType: sharedTaskType)
        record["listID"] = CKRecord.Reference(recordID: listRecordID, action: .deleteSelf)
        record["text"] = task.text
        record["isCompleted"] = task.isCompleted ? 1 : 0
        record["completedBy"] = task.completedBy
        record["completedByName"] = task.completedByName
        record["completedAt"] = task.completedAt

        return try await publicDatabase.save(record)
    }

    func fetchTasks(forListID listID: CKRecord.ID) async throws -> [TodoTask] {
        let reference = CKRecord.Reference(recordID: listID, action: .none)
        let predicate = NSPredicate(format: "listID == %@", reference)
        let query = CKQuery(recordType: sharedTaskType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query)

        var tasks: [TodoTask] = []
        for (_, result) in results {
            if case .success(let record) = result {
                let task = TodoTask(
                    id: UUID(),
                    text: record["text"] as? String ?? "",
                    isCompleted: (record["isCompleted"] as? Int64 ?? 0) == 1,
                    completedBy: record["completedBy"] as? String,
                    completedByName: record["completedByName"] as? String,
                    completedAt: record["completedAt"] as? Date,
                    createdAt: record.creationDate ?? Date(),
                    modifiedAt: record.modificationDate ?? Date()
                )
                tasks.append(task)
            }
        }
        return tasks
    }

    func updateTask(_ record: CKRecord, with task: TodoTask) async throws {
        record["text"] = task.text
        record["isCompleted"] = task.isCompleted ? 1 : 0
        record["completedBy"] = task.completedBy
        record["completedByName"] = task.completedByName
        record["completedAt"] = task.completedAt

        try await publicDatabase.save(record)
    }

    func deleteTask(_ recordID: CKRecord.ID) async throws {
        try await publicDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Invitations

    func createInvitation(code: String, listRecordID: CKRecord.ID) async throws -> CKRecord {
        let record = CKRecord(recordType: invitationType)
        record["code"] = code
        record["listID"] = CKRecord.Reference(recordID: listRecordID, action: .deleteSelf)
        record["createdAt"] = Date()

        return try await publicDatabase.save(record)
    }

    func findInvitation(byCode code: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "code == %@", code)
        let query = CKQuery(recordType: invitationType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query)

        for (_, result) in results {
            if case .success(let record) = result {
                return record
            }
        }
        return nil
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async throws {
        // Subscribe to changes in shared lists
        let listSubscription = CKQuerySubscription(
            recordType: sharedListType,
            predicate: NSPredicate(value: true),
            subscriptionID: "shared-list-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        listSubscription.notificationInfo = notification

        try await publicDatabase.save(listSubscription)

        // Subscribe to changes in tasks
        let taskSubscription = CKQuerySubscription(
            recordType: sharedTaskType,
            predicate: NSPredicate(value: true),
            subscriptionID: "shared-task-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        taskSubscription.notificationInfo = notification

        try await publicDatabase.save(taskSubscription)
    }

    // MARK: - Participants

    func addParticipant(userID: String, userName: String, toListRecord listRecord: CKRecord) async throws {
        var participants = listRecord["participants"] as? [String] ?? []
        if !participants.contains(userID) {
            participants.append(userID)
            listRecord["participants"] = participants
            try await publicDatabase.save(listRecord)
        }
    }

    func removeParticipant(userID: String, fromListRecord listRecord: CKRecord) async throws {
        var participants = listRecord["participants"] as? [String] ?? []
        participants.removeAll { $0 == userID }
        listRecord["participants"] = participants
        try await publicDatabase.save(listRecord)
    }
}
