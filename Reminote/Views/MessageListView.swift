import SwiftUI

struct MessageListView: View {
    @Bindable var viewModel: MessageViewModel

    @State private var showCreate   = false
    @State private var selectedMsg: Message?
    @State private var showSettings = false
    @State private var appeared     = false

    @State private var profile   = UserProfileManager.shared
    @State private var premium   = PremiumManager.shared
    @State private var deepLink  = DeepLinkManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                if viewModel.isEmpty { emptyState } else { messageList }

                fabButton
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .preferredColorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
        .sheet(isPresented: $showCreate) {
            CreateMessageView(viewModel: viewModel)
        }
        .sheet(item: $selectedMsg) { msg in
            MessageDetailView(message: msg, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
        // Deep-link from notification tap → auto-open the right message
        .onChange(of: deepLink.pendingMessageID) { _, newID in
            guard let id = newID else { return }
            if let msg = viewModel.messages.first(where: { $0.id == id }) {
                selectedMsg = msg
            }
            DeepLinkManager.shared.pendingMessageID = nil
        }
    }

    // MARK: - List

    private var messageList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerArea
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                if !viewModel.unlockedUnread.isEmpty {
                    sectionHeader(icon: "envelope.open.fill", label: "Ready to open", color: .appAccent)
                        .padding(.horizontal, 24)
                    ForEach(viewModel.unlockedUnread) { m in
                        MessageCard(message: m, isReady: true)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                            .onTapGesture { selectedMsg = m }
                    }
                    Spacer().frame(height: 8)
                }

                if !viewModel.lockedMessages.isEmpty {
                    sectionHeader(icon: "lock.fill", label: "Waiting for you", color: .appSubtext)
                        .padding(.horizontal, 24)
                    ForEach(viewModel.lockedMessages) { m in
                        MessageCard(message: m, isReady: false)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                            .onTapGesture { selectedMsg = m }
                    }
                    Spacer().frame(height: 8)
                }

                if !viewModel.openedMessages.isEmpty {
                    sectionHeader(icon: "memories", label: "From your past", color: .appSubtext)
                        .padding(.horizontal, 24)
                    ForEach(viewModel.openedMessages) { m in
                        MessageCard(message: m, isReady: false, isOpened: true)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                            .onTapGesture { selectedMsg = m }
                    }
                }

                Spacer().frame(height: 120)
            }
            .opacity(appeared ? 1 : 0)
        }
    }

    // MARK: - Header (dynamic greeting)

    private var headerArea: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(profile.greeting)
                    .font(.serif(30))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Text("\(viewModel.messages.count) message\(viewModel.messages.count == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundColor(.appSubtext)

                    if !premium.isPremium {
                        Text("·")
                            .foregroundColor(.appHint)
                            .font(.system(size: 14))
                        Text("\(MessageViewModel.freeMessageLimit - viewModel.activeCount) free slot\(MessageViewModel.freeMessageLimit - viewModel.activeCount == 1 ? "" : "s") left")
                            .font(.system(size: 13))
                            .foregroundColor(.appHint)
                    }
                }
            }
            Spacer()
        }
    }

    private func sectionHeader(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .tracking(1.2)
            Spacer()
        }
        .padding(.bottom, 10)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "envelope.badge.clock")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundColor(.appAccent.opacity(0.6))

                VStack(spacing: 8) {
                    Text("No messages yet")
                        .font(.serif(24))
                        .foregroundColor(.appText)

                    let name = profile.userName.isEmpty ? "" : ", \(profile.userName)"
                    Text("Write your first message to\nyour future self\(name).")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(.appSubtext)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Button {
                Haptic.medium()
                showCreate = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                    Text("Write a message")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(ThemeManager.shared.current == .softLight ? .white : .black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(ThemeManager.shared.current == .softLight ? Color.appAccent : Color.white)
                .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 40)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - FAB

    private var fabButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    Haptic.medium()
                    if viewModel.canCreate { showCreate = true }
                    else { viewModel.showPaywall = true }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(ThemeManager.shared.current == .softLight ? .white : .black)
                        .frame(width: 58, height: 58)
                        .background(ThemeManager.shared.current == .softLight ? Color.appAccent : Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 34)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSettings = true
                Haptic.light()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(.appSubtext)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if !premium.isPremium {
                Button { viewModel.showPaywall = true } label: {
                    Text("Premium")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appAccent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Message Card

struct MessageCard: View {
    let message: Message
    var isReady: Bool   = false
    var isOpened: Bool  = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let title = message.title {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isReady ? .appAccent : .appSubtext)
                        .lineLimit(1)
                } else {
                    Text(isOpened ? "From \(message.yearWritten)" : "Untitled")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isOpened ? .appSubtext : .appHint)
                }
                Spacer()
                if isReady {
                    HStack(spacing: 4) {
                        Circle().fill(Color.appAccent).frame(width: 6, height: 6)
                        Text("Ready")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appAccent)
                    }
                } else if isOpened {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13)).foregroundColor(.appHint)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 10)).foregroundColor(.appHint)
                        Text(message.countdownString).font(.system(size: 11)).foregroundColor(.appHint)
                    }
                }
            }
            .padding(.bottom, 12)

            if isOpened {
                Text(message.content)
                    .font(.serif(17)).foregroundColor(.messageCream).lineLimit(3).lineSpacing(4)
            } else if isReady {
                Text(message.content)
                    .font(.serif(17)).foregroundColor(.messageCream).lineLimit(2).lineSpacing(4)
                    .blur(radius: 4)
                    .overlay(Text("Tap to open").font(.system(size: 12, weight: .medium)).foregroundColor(.appAccent))
            } else {
                Text("You wrote something important here.")
                    .font(.serif(17, italic: true)).foregroundColor(.appHint).lineLimit(2)
            }

            if message.hasMedia {
                HStack(spacing: 10) {
                    if message.audioFileName != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform").font(.system(size: 10))
                            Text("Voice").font(.system(size: 11))
                        }
                    }
                    if message.videoFileName != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "video.fill").font(.system(size: 10))
                            Text("Video").font(.system(size: 11))
                        }
                    }
                }
                .foregroundColor(.appAccent.opacity(0.7))
                .padding(.top, 10)
            }
        }
        .padding(18)
        .cardStyle()
        .shimmer()
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isReady ? Color.appAccent.opacity(0.4) : .clear, lineWidth: 0.8)
        )
    }
}

#Preview {
    MessageListView(viewModel: MessageViewModel())
}
