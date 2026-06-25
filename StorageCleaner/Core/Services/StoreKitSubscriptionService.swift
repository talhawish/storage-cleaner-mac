import AppKit
import Foundation
import StoreKit

/// The production `SubscriptionService`, backed by StoreKit 2.
///
/// Architecture: the actor protects all mutable state (cached products,
/// the latest entitlement, the fan-out list of stream continuations).
/// The single `Task` started in `init` listens to StoreKit's
/// `Transaction.updates` for the lifetime of the process — that's the
/// only way the app learns about renewals, refunds, Ask-to-Buy
/// approvals, and Family Sharing revocations without polling.
///
/// `showManageSubscriptions()` is the only MainActor-isolated member
/// because it hands control to AppKit's subscription management sheet
/// (App Review guideline 3.1.2 requires that auto-renewing subscribers
/// be able to manage their subscription in one tap).
actor StoreKitSubscriptionService: SubscriptionService {
    private var continuations: [UUID: AsyncStream<SubscriptionEntitlement>.Continuation] = [:]
    private var current: SubscriptionEntitlement = .free
    private var cachedProducts: [String: Product] = [:]
    private var transactionListener: Task<Void, Never>?
    private var didStartListener = false

    init() {}

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Lifecycle

    /// Idempotent. Starts the background `Transaction.updates` listener
    /// exactly once for the lifetime of the service. Safe to call from
    /// any number of consumers — duplicates are guarded.
    func startIfNeeded() async {
        guard !didStartListener else { return }
        didStartListener = true
        await refreshEntitlementFromCurrentEntitlements()
        startTransactionListener()
    }

    private func startTransactionListener() {
        transactionListener?.cancel()
        transactionListener = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: update)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let txn):
            await txn.finish()
            await refreshEntitlementFromCurrentEntitlements()
        case .unverified:
            // Keep the existing entitlement. Failing verification on a
            // single transaction shouldn't downgrade a user who's been
            // happily subscribed.
            break
        }
    }

    /// Re-reads `Transaction.currentEntitlements` and picks the "best"
    /// of any active subscriptions. Picks the lifetime product over
    /// yearly over monthly so an active Pro user who happens to have
    /// both never gets downgraded by a UI bug.
    private func refreshEntitlementFromCurrentEntitlements() async {
        var best: SubscriptionEntitlement = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            guard let ent = SubscriptionEntitlement.from(productID: txn.productID) else { continue }
            if priority(ent) > priority(best) {
                best = ent
            }
        }
        setEntitlement(best)
    }

    private func priority(_ entitlement: SubscriptionEntitlement) -> Int {
        switch entitlement {
        case .free: 0
        case .monthly: 1
        case .yearly: 2
        case .lifetime: 3
        }
    }

    private func setEntitlement(_ new: SubscriptionEntitlement) {
        guard new != current else { return }
        current = new
        for continuation in continuations.values {
            continuation.yield(new)
        }
    }

    // MARK: - SubscriptionService

    func currentEntitlement() async -> SubscriptionEntitlement {
        await startIfNeeded()
        return current
    }

    nonisolated func entitlementUpdates() -> AsyncStream<SubscriptionEntitlement> {
        AsyncStream { continuation in
            let id = UUID()
            // Seed the stream with the current entitlement so callers
            // don't have to call `currentEntitlement()` separately.
            Task { [weak self] in
                guard let self else {
                    continuation.yield(.free)
                    continuation.finish()
                    return
                }
                await self.startIfNeeded()
                let current = await self.current
                continuation.yield(current)
                await self.register(continuation: continuation, id: id)
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(
        continuation: AsyncStream<SubscriptionEntitlement>.Continuation,
        id: UUID
    ) {
        continuations[id] = continuation
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    func loadProducts() async throws -> [SubscriptionPlan] {
        await startIfNeeded()
        let storeProducts = try await Product.products(for: SubscriptionProductID.all)
        cachedProducts = Dictionary(
            uniqueKeysWithValues: storeProducts.map { ($0.id, $0) }
        )
        return storeProducts
            .sorted(by: Self.productOrdering)
            .map(plan(from:))
    }

    /// Stable sort order matching `SubscriptionProductID.all` so the
    /// paywall renders Monthly → Yearly → Lifetime regardless of the
    /// order StoreKit returns.
    private static func productOrdering(_ lhs: Product, _ rhs: Product) -> Bool {
        let leftIndex = SubscriptionProductID.all.firstIndex(of: lhs.id) ?? .max
        let rightIndex = SubscriptionProductID.all.firstIndex(of: rhs.id) ?? .max
        return leftIndex < rightIndex
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        await startIfNeeded()
        let product = try await resolveProduct(forID: productID)
        let result = try await runPurchase(on: product)
        return try await handle(result: result, productID: productID)
    }

    /// Resolves a `Product` for the given id, preferring the
    /// in-memory cache and falling back to a fresh StoreKit fetch.
    /// Extracted from `purchase(productID:)` to keep that function
    /// under SwiftLint's complexity threshold.
    private func resolveProduct(forID productID: String) async throws -> Product {
        if let cached = cachedProducts[productID] {
            return cached
        }
        do {
            let fresh = try await Product.products(for: [productID])
            guard let match = fresh.first else {
                throw SubscriptionServiceError.productNotFound(productID: productID)
            }
            return match
        } catch let error as SubscriptionServiceError {
            throw error
        } catch {
            throw SubscriptionServiceError.purchaseFailed(message: error.localizedDescription)
        }
    }

    private func runPurchase(on product: Product) async throws -> Product.PurchaseResult {
        do {
            return try await product.purchase()
        } catch {
            throw SubscriptionServiceError.purchaseFailed(message: error.localizedDescription)
        }
    }

    private func handle(
        result: Product.PurchaseResult,
        productID: String
    ) async throws -> PurchaseOutcome {
        switch result {
        case .success(let verification):
            return try await handleVerification(verification, productID: productID)
        case .userCancelled:
            throw SubscriptionServiceError.purchaseCancelled
        case .pending:
            return .pending
        @unknown default:
            throw SubscriptionServiceError.purchaseFailed(
                message: "Unknown purchase result"
            )
        }
    }

    private func handleVerification(
        _ verification: VerificationResult<Transaction>,
        productID: String
    ) async throws -> PurchaseOutcome {
        switch verification {
        case .verified(let txn):
            await txn.finish()
            let entitlement = SubscriptionEntitlement.from(productID: productID) ?? .lifetime
            setEntitlement(entitlement)
            return .purchased(entitlement)
        case .unverified:
            throw SubscriptionServiceError.verificationFailed
        }
    }

    func restore() async throws -> SubscriptionEntitlement {
        await startIfNeeded()
        do {
            try await AppStore.sync()
        } catch {
            throw SubscriptionServiceError.restoreFailed(message: error.localizedDescription)
        }
        await refreshEntitlementFromCurrentEntitlements()
        return current
    }

    @MainActor
    func showManageSubscriptions() {
        // macOS has no public AppKit API for "open subscription
        // management" — `AppStore.showManageSubscriptions(in:)` is
        // iOS-only (takes a `UIWindowScene`). Apple's recommended
        // macOS pattern is to deep-link the App Store's own
        // subscription management URL, which the App Store app
        // intercepts and opens in-place.
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Plan mapping

    private func plan(from product: Product) -> SubscriptionPlan {
        let entitlement = SubscriptionEntitlement.from(productID: product.id) ?? .lifetime
        let period: SubscriptionPlan.BillingPeriod? = switch entitlement {
        case .monthly: .monthly
        case .yearly: .yearly
        case .lifetime: .lifetime
        case .free: nil
        }
        return SubscriptionPlan(
            id: product.id,
            entitlement: entitlement,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            period: period
        )
    }
}
