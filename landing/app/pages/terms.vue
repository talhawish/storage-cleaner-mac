<script setup lang="ts">
usePageSeo({
  title: 'Terms & Conditions',
  description:
    'The terms governing your use of Storage Cleaner for Developers. Plain English summary plus the full legal text.',
  image: '/og-image-terms.png',
  path: '/terms'
})

const contactEmail = useSiteConfig().email
const updated = '2026-01-15'

const sections = [
  {
    title: '1. Acceptance of these terms',
    body: [
      'By installing, copying, or otherwise using Storage Cleaner for Developers (the "App"), you agree to be bound by these Terms & Conditions ("Terms"). If you do not agree, do not install or use the App.',
      'We may update these Terms from time to time. Material changes will be announced in the App and on this page. Continued use after a change indicates acceptance of the updated Terms.'
    ]
  },
  {
    title: '2. License',
    body: [
      'Subject to your compliance with these Terms, you are granted a personal, non-exclusive, non-transferable, revocable license to install and use the App on Mac computers you own or control.',
      'You may not redistribute, resell, decompile, reverse-engineer, or create derivative works of the App, except to the extent expressly permitted by applicable law.'
    ]
  },
  {
    title: '3. Subscriptions & billing',
    body: [
      'The App offers optional Pro subscriptions via the Mac App Store, billed monthly or annually at the price displayed at the time of purchase. Payment is charged to your Apple ID account at confirmation of purchase.',
      'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. You can manage or cancel subscriptions in Settings → Apple ID → Subscriptions on your Mac.',
      'Refunds are handled by Apple in accordance with their policies. We do not have the ability to issue refunds directly.'
    ]
  },
  {
    title: '4. Acceptable use',
    body: [
      'You agree not to use the App to violate any applicable law, infringe on the rights of others, or attempt to disable, impair, or circumvent the safety mechanisms (Trash-based deletion, path validation, audit logging) we have built into the App.',
      'You are solely responsible for the files on your Mac and for verifying previews before confirming any cleanup operation.'
    ]
  },
  {
    title: '5. Safety model',
    body: [
      'The App performs read-only inventory scans by default. Cleanup operations move files to the macOS Trash. The App does not perform permanent deletion of your files. The App may, with your explicit confirmation, invoke platform tools such as xcrun simctl runtime delete for Apple simulator runtimes; these tools may delete those runtimes from your system. We surface the exact action and target before any confirmation.',
      'You are responsible for reviewing the preview, the file paths, and the recovery estimate before confirming any cleanup.'
    ]
  },
  {
    title: '6. Intellectual property',
    body: [
      'The App, including its source-available code, design, and documentation, is the property of the developer and its licensors. The open-source license applies to source code; the App as distributed is a copyrighted work.',
      'Feedback you provide may be used by us to improve the App without restriction or compensation.'
    ]
  },
  {
    title: '7. Disclaimer of warranties',
    body: [
      'The App is provided "as is" and "as available" without warranties of any kind, express or implied, including but not limited to merchantability, fitness for a particular purpose, and non-infringement.',
      'We do not warrant that the App will be uninterrupted, error-free, or that the inventory it produces is exhaustive of all reclaimable storage on your Mac.'
    ]
  },
  {
    title: '8. Limitation of liability',
    body: [
      'To the maximum extent permitted by law, in no event shall the developer be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of data, arising out of or in connection with your use of the App.',
      'Our total cumulative liability for any claim arising from the App shall not exceed the amount you paid us in the twelve (12) months preceding the claim, or USD 50, whichever is greater.'
    ]
  },
  {
    title: '9. Termination',
    body: [
      'These Terms remain in effect until terminated. You may terminate at any time by uninstalling the App. We may terminate or suspend your license if you breach these Terms.',
      'Sections 6, 7, 8, and 10 survive termination.'
    ]
  },
  {
    title: '10. Governing law',
    body: [
      'These Terms are governed by the laws of the jurisdiction in which the developer is established, without regard to conflict-of-laws principles. Any dispute shall be resolved in the courts of that jurisdiction.'
    ]
  },
  {
    title: '11. Contact',
    body: [
      `Questions about these Terms can be sent to ${contactEmail} or via the contact form.`
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
        <h1 class="heading-section mt-4 text-balance">Terms &amp; Conditions</h1>
        <p class="lede mt-4 max-w-2xl text-pretty">
          Plain-English summary of the rules that govern Storage Cleaner for
          Developers, plus the full legal text. The summary is here to help;
          the section below is the binding agreement.
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

      <div class="prose-legal">
        <section class="rounded-2xl border border-ink-200 bg-ink-50/40 p-6">
          <h2 class="text-base font-semibold text-ink-900">In plain English</h2>
          <ul class="mt-3 space-y-2 text-sm leading-relaxed text-ink-700">
            <li>· You can use the App on any Mac you own or control.</li>
            <li>· The App is free to scan; Pro is an optional subscription billed by Apple.</li>
            <li>· The App never permanently deletes files. Cleanup always goes to Trash first.</li>
            <li>· The App is provided as-is. We do our best, but we cannot guarantee zero bugs.</li>
            <li>· If something goes wrong, our liability is capped at what you paid us.</li>
          </ul>
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
