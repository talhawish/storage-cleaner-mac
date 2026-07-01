import Foundation
import Observation

@MainActor
@Observable
final class PaywallViewModel {
    enum Banner: Equatable {
        case none
        case success(message: String)
        case error(message: String)
        case info(message: String)
    }

    private(set) var purchasingProductID: String?
    private(set) var restoring: Bool = false
    private(set) var plans: [SubscriptionPlan] = []
    private(set) var currentEntitlement: SubscriptionEntitlement = .free
    private(set) var banner: Banner = .none
    private(set) var isLoadingProducts = true
    private(set) var highlightedPlanID: String = SubscriptionProductID.yearly

    private let service: any SubscriptionService
    private let onEntitlementUpgraded: (@MainActor () -> Void)?
    private var entitlementTask: Task<Void, Never>?
    private var hasReceivedInitialEntitlement = false

    init(
        service: any SubscriptionService,
        onEntitlementUpgraded: (@MainActor () -> Void)? = nil
    ) {
        self.service = service
        self.onEntitlementUpgraded = onEntitlementUpgraded
        subscribeToEntitlementStream()
    }

    // MARK: - Lifecycle

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loadedPlans = try await service.loadProducts()
            plans = loadedPlans.sorted { lhs, rhs in
                let leftIndex = SubscriptionProductID.all.firstIndex(of: lhs.id) ?? .max
                let rightIndex = SubscriptionProductID.all.firstIndex(of: rhs.id) ?? .max
                return leftIndex < rightIndex
            }
            highlightedPlanID = plans.contains { $0.id == SubscriptionProductID.yearly }
                ? SubscriptionProductID.yearly
                : (plans.first?.id ?? SubscriptionProductID.yearly)
        } catch {
            banner = .error(
                message: error.localizedDescription
            )
        }
    }

    func purchase(productID: String) async {
        guard purchasingProductID == nil else { return }
        purchasingProductID = productID
        banner = .none
        defer { purchasingProductID = nil }

        do {
            let outcome = try await service.purchase(productID: productID)
            switch outcome {
            case .purchased(let entitlement):
                currentEntitlement = entitlement
                banner = .success(message: successMessage(for: entitlement))
                onEntitlementUpgraded?()
            case .pending:
                banner = .info(
                    message: "Your purchase is pending approval. We'll unlock Pro once it's confirmed."
                )
            case .cancelled:
                banner = .info(message: "Purchase cancelled.")
            }
        } catch SubscriptionServiceError.purchaseCancelled {
            banner = .info(message: "Purchase cancelled.")
        } catch let error as SubscriptionServiceError {
            banner = .error(message: error.errorDescription ?? "Something went wrong.")
        } catch {
            banner = .error(message: error.localizedDescription)
        }
    }

    func restore() async {
        guard !restoring else { return }
        restoring = true
        banner = .none
        defer { restoring = false }

        do {
            let entitlement = try await service.restore()
            currentEntitlement = entitlement
            if entitlement == .free {
                banner = .info(
                    message: "No previous purchases found on this Apple ID."
                )
            } else {
                banner = .success(message: successMessage(for: entitlement))
                onEntitlementUpgraded?()
            }
        } catch let error as SubscriptionServiceError {
            banner = .error(message: error.errorDescription ?? "Couldn't restore purchases.")
        } catch {
            banner = .error(message: error.localizedDescription)
        }
    }

    func clearBanner() {
        banner = .none
    }

    var shouldAutoDismissOnPurchase: Bool {
        currentEntitlement == .free
    }

    // MARK: - Stream

    private func subscribeToEntitlementStream() {
        entitlementTask?.cancel()
        let stream = service.entitlementUpdates()
        entitlementTask = Task { [weak self] in
            for await entitlement in stream {
                guard let self else { return }
                let previous = self.currentEntitlement
                self.currentEntitlement = entitlement

                guard self.hasReceivedInitialEntitlement else {
                    self.hasReceivedInitialEntitlement = true
                    continue
                }

                guard entitlement != previous, entitlement != .free else { continue }

                self.banner = .success(message: self.successMessage(for: entitlement))
                if self.shouldAutoDismissOnPurchase {
                    self.onEntitlementUpgraded?()
                }
            }
        }
    }

    private func successMessage(for entitlement: SubscriptionEntitlement) -> String {
        switch entitlement {
        case .free: ""
        case .monthly: "Storage Cleaner Pro (Monthly) is now active. Thanks!"
        case .yearly: "Storage Cleaner Pro (Yearly) is now active. Thanks!"
        case .lifetime: "Storage Cleaner Pro (Lifetime) is now active. Thanks!"
        }
    }
}
