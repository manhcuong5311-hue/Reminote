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
        Task {
            let synced = await iCloudManager.shared.upload(message)
            if let idx = messages.firstIndex(where: { $0.id == synced.id }) {
                messages[idx] = synced
                persist()
            }
        }
    }

    func openMessage(_ message: Message) -> Message? {
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return nil }
        messages[idx].isOpened = true
        persist()
        let opened = messages[idx]
        Task {
            let synced = await iCloudManager.shared.upload(opened)
            if let i = messages.firstIndex(where: { $0.id == synced.id }) {
                messages[i] = synced; persist()
            }
        }
        return messages[idx]
    }

    func saveReflection(for message: Message, note: String) {
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[idx].reflectNote = note
        messages[idx].cloudSyncedAt = nil   // mark dirty for next sync
        persist()
        let updated = messages[idx]
        Task {
            let synced = await iCloudManager.shared.upload(updated)
            if let i = messages.firstIndex(where: { $0.id == synced.id }) {
                messages[i] = synced; persist()
            }
        }
    }

    func deleteMessage(_ message: Message) {
        if let fn = message.audioFileName { StorageService.shared.deleteAudio(fileName: fn) }
        if let fn = message.videoFileName { StorageService.shared.deleteVideo(fileName: fn) }
        NotificationManager.shared.cancelUnlock(for: message)
        messages.removeAll { $0.id == message.id }
        persist()
        if messages.isEmpty { NotificationManager.shared.scheduleReengagement() }
        Task { await iCloudManager.shared.delete(id: message.id) }
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

    // MARK: - Cloud merge (called by ContentView when iCloudManager has remote data)

    func mergeFromCloud(_ remote: [Message]) {
        messages = remote
        persist()
    }

    // MARK: - Full cloud sync (called on launch + from Settings)

    func syncWithCloud() {
        Task {
            let merged = await iCloudManager.shared.syncAll(messages: messages)
            await MainActor.run { messages = merged }
        }
    }

    // MARK: - Persistence

    private func persist() { StorageService.shared.saveMessages(messages) }
}
