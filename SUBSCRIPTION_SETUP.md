# Subscription Setup Guide

Step-by-step walkthrough for wiring **Storage Cleaner Pro** subscriptions to
the App Store, configuring the project, and validating everything end-to-end
before the first paid release.

> **TL;DR** — Create 3 IAPs in App Store Connect with the exact product IDs
> below, attach `StorageCleanerPro.storekit` to your scheme, update
> `AppLinks`, then ship a TestFlight build to a sandbox account.

---

## 1. App Store Connect setup

Sign in to [App Store Connect](https://appstoreconnect.apple.com) with the
account that owns the **Storage Cleaner** app record.

### 1.1 Paid Applications Agreement (one-time)

The App Store won't let you create a paid IAP until your team has an active
**Paid Applications Agreement** with banking and tax info on file.

1. **App Store Connect → Agreements, Tax, and Banking**
2. If the agreement is missing, click **Request Contracts** and accept the
   **Paid Applications** agreement.
3. Fill in **Bank Info** (where Apple sends your payouts) and **Tax Info**
   (W-8BEN/W-8BEN-E for non-US entities). Without these, your IAPs sit in
   "Missing Info" status forever.

This is the #1 reason "I created the IAP but it won't submit" — verify the
status reads **Active** before you do anything else.

### 1.2 Create the subscription group

A subscription group is a logical bundle for all your auto-renewing
products. It also enables features like **Manage Subscriptions** grouping
in the App Store UI.

1. **App Store Connect → My Apps → Storage Cleaner**
2. In the left sidebar, under **Monetization**, click **Subscriptions**
3. Click **Create Subscription Group**
4. **Reference name** (internal only): `Pro`
5. **Display name** (shown in App Store / system Settings): `Storage Cleaner Pro`
6. Save

> You only need one group. Monthly + Yearly live in it; Lifetime is a
> non-consumable and is created separately in **In-App Purchases** (§1.4).

### 1.3 Create the two auto-renewable subscriptions

For each of the following, click **Create Subscription** in the group you
just made and fill in **every** field below. Apple rejects apps that leave
required metadata blank.

| Field                  | Monthly                         | Yearly                           |
| ---------------------- | ------------------------------- | -------------------------------- |
| **Product ID**         | `com.storagecleaner.developer.pro.monthly` | `com.storagecleaner.developer.pro.yearly` |
| **Reference name**     | `Pro Monthly`                   | `Pro Yearly`                     |
| **Subscription Period**| `1 month`                       | `1 year`                         |
| **Subscription Price** | Tier 5 → **$4.99** (USD)        | Tier 30 → **$29.99** (USD)       |

Per locale you support, also fill in:

- **Display name** — e.g. "Storage Cleaner Pro · Monthly"
- **Description** — short marketing line (≤85 chars)
- **App Store promotion image** (optional) — 1024×1024 PNG, no text
- **Review information** — one screenshot showing the paywall + a demo
  sandbox account in TestFlight that the reviewer can use. **Without
  this, review is delayed or rejected.**

### 1.4 Create the Lifetime non-consumable

A lifetime "one-time" purchase is **not** a subscription — it's a
non-consumable IAP.

1. **App Store Connect → My Apps → Storage Cleaner → In-App Purchases**
2. **Create In-App Purchase** → **Non-Consumable**
3. **Product ID**: `com.storagecleaner.developer.pro.lifetime`
4. **Reference name**: `Pro Lifetime`
5. **Price**: Tier 50 → **$49.99** (USD)
6. **Display name** + **Description** (per locale)
7. **App Store promotion image** (optional)
8. **Review screenshot** + **Review notes**

> Lifetime IAPs *do not auto-renew*, *do not show in the Manage
> Subscriptions list*, and *are eligible for Family Sharing* (we have it
> off above — turn it on in step 5 if you want families to share Pro
> access).

### 1.5 Set up Family Sharing (optional)

For each product, in the **Subscription Prices** / **In-App Purchase**
detail page, toggle **Family Sharing** on or off. We default to **off**
so each user gets their own Pro entitlement.

### 1.6 Localization

If you ship in multiple storefronts, add localized **display names** and
**descriptions** for each. The app reads these via StoreKit
(`product.displayName`, `product.description`, `product.displayPrice`) and
shows them directly in the paywall — so pricing appears in the user's
local currency automatically.

Recommended first wave of locales: **en-US, en-GB, de-DE, fr-FR, es-ES,
ja, zh-Hans**. App Store Connect will suggest prices for each tier per
storefront.

### 1.7 Submit for review (just the IAPs)

You don't need a full app submission — IAPs are reviewed **independently**
and you can submit them ahead of the app binary so they're "ready" when
the app goes up.

1. Select the IAP → **Submit for Review**
2. Repeat for all 3 products
3. Wait for status: **Ready to Submit** (this is the state you need
   before you can buy it in sandbox — see §3)

---

## 2. Project configuration

### 2.1 Update `AppLinks`

The paywall's Terms of Service and Privacy Policy links are required by
App Review. Open `StorageCleaner/Core/Models/AppLinks.swift` and replace
the placeholder URLs with your real ones:

```swift
static let terms = URL(string: "https://your-domain.com/terms")!
static let privacy = URL(string: "https://your-domain.com/privacy")!
```

These URLs must:

- Be publicly reachable (no auth wall, no "coming soon").
- Host your actual legal copy. Apple has rejected apps that point to
  generic landing pages.
- Be served over HTTPS.

### 2.2 Attach the StoreKit configuration to your scheme

The bundled `StorageCleaner/Resources/StorageCleanerPro.storekit` file
defines all 3 products locally so you can test purchases in the
debugger without an App Store Connect account.

1. Open the project in Xcode
2. **Product → Scheme → Edit Scheme…**
3. Select **Run** (left sidebar)
4. **Options** tab
5. **StoreKit Configuration** → **Choose…** → `StorageCleanerPro.storekit`
6. Close the scheme editor

> Repeat for the **Test** scheme if you want UI tests to use the
> configuration. UI tests currently use the live `StoreKitSubscriptionService`
> against the configuration — no test code changes needed.

### 2.3 Bundle ID and capability

No entitlements change is required for StoreKit 2 — it's an entirely
software-based API. The existing app-sandbox + bookmarks in
`StorageCleaner.entitlements` are fine.

If you change your bundle ID in the future, update the three product IDs
in `StorageCleaner/Core/Models/SubscriptionEntitlement.swift` to match.

### 2.4 Add a "Privacy Choices" entry (optional but recommended)

Apple now requires apps with auto-renewing subscriptions to expose a way
to manage the subscription. We already do this via
**Settings → Manage Subscription** (which opens the App Store's
management URL). To go further, add a `NSAppTransportSecurity` exception
if you ever host the terms page on a custom domain with HSTS quirks —
usually not needed.

---

## 3. Testing

There are three test paths. Use them in this order.

### 3.1 Local (debugger + .storekit file)

The fastest feedback loop. No Apple account, no network, no sandbox.

1. Make sure `StorageCleanerPro.storekit` is attached to the Run scheme
   (§2.2).
2. **Run** the app in Xcode (⌘R)
3. Click any cleanup action — the paywall appears
4. Click **Start Yearly** — a fake StoreKit sheet confirms the purchase
5. The app immediately reflects the new entitlement
6. To reset: in Xcode menu → **Debug → StoreKit → Reset Configuration**
   (or relaunch)

You can also use the **Editor → Manage Transactions** window to force
refunds, ask-to-buy pending states, or revoked entitlements — useful for
exercising the error banners.

### 3.2 Sandbox (TestFlight + real App Store Connect)

The path that validates your ASC config is real.

#### Create a sandbox tester

1. **App Store Connect → Users and Access → Sandbox → Testers**
2. Click **+** to add a new tester
3. Use a **real** email you control but **that has never been associated
   with an Apple ID** (Apple's "must be virgin" rule — if the email is
   already a customer of anything in the App Store, it won't work as
   sandbox).
4. Don't sign in to the App Store with that account yet — you'll be
   prompted to do so during the test purchase on device.

#### Submit your app to TestFlight

1. Bump the build number, archive, and **Distribute App → TestFlight**
2. Once processing finishes, add yourself (the sandbox tester) under
   **Internal Testing**
3. Open the TestFlight app on the same Mac, install the build

#### Trigger a sandbox purchase

1. Sign out of the App Store in **System Settings → Media & App Store**
   (the *Media* section, not the iCloud one — on macOS 14 the entry is
   under Apple ID in App Store preferences)
2. Run your build from TestFlight (or open it in Xcode with a sandbox
   entitlement)
3. When the StoreKit sheet appears, sign in with the sandbox account
4. Confirm — Apple shows a "SANDBOX" banner above the confirmation so
   you know it's not a real charge
5. The app picks up the entitlement via `Transaction.updates`

#### Reset sandbox state

Sandbox subscriptions auto-renew **much faster** than production
(3 minutes for monthly, 3 minutes for yearly) so you can validate
renewal → expiration flows in one coffee break. To force an expiration
mid-test:

1. **App Store Connect → My Apps → Storage Cleaner → Subscriptions**
2. Find the active sandbox subscription
3. Use **Cancel Subscription** in the Sandbox Tester menu

### 3.3 TestFlight (internal team / real testers)

Same as §3.2 but distributed via **External TestFlight** to anyone on
your team. They'll need their own sandbox accounts. The paywall flow
is identical.

### 3.4 UI tests

The `StorageCleanerUITests` target runs with the `--use-demo-scanner`
flag, which puts the app in offline mode but **still uses the real
`StoreKitSubscriptionService`**. As long as you've attached the
`.storekit` configuration to the **Test** scheme (§2.2), UI tests can
drive purchases and the paywall will react correctly.

To make a test simulate a successful purchase:

```swift
let app = XCUIApplication()
app.launchArguments += ["--use-demo-scanner"]
app.launch()
// Paywall appears after any cleanup attempt
app.buttons["paywall-restore-purchases"].tap() // (restore from .storekit)
```

---

## 4. App Review checklist

Apple's review for an app with subscriptions looks at three things in
addition to the normal app review. Make sure all of these are in place
**before** you submit the binary:

- [ ] **Paywall has clear pricing.** Each plan card shows the localized
      price (e.g. "$4.99", "€4,99") and the billing period ("/ month").
- [ ] **Auto-renew disclosure is visible.** We render this in
      `PaywallView.autoRenewDisclosure`:
      "Subscriptions renew automatically until cancelled in App Store
      Settings." (App Review guideline 3.1.2)
- [ ] **Link to Terms of Service and Privacy Policy in the paywall.**
      We have this in `PaywallFooterBar` and both URLs are reachable.
- [ ] **Link to Manage Subscriptions for active subscribers.** We have
      this in `SubscriptionSettingsSection` — opens
      `https://apps.apple.com/account/subscriptions`.
- [ ] **Restore Purchases is available without purchase.** Visible at
      the bottom of every paywall presentation.
- [ ] **No "free trial" claims unless the product has an introductory
      offer configured** in App Store Connect. We currently don't.
- [ ] **Subscription group exists and all products are inside it.**
      Lifetime is a non-consumable and lives in **In-App Purchases**,
      not the subscription group — that's expected.
- [ ] **Review screenshots show the paywall** with the prices in the
      correct storefront currency.
- [ ] **Sandbox demo account credentials** in the **Review Notes**
      field of the App Store version. Even if the sandbox tester is
      obvious, fill this in.

---

## 5. Going live

Once everything is green:

1. **Archive the app** with the production scheme (`.storekit` config
   removed from the scheme if you want to be doubly sure no test
   products slip through)
2. **Submit to App Review** with the IAPs attached
3. After approval, the IAPs move from **Ready to Submit** to **Approved**
   automatically — no separate step
4. Users can now buy Pro

After launch, monitor:

- **App Store Connect → Sales and Trends** for daily revenue
- **App Store Connect → Subscriptions → Retention** for churn by
  cohort
- **Crash logs** for `StoreKit` errors — we map them all to
  `SubscriptionServiceError` for easy filtering

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Products don't load in the paywall | Product not in "Ready to Submit" status, or bundle ID mismatch | Verify product IDs in §1.3 / §1.4 match the live service, ensure status is **Ready to Submit** |
| `purchase(productID:)` returns `.notFound` | App Store Connect hasn't published the product yet to the user's storefront | Wait 24h after submission, or add the storefront in App Store Connect |
| Purchase succeeds but entitlement doesn't update | `Transaction.updates` not being observed | Verify the app isn't terminating; the actor starts the listener on first use. Cold-launch the app and try again |
| "Missing Info" badge in ASC | Paid Applications Agreement not signed or banking missing | §1.1 |
| `AppStore.showManageSubscriptions` doesn't compile | That API is iOS-only (takes `UIWindowScene`) | Our macOS fallback opens the URL — already handled in `StoreKitSubscriptionService.showManageSubscriptions()` |
| `force_unwrapping` SwiftLint error in `AppLinks` | `URL(string:)!` | The URLs are placeholders — replace with your own; the force-unwrap is intentional to crash early in dev if the URL is malformed |
| Sandbox "Cannot connect to iTunes Store" | Signed-in Apple ID is not a sandbox account, or you forgot to sign out of your real account first | Sign out of System Settings → Media & App Store, then sign in with the sandbox tester when prompted by the StoreKit sheet |
| Restore Purchases returns nothing on a device that has a subscription | The StoreKit transaction history on the device is empty (sandbox reset, restored from backup, etc.) | Sign in to the App Store with the same Apple ID that bought the subscription; the transaction lives in iCloud |

---

## File map

Everything the implementation needs to know about your products:

- `StorageCleaner/Core/Models/SubscriptionEntitlement.swift` —
  product IDs and entitlement enum
- `StorageCleaner/Core/Models/AppLinks.swift` — Terms + Privacy URLs
- `StorageCleaner/Core/Services/SubscriptionService.swift` —
  protocol, errors, plan model
- `StorageCleaner/Core/Services/StoreKitSubscriptionService.swift` —
  live StoreKit 2 implementation
- `StorageCleaner/Resources/StorageCleanerPro.storekit` — local
  development configuration
- `StorageCleaner/Features/Paywall/` — paywall UI
- `StorageCleaner/Features/Settings/SubscriptionSettingsSection.swift` —
  current plan + manage + upgrade
- `StorageCleanerTests/Core/MockSubscriptionService.swift` — test
  double for unit tests
