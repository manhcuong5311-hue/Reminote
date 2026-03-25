import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var viewModel     = MessageViewModel()
    @State private var themeManager  = ThemeManager.shared

    // In-app unlock banner
    @State private var bannerMessage: Message?
    @State private var shownBannerIDs: Set<UUID> = []

    // Poll every 15 s to catch messages that unlock while the app is open
    private let unlockTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if viewModel.hasCompletedOnboarding {
                    MessageListView(viewModel: viewModel)
                } else {
                    OnboardingView {
                        viewModel.completeOnboarding()
                        NotificationManager.shared.rescheduleReminders()
                        NotificationManager.shared.rescheduleNudge()
                    }
                }
            }
            // Forces full view-tree refresh when theme changes
            .id(themeManager.themeId)
            .animation(.easeInOut(duration: 0.4), value: viewModel.hasCompletedOnboarding)
            .preferredColorScheme(themeManager.current == .softLight ? .light : .dark)

            // ── In-app unlock banner ──────────────────────────────────────
            if let msg = bannerMessage {
                UnlockBannerView(
                    message: msg,
                    onOpen: {
                        DeepLinkManager.shared.pendingMessageID = msg.id
                        bannerMessage = nil
                    },
                    onDismiss: {
                        bannerMessage = nil
                    }
                )
                .padding(.top, 56)   // clears status bar
                .zIndex(99)
            }
        }
        .onReceive(unlockTimer) { _ in checkForNewlyUnlocked() }
        .onAppear { checkForNewlyUnlocked() }
    }

    // MARK: - Unlock check

    private func checkForNewlyUnlocked() {
        guard bannerMessage == nil else { return }
        for msg in viewModel.unlockedUnread {
            guard !shownBannerIDs.contains(msg.id) else { continue }
            shownBannerIDs.insert(msg.id)
            withAnimation { bannerMessage = msg }
            Haptic.success()
            break
        }
    }
}

#Preview {
    ContentView()
}
