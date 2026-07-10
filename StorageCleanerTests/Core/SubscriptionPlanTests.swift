import XCTest
@testable import StorageCleaner

final class SubscriptionPlanTests: XCTestCase {
    func testBillingDescriptionsDoNotHardCodeStorefrontPrices() {
        XCTAssertEqual(makePlan(period: .monthly).billingDescription, "Billed monthly")
        XCTAssertEqual(makePlan(period: .yearly).billingDescription, "Billed annually")
        XCTAssertEqual(makePlan(period: .lifetime).billingDescription, "One-time purchase")
        XCTAssertEqual(makePlan(period: nil).billingDescription, "")
    }

    func testAutoRenewalDisclosureIncludesRequiredCancellationTerms() {
        let disclosure = SubscriptionDisclosure.autoRenewal

        XCTAssertTrue(disclosure.contains("automatically renew"))
        XCTAssertTrue(disclosure.contains("24 hours"))
        XCTAssertTrue(disclosure.contains("Manage or cancel"))
        XCTAssertTrue(disclosure.contains("Apple ID"))
    }

    private func makePlan(period: SubscriptionPlan.BillingPeriod?) -> SubscriptionPlan {
        SubscriptionPlan(
            id: "test-plan",
            entitlement: .free,
            displayName: "Test Plan",
            description: "Test description",
            displayPrice: "Localized price",
            period: period
        )
    }
}
