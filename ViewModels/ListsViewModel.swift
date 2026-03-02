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
    /// Debounced save: cancelled + restarted on every mutation so rapid toggles/edits
    /// coalesce into a single background write instead of blocking the main thread.
    private var pendingSave: Task<Void, Never>?

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
        pendingSave?.cancel()
        let snapshot = lists          // capture value type before leaving main thread
        pendingSave = Task.detached(priority: .utility) { [weak storage] in
            // 300ms debounce — coalesces bursts (e.g. rapid toggles) into one write
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            storage?.saveLists(snapshot)
        }
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
    func updateStarGoal(listID: UUID, goal: Int?, rewardText: String?) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].starGoal = goal
        lists[index].rewardText = rewardText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
            ? nil
            : rewardText?.trimmingCharacters(in: .whitespacesAndNewlines)
        lists[index].rewardGiven = false  // reset so button re-appears when goal changes
        saveLists()
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

        // Fetch latest tasks from CloudKit
        let remoteTasks = try await CloudKitService.shared.fetchTasks(forListID: recordID)

        await MainActor.run {
            if let index = lists.firstIndex(where: { $0.id == list.id }) {
                // Merge tasks - prefer remote for shared lists
                lists[index].tasks = remoteTasks
                saveLists()
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
                await MainActor.run {
                    if let listIndex = lists.firstIndex(where: { $0.id == listID }),
                       let taskIndex = lists[listIndex].tasks.firstIndex(where: { $0.id == task.id }),
                       lists[listIndex].tasks[taskIndex].cloudRecordID == nil {
                        lists[listIndex].tasks[taskIndex].cloudRecordID = savedRecord.recordID.recordName
                        saveLists()
                    }
                }
            } catch {
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

        // Sync updated starCount to CloudKit for shared lists
        let list = lists[listIndex]
        guard list.isShared, let cloudRecordID = list.cloudRecordID else { return }
        let newStarCount = list.starCount
        Task {
            do {
                try await CloudKitService.shared.updateListStarCount(
                    cloudRecordID: cloudRecordID,
                    starCount: newStarCount
                )
            } catch {
                print("⭐ Failed to sync starCount to CloudKit: \(error)")
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
