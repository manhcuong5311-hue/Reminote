import Foundation

struct Message: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String?
    var content: String
    var createdDate: Date = Date()
    var unlockDate: Date
    var isOpened: Bool = false
    var audioFileName: String?
    var videoFileName: String?
    var reflectNote: String?

    // MARK: - Computed

    var isUnlocked: Bool { Date() >= unlockDate }

    var daysUntilUnlock: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: Date()),
            to:   cal.startOfDay(for: unlockDate)
        )
        return max(0, comps.day ?? 0)
    }

    var countdownString: String {
        let days = daysUntilUnlock
        if days == 0 { return "Ready to open" }
        if days == 1 { return "Opens tomorrow" }
        return "Opens in \(days) days"
    }

    var timeAgoString: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: createdDate, relativeTo: Date())
    }

    var formattedUnlockDate: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: unlockDate)
    }

    var yearWritten: Int {
        Calendar.current.component(.year, from: createdDate)
    }

    var hasMedia: Bool { audioFileName != nil || videoFileName != nil }
}
