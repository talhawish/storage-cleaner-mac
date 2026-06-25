<script setup lang="ts">
usePageSeo({
  title: 'Privacy Policy',
  description:
    'How Storage Cleaner for Developers handles your data: what we collect (nothing), what we don\u2019t, and your rights.',
  image: '/og-image-privacy.png',
  path: '/privacy'
})

const contactEmail = useSiteConfig().email
const updated = '2026-01-15'

const sections = [
  {
    title: 'The short version',
    body: [
      'Storage Cleaner for Developers is built around a simple principle: the files on your Mac are yours. The App performs all scanning, analysis, and cleanup locally on your device. We do not collect, transmit, or sell your personal data.'
    ]
  },
  {
    title: '1. Data we do not collect',
    body: [
      'The App does not collect, store, or transmit the contents of your files, your file paths, your filenames, your scan results, your device identifiers, your IP address, your location, or any analytics events.',
      'We do not use third-party analytics, crash reporting, advertising SDKs, or tracking pixels of any kind.'
    ]
  },
  {
    title: '2. Data stored locally on your Mac',
    body: [
      'The App stores the following data on your device, inside its sandbox:',
      '· SwiftData history of scans, findings, and cleanup audit records.',
      '· Your preferences (thresholds, ignore rules, scheduled scan settings).',
      'You can clear this data at any time from Settings → Reset. Uninstalling the App removes it entirely.'
    ]
  },
  {
    title: '3. macOS permissions',
    body: [
      'The App requests the minimum permissions needed to function. These permissions are managed by macOS, not by us:',
      '· Full Disk Access — required to inventory protected developer folders (Xcode, sim runtimes, etc.).',
      '· Automation (AppleScript) — used to invoke xcrun simctl runtime delete when you choose to remove an Apple simulator runtime.',
      'No permission is used to access or transmit data off your device.'
    ]
  },
  {
    title: '4. In-app purchases',
    body: [
      'Pro subscriptions are processed by Apple via the Mac App Store. Apple shares with us a non-personal entitlement flag (active / inactive / expiry date) so the App can unlock Pro features. We do not receive your name, email, or payment details.'
    ]
  },
  {
    title: '5. Crash reports',
    body: [
      `The App does not include an automatic crash reporter. If you experience a crash, please send the crash log to ${contactEmail} — including the report helps us fix the issue faster and is the only way we will ever see diagnostic information.`
    ]
  },
  {
    title: '6. Children',
    body: [
      'The App is not directed to children under 13 and we do not knowingly collect any information from children. The App is a developer utility intended for adult professionals.'
    ]
  },
  {
    title: '7. International transfers',
    body: [
      'Because we do not collect your data, there is nothing to transfer. If you email us, your message is delivered to our support inbox and handled according to the privacy practices of our email provider.'
    ]
  },
  {
    title: '8. Your rights',
    body: [
      'You have the right to access, correct, or delete any personal data you have shared with us. In practice, the only personal data we ever hold is whatever is in the email thread you initiated.',
      `To exercise these rights, contact ${contactEmail}.`
    ]
  },
  {
    title: '9. Changes to this policy',
    body: [
      'We may update this policy from time to time. Material changes will be announced in the App and on this page, with an updated "Last updated" date.'
    ]
  },
  {
    title: '10. Contact',
    body: [
      `Questions about this policy can be sent to ${contactEmail} or via the contact form.`
    ]
  }
] as const
</script>

<template>
  <article class="bg-white">
    <header class="border-b border-ink-200 bg-ink-50/40 py-16 sm:py-20">
      <div class="container-page">
        <NuxtLink to="/" class="text-xs text-ink-500 hover:text-ink-900">
          ← Back to home
        </NuxtLink>
        <p class="eyebrow mt-6">Legal</p>
        <h1 class="heading-section mt-4 text-balance">Privacy Policy</h1>
        <p class="lede mt-4 max-w-2xl text-pretty">
          We built Storage Cleaner for Developers to look at your files, not
          at you. This page explains exactly what data we handle — and
          why the answer is almost none.
        </p>
        <p class="mt-5 text-xs text-ink-500">Last updated {{ updated }}</p>
      </div>
    </header>

    <div class="container-page grid gap-12 py-16 sm:py-20 lg:grid-cols-[1fr_2.2fr]">
      <aside class="lg:sticky lg:top-24 lg:self-start">
        <h2 class="text-xs font-semibold uppercase tracking-[0.14em] text-ink-500">
          On this page
        </h2>
        <ol class="mt-4 space-y-2 text-sm text-ink-600">
          <li v-for="s in sections" :key="s.title" class="leading-snug">
            <a :href="`#${s.title.replace(/\W+/g, '-').toLowerCase()}`" class="hover:text-ink-900">
              {{ s.title }}
            </a>
          </li>
        </ol>
      </aside>

      <div>
        <section class="rounded-2xl border border-emerald-200 bg-emerald-50/50 p-6">
          <h2 class="text-base font-semibold text-emerald-900">In one line</h2>
          <p class="mt-3 text-[15px] leading-relaxed text-emerald-900/80">
            The App runs entirely on your Mac. We do not collect, transmit, or
            sell your data. Ever.
          </p>
        </section>

        <section v-for="section in sections" :key="section.title" :id="section.title.replace(/\W+/g, '-').toLowerCase()" class="mt-10 scroll-mt-24">
          <h2 class="text-lg font-semibold tracking-[-0.01em] text-ink-900">
            {{ section.title }}
          </h2>
          <div class="mt-3 space-y-3 text-[15px] leading-[1.7] text-ink-700">
            <p v-for="(paragraph, i) in section.body" :key="i">{{ paragraph }}</p>
          </div>
        </section>
      </div>
    </div>
  </article>
</template>
