import Foundation
import Observation

@Observable
final class UserProfileManager {
    static let shared = UserProfileManager()

    var userName: String = "" {
        didSet { UserDefaults.standard.set(userName, forKey: "profile_name") }
    }

    var birthDate: Date? {
        didSet {
            if let d = birthDate {
                UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "profile_birthdate")
            } else {
                UserDefaults.standard.removeObject(forKey: "profile_birthdate")
            }
        }
    }

    // MARK: - Computed

    var displayName: String { userName.isEmpty ? "you" : userName }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix: String
        switch hour {
        case 5..<12:  prefix = "Good morning"
        case 12..<17: prefix = "Good afternoon"
        case 17..<22: prefix = "Good evening"
        default:      prefix = "Good night"
        }
        return userName.isEmpty ? prefix : "\(prefix), \(userName)"
    }

    var isBirthday: Bool {
        guard let bd = birthDate else { return false }
        let cal = Calendar.current
        let today = Date()
        return cal.component(.month, from: bd) == cal.component(.month, from: today)
            && cal.component(.day, from: bd) == cal.component(.day, from: today)
    }

    // MARK: - Init

    private init() {
        userName = UserDefaults.standard.string(forKey: "profile_name") ?? ""
        let ts = UserDefaults.standard.double(forKey: "profile_birthdate")
        birthDate = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
}
