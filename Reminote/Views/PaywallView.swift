import SwiftUI
import StoreKit

struct PaywallView: View {
    @Bindable var viewModel: MessageViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var premium    = PremiumManager.shared
    @State private var selectedID = StoreIDs.yearly   // default selection
    @State private var appeared   = false

    private let gold = Color(red: 0.82, green: 0.70, blue: 0.45)

    private let features: [(icon: String, color: Color, text: String, sub: String)] = [
        ("infinity",        Color(red: 0.82, green: 0.70, blue: 0.45), "Unlimited messages",  "No 3-message cap"),
        ("mic.fill",        Color(red: 0.5,  green: 0.8,  blue: 0.6 ), "Voice notes",         "Record audio for your future self"),
        ("video.fill",      Color(red: 0.5,  green: 0.7,  blue: 1.0 ), "Video notes",         "Up to 60 seconds of video"),
        ("paintbrush.fill", Color(red: 0.8,  green: 0.5,  blue: 1.0 ), "Premium themes",      "Soft Light, Midnight Blue, Sunset Ember"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                closeButton.padding(.top, 16).padding(.trailing, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        heroSection
                        featuresSection
                        planPickerSection
                        ctaSection
                        legalText
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            // Retry product load if empty (e.g., paywall opened before products arrived)
            if premium.yearlyProduct == nil && premium.lifetimeProduct == nil {
                Task { await premium.loadProducts() }
            }
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(gold.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "envelope.badge.clock.fill")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(gold)
            }

            VStack(spacing: 10) {
                Text("Your future self deserves\nmore.")
                    .font(.serif(30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Unlock the full Future Message experience.\nNo limits. No compromises.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                if i > 0 { Divider().background(Color.white.opacity(0.06)) }
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(f.color.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: f.icon)
                            .font(.system(size: 15)).foregroundColor(f.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.text).font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                        Text(f.sub).font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(gold)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }

    // MARK: - Plan picker

    private var planPickerSection: some View {
        Group {
            if premium.isLoadingProducts {
                HStack { Spacer(); ProgressView().tint(gold); Spacer() }
                    .frame(height: 110)
            } else if premium.yearlyProduct == nil && premium.lifetimeProduct == nil {
                VStack(spacing: 8) {
                    Text("Could not load products.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    Button("Retry") { Task { await premium.loadProducts() } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(gold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                HStack(spacing: 12) {
                    if let yearly = premium.yearlyProduct {
                        planCard(
                            id: StoreIDs.yearly,
                            price: yearly.displayPrice,
                            period: "/ year",
                            badge: "Best value",
                            note: "Renews annually"
                        )
                    }
                    if let lifetime = premium.lifetimeProduct {
                        planCard(
                            id: StoreIDs.lifetime,
                            price: lifetime.displayPrice,
                            period: "one-time",
                            badge: "Own forever",
                            note: "No subscription"
                        )
                    }
                }
            }
        }
    }

    private func planCard(id: String, price: String, period: String, badge: String, note: String) -> some View {
        let isSelected = selectedID == id
        return Button {
            Haptic.light()
            selectedID = id
        } label: {
            VStack(spacing: 6) {
                Text(badge.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .tracking(0.8)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(gold)
                    .clipShape(Capsule())

                Text(price)
                    .font(.serif(26))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.55))

                Text(period)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .white.opacity(0.3))

                Text(note)
                    .font(.system(size: 10))
                    .foregroundColor(gold.opacity(isSelected ? 1 : 0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? gold.opacity(0.6) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: selectedID)
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 14) {
            // Error message
            if let err = premium.purchaseError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button {
                guard let product = selectedProduct else { return }
                Haptic.success()
                Task {
                    let ok = await premium.purchase(product)
                    if ok { dismiss() }
                }
            } label: {
                Group {
                    if premium.isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text(ctaLabel)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(gold)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(premium.isPurchasing || selectedProduct == nil)

            Button {
                Haptic.light()
                Task { _ = await premium.restore() }
            } label: {
                Text("Restore purchase")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }
            .disabled(premium.isPurchasing)
        }
    }

    // MARK: - Legal

    private var legalText: some View {
        Text(selectedID == StoreIDs.yearly
            ? "Yearly plan auto-renews at \(premium.yearlyProduct?.displayPrice ?? "$2.99"). Cancel anytime in Settings → Apple ID → Subscriptions."
            : "One-time purchase. No subscription. Yours forever.")
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.22))
            .multilineTextAlignment(.center)
    }

    // MARK: - Helpers

    private var selectedProduct: Product? {
        selectedID == StoreIDs.yearly ? premium.yearlyProduct : premium.lifetimeProduct
    }

    private var ctaLabel: String {
        if selectedID == StoreIDs.yearly {
            if let p = premium.yearlyProduct { return "Start Premium — \(p.displayPrice)/yr" }
            return "Start Yearly Premium"
        } else {
            if let p = premium.lifetimeProduct { return "Get Lifetime — \(p.displayPrice)" }
            return "Get Lifetime Access"
        }
    }
}

#Preview { PaywallView(viewModel: MessageViewModel()) }
