<script setup lang="ts">
const points = [
  {
    title: 'Read-only by default',
    body: 'Scanning never moves, modifies, or deletes a file. Cleanup is an explicit, confirmable action.'
  },
  {
    title: 'Trash, never hard delete',
    body: 'Everything the app removes goes to the macOS Trash. Restore any item from Finder in a click.'
  },
  {
    title: 'Safe vs. review gating',
    body: 'Caches, build outputs, and runtime duplicates are marked Safe. Media, photos, screenshots, APKs, and Trash stay in review.'
  },
  {
    title: 'Path-validated, never stale',
    body: 'Before any cleanup, every path is re-validated. If a file moved or changed size, the action is skipped, not guessed.'
  },
  {
    title: 'Streaming, cancelable scans',
    body: 'A 1 TB disk shouldn\u2019t lock your Mac. The scanner streams results and honors ⌘. (Cancel) at any moment.'
  },
  {
    title: 'Full audit trail',
    body: 'Every action is logged with a timestamp, target, size, and outcome. Exportable from Settings.'
  }
] as const
</script>

<template>
  <section class="border-y border-ink-200/70 bg-ink-900 py-24 text-white sm:py-32">
    <div class="container-page">
      <div class="grid gap-12 lg:grid-cols-[1fr_1.4fr]">
        <div>
          <span class="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1 text-xs font-medium tracking-wide text-white/80">
            <span class="size-1.5 rounded-full bg-emerald-400" aria-hidden="true" />
            Safety model
          </span>
          <h2 class="mt-4 text-3xl font-semibold tracking-[-0.02em] text-balance sm:text-4xl">
            Destructive operations deserve
            <span class="text-white/50">obsessive care.</span>
          </h2>
          <p class="mt-4 text-base leading-relaxed text-white/70 text-pretty">
            Storage cleanup is one of the most dangerous things a Mac app can
            do. The product is engineered around the principle that nothing
            should ever be permanently destroyed by accident — and that
            the user should always know exactly what is about to happen.
          </p>
        </div>
        <div class="grid gap-px overflow-hidden rounded-2xl border border-white/10 bg-white/10 sm:grid-cols-2">
          <article
            v-for="point in points"
            :key="point.title"
            class="flex flex-col gap-2 bg-ink-900 p-5"
          >
            <h3 class="text-sm font-semibold text-white">{{ point.title }}</h3>
            <p class="text-[13px] leading-relaxed text-white/65">{{ point.body }}</p>
          </article>
        </div>
      </div>
    </div>
  </section>
</template>
