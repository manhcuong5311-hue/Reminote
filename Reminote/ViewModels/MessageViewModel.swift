import Foundation
import SwiftUI
import Observation

@Observable
final class MessageViewModel {

    // MARK: - State
    var messages: [Message] = []
    var hasCompletedOnboarding: Bool = false

    // Delegate premium state to PremiumManager
    var isPremium: Bool { PremiumManager.shared.isPremium }
    var showPaywall: Bool {
        get { PremiumManager.shared.showPaywall }
        set { PremiumManager.shared.showPaywall = newValue }
    }

    static let freeMessageLimit = 3

    // MARK: - Computed

    var lockedMessages: [Message] {
        messages
            .filter { !$0.isUnlocked && !$0.isOpened }
            .sorted { $0.unlockDate < $1.unlockDate }
    }

    var unlockedUnread: [Message] {
        messages.filter { $0.isUnlocked && !$0.isOpened }
            .sorted { $0.unlockDate < $1.unlockDate }
    }

    var openedMessages: [Message] {
        messages.filter { $0.isOpened }
            .sorted { $0.unlockDate > $1.unlockDate }
    }

    var activeCount: Int {
        messages.filter { !$0.isOpened }.count
    }

    var canCreate: Bool {
        isPremium || activeCount < Self.freeMessageLimit
    }

    var isEmpty: Bool { messages.isEmpty }

    // MARK: - Init

    init() {
        messages = StorageService.shared.loadMessages()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_v1")
    }

    // MARK: - Actions

    func createMessage(_ message: Message) {
        guard canCreate else { showPaywall = true; return }
        messages.append(message)
        persist()
        NotificationManager.shared.scheduleUnlock(for: message)
        NotificationManager.shared.cancelReengagement()
        Task { await NotificationManager.shared.requestPermission() }
    }

    func openMessage(_ message: Message) -> Message? {
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return nil }
        messages[idx].isOpened = true
        persist()
        return messages[idx]
    }

    func saveReflection(for message: Message, note: String) {
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[idx].reflectNote = note
        persist()
    }

    func deleteMessage(_ message: Message) {
        if let fn = message.audioFileName { StorageService.shared.deleteAudio(fileName: fn) }
        if let fn = message.videoFileName { StorageService.shared.deleteVideo(fileName: fn) }
        NotificationManager.shared.cancelUnlock(for: message)
        messages.removeAll { $0.id == message.id }
        persist()
        if messages.isEmpty { NotificationManager.shared.scheduleReengagement() }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "onboarding_v1")
    }

    // Legacy shim — use PremiumManager directly going forward
    func unlockPremium() { PremiumManager.shared.unlock() }

    // Debug only — bypasses canCreate limit
    func debugForceCreate(_ message: Message) {
        messages.append(message)
        persist()
        NotificationManager.shared.scheduleUnlock(for: message)
    }

    // MARK: - Persistence

    private func persist() { StorageService.shared.saveMessages(messages) }
}
