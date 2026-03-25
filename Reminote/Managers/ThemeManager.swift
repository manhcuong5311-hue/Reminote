import SwiftUI
import Observation

// MARK: - AppTheme

struct AppTheme: Equatable {
    let id: String
    let name: String
    let description: String
    let isPremium: Bool

    let bg: Color
    let surface: Color
    let elevated: Color     // cards, inputs
    let border: Color
    let accent: Color
    let text: Color
    let subtext: Color
    let hint: Color
    let messageColor: Color  // serif content text

    // MARK: - Presets

    static let defaultDark = AppTheme(
        id: "default_dark",
        name: "Default Dark",
        description: "Classic dark, timeless.",
        isPremium: false,
        bg:           Color(red: 0.05, green: 0.05, blue: 0.06),
        surface:      Color(red: 0.10, green: 0.10, blue: 0.11),
        elevated:     Color(red: 0.13, green: 0.13, blue: 0.14),
        border:       Color.white.opacity(0.08),
        accent:       Color(red: 0.82, green: 0.70, blue: 0.45),
        text:         Color.white,
        subtext:      Color.white.opacity(0.55),
        hint:         Color.white.opacity(0.28),
        messageColor: Color(red: 0.97, green: 0.93, blue: 0.85)
    )

    static let softLight = AppTheme(
        id: "soft_light",
        name: "Soft Light",
        description: "Paper-like warmth. Like writing a real letter.",
        isPremium: true,
        bg:           Color(red: 0.95, green: 0.91, blue: 0.85),
        surface:      Color(red: 1.00, green: 0.98, blue: 0.96),
        elevated:     Color(red: 0.98, green: 0.96, blue: 0.93),
        border:       Color.black.opacity(0.07),
        accent:       Color(red: 0.54, green: 0.43, blue: 0.28),
        text:         Color(red: 0.11, green: 0.11, blue: 0.12),
        subtext:      Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.55),
        hint:         Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.28),
        messageColor: Color(red: 0.17, green: 0.11, blue: 0.06)
    )

    static let midnightBlue = AppTheme(
        id: "midnight_blue",
        name: "Midnight Blue",
        description: "Deep ocean calm. Write at 3am without regret.",
        isPremium: true,
        bg:           Color(red: 0.03, green: 0.05, blue: 0.10),
        surface:      Color(red: 0.06, green: 0.08, blue: 0.16),
        elevated:     Color(red: 0.09, green: 0.12, blue: 0.22),
        border:       Color.white.opacity(0.10),
        accent:       Color(red: 0.36, green: 0.60, blue: 0.84),
        text:         Color.white,
        subtext:      Color.white.opacity(0.58),
        hint:         Color.white.opacity(0.30),
        messageColor: Color(red: 0.85, green: 0.92, blue: 1.00)
    )

    static let sunsetEmber = AppTheme(
        id: "sunset_ember",
        name: "Sunset Ember",
        description: "Warm as the hour between day and night.",
        isPremium: true,
        bg:           Color(red: 0.10, green: 0.05, blue: 0.08),
        surface:      Color(red: 0.17, green: 0.08, blue: 0.12),
        elevated:     Color(red: 0.22, green: 0.11, blue: 0.16),
        border:       Color(red: 1.0, green: 0.4, blue: 0.3).opacity(0.15),
        accent:       Color(red: 0.94, green: 0.52, blue: 0.35),
        text:         Color.white,
        subtext:      Color.white.opacity(0.58),
        hint:         Color.white.opacity(0.28),
        messageColor: Color(red: 1.00, green: 0.94, blue: 0.88)
    )

    static let all: [AppTheme] = [.defaultDark, .softLight, .midnightBlue, .sunsetEmber]

    // Compare by id — avoids comparing every Color value
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.id == rhs.id }
}

// MARK: - ThemeManager

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var current: AppTheme = .defaultDark {
        didSet { UserDefaults.standard.set(current.id, forKey: "app_theme_id") }
    }

    var themeId: String { current.id }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_theme_id"),
           let theme = AppTheme.all.first(where: { $0.id == saved }) {
            current = theme
        }
    }

    func apply(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.35)) {
            current = theme
        }
    }
}
