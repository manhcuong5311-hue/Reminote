import SwiftUI

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeManager = ThemeManager.shared
    @State private var premiumManager = PremiumManager.shared
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 28)

                        VStack(spacing: 14) {
                            ForEach(AppTheme.all, id: \.id) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isSelected: themeManager.current.id == theme.id,
                                    isUnlocked: !theme.isPremium || premiumManager.isPremium
                                ) {
                                    if theme.isPremium && !premiumManager.isPremium {
                                        showPaywall = true
                                    } else {
                                        Haptic.medium()
                                        themeManager.apply(theme)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 60)
                    }
                }
            }
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
        .preferredColorScheme(themeManager.current == .softLight ? .light : .dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: MessageViewModel())
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Choose your theme")
                .font(.serif(26))
                .foregroundColor(.appText)
            Text("The right mood for every memory.")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.appSubtext)
        }
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let isUnlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Color swatch
                themeSwatchView

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(theme.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appText)
                        if theme.isPremium && !isUnlocked {
                            PremiumBadge()
                        }
                    }
                    Text(theme.description)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.appSubtext)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.appAccent)
                } else if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.appHint)
                } else {
                    Circle()
                        .strokeBorder(Color.appBorder, lineWidth: 1)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(16)
            .background(isSelected ? Color.appAccent.opacity(0.08) : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.appAccent.opacity(0.4) : Color.appBorder,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var themeSwatchView: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.bg)
                .frame(width: 52, height: 52)

            // Mini UI preview
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.surface)
                    .frame(width: 36, height: 8)

                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent)
                    .frame(width: 22, height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.surface)
                    .frame(width: 30, height: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

#Preview {
    ThemeSelectionView()
}
