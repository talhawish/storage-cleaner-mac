<script setup lang="ts">
const tiers = [
  {
    name: 'Free',
    price: '$0',
    cadence: 'forever',
    note: '',
    summary: 'Full scan, full inventory, full preview. Clean what you want, when you want.',
    cta: 'Download',
    href: '#download',
    primary: false,
    features: [
      'Unlimited read-only scans',
      'All 15+ storage domains',
      'Manual Trash cleanup',
      'Full audit log',
      'macOS 14 Sonoma or later'
    ]
  },
  {
    name: 'Monthly',
    price: '$4.99',
    cadence: 'per month',
    note: 'Billed monthly · cancel anytime',
    summary: 'One-click Quick Clean, scheduled scans, and per-domain rules — pay as you go.',
    cta: 'Start monthly',
    href: '#download',
    primary: false,
    features: [
      'Everything in Free',
      'One-click Quick Clean',
      'Scheduled background scans',
      'Custom size & inactivity thresholds',
      'Per-domain keep / ignore rules',
      'Exportable audit history'
    ]
  },
  {
    name: 'Yearly',
    price: '$29.99',
    cadence: 'per year',
    note: '~50% off vs monthly · most popular',
    summary: 'Full Pro for the price of six months. The plan most working developers pick.',
    cta: 'Start yearly',
    href: '#download',
    primary: true,
    badge: 'Most popular',
    features: [
      'Everything in Monthly',
      'Priority release channel access',
      'Early-access feature flags',
      'Email support within 1 business day',
      'Family Sharing (up to 6 seats)',
      'Locked-in renewal price for life of the subscription'
    ]
  },
  {
    name: 'Lifetime',
    price: '$49.99',
    cadence: 'one-time',
    note: 'Pay once · own it forever',
    summary: 'Every Pro feature, every future update, no subscription. For the indecisive.',
    cta: 'Buy lifetime',
    href: '#download',
    primary: false,
    features: [
      'Everything in Yearly',
      'All future macOS major-version updates',
      'All future Pro features, included',
      'No subscription, no renewals, no upsells',
      'Transferable to a new Mac',
      'Email support within 1 business day'
    ]
  }
] as const
</script>

<template>
  <section id="pricing" class="py-24 sm:py-32">
    <div class="container-page">
      <div class="mx-auto max-w-2xl text-center">
        <span class="eyebrow">Pricing</span>
        <h2 class="heading-section mt-4 text-balance">
          Free forever, Pro when you need it.
        </h2>
        <p class="lede mt-4 text-pretty">
          The scanner and inventory are unrestricted. Pro unlocks the
          automation and policy tools for developers who want cleaning to
          happen quietly, in the background. Pick the plan that fits — or
          pay once and never think about it again.
        </p>
      </div>

      <div class="mx-auto mt-14 grid max-w-6xl gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <article
          v-for="tier in tiers"
          :key="tier.name"
          :class="[
            'relative flex flex-col gap-6 rounded-2xl border bg-white p-6',
            tier.primary
              ? 'border-ink-900 shadow-[0_1px_0_rgba(15,23,42,0.04),0_24px_60px_-20px_rgba(15,23,42,0.25)]'
              : 'border-ink-200'
          ]"
        >
          <span
            v-if="tier.badge"
            class="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-ink-900 px-2.5 py-0.5 text-[11px] font-medium text-white"
          >
            {{ tier.badge }}
          </span>
          <div>
            <h3 class="text-base font-semibold tracking-[-0.01em] text-ink-900">
              {{ tier.name }}
            </h3>
            <p v-if="tier.note" class="mt-1 text-[11px] font-medium text-ink-500">
              {{ tier.note }}
            </p>
          </div>
          <p class="font-mono text-3xl font-semibold tracking-tight text-ink-900 sm:text-4xl">
            {{ tier.price }}
            <span class="ml-1 text-sm font-normal text-ink-500">{{ tier.cadence }}</span>
          </p>
          <p class="text-sm leading-relaxed text-ink-600">{{ tier.summary }}</p>
          <ul class="space-y-2.5 text-sm text-ink-700">
            <li v-for="feature in tier.features" :key="feature" class="flex items-start gap-2.5">
              <svg viewBox="0 0 20 20" class="mt-0.5 size-4 shrink-0 text-emerald-600" aria-hidden="true">
                <path
                  fill="currentColor"
                  d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0L3.3 9.7a1 1 0 0 1 1.4-1.4l3.8 3.8 6.8-6.8a1 1 0 0 1 1.4 0Z"
                />
              </svg>
              <span>{{ feature }}</span>
            </li>
          </ul>
          <a
            :href="tier.href"
            :class="[
              'mt-auto w-full shrink-0',
              tier.primary ? 'btn-primary py-2.5 text-[13px]' : 'btn-secondary py-2.5 text-[13px]'
            ]"
          >
            {{ tier.cta }}
          </a>
        </article>
      </div>

      <p class="mx-auto mt-8 max-w-3xl text-center text-xs text-ink-500">
        Prices in USD. Subscriptions are billed through the Mac App Store and
        can be managed or cancelled in System Settings → Apple ID → Subscriptions.
        Refunds are handled by Apple in accordance with their policies.
      </p>
    </div>
  </section>
</template>
