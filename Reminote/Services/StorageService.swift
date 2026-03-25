import Foundation

final class StorageService {
    static let shared = StorageService()

    private let messagesKey = "future_messages_v1"
    private let documentsURL: URL

    private init() {
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    // MARK: - Messages

    func saveMessages(_ messages: [Message]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(messages) {
            UserDefaults.standard.set(data, forKey: messagesKey)
        }
    }

    func loadMessages() -> [Message] {
        guard let data = UserDefaults.standard.data(forKey: messagesKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Message].self, from: data)) ?? []
    }

    // MARK: - Audio

    func newAudioURL() -> URL {
        documentsURL.appendingPathComponent("\(UUID().uuidString).m4a")
    }

    func audioURL(for fileName: String) -> URL {
        documentsURL.appendingPathComponent(fileName)
    }

    func deleteAudio(fileName: String) {
        try? FileManager.default.removeItem(at: audioURL(for: fileName))
    }

    // MARK: - Video

    func newVideoURL() -> URL {
        documentsURL.appendingPathComponent("\(UUID().uuidString).mov")
    }

    func videoURL(for fileName: String) -> URL {
        documentsURL.appendingPathComponent(fileName)
    }

    func deleteVideo(fileName: String) {
        try? FileManager.default.removeItem(at: videoURL(for: fileName))
    }
}
