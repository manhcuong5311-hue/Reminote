import CloudKit
import Foundation

// MARK: - CloudKit field keys

private enum CKField {
    static let msgID        = "msgID"
    static let title        = "title"
    static let content      = "content"
    static let createdDate  = "createdDate"
    static let unlockDate   = "unlockDate"
    static let isOpened     = "isOpened"
    static let reflectNote  = "reflectNote"
    static let audioAsset   = "audioAsset"
    static let videoAsset   = "videoAsset"
    static let audioName    = "audioName"
    static let videoName    = "videoName"
}

private let kRecordType     = "FutureMessage"
private let kSubscriptionID = "private-db-changes"

// MARK: - CloudSyncService
//
// Uses CKContainer.default() → iCloud.$(PRODUCT_BUNDLE_IDENTIFIER).
// Enable iCloud + CloudKit capability in Xcode before using.
//
// Implemented as a plain final class, NOT an actor, because all stored
// properties are read-only after init — there is no shared mutable state
// to protect. All public methods are async and safe to call from any Task.

final class CloudSyncService {
    static let shared = CloudSyncService()
    private init() {}

    private let container = CKContainer.default()
    private var db: CKDatabase { container.privateCloudDatabase }
    private let storage   = StorageService.shared

    // MARK: - Account status

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    // MARK: - Upload (create or overwrite)

    /// Saves a message to CloudKit. Returns the server-assigned modification date.
    @discardableResult
    func upload(_ message: Message) async throws -> Date {
        let recordID = CKRecord.ID(recordName: message.id.uuidString)

        // Preserve the changeTag by fetching first — prevents server-side conflicts.
        // Only create a fresh record when it genuinely doesn't exist yet.
        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            record = CKRecord(recordType: kRecordType, recordID: recordID)
        }
        // Other errors (network, auth…) propagate so callers can retry.

        record[CKField.msgID]       = message.id.uuidString
        record[CKField.title]       = message.title
        record[CKField.content]     = message.content
        record[CKField.createdDate] = message.createdDate
        record[CKField.unlockDate]  = message.unlockDate
        record[CKField.isOpened]    = message.isOpened ? 1 : 0
        record[CKField.reflectNote] = message.reflectNote

        if let name = message.audioFileName {
            let url = storage.audioURL(for: name)
            if FileManager.default.fileExists(atPath: url.path) {
                record[CKField.audioAsset] = CKAsset(fileURL: url)
                record[CKField.audioName]  = name
            }
        }

        if let name = message.videoFileName {
            let url = storage.videoURL(for: name)
            if FileManager.default.fileExists(atPath: url.path) {
                record[CKField.videoAsset] = CKAsset(fileURL: url)
                record[CKField.videoName]  = name
            }
        }

        let saved = try await db.save(record)
        return saved.modificationDate ?? Date()
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await db.deleteRecord(withID: recordID)
    }

    // MARK: - Fetch all messages

    func fetchAll() async throws -> [Message] {
        let query = CKQuery(
            recordType: kRecordType,
            predicate: NSPredicate(value: true)
        )
        return try await runQuery(query)
    }

    // MARK: - Fetch changes since a date

    func fetchChanges(since date: Date) async throws -> [Message] {
        let predicate = NSPredicate(format: "modificationDate > %@", date as CVarArg)
        let query = CKQuery(recordType: kRecordType, predicate: predicate)
        return try await runQuery(query)
    }

    // MARK: - Register push subscription (call once per install)

    func setupSubscription() async throws {
        let subs = try await db.allSubscriptions()
        if subs.contains(where: { $0.subscriptionID == kSubscriptionID }) { return }

        let sub  = CKDatabaseSubscription(subscriptionID: kSubscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push
        sub.notificationInfo = info
        try await db.save(sub)
    }

    // MARK: - Merge strategy (pure — no async needed)

    /// Last-write-wins for text fields; isOpened is monotonically sticky.
    func merge(remote: [Message], local: [Message]) -> [Message] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for remoteMsg in remote {
            if var localMsg = byID[remoteMsg.id] {
                localMsg.isOpened = localMsg.isOpened || remoteMsg.isOpened

                if (localMsg.reflectNote ?? "").isEmpty {
                    localMsg.reflectNote = remoteMsg.reflectNote
                }
                if localMsg.audioFileName == nil { localMsg.audioFileName = remoteMsg.audioFileName }
                if localMsg.videoFileName == nil { localMsg.videoFileName = remoteMsg.videoFileName }

                let remoteIsNewer: Bool = {
                    guard let rt = remoteMsg.cloudSyncedAt else { return false }
                    guard let lt = localMsg.cloudSyncedAt  else { return true  }
                    return rt > lt
                }()
                if remoteIsNewer {
                    localMsg.title      = remoteMsg.title
                    localMsg.content    = remoteMsg.content
                    localMsg.unlockDate = remoteMsg.unlockDate
                }
                localMsg.cloudSyncedAt = remoteMsg.cloudSyncedAt
                byID[remoteMsg.id] = localMsg
            } else {
                byID[remoteMsg.id] = remoteMsg
            }
        }

        return byID.values.sorted { $0.unlockDate < $1.unlockDate }
    }

    // MARK: - Helpers

    private func runQuery(_ query: CKQuery) async throws -> [Message] {
        var results: [Message] = []

        let (batch, cursor) = try await db.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )
        for (_, result) in batch {
            if case .success(let record) = result,
               let msg = messageFrom(record) {
                results.append(msg)
            }
        }

        var nextCursor = cursor
        while let current = nextCursor {
            let (more, moreCursor) = try await db.records(
                continuingMatchFrom: current,
                resultsLimit: CKQueryOperation.maximumResults
            )
            for (_, result) in more {
                if case .success(let record) = result,
                   let msg = messageFrom(record) {
                    results.append(msg)
                }
            }
            nextCursor = moreCursor
        }

        return results
    }

    /// Synchronous — FileManager calls are blocking but fast for our file sizes.
    private func messageFrom(_ record: CKRecord) -> Message? {
        guard
            let idStr   = record[CKField.msgID]       as? String,
            let id      = UUID(uuidString: idStr),
            let content = record[CKField.content]     as? String,
            let created = record[CKField.createdDate] as? Date,
            let unlock  = record[CKField.unlockDate]  as? Date
        else { return nil }

        var msg = Message(
            id:          id,
            content:     content,
            createdDate: created,
            unlockDate:  unlock
        )
        msg.title         = record[CKField.title]       as? String
        msg.isOpened      = (record[CKField.isOpened]   as? Int64 ?? 0) == 1
        msg.reflectNote   = record[CKField.reflectNote] as? String
        msg.cloudSyncedAt = record.modificationDate

        if let asset = record[CKField.audioAsset] as? CKAsset,
           let src   = asset.fileURL,
           let name  = record[CKField.audioName] as? String {
            let dest = storage.audioURL(for: name)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: src, to: dest)
            }
            msg.audioFileName = name
        }

        if let asset = record[CKField.videoAsset] as? CKAsset,
           let src   = asset.fileURL,
           let name  = record[CKField.videoName] as? String {
            let dest = storage.videoURL(for: name)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: src, to: dest)
            }
            msg.videoFileName = name
        }

        return msg
    }
}
