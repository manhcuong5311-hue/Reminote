import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MessageViewModel

    @State private var profile = UserProfileManager.shared
    @State private var theme   = ThemeManager.shared
    @State private var premium = PremiumManager.shared

    @State private var showNotifications = false
    @State private var showThemes        = false
    @State private var showFAQ           = false
    @State private var showPrivacy       = false
    @State private var showTerms         = false
    @State private var showPaywall       = false
    @State private var showBirthDatePicker = false
    @State private var showDebug         = false

    // Hidden debug tap counter
    @State private var debugTapCount     = 0
    @State private var debugTapTimer:    Timer?

    @State private var nameField: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileSection
                        notificationsSection
                        themesSection
                        premiumSection
                        supportSection
                        legalSection
                        versionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
        .preferredColorScheme(theme.current == .softLight ? .light : .dark)
        .onAppear { nameField = profile.userName }
        .sheet(isPresented: $showNotifications) { NotificationSettingsView() }
        .sheet(isPresented: $showThemes)        { ThemeSelectionView() }
        .sheet(isPresented: $showFAQ)           { FAQView() }
        .sheet(isPresented: $showPrivacy)       { PrivacyPolicyView() }
        .sheet(isPresented: $showTerms)         { TermsView() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: viewModel)
        }
        .sheet(isPresented: $showDebug) {
            DebugMenuView(viewModel: viewModel)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        settingsCard {
            sectionLabel("PROFILE")
                .padding(.bottom, 14)

            VStack(spacing: 16) {
                // Avatar + name
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Text(profile.userName.prefix(1).uppercased().isEmpty ? "?" : String(profile.userName.prefix(1).uppercased()))
                            .font(.serif(22))
                            .foregroundColor(.appAccent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Your name", text: $nameField)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appText)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                profile.userName = nameField.trimmingCharacters(in: .whitespaces)
                                Haptic.light()
                            }
                            .onChange(of: nameField) { _, v in
                                profile.userName = v
                            }

                        Text("Used in greetings and on your home screen")
                            .font(.system(size: 11))
                            .foregroundColor(.appHint)
                    }
                }

                Divider().background(Color.appBorder)

                // Birth date
                Button {
                    withAnimation { showBirthDatePicker.toggle() }
                    Haptic.light()
                } label: {
                    SettingsRow(icon: "gift.fill", iconColor: Color(red: 0.9, green: 0.45, blue: 0.5)) {
                        Text("Birthday")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    } trailing: {
                        HStack(spacing: 4) {
                            Text(profile.birthDate.map { formattedBirthdate($0) } ?? "Not set")
                                .font(.system(size: 14))
                                .foregroundColor(.appSubtext)
                            Image(systemName: showBirthDatePicker ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(.appHint)
                        }
                    }
                }

                if showBirthDatePicker {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { profile.birthDate ?? Calendar.current.date(byAdding: .year, value: -25, to: Date())! },
                            set: { profile.birthDate = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.appAccent)
                    .labelsHidden()
                    .colorScheme(theme.current == .softLight ? .light : .dark)

                    if profile.birthDate != nil {
                        Button {
                            profile.birthDate = nil
                            withAnimation { showBirthDatePicker = false }
                        } label: {
                            Text("Clear birthday")
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        settingsCard {
            sectionLabel("NOTIFICATIONS")
                .padding(.bottom, 14)

            Button { showNotifications = true; Haptic.light() } label: {
                SettingsRow(icon: "bell.fill", iconColor: Color(red: 0.4, green: 0.6, blue: 0.9)) {
                    Text("Notification Settings")
                        .font(.system(size: 15))
                        .foregroundColor(.appText)
                } trailing: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.appHint)
                }
            }
        }
    }

    // MARK: - Themes

    private var themesSection: some View {
        settingsCard {
            sectionLabel("APPEARANCE")
                .padding(.bottom, 14)

            Button { showThemes = true; Haptic.light() } label: {
                SettingsRow(icon: "paintbrush.fill", iconColor: Color(red: 0.7, green: 0.5, blue: 0.9)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                        Text(theme.current.name)
                            .font(.system(size: 12))
                            .foregroundColor(.appSubtext)
                    }
                } trailing: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(theme.current.accent)
                            .frame(width: 18, height: 18)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.appHint)
                    }
                }
            }
        }
    }

    // MARK: - Premium

    private var premiumSection: some View {
        settingsCard {
            sectionLabel("PREMIUM")
                .padding(.bottom, 14)

            if premium.isPremium {
                VStack(spacing: 0) {
                    SettingsRow(icon: "checkmark.seal.fill", iconColor: .appAccent) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Future Message Premium")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.appText)
                            Text(premium.activePlanLabel.isEmpty
                                 ? "All features unlocked"
                                 : "\(premium.activePlanLabel) · All features unlocked")
                                .font(.system(size: 12))
                                .foregroundColor(.appAccent)
                        }
                    } trailing: { EmptyView() }

                    // Only yearly subscribers need to manage their subscription
                    if premium.activePlanLabel == "Yearly" {
                        Divider().background(Color.appBorder).padding(.vertical, 6)

                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            SettingsRow(icon: "arrow.clockwise.circle.fill",
                                        iconColor: Color(red: 0.4, green: 0.7, blue: 0.5)) {
                                Text("Manage Subscription")
                                    .font(.system(size: 15))
                                    .foregroundColor(.appText)
                            } trailing: {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appHint)
                            }
                        }
                    }
                }
            } else {
                Button { showPaywall = true; Haptic.medium() } label: {
                    SettingsRow(icon: "star.fill", iconColor: .appAccent) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.appText)
                            Text("Unlimited messages · All themes · Voice & Video")
                                .font(.system(size: 11))
                                .foregroundColor(.appSubtext)
                        }
                    } trailing: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.appHint)
                    }
                }
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        settingsCard {
            sectionLabel("SUPPORT")
                .padding(.bottom, 14)

            VStack(spacing: 16) {
                Button { showFAQ = true } label: {
                    SettingsRow(icon: "questionmark.circle.fill", iconColor: Color(red: 0.3, green: 0.7, blue: 0.6)) {
                        Text("FAQ")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    } trailing: {
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.appHint)
                    }
                }

                Divider().background(Color.appBorder)

                Link(destination: URL(string: "mailto:support@futuremessage.app")!) {
                    SettingsRow(icon: "envelope.fill", iconColor: Color(red: 0.5, green: 0.7, blue: 0.9)) {
                        Text("Contact Support")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    } trailing: {
                        Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundColor(.appHint)
                    }
                }

                Divider().background(Color.appBorder)

                Link(destination: URL(string: "https://apps.apple.com")!) {
                    SettingsRow(icon: "star.fill", iconColor: Color(red: 1.0, green: 0.8, blue: 0.2)) {
                        Text("Rate the App")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    } trailing: {
                        Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundColor(.appHint)
                    }
                }
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        settingsCard {
            sectionLabel("LEGAL")
                .padding(.bottom, 14)

            VStack(spacing: 16) {
                Button { showPrivacy = true } label: {
                    SettingsRow(icon: "hand.raised.fill", iconColor: Color(red: 0.5, green: 0.6, blue: 0.8)) {
                        Text("Privacy Policy")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    } trailing: {
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.appHint)
                    }
                }

                Divider().background(Color.appBorder)

                Button { showTerms = true } label: {
                    SettingsRow(icon: "doc.text.fill", iconColor: Color(red: 0.6, green: 0.6, blue: 0.7)) {
                        Text("Terms of Use")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    } trailing: {
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.appHint)
                    }
                }
            }
        }
    }

    // MARK: - Footer (hidden debug trigger: tap 5×)

    private var versionFooter: some View {
        VStack(spacing: 6) {
            Text("Future Message v1.0")
                .font(.system(size: 12))
                .foregroundColor(debugTapCount > 0 ? .appAccent.opacity(Double(debugTapCount) * 0.2) : .appHint)
                .animation(.easeInOut(duration: 0.15), value: debugTapCount)

            if debugTapCount > 0 && debugTapCount < 5 {
                Text("\(5 - debugTapCount) more to unlock debug")
                    .font(.system(size: 10))
                    .foregroundColor(.appHint)
                    .transition(.opacity)
            }
        }
        .padding(.top, 4)
        .contentShape(Rectangle())
        .onTapGesture { handleDebugTap() }
    }

    private func handleDebugTap() {
        debugTapTimer?.invalidate()
        debugTapCount += 1
        Haptic.light()

        if debugTapCount >= 5 {
            debugTapCount = 0
            Haptic.success()
            showDebug = true
        } else {
            // Reset count if user stops tapping for 2 s
            debugTapTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                debugTapCount = 0
            }
        }
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .cardStyle()
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.appHint)
            .tracking(1.2)
    }

    private func formattedBirthdate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

#Preview { SettingsView(viewModel: MessageViewModel()) }
