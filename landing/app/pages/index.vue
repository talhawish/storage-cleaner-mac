<script setup lang="ts">
usePageSeo({
  title: 'Storage Cleaner for Developers — Reclaim your Mac, the safe way',
  description:
    'A native macOS app that helps developers see where every gigabyte goes and safely reclaim storage used by build artifacts, package caches, simulators, Docker, duplicates, and more.'
})
</script>

<template>
  <div>
    <!-- ============================================================
         Hero
         ============================================================ -->
    <section class="relative overflow-hidden">
      <div class="absolute inset-0 grid-lines" aria-hidden="true" />
      <div
        class="absolute inset-x-0 top-0 -z-10 h-[420px] bg-gradient-to-b from-ink-50 to-transparent"
        aria-hidden="true"
      />

      <div class="container-page relative pt-20 pb-16 sm:pt-28 sm:pb-24">
        <div class="mx-auto max-w-3xl text-center">
          <span class="eyebrow">
            <span class="size-1.5 rounded-full bg-emerald-500" aria-hidden="true" />
            Native macOS · Apple silicon & Intel
          </span>

          <h1 class="heading-display mt-6 text-balance">
            Reclaim the space your Mac
            <span class="relative inline-block">
              <span class="relative z-10">actually</span>
              <span
                class="absolute inset-x-0 bottom-1 -z-0 h-3 rounded-sm bg-brand-200/70"
                aria-hidden="true"
              />
            </span>
            forgot about.
          </h1>

          <p class="lede mt-6 text-balance">
            A native storage inspector built for the way developers work.
            See exactly which builds, caches, simulators, containers and
            duplicate files are eating your disk — then clean them with full
            preview, audit trail, and Trash-based safety.
          </p>

          <div class="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <a href="#download" class="btn-primary shrink-0 px-6 py-3 text-[15px]">
              <svg viewBox="0 0 20 20" class="h-4 w-4 shrink-0" aria-hidden="true">
                <path
                  fill="currentColor"
                  d="M10.75 3a.75.75 0 0 0-1.5 0v9.69l-2.47-2.47a.75.75 0 1 0-1.06 1.06l3.75 3.75a.75.75 0 0 0 1.06 0l3.75-3.75a.75.75 0 1 0-1.06-1.06l-2.47 2.47V3Z"
                />
                <path
                  fill="currentColor"
                  d="M3.75 15a.75.75 0 0 0-.75.75v.75h14v-.75a.75.75 0 0 1 1.5 0v1.5A1.5 1.5 0 0 1 17 18.5H3a1.5 1.5 0 0 1-1.5-1.5v-1.5a.75.75 0 0 1 .75-.75Z"
                />
              </svg>
              <span>Download for macOS</span>
            </a>
            <a href="#features" class="btn-secondary shrink-0 px-6 py-3 text-[15px]">
              See what's inside
            </a>
          </div>

          <p class="mt-5 text-xs text-ink-500">
            Free to scan · No account · macOS 14 Sonoma or later
          </p>
        </div>

        <!-- App preview -->
        <div class="relative mx-auto mt-16 max-w-5xl">
          <div
            class="absolute -inset-x-12 -inset-y-8 -z-10 rounded-[40px] bg-gradient-to-b from-ink-100/60 via-transparent to-transparent blur-2xl"
            aria-hidden="true"
          />
          <DashboardPreview />
        </div>
      </div>
    </section>

    <!-- ============================================================
         Stats
         ============================================================ -->
    <section class="border-y border-ink-200/70 bg-ink-50/40">
      <div class="container-page grid grid-cols-2 gap-y-8 py-12 sm:grid-cols-4">
        <div v-for="stat in [
          { value: '15+', label: 'Detection domains', sub: 'Xcode, Docker, Flutter, Android, AI…' },
          { value: '87 GB', label: 'Median reclaim', sub: 'on a working dev machine' },
          { value: '0',    label: 'Hard-deleted files', sub: 'Trash-first, always recoverable' },
          { value: '< 4s', label: 'To first result', sub: 'streaming, cancelable scans' }
        ]" :key="stat.label" class="px-2 sm:border-r sm:border-ink-200/70 sm:last:border-r-0">
          <p class="font-mono text-2xl font-semibold tracking-tight text-ink-900 sm:text-3xl">
            {{ stat.value }}
          </p>
          <p class="mt-1 text-sm font-medium text-ink-700">{{ stat.label }}</p>
          <p class="mt-0.5 text-xs text-ink-500">{{ stat.sub }}</p>
        </div>
      </div>
    </section>

    <SectionFeatures id="features" />
    <SectionCoverage id="coverage" />
    <SectionWorkflow id="workflow" />
    <SectionSafety />
    <SectionPricing id="pricing" />
    <SectionFaq id="faq" />
    <SectionCta id="download" />
  </div>
</template>
