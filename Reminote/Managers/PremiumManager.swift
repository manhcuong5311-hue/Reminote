import StoreKit
import Foundation
import Observation

// MARK: - Product IDs
// These MUST match exactly what you configure in App Store Connect.

enum StoreIDs {
    static let yearly   = "com.reminote.premium.yearly"    // Auto-renewable subscription – $2.99/yr
    static let lifetime = "com.reminote.premium.lifetime"  // Non-consumable (one-time)    – $9.99
    static var all: [String] { [yearly, lifetime] }
}

// MARK: - PremiumManager

@Observable
final class PremiumManager {
    static let shared = PremiumManager()

    // MARK: - Observable state

    var isPremium:       Bool    = false
    var isPurchasing:    Bool    = false
    var isLoadingProducts: Bool  = true
    var showPaywall:     Bool    = false
    var purchaseError:   String? = nil
    var activePlanLabel: String  = ""   // "Yearly" | "Lifetime" | ""

    // MARK: - Loaded products (nil until App Store responds)

    var yearlyProduct:   Product?
    var lifetimeProduct: Product?

    // MARK: - Feature gates (single source of truth)

    var canUseVoiceNotes:      Bool { isPremium }
    var canUseVideoNotes:      Bool { isPremium }
    var canUseThemes:          Bool { isPremium }
    var hasUnlimitedMessages:  Bool { isPremium }

    // MARK: - Internal

    private var transactionListener: Task<Void, Never>?

    private init() {
        // Restore cached state for instant UI (will be verified against App Store below)
        isPremium = UserDefaults.standard.bool(forKey: "is_premium")
        activePlanLabel = UserDefaults.standard.string(forKey: "active_plan") ?? ""

        // Long-lived listener for renewals, refunds, billing-issue resolutions
        transactionListener = startTransactionListener()

        Task {
            await loadProducts()
            await verifyEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load products from App Store

    @MainActor
    func loadProducts() async {
        isLoadingProducts = true
        do {
            let products = try await Product.products(for: StoreIDs.all)
            for product in products {
                switch product.id {
                case StoreIDs.yearly:   yearlyProduct   = product
                case StoreIDs.lifetime: lifetimeProduct = product
                default: break
                }
            }
        } catch {
            // Silent — products stay nil; UI shows "unavailable" state
        }
        isLoadingProducts = false
    }

    // MARK: - Purchase

    @MainActor
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await applyTransaction(transaction)
                await transaction.finish()
                showPaywall = false
                isPurchasing = false
                return true

            case .userCancelled:
                isPurchasing = false
                return false

            case .pending:
                // Awaiting parent approval / Ask to Buy
                isPurchasing = false
                return false

            @unknown default:
                isPurchasing = false
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            isPurchasing = false
            return false
        }
    }

    // MARK: - Restore purchases

    @MainActor
    func restore() async -> Bool {
        isPurchasing = true
        purchaseError = nil
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = error.localizedDescription
        }
        await verifyEntitlements()
        isPurchasing = false
        if isPremium { showPaywall = false }
        return isPremium
    }

    // MARK: - Verify current entitlements (runs at launch and after purchase)

    func verifyEntitlements() async {
        var foundActive = false
        var planLabel   = ""

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }

            switch transaction.productID {
            case StoreIDs.lifetime:
                // Non-consumable: once purchased, always valid
                foundActive = true
                planLabel   = "Lifetime"

            case StoreIDs.yearly:
                // Subscription: only valid if not expired
                if let expiry = transaction.expirationDate, expiry > Date() {
                    foundActive = true
                    planLabel   = "Yearly"
                }

            default:
                break
            }

            // Lifetime beats yearly — keep it
            if planLabel == "Lifetime" { break }
        }

        await MainActor.run {
            self.isPremium       = foundActive
            self.activePlanLabel = planLabel
            UserDefaults.standard.set(foundActive, forKey: "is_premium")
            UserDefaults.standard.set(planLabel,   forKey: "active_plan")
        }
    }

    // MARK: - Transaction listener (renewals, refunds, billing recoveries)

    private func startTransactionListener() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try Self.checkVerified(result)
                    await self.applyTransaction(transaction)
                    await transaction.finish()
                } catch {
                    // Verification failed — skip
                }
            }
        }
    }

    // MARK: - Apply a verified transaction to app state

    private func applyTransaction(_ transaction: Transaction) async {
        switch transaction.productID {
        case StoreIDs.lifetime:
            await MainActor.run {
                self.isPremium       = true
                self.activePlanLabel = "Lifetime"
                UserDefaults.standard.set(true,       forKey: "is_premium")
                UserDefaults.standard.set("Lifetime", forKey: "active_plan")
            }

        case StoreIDs.yearly:
            let isActive = transaction.expirationDate.map { $0 > Date() } ?? true
            await MainActor.run {
                self.isPremium       = isActive
                self.activePlanLabel = isActive ? "Yearly" : ""
                UserDefaults.standard.set(isActive,                forKey: "is_premium")
                UserDefaults.standard.set(isActive ? "Yearly" : "", forKey: "active_plan")
            }

        default:
            break
        }
    }

    // MARK: - Verification helper

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }

    // MARK: - Legacy shims (keep existing callers working)

    func unlock() {
        isPremium       = true
        activePlanLabel = "Lifetime"
        showPaywall     = false
        UserDefaults.standard.set(true,       forKey: "is_premium")
        UserDefaults.standard.set("Lifetime", forKey: "active_plan")
    }
}
