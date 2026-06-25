<script setup lang="ts">
const tiers = [
  {
    name: 'Free',
    price: '$0',
    cadence: 'forever',
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
    name: 'Pro',
    price: '$4',
    cadence: 'per month',
    summary: 'One-click Quick Clean, scheduled scans, and per-domain rules — for power users.',
    cta: 'Start Pro trial',
    href: '#download',
    primary: true,
    features: [
      'Everything in Free',
      'One-click Quick Clean',
      'Scheduled background scans',
      'Custom size & inactivity thresholds',
      'Per-domain keep / ignore rules',
      'Exportable audit history'
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
          happen quietly, in the background.
        </p>
      </div>

      <div class="mx-auto mt-14 grid max-w-4xl gap-4 lg:grid-cols-2">
        <article
          v-for="tier in tiers"
          :key="tier.name"
          :class="[
            'flex flex-col gap-6 rounded-2xl border bg-white p-7',
            tier.primary
              ? 'border-ink-900 shadow-[0_1px_0_rgba(15,23,42,0.04),0_24px_60px_-20px_rgba(15,23,42,0.25)]'
              : 'border-ink-200'
          ]"
        >
          <div class="flex items-baseline justify-between">
            <h3 class="text-lg font-semibold tracking-[-0.01em] text-ink-900">
              {{ tier.name }}
            </h3>
            <span
              v-if="tier.primary"
              class="rounded-full bg-ink-900 px-2.5 py-0.5 text-[11px] font-medium text-white"
            >
              Most popular
            </span>
          </div>
          <p class="font-mono text-4xl font-semibold tracking-tight text-ink-900">
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
              'mt-auto',
              tier.primary ? 'btn-primary w-full py-3 text-[14px]' : 'btn-secondary w-full py-3 text-[14px]'
            ]"
          >
            {{ tier.cta }}
          </a>
        </article>
      </div>
    </div>
  </section>
</template>
