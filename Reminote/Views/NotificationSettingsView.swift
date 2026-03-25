import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = NotificationManager.shared

    private let hourOptions = Array(6...22)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if !manager.isAuthorized {
                            permissionBanner
                        }

                        unlockSection
                        reminderSection
                        nudgeSection
                        timeSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
            .onAppear {
                Task { await manager.checkAuthorization() }
            }
        }
        .preferredColorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Notifications are disabled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)
                Text("Enable them in Settings to receive message unlock alerts.")
                    .font(.system(size: 12))
                    .foregroundColor(.appSubtext)
            }

            Spacer()

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Sections

    private var unlockSection: some View {
        settingsCard {
            VStack(spacing: 0) {
                sectionLabel("UNLOCK ALERTS")
                    .padding(.bottom, 12)

                Toggle(isOn: $manager.unlockEnabled) {
                    SettingsRow(icon: "envelope.open.fill", iconColor: .appAccent) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Message ready")
                                .font(.system(size: 15))
                                .foregroundColor(.appText)
                            Text("Notified when a message unlocks")
                                .font(.system(size: 12))
                                .foregroundColor(.appSubtext)
                        }
                    } trailing: { EmptyView() }
                }
                .tint(.appAccent)
            }
        }
    }

    private var reminderSection: some View {
        settingsCard {
            VStack(spacing: 0) {
                sectionLabel("REMINDERS")
                    .padding(.bottom, 12)

                VStack(spacing: 16) {
                    Toggle(isOn: $manager.reminderEnabled) {
                        SettingsRow(icon: "calendar.badge.clock", iconColor: Color(red: 0.4, green: 0.7, blue: 0.4)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Periodic reminder")
                                    .font(.system(size: 15))
                                    .foregroundColor(.appText)
                                Text("Reminds you to write a new message")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appSubtext)
                            }
                        } trailing: { EmptyView() }
                    }
                    .tint(.appAccent)

                    if manager.reminderEnabled {
                        Divider().background(Color.appBorder)

                        HStack {
                            Text("Frequency")
                                .font(.system(size: 14))
                                .foregroundColor(.appSubtext)
                            Spacer()
                            Picker("", selection: $manager.reminderFrequency) {
                                ForEach(ReminderFrequency.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                    }
                }
            }
        }
    }

    private var nudgeSection: some View {
        settingsCard {
            VStack(spacing: 0) {
                sectionLabel("EMOTIONAL NUDGES")
                    .padding(.bottom, 12)

                Toggle(isOn: $manager.nudgesEnabled) {
                    SettingsRow(icon: "sparkles", iconColor: Color(red: 0.7, green: 0.5, blue: 0.9)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Thoughtful nudges")
                                .font(.system(size: 15))
                                .foregroundColor(.appText)
                            Text("\"You wrote something important. Don't forget.\"")
                                .font(.system(size: 12))
                                .foregroundColor(.appSubtext)
                                .lineLimit(2)
                        }
                    } trailing: { EmptyView() }
                }
                .tint(.appAccent)
            }
        }
    }

    private var timeSection: some View {
        settingsCard {
            VStack(spacing: 0) {
                sectionLabel("DELIVERY TIME")
                    .padding(.bottom, 12)

                HStack {
                    SettingsRow(icon: "clock.fill", iconColor: Color(red: 0.6, green: 0.4, blue: 0.3)) {
                        Text("Time of day")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    } trailing: {
                        Picker("", selection: $manager.notificationHour) {
                            ForEach(hourOptions, id: \.self) { h in
                                Text(formattedHour(h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.appAccent)
                    }
                }
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

    private func formattedHour(_ h: Int) -> String {
        let ampm = h < 12 ? "AM" : "PM"
        let display = h == 0 ? 12 : h > 12 ? h - 12 : h
        return "\(display):00 \(ampm)"
    }
}

#Preview { NotificationSettingsView() }
