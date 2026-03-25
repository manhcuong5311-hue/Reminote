import CloudKit
import Foundation
import Observation

// MARK: - Sync state

enum CloudSyncState: Equatable {
    case unknown
    case unavailable        // No iCloud account
    case idle
    case syncing
    case synced(Date)       // Last successful sync
    case error(String)

    var label: String {
        switch self {
        case .unknown:         return "Checking…"
        case .unavailable:     return "iCloud Off"
        case .idle:            return "Not synced"
        case .syncing:         return "Syncing…"
        case .synced(let d):
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "Synced \(f.localizedString(for: d, relativeTo: Date()))"
        case .error(let msg):  return msg
        }
    }

    var isSyncing: Bool { self == .syncing }
    var isError: Bool   { if case .error = self { return true }; return false }
}

// MARK: - iCloudManager

@Observable
final class iCloudManager {
    static let shared = iCloudManager()

    // MARK: State

    var syncState: CloudSyncState = .unknown
    var isAvailable: Bool         = false

    /// Messages fetched from remote, waiting to be merged into the view model.
    /// ContentView observes this and drains it immediately.
    var pendingRemoteMerge: [Message]? = nil

    // MARK: User preferences
    // Stored properties so @Observable tracks changes and SwiftUI re-renders.
    // UserDefaults is the backing store, synced via didSet.

    var isSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "icloud_sync_enabled") {
        didSet { UserDefaults.standard.set(isSyncEnabled, forKey: "icloud_sync_enabled") }
    }

    var hasShownPrompt: Bool = UserDefaults.standard.bool(forKey: "icloud_prompt_shown") {
        didSet { UserDefaults.standard.set(hasShownPrompt, forKey: "icloud_prompt_shown") }
    }

    private var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "icloud_last_sync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "icloud_last_sync") }
    }

    private init() {}

    // MARK: - Account check

    func checkAccountStatus() async {
        do {
            let status = try await CloudSyncService.shared.accountStatus()
            await MainActor.run {
                self.isAvailable = (status == .available)
                if status != .available {
                    self.syncState = .unavailable
                }
            }
        } catch {
            await MainActor.run {
                self.isAvailable = false
                self.syncState   = .unavailable
            }
        }
    }

    // MARK: - Enable / disable

    func enableSync(messages: [Message]) async {
        isSyncEnabled = true
        hasShownPrompt = true
        await syncAll(messages: messages)
        try? await CloudSyncService.shared.setupSubscription()
    }

    func disableSync() {
        isSyncEnabled  = false
        hasShownPrompt = true
        syncState = .idle
    }

    // MARK: - Full sync (bidirectional)

    /// Fetches remote changes, merges with `localMessages`, and uploads anything not yet in cloud.
    /// Returns the merged message array so the caller can update its state.
    @discardableResult
    func syncAll(messages: [Message]) async -> [Message] {
        guard isSyncEnabled, isAvailable else { return messages }
        await MainActor.run { syncState = .syncing }

        do {
            // 1. Pull remote
            let since = lastSyncDate ?? .distantPast
            let remote = since < Date().addingTimeInterval(-3600)
                ? try await CloudSyncService.shared.fetchAll()                 // full sync if >1h
                : try await CloudSyncService.shared.fetchChanges(since: since) // incremental

            // 2. Merge (nonisolated — no await needed)
            let merged = CloudSyncService.shared.merge(remote: remote, local: messages)

            // 3. Push any local messages not yet synced
            let unsynced = merged.filter { $0.cloudSyncedAt == nil }
            var finalMessages = merged
            for (i, msg) in finalMessages.enumerated() {
                if unsynced.contains(where: { $0.id == msg.id }) {
                    if let serverDate = try? await CloudSyncService.shared.upload(msg) {
                        finalMessages[i].cloudSyncedAt = serverDate
                    }
                }
            }

            let now = Date()
            lastSyncDate = now
            await MainActor.run {
                self.syncState = .synced(now)
                if !remote.isEmpty { self.pendingRemoteMerge = finalMessages }
            }
            StorageService.shared.saveMessages(finalMessages)
            return finalMessages

        } catch {
            await MainActor.run { syncState = .error(Self.userMessage(for: error)) }
            return messages
        }
    }

    // MARK: - Upload a single message after create/edit

    func upload(_ message: Message) async -> Message {
        guard isSyncEnabled, isAvailable else { return message }
        do {
            let serverDate = try await CloudSyncService.shared.upload(message)
            var synced = message
            synced.cloudSyncedAt = serverDate
            return synced
        } catch {
            // Non-fatal: will be picked up on next syncAll
            return message
        }
    }

    // MARK: - Delete remote record

    func delete(id: UUID) async {
        guard isSyncEnabled, isAvailable else { return }
        try? await CloudSyncService.shared.delete(id: id)
    }

    // MARK: - Called from AppDelegate on silent push (CKDatabaseSubscription)

    func handleRemoteNotification() async {
        guard isSyncEnabled, isAvailable else { return }
        await MainActor.run { syncState = .syncing }
        do {
            let since = lastSyncDate ?? .distantPast
            let remote = try await CloudSyncService.shared.fetchChanges(since: since)
            if !remote.isEmpty {
                let now = Date()
                lastSyncDate = now
                await MainActor.run {
                    self.pendingRemoteMerge = remote
                    self.syncState = .synced(now)
                }
            } else {
                await MainActor.run { syncState = .idle }
            }
        } catch {
            await MainActor.run { syncState = .error(Self.userMessage(for: error)) }
        }
    }

    // MARK: - Error messages

    private static func userMessage(for error: Error) -> String {
        if let ck = error as? CKError {
            switch ck.code {
            case .networkUnavailable, .networkFailure:
                return "No internet — will retry when online"
            case .notAuthenticated:
                return "Sign in: Settings → [Your Name] → iCloud"
            case .quotaExceeded:
                return "iCloud full — free space in Settings → iCloud → Manage"
            case .serverRejectedRequest:
                return "iCloud rejected request — try again later"
            case .zoneNotFound, .userDeletedZone:
                return "iCloud data reset — re-enable sync"
            case .permissionFailure:
                return "iCloud permission denied — check Settings → Privacy"
            case .accountTemporarilyUnavailable:
                return "iCloud unavailable — try again later"
            default:
                return "Sync error (code \(ck.code.rawValue))"
            }
        }
        return "Sync failed — check iCloud in Settings"
    }
}
