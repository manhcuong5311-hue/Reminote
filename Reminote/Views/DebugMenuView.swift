import SwiftUI

struct DebugMenuView: View {
    @Bindable var viewModel: MessageViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDebugCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header badge
                        HStack(spacing: 8) {
                            Image(systemName: "ant.fill")
                                .font(.system(size: 12))
                            Text("DEBUG MODE")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.5)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 8)

                        // ── 1. Onboarding ───────────────────────────────────
                        debugCard(
                            number: "1",
                            title: "Reset Onboarding",
                            subtitle: "Shows the onboarding flow next time you open the app.",
                            icon: "arrow.counterclockwise",
                            iconColor: Color(red: 0.4, green: 0.7, blue: 1.0)
                        ) {
                            resetOnboarding()
                        }

                        // ── 2. Auto-open test ────────────────────────────────
                        debugCard(
                            number: "2",
                            title: "Auto-Open in 2 Minutes",
                            subtitle: "Write a real message with text, audio, and video — unlocks in 2 min to test the full flow.",
                            icon: "timer",
                            iconColor: Color(red: 0.5, green: 0.9, blue: 0.5)
                        ) {
                            showDebugCreate = true
                        }

                        Divider()
                            .background(Color.appBorder)
                            .padding(.horizontal, 8)

                        // ── State info ───────────────────────────────────────
                        stateInfo

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
        .preferredColorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
        .sheet(isPresented: $showDebugCreate) {
            CreateMessageView(viewModel: viewModel, debugMode: true)
        }
    }

    // MARK: - Actions

    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "onboarding_v1")
        viewModel.hasCompletedOnboarding = false
        Haptic.success()
        dismiss()
    }

    // MARK: - State info panel

    private var stateInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT STATE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.appHint)
                .tracking(1.2)

            let rows: [(String, String)] = [
                ("Onboarding done",  viewModel.hasCompletedOnboarding ? "YES" : "NO"),
                ("Premium",          PremiumManager.shared.isPremium ? "YES" : "NO"),
                ("Messages",         "\(viewModel.messages.count) total"),
                ("Locked",           "\(viewModel.lockedMessages.count)"),
                ("Ready to open",    "\(viewModel.unlockedUnread.count)"),
                ("Opened",           "\(viewModel.openedMessages.count)"),
                ("Theme",            ThemeManager.shared.current.name),
                ("User name",        UserProfileManager.shared.userName.isEmpty ? "(none)" : UserProfileManager.shared.userName),
            ]

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    if i > 0 { Divider().background(Color.appBorder) }
                    HStack {
                        Text(row.0)
                            .font(.system(size: 13))
                            .foregroundColor(.appSubtext)
                        Spacer()
                        Text(row.1)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.appText)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Card builder

    private func debugCard(
        number: String,
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("[\(number)]")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appText)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.appSubtext)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.appHint)
            }
            .padding(14)
            .cardStyle()
        }
    }
}

#Preview {
    DebugMenuView(viewModel: MessageViewModel())
}
