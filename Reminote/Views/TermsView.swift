import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Terms of Use")
                                .font(.serif(28))
                                .foregroundColor(.appText)
                            Text("Last updated: March 2026")
                                .font(.system(size: 13))
                                .foregroundColor(.appHint)
                        }

                        Divider().background(Color.appBorder)

                        termSection(
                            number: "1",
                            title: "Acceptance",
                            body: "By using Future Message, you agree to these terms. If you do not agree, please do not use the app."
                        )

                        termSection(
                            number: "2",
                            title: "License",
                            body: "Future Message grants you a personal, non-transferable license to use the app on Apple devices you own or control, subject to the App Store Terms of Service."
                        )

                        termSection(
                            number: "3",
                            title: "User Content",
                            body: "You own all messages, notes, and recordings you create. You are responsible for the content you store. We cannot access it, and we do not take responsibility for it."
                        )

                        termSection(
                            number: "4",
                            title: "Subscriptions",
                            body: "Premium subscriptions are billed through the App Store. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings → Apple ID → Subscriptions."
                        )

                        termSection(
                            number: "5",
                            title: "No Warranty",
                            body: "The app is provided \"as is\" without warranties of any kind. We do not guarantee uninterrupted availability or that all features will function error-free at all times."
                        )

                        termSection(
                            number: "6",
                            title: "Limitation of Liability",
                            body: "To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages arising from your use of the app, including loss of message content."
                        )

                        termSection(
                            number: "7",
                            title: "Apple EULA",
                            body: "Your use of Future Message is also subject to Apple's standard End User License Agreement for App Store apps."
                        )

                        // Apple EULA link
                        Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                            HStack(spacing: 8) {
                                Text("Apple Standard EULA")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appAccent)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appAccent)
                            }
                        }

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Terms of Use")
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

    private func termSection(number: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number + ".")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appAccent)
                    .frame(width: 18, alignment: .leading)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appText)
            }
            Text(body)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.appSubtext)
                .lineSpacing(5)
                .padding(.leading, 26)
        }
    }
}

#Preview { TermsView() }
