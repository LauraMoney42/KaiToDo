import Foundation
import CloudKit

actor CloudKitService {
    static let shared = CloudKitService()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    // Record Types
    private let sharedListType = "SharedList"
    private let sharedTaskType = "SharedTask"
    private let userProfileType = "UserProfile"
    private let invitationType = "Invitation"

    private init() {
        container = CKContainer(identifier: "iCloud.com.kaitodo.app")
        privateDatabase = container.privateCloudDatabase
        publicDatabase = container.publicCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
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
        taskRecord["sortOrder"] = 0.0 as Double

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
        // kai-sync-003 Bug 1: Include star/reward fields so participants see them
        record["starCount"] = Int64(list.starCount)
        record["starGoal"] = list.starGoal.map { Int64($0) }
        record["rewardText"] = list.rewardText
        record["rewardGiven"] = list.rewardGiven ? 1 : 0 as Int64

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
        // kai-sync-003 Bug 1: Sync star/reward fields on every list update
        record["starCount"] = Int64(list.starCount)
        record["starGoal"] = list.starGoal.map { Int64($0) }
        record["rewardText"] = list.rewardText
        record["rewardGiven"] = list.rewardGiven ? 1 : 0 as Int64
        try await publicDatabase.save(record)
    }

    /// Persists all star/reward fields for a shared list to CloudKit so all
    /// participants see the same running total and reward progress.
    func updateListStarData(cloudRecordID: String, starCount: Int, starGoal: Int?, rewardText: String?, rewardGiven: Bool) async throws {
        let recordID = CKRecord.ID(recordName: cloudRecordID)
        let record = try await publicDatabase.record(for: recordID)
        record["starCount"] = Int64(starCount)
        record["starGoal"] = starGoal.map { Int64($0) }
        record["rewardText"] = rewardText
        record["rewardGiven"] = rewardGiven ? 1 : 0 as Int64
        try await publicDatabase.save(record)
    }

    /// Fetches the star/reward fields from a SharedList CKRecord so participants
    /// see the same star chart as the list owner. (kai-sync-003 Bug 1)
    func fetchListStarData(cloudRecordID: String) async throws -> (starCount: Int, starGoal: Int?, rewardText: String?, rewardGiven: Bool) {
        let recordID = CKRecord.ID(recordName: cloudRecordID)
        let record = try await publicDatabase.record(for: recordID)
        let starCount = (record["starCount"] as? Int64).map(Int.init) ?? 0
        let starGoal = (record["starGoal"] as? Int64).map(Int.init)
        let rewardText = record["rewardText"] as? String
        let rewardGiven = (record["rewardGiven"] as? Int64 ?? 0) == 1
        return (starCount, starGoal, rewardText, rewardGiven)
    }

    // MARK: - Tasks

    /// Upsert with participant fallback (kai-sync-004).
    ///
    /// CloudKit public DB only allows the record CREATOR to modify a record.
    /// When a participant (daughter) toggles a task, she can't update the parent's
    /// CKRecord — `save()` fails with "permission failure". This was the root cause
    /// of one-way sync: daughter's writes silently failed, then the next pull
    /// overwrote her local change with the parent's stale version.
    ///
    /// Fix: on permission error, delete the old record (by the creator-agnostic
    /// batch delete) and create a NEW record owned by the current user. All other
    /// devices will pick up the replacement record on next sync via its listID
    /// reference — the `cloudRecordID` changes but the task text + state are preserved.
    func saveTask(_ task: TodoTask, listRecordID: CKRecord.ID) async throws -> CKRecord {
        if let existingRecordName = task.cloudRecordID {
            let recordID = CKRecord.ID(recordName: existingRecordName)
            do {
                // Try to update the existing record (works if we are the creator)
                let existingRecord = try await publicDatabase.record(for: recordID)
                existingRecord["isCompleted"] = task.isCompleted ? 1 : 0
                existingRecord["completedBy"] = task.completedBy
                existingRecord["completedByName"] = task.completedByName
                existingRecord["completedAt"] = task.completedAt
                existingRecord["sortOrder"] = task.sortOrder ?? 0.0
                return try await publicDatabase.save(existingRecord)
            } catch {
                // Permission denied — we're a participant, not the creator.
                // Create a replacement record that WE own so our write persists.
                // The old record still exists (we can't delete it either), so we
                // create the new one with a special "replacesRecord" field so the
                // owner's next sync can clean up the orphan.
                let replacement = CKRecord(recordType: sharedTaskType)
                replacement["listID"] = CKRecord.Reference(recordID: listRecordID, action: .deleteSelf)
                replacement["text"] = task.text
                replacement["isCompleted"] = task.isCompleted ? 1 : 0
                replacement["completedBy"] = task.completedBy
                replacement["completedByName"] = task.completedByName
                replacement["completedAt"] = task.completedAt
                replacement["sortOrder"] = task.sortOrder ?? 0.0
                replacement["replacesRecord"] = existingRecordName  // link to orphan for cleanup
                return try await publicDatabase.save(replacement)
            }
        } else {
            // First save — create new record (always succeeds, we're the creator)
            let record = CKRecord(recordType: sharedTaskType)
            record["listID"] = CKRecord.Reference(recordID: listRecordID, action: .deleteSelf)
            record["text"] = task.text
            record["isCompleted"] = task.isCompleted ? 1 : 0
            record["completedBy"] = task.completedBy
            record["completedByName"] = task.completedByName
            record["completedAt"] = task.completedAt
            record["sortOrder"] = task.sortOrder ?? 0.0
            return try await publicDatabase.save(record)
        }
    }

    func fetchTasks(forListID listID: CKRecord.ID) async throws -> [TodoTask] {
        let reference = CKRecord.Reference(recordID: listID, action: .none)
        let predicate = NSPredicate(format: "listID == %@", reference)
        let query = CKQuery(recordType: sharedTaskType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query)

        // kai-sync-004: Collect all records, then deduplicate.
        // When a participant creates a replacement record (because they can't modify
        // the original), both the old and new records exist. The replacement has a
        // "replacesRecord" field pointing to the orphan's recordName. We keep only
        // the replacement and schedule the orphan for cleanup.
        var recordsByID: [String: CKRecord] = [:]
        var replacedIDs: Set<String> = []

        for (_, result) in results {
            if case .success(let record) = result {
                recordsByID[record.recordID.recordName] = record
                // Track which old records have been replaced
                if let replacedID = record["replacesRecord"] as? String {
                    replacedIDs.insert(replacedID)
                }
            }
        }

        // Filter out orphaned records that have been replaced
        var tasks: [TodoTask] = []
        for (recordName, record) in recordsByID where !replacedIDs.contains(recordName) {
            let task = TodoTask(
                id: UUID(),
                cloudRecordID: record.recordID.recordName,
                text: record["text"] as? String ?? "",
                isCompleted: (record["isCompleted"] as? Int64 ?? 0) == 1,
                completedBy: record["completedBy"] as? String,
                completedByName: record["completedByName"] as? String,
                completedAt: record["completedAt"] as? Date,
                createdAt: record.creationDate ?? Date(),
                modifiedAt: record.modificationDate ?? Date(),
                sortOrder: record["sortOrder"] as? Double
            )
            tasks.append(task)
        }

        // Best-effort cleanup: delete orphaned records we own (non-blocking)
        for orphanID in replacedIDs {
            if let orphanRecord = recordsByID[orphanID] {
                Task {
                    try? await self.publicDatabase.deleteRecord(withID: orphanRecord.recordID)
                }
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
        record["sortOrder"] = task.sortOrder ?? 0.0

        try await publicDatabase.save(record)
    }

    func deleteTask(_ recordID: CKRecord.ID) async throws {
        try await publicDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Invitations

    /// Legacy: Create invitation with a CKRecord.Reference (public DB only — both records must be in same DB).
    func createInvitation(code: String, listRecordID: CKRecord.ID) async throws -> CKRecord {
        let record = CKRecord(recordType: invitationType)
        record["code"] = code
        record["listID"] = CKRecord.Reference(recordID: listRecordID, action: .deleteSelf)
        record["createdAt"] = Date()

        return try await publicDatabase.save(record)
    }

    /// Phase 2: Create invitation with zone metadata as strings (no cross-database reference).
    /// The invitation lives in public DB but points to a zone in the owner's private DB.
    func createInvitationForZone(code: String, shareURL: String, zoneName: String, zoneOwnerName: String) async throws -> CKRecord {
        let record = CKRecord(recordType: invitationType)
        record["code"] = code
        record["createdAt"] = Date()
        record["shareURL"] = shareURL
        record["zoneName"] = zoneName
        record["zoneOwnerName"] = zoneOwnerName
        record["migratedToPrivateDB"] = 1 as Int64

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

    // MARK: - CKShare + Private DB (Phase 2)
    // Zone-level sharing: each shared list gets its own custom zone in the owner's
    // private DB. A CKShare grants participants readWrite access via their shared DB.
    // This eliminates the replacement record workaround — all participants can modify
    // any record in the shared zone directly.

    /// Determine which database to use for a given zone based on ownership.
    func database(for zoneID: CKRecordZone.ID) -> CKDatabase {
        if zoneID.ownerName == CKCurrentUserDefaultName {
            return privateDatabase
        } else {
            return sharedDatabase
        }
    }

    /// Create a custom zone for a shared list (owner only).
    func createZone(named zoneName: String) async throws -> CKRecordZone {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        return try await privateDatabase.save(zone)
    }

    /// Create a CKShare for zone-level sharing (owner only).
    /// Returns the saved CKShare with its URL for participant acceptance.
    func createZoneShare(in zoneID: CKRecordZone.ID) async throws -> CKShare {
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "KaiToDo Shared List"
        share.publicPermission = .readWrite  // anyone with the link can join

        let saved = try await privateDatabase.save(share)
        guard let savedShare = saved as? CKShare else {
            throw CloudKitSyncError.shareCreationFailed
        }
        return savedShare
    }

    /// Accept a CKShare by its URL. After acceptance, the shared zone appears
    /// in the participant's sharedCloudDatabase.
    func acceptShare(url: URL) async throws {
        // Step 1: Fetch share metadata from the URL
        let metadata = try await fetchShareMetadata(url: url)

        // Step 2: Accept the share
        try await acceptShareMetadata(metadata)
    }

    private func fetchShareMetadata(url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            var fetchedMetadata: CKShare.Metadata?

            operation.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let metadata):
                    fetchedMetadata = metadata
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let metadata = fetchedMetadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: CloudKitSyncError.shareCreationFailed)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    private func acceptShareMetadata(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])

            operation.perShareResultBlock = { _, result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    continuation.resume(throwing: error)
                    return
                }
            }

            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    /// Save a SharedList record into a custom zone (private or shared DB).
    func saveSharedListInZone(_ list: TodoList, ownerID: String, ownerName: String, zoneID: CKRecordZone.ID) async throws -> CKRecord {
        let db = database(for: zoneID)
        let recordID: CKRecord.ID
        if let existing = list.cloudRecordID {
            recordID = CKRecord.ID(recordName: existing, zoneID: zoneID)
        } else {
            recordID = CKRecord.ID(zoneID: zoneID)
        }
        let record = CKRecord(recordType: sharedListType, recordID: recordID)
        record["name"] = list.name
        record["color"] = list.color
        record["ownerID"] = ownerID
        record["ownerName"] = ownerName
        record["inviteCode"] = list.inviteCode
        record["starCount"] = Int64(list.starCount)
        record["starGoal"] = list.starGoal.map { Int64($0) }
        record["rewardText"] = list.rewardText
        record["rewardGiven"] = list.rewardGiven ? 1 : 0 as Int64
        return try await db.save(record)
    }

    /// Save a task record into a custom zone. No replacement record pattern needed —
    /// CKShare gives all participants readWrite access.
    func saveTaskInZone(_ task: TodoTask, listRecordID: CKRecord.ID, zoneID: CKRecordZone.ID) async throws -> CKRecord {
        let db = database(for: zoneID)
        let recordID: CKRecord.ID
        if let existingName = task.cloudRecordID {
            recordID = CKRecord.ID(recordName: existingName, zoneID: zoneID)
            // Fetch and update existing record
            let existing = try await db.record(for: recordID)
            existing["text"] = task.text
            existing["isCompleted"] = task.isCompleted ? 1 : 0
            existing["completedBy"] = task.completedBy
            existing["completedByName"] = task.completedByName
            existing["completedAt"] = task.completedAt
            existing["sortOrder"] = task.sortOrder ?? 0.0
            return try await db.save(existing)
        } else {
            // New task — create in zone
            recordID = CKRecord.ID(zoneID: zoneID)
            let record = CKRecord(recordType: sharedTaskType, recordID: recordID)
            record["listID"] = CKRecord.Reference(recordID: listRecordID, action: .deleteSelf)
            record["text"] = task.text
            record["isCompleted"] = task.isCompleted ? 1 : 0
            record["completedBy"] = task.completedBy
            record["completedByName"] = task.completedByName
            record["completedAt"] = task.completedAt
            record["sortOrder"] = task.sortOrder ?? 0.0
            return try await db.save(record)
        }
    }

    /// Fetch all tasks in a custom zone. No dedup/replacement logic needed.
    func fetchTasksInZone(_ zoneID: CKRecordZone.ID) async throws -> [TodoTask] {
        let db = database(for: zoneID)
        let query = CKQuery(recordType: sharedTaskType, predicate: NSPredicate(value: true))
        let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)

        var tasks: [TodoTask] = []
        for (_, result) in results {
            if case .success(let record) = result {
                let task = TodoTask(
                    id: UUID(),
                    cloudRecordID: record.recordID.recordName,
                    text: record["text"] as? String ?? "",
                    isCompleted: (record["isCompleted"] as? Int64 ?? 0) == 1,
                    completedBy: record["completedBy"] as? String,
                    completedByName: record["completedByName"] as? String,
                    completedAt: record["completedAt"] as? Date,
                    createdAt: record.creationDate ?? Date(),
                    modifiedAt: record.modificationDate ?? Date(),
                    sortOrder: record["sortOrder"] as? Double
                )
                tasks.append(task)
            }
        }
        return tasks
    }

    /// Fetch star/reward data from a SharedList record in a custom zone.
    func fetchListStarDataInZone(_ zoneID: CKRecordZone.ID, cloudRecordID: String) async throws -> (starCount: Int, starGoal: Int?, rewardText: String?, rewardGiven: Bool) {
        let db = database(for: zoneID)
        let recordID = CKRecord.ID(recordName: cloudRecordID, zoneID: zoneID)
        let record = try await db.record(for: recordID)
        let starCount = (record["starCount"] as? Int64).map(Int.init) ?? 0
        let starGoal = (record["starGoal"] as? Int64).map(Int.init)
        let rewardText = record["rewardText"] as? String
        let rewardGiven = (record["rewardGiven"] as? Int64 ?? 0) == 1
        return (starCount, starGoal, rewardText, rewardGiven)
    }

    /// Update star/reward data in a custom zone. Any participant can write (CKShare readWrite).
    func updateListStarDataInZone(_ zoneID: CKRecordZone.ID, cloudRecordID: String, starCount: Int, starGoal: Int?, rewardText: String?, rewardGiven: Bool) async throws {
        let db = database(for: zoneID)
        let recordID = CKRecord.ID(recordName: cloudRecordID, zoneID: zoneID)
        let record = try await db.record(for: recordID)
        record["starCount"] = Int64(starCount)
        record["starGoal"] = starGoal.map { Int64($0) }
        record["rewardText"] = rewardText
        record["rewardGiven"] = rewardGiven ? 1 : 0 as Int64
        try await db.save(record)
    }

    /// Delete a task in a custom zone.
    func deleteTaskInZone(_ recordID: CKRecord.ID, zoneID: CKRecordZone.ID) async throws {
        let db = database(for: zoneID)
        try await db.deleteRecord(withID: recordID)
    }

    /// Update the Invitation record in public DB with CKShare metadata so
    /// participants can find and accept the share when they enter the invite code.
    func updateInvitationWithShareURL(code: String, shareURL: String, zoneName: String, zoneOwnerName: String) async throws {
        guard let invitation = try await findInvitation(byCode: code) else { return }
        invitation["shareURL"] = shareURL
        invitation["zoneName"] = zoneName
        invitation["zoneOwnerName"] = zoneOwnerName
        invitation["migratedToPrivateDB"] = 1 as Int64
        try await publicDatabase.save(invitation)
    }

    // MARK: - Database Subscriptions (Phase 2)
    // CKDatabaseSubscription monitors ALL custom zones for changes — required
    // because CKQuerySubscription doesn't work on the shared database.

    func setupDatabaseSubscriptions() async throws {
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true

        // Private DB subscription (for lists we own)
        let privateSub = CKDatabaseSubscription(subscriptionID: "private-db-changes")
        privateSub.notificationInfo = notification
        try await privateDatabase.save(privateSub)

        // Shared DB subscription (for lists others shared with us)
        let sharedSub = CKDatabaseSubscription(subscriptionID: "shared-db-changes")
        sharedSub.notificationInfo = notification
        try await sharedDatabase.save(sharedSub)
    }

    // MARK: - Delta Sync (Phase 3)
    // Fetch only records that changed since the last sync using change tokens.

    struct ZoneChanges {
        var changedRecords: [CKRecord]
        var deletedRecordIDs: [CKRecord.ID]
        var newChangeToken: CKServerChangeToken?
        var hasMoreChanges: Bool
    }

    struct DatabaseChanges {
        var changedZoneIDs: [CKRecordZone.ID]
        var deletedZoneIDs: [CKRecordZone.ID]
        var newChangeToken: CKServerChangeToken?
    }

    /// Fetch records that changed in a zone since the given token.
    /// Pass nil for initial full fetch; returns a new token for subsequent delta syncs.
    func fetchZoneChanges(zoneID: CKRecordZone.ID, since token: CKServerChangeToken?) async throws -> ZoneChanges {
        let db = database(for: zoneID)
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = token

        var changedRecords: [CKRecord] = []
        var deletedIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?
        var moreComing = false

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: config]
        )

        operation.recordWasChangedBlock = { _, result in
            if case .success(let record) = result {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { _, serverToken, _ in
            newToken = serverToken
        }

        operation.recordZoneFetchResultBlock = { _, result in
            if case .success(let (serverToken, _, moreToCome)) = result {
                newToken = serverToken
                moreComing = moreToCome
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ZoneChanges(
                        changedRecords: changedRecords,
                        deletedRecordIDs: deletedIDs,
                        newChangeToken: newToken,
                        hasMoreChanges: moreComing
                    ))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            db.add(operation)
        }
    }

    /// Fetch which zones changed in a database since the given token.
    func fetchDatabaseChanges(in db: CKDatabase, since token: CKServerChangeToken?) async throws -> DatabaseChanges {
        var changedZoneIDs: [CKRecordZone.ID] = []
        var deletedZoneIDs: [CKRecordZone.ID] = []
        var newToken: CKServerChangeToken?

        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: token)

        operation.recordZoneWithIDChangedBlock = { zoneID in
            changedZoneIDs.append(zoneID)
        }

        operation.recordZoneWithIDWasDeletedBlock = { zoneID in
            deletedZoneIDs.append(zoneID)
        }

        operation.changeTokenUpdatedBlock = { serverToken in
            newToken = serverToken
        }

        return try await withCheckedThrowingContinuation { continuation in
            operation.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success(let (serverToken, _)):
                    newToken = serverToken
                    continuation.resume(returning: DatabaseChanges(
                        changedZoneIDs: changedZoneIDs,
                        deletedZoneIDs: deletedZoneIDs,
                        newChangeToken: newToken
                    ))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            db.add(operation)
        }
    }
}

// MARK: - Error Types

enum CloudKitSyncError: LocalizedError {
    case shareCreationFailed
    case participantNotFound
    case migrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .shareCreationFailed: return "Failed to create CloudKit share"
        case .participantNotFound: return "Participant not found"
        case .migrationFailed(let reason): return "Migration failed: \(reason)"
        }
    }
}
