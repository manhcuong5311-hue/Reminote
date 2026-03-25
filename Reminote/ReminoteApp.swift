import SwiftUI
import UserNotifications

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
        return true
    }

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

        // Both a direct tap and the OPEN_MESSAGE action should open the message
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
