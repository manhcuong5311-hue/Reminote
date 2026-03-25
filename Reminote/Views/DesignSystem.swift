import SwiftUI

// MARK: - Colors (theme-aware via ThemeManager.shared)

extension Color {
    static var appBg:          Color { ThemeManager.shared.current.bg }
    static var appSurface:     Color { ThemeManager.shared.current.surface }
    static var appElevated:    Color { ThemeManager.shared.current.elevated }
    static var appBorder:      Color { ThemeManager.shared.current.border }
    static var appAccent:      Color { ThemeManager.shared.current.accent }
    static var appText:        Color { ThemeManager.shared.current.text }
    static var appSubtext:     Color { ThemeManager.shared.current.subtext }
    static var appHint:        Color { ThemeManager.shared.current.hint }
    static var messageCream:   Color { ThemeManager.shared.current.messageColor }
}

// MARK: - Typography

extension Font {
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "Georgia-Italic" : "Georgia", size: size)
    }
}

// MARK: - Haptics

struct Haptic {
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - PremiumBadge

struct PremiumBadge: View {
    var body: some View {
        Text("PREMIUM")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.appAccent)
            .tracking(0.8)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appAccent.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - CardStyle

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

// MARK: - Settings row

struct SettingsRow<Label: View, Trailing: View>: View {
    let icon: String
    let iconColor: Color
    @ViewBuilder let label: () -> Label
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(iconColor)
            }
            label()
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shimmer

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.04), .clear]),
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint:   .init(x: phase + 0.3, y: 0)
                )
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
