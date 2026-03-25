import UserNotifications
import Foundation
import Observation

// MARK: - Reminder Frequency

enum ReminderFrequency: String, CaseIterable, Codable {
    case weekly  = "Weekly"
    case monthly = "Monthly"
}

// MARK: - NotificationManager

@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    // MARK: - Settings (persisted)

    var unlockEnabled: Bool = true {
        didSet { persist(); rescheduleReminders() }
    }
    var reminderEnabled: Bool = true {
        didSet { persist(); rescheduleReminders() }
    }
    var reminderFrequency: ReminderFrequency = .weekly {
        didSet { persist(); rescheduleReminders() }
    }
    var nudgesEnabled: Bool = false {
        didSet { persist(); rescheduleNudge() }
    }
    var notificationHour: Int = 10 {
        didSet { persist(); rescheduleReminders() }
    }

    var isAuthorized: Bool = false

    private init() {
        load()
        Task { await checkAuthorization() }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Category registration (call once at app launch)

    static func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_MESSAGE",
            title: "Open Message",
            options: [.foreground]
        )
        let unlockCategory = UNNotificationCategory(
            identifier: "UNLOCK",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([unlockCategory])
    }

    // MARK: - Unlock notification

    func scheduleUnlock(for message: Message) {
        guard unlockEnabled else { return }

        let interval = message.unlockDate.timeIntervalSinceNow
        guard interval > 0 else { return }   // already unlocked, no notification needed

        let content = UNMutableNotificationContent()
        content.title = "Your time capsule just unlocked"
        content.body = message.title.map { "\"\($0)\" — a message from your past is waiting." }
            ?? "You left yourself a message. It's time to open it."
        content.sound = .defaultCritical
        content.categoryIdentifier = "UNLOCK"
        content.userInfo = ["messageId": message.id.uuidString]
        if #available(iOS 15, *) {
            content.interruptionLevel = .timeSensitive
        }

        // UNTimeIntervalNotificationTrigger is more reliable than calendar-based,
        // especially for short intervals (e.g. the 2-minute debug test).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let req = UNNotificationRequest(
            identifier: "unlock_\(message.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(req)
    }

    func cancelUnlock(for message: Message) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["unlock_\(message.id.uuidString)"])
    }

    // MARK: - Reminders

    func rescheduleReminders() {
        cancelReminders()
        guard reminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Future Message"
        content.body = "You left something for yourself in the future."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = notificationHour
        comps.minute = 0

        switch reminderFrequency {
        case .weekly:
            comps.weekday = 1 // Sunday
        case .monthly:
            comps.day = 1
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: "reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func cancelReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reminder"])
    }

    // MARK: - Nudges

    func rescheduleNudge() {
        cancelNudge()
        guard nudgesEnabled else { return }

        let bodies = [
            "You wrote something important. Don't forget.",
            "Your future self is waiting to hear from you.",
            "The best time to write is now."
        ]

        let content = UNMutableNotificationContent()
        content.title = "Future Message"
        content.body = bodies.randomElement() ?? bodies[0]
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 60 * 60, repeats: true)
        let req = UNNotificationRequest(identifier: "nudge", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func cancelNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["nudge"])
    }

    // MARK: - Re-engagement

    func scheduleReengagement() {
        let content = UNMutableNotificationContent()
        content.title = "Future Message"
        content.body = "It's been a while since you wrote to yourself."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 24 * 60 * 60, repeats: false)
        let req = UNNotificationRequest(identifier: "reengagement", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func cancelReengagement() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reengagement"])
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(unlockEnabled, forKey: "notif_unlock")
        UserDefaults.standard.set(reminderEnabled, forKey: "notif_reminder")
        UserDefaults.standard.set(reminderFrequency.rawValue, forKey: "notif_frequency")
        UserDefaults.standard.set(nudgesEnabled, forKey: "notif_nudges")
        UserDefaults.standard.set(notificationHour, forKey: "notif_hour")
    }

    private func load() {
        let ud = UserDefaults.standard
        if ud.object(forKey: "notif_unlock") != nil {
            unlockEnabled     = ud.bool(forKey: "notif_unlock")
            reminderEnabled   = ud.bool(forKey: "notif_reminder")
            nudgesEnabled     = ud.bool(forKey: "notif_nudges")
            notificationHour  = ud.integer(forKey: "notif_hour")
            if let f = ud.string(forKey: "notif_frequency"),
               let freq = ReminderFrequency(rawValue: f) {
                reminderFrequency = freq
            }
        }
    }
}
