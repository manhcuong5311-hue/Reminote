import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<Int> = []

    private let items: [(q: String, a: String)] = [
        (
            "What is Future Message?",
            "Future Message is a private time capsule for your thoughts. Write a message to yourself, lock it, and it opens on a date you choose — delivering a piece of your past back to you."
        ),
        (
            "Can I edit a message after locking it?",
            "No. Once locked, a message cannot be edited or deleted until opened. This is intentional — the authenticity of your past words is what makes opening them meaningful."
        ),
        (
            "Are my messages private?",
            "Yes, completely. Your messages are stored only on your device. No account is required. Nothing is sent to any server. Only you can read what you write."
        ),
        (
            "What happens if I delete the app?",
            "Your messages are stored in your device's local storage. Deleting the app will permanently delete your messages. We recommend keeping the app installed until your messages have been opened."
        ),
        (
            "What does Premium unlock?",
            "Premium removes the 3-message limit, unlocks voice and video notes, and gives access to all themes. It's a one-time way to support the app and invest in your future self."
        ),
        (
            "What if I forget I have messages?",
            "You won't — the app sends you a notification the moment a message is ready to open. You can also set weekly reminders in Notification Settings."
        ),
        (
            "Can I share a message with someone?",
            "You can share the moment of reading a message — a beautiful image card is generated that you can post or send to friends. The original message stays private."
        ),
        (
            "Is my voice or video note private too?",
            "Yes. All media is stored locally on your device, just like your text messages. Nothing leaves your phone."
        )
    ]

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

                        VStack(spacing: 1) {
                            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                                FAQItem(
                                    index: i,
                                    question: item.q,
                                    answer: item.a,
                                    isExpanded: expanded.contains(i)
                                ) {
                                    Haptic.light()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        if expanded.contains(i) { expanded.remove(i) }
                                        else { expanded.insert(i) }
                                    }
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.appBorder, lineWidth: 0.5)
                        )
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 60)
                    }
                }
            }
            .navigationTitle("FAQ")
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequently Asked\nQuestions")
                .font(.serif(28))
                .foregroundColor(.appText)
                .lineSpacing(4)
            Text("Everything you need to know about Future Message.")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.appSubtext)
        }
    }
}

struct FAQItem: View {
    let index: Int
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if index > 0 {
                Divider()
                    .background(Color.appBorder)
            }

            Button(action: onTap) {
                HStack(spacing: 14) {
                    Text(question)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appAccent)
                        .frame(width: 20)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }

            if isExpanded {
                Text(answer)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.appSubtext)
                    .lineSpacing(4)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.appSurface)
    }
}

#Preview {
    FAQView()
}
