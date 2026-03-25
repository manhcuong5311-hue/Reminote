import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy Policy")
                                .font(.serif(28))
                                .foregroundColor(.appText)
                            Text("Last updated: March 2026")
                                .font(.system(size: 13))
                                .foregroundColor(.appHint)
                        }

                        Divider().background(Color.appBorder)

                        privacySection(
                            title: "Your data stays on your device",
                            icon: "iphone.and.arrow.forward",
                            body: "Future Message stores all your messages, voice notes, and video notes locally on your device only. We do not upload, sync, or transmit any of your personal content to any server."
                        )

                        privacySection(
                            title: "No account required",
                            icon: "person.slash",
                            body: "You do not need to create an account, sign in, or provide any personal information to use Future Message. Your messages are anonymous by design."
                        )

                        privacySection(
                            title: "No data shared with third parties",
                            icon: "hand.raised.fill",
                            body: "We do not share, sell, or disclose any data with third parties, advertisers, or analytics providers. Your thoughts are yours alone."
                        )

                        privacySection(
                            title: "Local notifications only",
                            icon: "bell.slash.fill",
                            body: "Notifications are scheduled entirely on your device using iOS's local notification system. We never send push notifications from a server."
                        )

                        privacySection(
                            title: "What happens if you delete the app",
                            icon: "trash",
                            body: "Deleting the app permanently removes all your messages from the device. This cannot be undone. We recommend opening all pending messages before deleting."
                        )

                        privacySection(
                            title: "Camera & Microphone",
                            icon: "mic.and.signal.meter.fill",
                            body: "Camera and microphone access is only used when you choose to record a video or voice note. This data is stored locally and never transmitted."
                        )

                        privacySection(
                            title: "Analytics",
                            icon: "chart.bar.xaxis",
                            body: "We may collect anonymous crash reports through Apple's standard mechanisms to improve stability. This contains no personal data or message content."
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contact")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appText)
                            Text("If you have any questions about this privacy policy, please contact us through the App Store listing.")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.appSubtext)
                                .lineSpacing(4)
                        }

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
        .preferredColorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
    }

    private func privacySection(title: String, icon: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.appAccent)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appText)
            }
            Text(body)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.appSubtext)
                .lineSpacing(5)
        }
    }
}

#Preview { PrivacyPolicyView() }
