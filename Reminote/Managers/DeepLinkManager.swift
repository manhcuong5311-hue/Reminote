import Foundation
import Observation

@Observable
final class DeepLinkManager {
    static let shared = DeepLinkManager()
    var pendingMessageID: UUID?
    private init() {}
}
