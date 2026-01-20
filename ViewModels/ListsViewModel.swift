import Foundation
import SwiftUI
import CloudKit

@Observable
class ListsViewModel {
    var lists: [TodoList] = []
    var showingConfetti = false
    var lastCompletedTaskID: UUID?
    var isSyncing = false
    var syncError: String?

    private let storage = StorageService.shared

    init() {
        loadLists()
    }

    // MARK: - List Operations

    func loadLists() {
        lists = storage.loadLists()
    }

    func saveLists() {
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

    func deleteList(_ list: TodoList) {
        lists.removeAll { $0.id == list.id }
        saveLists()
    }

    func getList(by id: UUID) -> TodoList? {
        lists.first { $0.id == id }
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
        if task.isCompleted {
            task.uncomplete()
        } else {
            task.complete(by: userID, name: userName)
            triggerConfetti(for: taskID)
        }
        lists[listIndex].tasks[taskIndex] = task
        saveLists()
    }

    func updateTask(in listID: UUID, task: TodoTask) {
        guard let listIndex = lists.firstIndex(where: { $0.id == listID }),
              let taskIndex = lists[listIndex].tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        lists[listIndex].tasks[taskIndex] = task
        saveLists()
    }

    func deleteTask(in listID: UUID, taskID: UUID) {
        guard let listIndex = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[listIndex].tasks.removeAll { $0.id == taskID }
        saveLists()
    }

    // MARK: - Confetti

    private func triggerConfetti(for taskID: UUID) {
        lastCompletedTaskID = taskID
        showingConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showingConfetti = false
        }
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
                _ = try await CloudKitService.shared.saveTask(task, listRecordID: recordID)
            } catch {
                print("Failed to sync task to CloudKit: \(error)")
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
        if task.isCompleted {
            task.uncomplete()
        } else {
            task.complete(by: userID, name: userName)
            triggerConfetti(for: taskID)
        }
        lists[listIndex].tasks[taskIndex] = task
        saveLists()

        // Sync to CloudKit if shared
        if lists[listIndex].isShared {
            syncTaskToCloud(listID: listID, task: task)
        }
    }
}
