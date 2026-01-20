import Foundation
import UserNotifications
import UIKit

@Observable
class NotificationService: NSObject {
    static let shared = NotificationService()

    var isAuthorized = false
    var deviceToken: String?

    override private init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]

        let granted = try await center.requestAuthorization(options: options)
        await MainActor.run {
            isAuthorized = granted
        }

        if granted {
            await registerForRemoteNotifications()
        }

        return granted
    }

    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    @MainActor
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Device Token

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString
    }

    func handleRegistrationError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - Local Notifications

    func scheduleTaskCompletionNotification(
        taskName: String,
        completedBy: String,
        listName: String
    ) async throws {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Completed! 🎉"
        content.body = "\(completedBy) completed \"\(taskName)\" in \(listName)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        try await center.add(request)
    }

    func scheduleReminderNotification(
        taskName: String,
        listName: String,
        at date: Date
    ) async throws {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = "Don't forget: \"\(taskName)\" in \(listName)"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        try await center.add(request)
    }

    // MARK: - Badge Management

    @MainActor
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    @MainActor
    func setBadge(count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }

    // MARK: - Notification Handling

    func handleNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        // Handle CloudKit notifications
        if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String: NSObject]) {
            handleCloudKitNotification(ckNotification)
        }
    }

    private func handleCloudKitNotification(_ notification: CKNotification) {
        guard let queryNotification = notification as? CKQueryNotification else { return }

        switch queryNotification.queryNotificationReason {
        case .recordCreated:
            NotificationCenter.default.post(name: .cloudKitRecordCreated, object: queryNotification)
        case .recordUpdated:
            NotificationCenter.default.post(name: .cloudKitRecordUpdated, object: queryNotification)
        case .recordDeleted:
            NotificationCenter.default.post(name: .cloudKitRecordDeleted, object: queryNotification)
        @unknown default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudKitRecordCreated = Notification.Name("cloudKitRecordCreated")
    static let cloudKitRecordUpdated = Notification.Name("cloudKitRecordUpdated")
    static let cloudKitRecordDeleted = Notification.Name("cloudKitRecordDeleted")
}

// MARK: - CKNotification import
import CloudKit
