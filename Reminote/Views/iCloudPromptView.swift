import SwiftUI

struct iCloudPromptView: View {
    let onEnable: () -> Void
    let onSkip:   () -> Void

    @State private var appeared = false

    private let perks: [(icon: String, color: Color, text: String)] = [
        ("icloud.fill",        Color(red: 0.3, green: 0.55, blue: 0.95), "Sync across all your devices"),
        ("lock.rotation",      Color(red: 0.82, green: 0.70, blue: 0.45),"Messages unlock on every device"),
        ("arrow.counterclockwise.icloud", Color(red: 0.4, green: 0.75, blue: 0.5), "Never lose a memory"),
        ("wifi.slash",         Color(red: 0.6, green: 0.6, blue: 0.7),  "Offline-first — syncs when ready"),
    ]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.3, green: 0.55, blue: 0.95).opacity(0.12))
                            .frame(width: 96, height: 96)
                        Image(systemName: "arrow.clockwise.icloud.fill")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(Color(red: 0.3, green: 0.55, blue: 0.95))
                    }

                    // Headline
                    VStack(spacing: 10) {
                        Text("Sync your memories\nacross devices")
                            .font(.serif(28))
                            .foregroundColor(.appText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("Your future messages — text, audio, and video — will appear on every device signed into your iCloud.")
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(.appSubtext)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 16)
                    }

                    // Perk list
                    VStack(spacing: 0) {
                        ForEach(Array(perks.enumerated()), id: \.offset) { i, perk in
                            if i > 0 { Divider().background(Color.appBorder) }
                            HStack(spacing: 14) {
                                Image(systemName: perk.icon)
                                    .font(.system(size: 15))
                                    .foregroundColor(perk.color)
                                    .frame(width: 24)
                                Text(perk.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(.appText)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 0.5)
                    )

                    // CTA
                    VStack(spacing: 12) {
                        Button {
                            Haptic.success()
                            onEnable()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "icloud.fill")
                                    .font(.system(size: 15))
                                Text("Enable iCloud Sync")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(ThemeManager.shared.current == .softLight ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(red: 0.3, green: 0.55, blue: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Button {
                            Haptic.light()
                            onSkip()
                        } label: {
                            Text("Not now")
                                .font(.system(size: 14))
                                .foregroundColor(.appHint)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

                Spacer()
            }
        }
        .preferredColorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }
}
