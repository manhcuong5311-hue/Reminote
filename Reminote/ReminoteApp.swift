import SwiftUI
import UserNotifications
import CloudKit

@main
struct ReminoteApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Register notification categories with action buttons
        NotificationManager.registerCategories()

        // Register for remote notifications (needed for CloudKit silent pushes)
        // Requires "Background Modes → Remote notifications" capability in Xcode
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - Remote notifications (CloudKit subscription pushes)

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Check if this is a CloudKit database notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.notificationType == .database else {
            completionHandler(.noData)
            return
        }

        // Fetch changes triggered by another device
        Task {
            await iCloudManager.shared.handleRemoteNotification()
            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // CloudKit handles its own registration; no extra work needed here
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Silent fail — CloudKit subscriptions will still work via foreground polling
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show banners + play sound even when app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle taps on the notification itself OR the "Open Message" action button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier ||
           response.actionIdentifier == "OPEN_MESSAGE" {
            if let idString = userInfo["messageId"] as? String,
               let uuid = UUID(uuidString: idString) {
                DispatchQueue.main.async {
                    DeepLinkManager.shared.pendingMessageID = uuid
                }
            }
        }

        completionHandler()
    }
}
