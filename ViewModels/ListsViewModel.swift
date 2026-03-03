import Foundation
import SwiftUI
import CloudKit
import UserNotifications

@Observable
class ListsViewModel {
    var lists: [TodoList] = [] {
        didSet { rebuildIndex() }
    }
    var confettiTrigger = 0          // increment to fire single-task confetti
    var listCompletedTrigger = 0     // increment to fire multi-firework when all tasks done
    var lastCompletedTaskID: UUID?
    var isSyncing = false
    var syncError: String?

    /// O(1) lookup dictionary — rebuilt whenever `lists` changes.
    private var listIndex: [UUID: Int] = [:]

    private let storage = StorageService.shared
    /// Previously debounced saves via Task.detached with 300ms delay — removed because
    /// force-quit during the sleep window caused data loss (kai-persist-001).
    /// Saves are now synchronous; UserDefaults is memory-mapped so writes are <1ms.

    /// Track last sync time to debounce repeated foreground transitions
    private var lastSyncTime: Date = .distantPast

    init() {
        // Load lists asynchronously so init() returns immediately — the main thread is
        // NOT blocked, allowing the splash screen to render on the very first frame.
        // Previously, synchronous loadLists() in init() blocked the main thread during
        // @State initialisation in KaiToDoApp, causing 10-15s dark grey screen before
        // any UI painted. The splash screen couldn't help because it was also blocked.
        // Data arrives within milliseconds (UserDefaults is in-memory); the 2-second
        // splash window comfortably covers the async gap.
        Task { @MainActor [weak self] in
            guard let self else { return }
            let loaded = await Task.detached(priority: .userInitiated) {
                StorageService.shared.loadLists()
            }.value
            self.lists = loaded

            // MARK: - kai-sync-001: Launch sync for shared lists
            // After loading from local storage, immediately sync shared lists with CloudKit
            // so user sees fresh remote changes (from other participants) on every cold start.
            // This fixes the case where user leaves app, family member checks items, and user
            // relaunches — user would see stale data unless we pull from CloudKit here.
            await self.syncSharedLists()
        }

        // Listen for CloudKit silent push notifications (via AppDelegate → NotificationCenter).
        // Triggers syncSharedLists() so all participants see task changes in real time
        // without requiring a manual pull-to-refresh.
        NotificationCenter.default.addObserver(
            forName: .cloudKitDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.syncSharedLists() }
        }
    }

    private func rebuildIndex() {
        listIndex = Dictionary(uniqueKeysWithValues: lists.enumerated().map { ($1.id, $0) })
    }

    // MARK: - List Operations

    /// Synchronous load — kept for explicit call sites that need immediate data
    /// (e.g. after a CloudKit sync writes new data and calls this directly).
    func loadLists() {
        lists = storage.loadLists()
    }

    func saveLists() {
        // Synchronous save — data is persisted before this method returns.
        // Previously used a 300ms debounced Task.detached, but force-quit during the
        // sleep window killed the task before UserDefaults.set() ran → data loss.
        // UserDefaults writes are memory-mapped (<1ms) so sync is safe here.
        storage.saveLists(lists)
    }

    func createList(name: String, color: String) -> TodoList {
        let list = TodoList(name: name, color: color)
        lists.append(list)
        saveLists()
        return list
    }

    func updateList(_ list: TodoList) {
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            lists[index] = list
            saveLists()
        }
    }

    func updateListName(listID: UUID, name: String) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].name = name
        saveLists()
    }

    /// Update the Gold Star goal and reward text for a list.
    /// Pass nil for goal to clear it (no goal set). Also resets rewardGiven so button re-appears.
    /// kai-sync-004: Now pushes star/reward fields to CloudKit so participants (daughter)
    /// see the HomeRewardCard immediately after the owner sets a goal.
    func updateStarGoal(listID: UUID, goal: Int?, rewardText: String?) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].starGoal = goal
        lists[index].rewardText = rewardText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
            ? nil
            : rewardText?.trimmingCharacters(in: .whitespacesAndNewlines)
        lists[index].rewardGiven = false  // reset so button re-appears when goal changes
        saveLists()

        // Push star goal to CloudKit so participants see it on next sync.
        // Only the owner can modify the SharedList record in public DB.
        let list = lists[index]
        guard list.isShared,
              list.shareType == .owned,
              let cloudRecordID = list.cloudRecordID else { return }
        Task {
            try? await CloudKitService.shared.updateListStarData(
                cloudRecordID: cloudRecordID,
                starCount: list.starCount,
                starGoal: list.starGoal,
                rewardText: list.rewardText,
                rewardGiven: list.rewardGiven
            )
        }
    }

    /// Call after incrementing starCount — fires push notification if goal just reached.
    /// Guards against repeat: only fires when starCount == starGoal exactly and !rewardGiven.
    func checkGoalReached(for listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        let list = lists[index]
        guard let goal = list.starGoal,
              list.starCount == goal,
              !list.rewardGiven else { return }
        Task {
            try? await NotificationService.shared.scheduleGoalReachedNotification(
                listName: list.name,
                rewardText: list.rewardText
            )
        }
    }

    /// Mark the reward as physically given — hides the "Mark reward given" button until next goal cycle.
    func markRewardGiven(listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].rewardGiven = true
        saveLists()
    }

    func deleteList(_ list: TodoList) {
        lists.removeAll { $0.id == list.id }
        saveLists()
    }

    /// Moves `list` to the position immediately before `target` in the grid order.
    func reorderList(moving list: TodoList, before target: TodoList) {
        guard let fromIndex = lists.firstIndex(of: list),
              var toIndex = lists.firstIndex(of: target),
              fromIndex != toIndex else { return }
        lists.remove(at: fromIndex)
        if fromIndex < toIndex { toIndex -= 1 }
        lists.insert(list, at: toIndex)
        saveLists()
    }

    func getList(by id: UUID) -> TodoList? {
        // Use index if available and still valid, fall back to linear scan for safety
        if let idx = listIndex[id], lists.indices.contains(idx), lists[idx].id == id {
            return lists[idx]
        }
        return lists.first { $0.id == id }
    }

    // MARK: - Task Operations

    func addTask(to listID: UUID, text: String) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        let task = TodoTask(text: text)
        lists[index].tasks.append(task)
        saveLists()
    }

    func toggleTask(in listID: UUID, taskID: UUID, userID: String, userName: String) {
        guard let listIndex = lists.firstIndex(where: { $0.id == listID }),
              let taskIndex = lists[listIndex].tasks.firstIndex(where: { $0.id == taskID }) else {
            return
        }

        var task = lists[listIndex].tasks[taskIndex]
        let wasCompleting = !task.isCompleted   // capture direction before mutation
        if task.isCompleted {
            task.uncomplete()
        } else {
            task.complete(by: userID, name: userName)
            triggerConfetti(for: taskID)
            // Notify family members that task is complete
            Task {
                try? await NotificationService.shared.scheduleTaskCompletionNotification(
                    taskName: task.text,
                    completedBy: userName,
                    listName: lists[listIndex].name
                )
            }
        }
        lists[listIndex].tasks[taskIndex] = task
        saveLists()

        if wasCompleting {
            // Per-task star: reward every individual completion
            awardStar(at: listIndex)

            // Bonus star + firework: reward finishing the whole list
            if !lists[listIndex].tasks.isEmpty &&
               lists[listIndex].tasks.allSatisfy({ $0.isCompleted }) {
                listCompletedTrigger += 1
                awardStar(at: listIndex)
            }
        }
    }

    func updateTask(in listID: UUID, task: TodoTask) {
        guard let listIndex = lists.firstIndex(where: { $0.id == listID }),
              let taskIndex = lists[listIndex].tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        lists[listIndex].tasks[taskIndex] = task
        saveLists()
    }

    /// Reorders tasks within a list using IndexSet from `.onMove`. Persists immediately.
    func moveTask(in listID: UUID, from source: IndexSet, to destination: Int) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].tasks.move(fromOffsets: source, toOffset: destination)
        saveLists()
    }

    func deleteTask(in listID: UUID, taskID: UUID) {
        guard let listIndex = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[listIndex].tasks.removeAll { $0.id == taskID }
        saveLists()
    }

    /// Uncheck all tasks in a list so it can be reused, preserving the tasks themselves
    func resetList(_ listID: UUID) {
        guard let listIndex = lists.firstIndex(where: { $0.id == listID }) else { return }
        for taskIndex in lists[listIndex].tasks.indices {
            lists[listIndex].tasks[taskIndex].uncomplete()
        }
        saveLists()
    }

    // MARK: - Confetti

    private func triggerConfetti(for taskID: UUID) {
        lastCompletedTaskID = taskID
        confettiTrigger += 1
    }

    // MARK: - Sharing

    func shareList(_ listID: UUID, ownerID: String, ownerName: String) -> String? {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return nil }

        let inviteCode = TodoList.generateInviteCode()
        lists[index].isShared = true
        lists[index].shareType = .owned
        lists[index].ownerID = ownerID
        lists[index].ownerName = ownerName
        lists[index].inviteCode = inviteCode
        saveLists()

        return inviteCode
    }

    func addParticipant(to listID: UUID, participant: Participant) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        if !lists[index].participants.contains(where: { $0.id == participant.id }) {
            lists[index].participants.append(participant)
            saveLists()
        }
    }

    func removeParticipant(from listID: UUID, participantID: String) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].participants.removeAll { $0.id == participantID }
        saveLists()
    }

    // MARK: - Stats

    func totalCompletedTasks() -> Int {
        lists.reduce(0) { $0 + $1.completedTaskCount }
    }

    func totalTasks() -> Int {
        lists.reduce(0) { $0 + $1.totalTaskCount }
    }

    func participantStats(for listID: UUID) -> [String: Int] {
        guard let list = getList(by: listID) else { return [:] }
        var stats: [String: Int] = [:]
        for task in list.tasks where task.isCompleted {
            if let name = task.completedByName {
                stats[name, default: 0] += 1
            }
        }
        return stats
    }

    // MARK: - CloudKit Sync

    /// MARK: - kai-sync-001: Foreground sync
    /// Called when app enters foreground — syncs shared lists if enough time has passed
    /// since last sync (debounce to 5s to avoid hammering CloudKit on rapid foreground transitions).
    func syncWhenForeground() {
        let now = Date()
        guard now.timeIntervalSince(lastSyncTime) >= 5.0 else { return }
        lastSyncTime = now
        Task { await self.syncSharedLists() }
    }

    func syncSharedLists() async {
        isSyncing = true
        syncError = nil

        do {
            // Sync each shared list we own or participate in
            for list in lists where list.isShared && list.cloudRecordID != nil {
                try await syncList(list)
            }
            await MainActor.run {
                isSyncing = false
            }
        } catch {
            await MainActor.run {
                isSyncing = false
                syncError = error.localizedDescription
            }
        }
    }

    private func syncList(_ list: TodoList) async throws {
        guard let cloudRecordID = list.cloudRecordID else { return }

        let recordID = CKRecord.ID(recordName: cloudRecordID)

        // Fetch latest tasks AND star data from CloudKit in parallel
        async let remoteTasksFetch = CloudKitService.shared.fetchTasks(forListID: recordID)
        async let starDataFetch = CloudKitService.shared.fetchListStarData(cloudRecordID: cloudRecordID)

        let remoteTasks = try await remoteTasksFetch
        let starData = try await starDataFetch

        await MainActor.run {
            guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }

            // kai-sync-003 Bug 1: Sync star/reward fields from CloudKit → local
            // kai-sync-004: Use max(local, remote) for starCount so participant-earned
            // stars aren't overwritten by stale CloudKit data. The participant can't
            // write star updates to CloudKit (permission denied on public DB), so their
            // local count may be higher. Owner's authoritative count is pushed separately
            // (see owner star-push block below).
            lists[index].starCount = max(lists[index].starCount, starData.starCount)
            lists[index].starGoal = starData.starGoal
            lists[index].rewardText = starData.rewardText
            lists[index].rewardGiven = starData.rewardGiven

            // kai-sync-003 Bug 2: Merge tasks by cloudRecordID with timestamp comparison
            // instead of blind overwrite. Only accept remote version if it's newer.
            let localByCloudID = Dictionary(
                uniqueKeysWithValues: lists[index].tasks
                    .compactMap { task -> (String, TodoTask)? in
                        guard let cid = task.cloudRecordID else { return nil }
                        return (cid, task)
                    }
            )

            var mergedTasks: [TodoTask] = []
            // kai-sync-004: Track how many tasks flipped from incomplete→complete
            // during this sync (i.e. completed by the other participant remotely).
            // We award stars for these so the owner's star count stays accurate
            // and gets pushed to CloudKit for the participant to see.
            var remoteCompletions = 0

            for remoteTask in remoteTasks {
                guard let remoteCID = remoteTask.cloudRecordID else {
                    mergedTasks.append(remoteTask)
                    continue
                }

                if let localTask = localByCloudID[remoteCID] {
                    // Both exist — keep whichever was modified more recently
                    if remoteTask.modifiedAt > localTask.modifiedAt {
                        // kai-sync-004: Detect remote completion (other user toggled this task)
                        if remoteTask.isCompleted && !localTask.isCompleted {
                            remoteCompletions += 1
                        }
                        // Remote is newer — accept it but preserve local UUID for SwiftUI identity
                        var accepted = remoteTask
                        accepted = TodoTask(
                            id: localTask.id,
                            cloudRecordID: remoteCID,
                            text: remoteTask.text,
                            isCompleted: remoteTask.isCompleted,
                            completedBy: remoteTask.completedBy,
                            completedByName: remoteTask.completedByName,
                            completedAt: remoteTask.completedAt,
                            createdAt: remoteTask.createdAt,
                            modifiedAt: remoteTask.modifiedAt
                        )
                        mergedTasks.append(accepted)
                    } else {
                        // Local is newer or same — keep local version (daughter's toggle wins)
                        mergedTasks.append(localTask)
                    }
                } else {
                    // New task from remote — add it
                    // kai-sync-004: If it's already completed, count as remote completion
                    if remoteTask.isCompleted {
                        remoteCompletions += 1
                    }
                    mergedTasks.append(remoteTask)
                }
            }

            // Keep local-only tasks (not yet pushed to CloudKit) so they aren't lost
            for localTask in lists[index].tasks where localTask.cloudRecordID == nil {
                mergedTasks.append(localTask)
            }

            lists[index].tasks = mergedTasks

            // kai-sync-004: Award stars for tasks completed remotely by other participant.
            // This ensures the owner's star count reflects ALL completions (not just their own),
            // and the updated count gets pushed to CloudKit for participants to see.
            if remoteCompletions > 0 {
                lists[index].starCount += remoteCompletions
                // Also check if all tasks are now completed for bonus star
                if !lists[index].tasks.isEmpty &&
                   lists[index].tasks.allSatisfy({ $0.isCompleted }) {
                    lists[index].starCount += 1
                }
            }
            saveLists()

            // kai-sync-004: If we're the list OWNER and the remote star count differs from
            // what we have locally (e.g. daughter earned stars that only saved locally on her
            // device), push our authoritative star data back to CloudKit.
            // This closes the loop: daughter completes tasks → her device creates replacement
            // task records → owner syncs and sees them → owner pushes updated star count.
            if lists[index].shareType == .owned,
               lists[index].starCount != starData.starCount {
                let updatedList = lists[index]
                Task {
                    try? await CloudKitService.shared.updateListStarData(
                        cloudRecordID: cloudRecordID,
                        starCount: updatedList.starCount,
                        starGoal: updatedList.starGoal,
                        rewardText: updatedList.rewardText,
                        rewardGiven: updatedList.rewardGiven
                    )
                }
            }
        }
    }

    func syncTaskToCloud(listID: UUID, task: TodoTask) {
        guard let list = getList(by: listID),
              list.isShared,
              let cloudRecordID = list.cloudRecordID else {
            return
        }

        Task {
            do {
                let recordID = CKRecord.ID(recordName: cloudRecordID)
                let savedRecord = try await CloudKitService.shared.saveTask(task, listRecordID: recordID)
                // Write the CloudKit record name back onto the local task so future syncs
                // update the existing record instead of creating a duplicate.
                // kai-sync-004: Also update if the recordName CHANGED (participant created
                // a replacement record because they couldn't modify the original).
                let newRecordName = savedRecord.recordID.recordName
                await MainActor.run {
                    if let listIndex = lists.firstIndex(where: { $0.id == listID }),
                       let taskIndex = lists[listIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                        if lists[listIndex].tasks[taskIndex].cloudRecordID != newRecordName {
                            lists[listIndex].tasks[taskIndex].cloudRecordID = newRecordName
                            saveLists()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    syncError = "Failed to sync task: \(error.localizedDescription)"
                }
                print("Failed to sync task to CloudKit: \(error)")
            }
        }
    }

    // MARK: - Gold Star

    /// Hybrid star model:
    ///   • 1 star per individual task completion (reward momentum)
    ///   • +1 bonus star when ALL tasks in the list are completed (reward finishing)
    /// Both paths call this function; list-completion callers invoke it twice
    /// (once for the task, once for the bonus) so the same CloudKit sync logic applies.
    private func awardStar(at listIndex: Int) {
        lists[listIndex].starCount += 1
        saveLists()
        NotificationCenter.default.post(name: .starEarned, object: nil)

        // Sync star/reward fields to CloudKit for shared lists (kai-sync-003 Bug 1).
        // kai-sync-004: Only the list OWNER can modify the SharedList CKRecord.
        // Participants save locally (already done above) — their star count propagates
        // when the owner's device syncs and sees the completed tasks, then recalculates.
        let list = lists[listIndex]
        guard list.isShared,
              list.shareType == .owned,  // only owner can write to SharedList record
              let cloudRecordID = list.cloudRecordID else { return }
        let snapshot = (list.starCount, list.starGoal, list.rewardText, list.rewardGiven)
        Task {
            do {
                try await CloudKitService.shared.updateListStarData(
                    cloudRecordID: cloudRecordID,
                    starCount: snapshot.0,
                    starGoal: snapshot.1,
                    rewardText: snapshot.2,
                    rewardGiven: snapshot.3
                )
            } catch {
                print("⭐ Failed to sync star data to CloudKit: \(error)")
            }
        }
    }

    func addTaskWithSync(to listID: UUID, text: String) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        let task = TodoTask(text: text)
        lists[index].tasks.append(task)
        saveLists()

        // Sync to CloudKit if shared
        if lists[index].isShared {
            syncTaskToCloud(listID: listID, task: task)
        }
    }

    func toggleTaskWithSync(in listID: UUID, taskID: UUID, userID: String, userName: String) {
        guard let listIndex = lists.firstIndex(where: { $0.id == listID }),
              let taskIndex = lists[listIndex].tasks.firstIndex(where: { $0.id == taskID }) else {
            return
        }

        var task = lists[listIndex].tasks[taskIndex]
        let wasCompleting = !task.isCompleted   // capture direction before mutation
        if task.isCompleted {
            task.uncomplete()
        } else {
            task.complete(by: userID, name: userName)
            triggerConfetti(for: taskID)
        }
        lists[listIndex].tasks[taskIndex] = task
        saveLists()

        if wasCompleting {
            // Per-task star: reward every individual completion
            awardStar(at: listIndex)

            // Bonus star + firework: reward finishing the whole list
            if !lists[listIndex].tasks.isEmpty &&
               lists[listIndex].tasks.allSatisfy({ $0.isCompleted }) {
                listCompletedTrigger += 1
                awardStar(at: listIndex)
            }
        }

        // Sync to CloudKit if shared
        if lists[listIndex].isShared {
            syncTaskToCloud(listID: listID, task: task)
        }
    }
}
