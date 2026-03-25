import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var viewModel     = MessageViewModel()
    @State private var themeManager  = ThemeManager.shared
    @State private var cloud         = iCloudManager.shared

    // In-app unlock banner
    @State private var bannerMessage: Message?
    @State private var shownBannerIDs: Set<UUID> = []

    // iCloud first-launch prompt
    @State private var showCloudPrompt = false

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
                    onDismiss: { bannerMessage = nil }
                )
                .padding(.top, 56)
                .zIndex(99)
            }
        }
        // ── Timers ──────────────────────────────────────────────────────
        .onReceive(unlockTimer) { _ in checkForNewlyUnlocked() }
        .onAppear {
            checkForNewlyUnlocked()
            Task { await startupSync() }
        }
        // ── Drain remote merge payload ───────────────────────────────────
        .onChange(of: cloud.pendingRemoteMerge) { _, payload in
            guard let merged = payload else { return }
            viewModel.mergeFromCloud(merged)
            cloud.pendingRemoteMerge = nil
        }
        // ── iCloud first-launch prompt ───────────────────────────────────
        .sheet(isPresented: $showCloudPrompt) {
            iCloudPromptView(
                onEnable: {
                    showCloudPrompt = false
                    Task { await cloud.enableSync(messages: viewModel.messages) }
                },
                onSkip: {
                    cloud.disableSync()
                    showCloudPrompt = false
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Startup

    private func startupSync() async {
        await cloud.checkAccountStatus()

        // Show first-launch iCloud prompt if iCloud is available and we haven't asked yet
        if cloud.isAvailable && !cloud.hasShownPrompt {
            await MainActor.run { showCloudPrompt = true }
            return
        }

        // Already opted-in: sync on every launch
        if cloud.isSyncEnabled && cloud.isAvailable {
            viewModel.syncWithCloud()
        }
    }

    // MARK: - Unlock banner check

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
