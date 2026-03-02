import SwiftUI
import CloudKit
import UserNotifications

// MARK: - App Delegate (CloudKit silent push handling)

/// Receives CloudKit silent push notifications and forwards them to ListsViewModel via
/// NotificationCenter. This is the only reliable way to handle background CloudKit
/// subscription callbacks in a SwiftUI lifecycle app.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register for remote notifications — required for CloudKit subscriptions to deliver pushes
        application.registerForRemoteNotifications()
        // Set up CloudKit subscriptions (idempotent — CloudKit ignores duplicate subscription IDs)
        Task {
            try? await CloudKitService.shared.setupSubscriptions()
        }
        return true
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ Failed to register for remote notifications: \(error)")
    }

    /// CloudKit silent push — content-available:1, no alert/sound/badge.
    /// Parse as CKNotification; if valid, post local notification so ListsViewModel syncs.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let dict = userInfo as? [String: NSObject],
              let ckNotification = CKNotification(fromRemoteNotificationDictionary: dict),
              ckNotification.notificationType == .query else {
            completionHandler(.noData)
            return
        }
        // Broadcast to any listening ListsViewModel instances
        NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
        completionHandler(.newData)
    }
}

extension Notification.Name {
    /// Posted when a CloudKit subscription push arrives — triggers syncSharedLists().
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
    /// Posted by ListsViewModel when a list completes and a ⭐ is earned.
    /// userInfo: ["listID": UUID]
    static let starEarned = Notification.Name("starEarned")
}

// MARK: - Invite Code Item

/// Wrapper so a String invite code can drive sheet(item:)
struct InviteCodeItem: Identifiable {
    let id = UUID()
    let code: String
}

@main
struct KaiToDoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var listsViewModel = ListsViewModel()
    @State private var userViewModel = UserViewModel()

    // Deep link state: set when app is opened via kaitodo://join/CODE
    @State private var pendingInvite: InviteCodeItem? = nil

    // Splash screen — shown on cold start, auto-dismisses after ~2s
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // ContentView is NOT mounted until splash finishes.
                // This ensures SwiftUI's first rendered frame is KindCodeSplashView —
                // ViewModel I/O and CloudKit init cannot block the splash render.
                if !showingSplash {
                    ContentView()
                        .environment(listsViewModel)
                        .environment(userViewModel)
                        .onOpenURL { url in
                            handleDeepLink(url)
                        }
                        .sheet(item: $pendingInvite) { invite in
                            // Auto-present join sheet with prefilled code
                            JoinListSheet(prefillCode: invite.code)
                                .environment(listsViewModel)
                                .environment(userViewModel)
                        }
                        .transition(.opacity)
                }

                if showingSplash {
                    KindCodeSplashView(isShowing: $showingSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.3), value: showingSplash)
        }
    }

    /// Parses kaitodo://join/ABC123 and triggers the join sheet
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "kaitodo",
              url.host == "join" else { return }
        let code = url.pathComponents
            .filter { $0 != "/" }
            .first?
            .uppercased()
        guard let code, code.count == 6 else { return }
        pendingInvite = InviteCodeItem(code: code)
    }
}

// MARK: - Color Extensions

extension Color {
    static let kaiPurple = Color(hex: "7161EF")
    static let kaiRed = Color(hex: "FF6B6B")
    static let kaiTeal = Color(hex: "4ECDC4")
    static let kaiYellow = Color(hex: "FFE66D")
    static let kaiOrange = Color(hex: "FF8C42")
    static let kaiMint = Color(hex: "95E1D3")
    static let kaiPink = Color(hex: "F38181")
    static let kaiBlue = Color(hex: "3D5A80")

    static let listColors: [Color] = [
        kaiPurple, kaiRed, kaiTeal, kaiYellow,
        kaiOrange, kaiMint, kaiPink, kaiBlue
    ]

    static let listColorHexes: [String] = [
        "7161EF", "FF6B6B", "4ECDC4", "FFE66D",
        "FF8C42", "95E1D3", "F38181", "3D5A80"
    ]

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
