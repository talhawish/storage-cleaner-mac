<script setup lang="ts">
const steps = [
  {
    n: '01',
    title: 'One scan, every domain',
    body:
      'A single click walks DerivedData, node_modules, Docker layers, sim runtimes, AI caches, browser caches, Trash, and more — concurrently and cancelable.'
  },
  {
    n: '02',
    title: 'Inspect with full paths',
    body:
      'Every finding shows the exact path, size, count, and provenance. Safe-to-clear items are flagged; user-created media stays in review.'
  },
  {
    n: '03',
    title: 'Preview, then clean',
    body:
      'A live preview summarizes the recovery estimate and what will be removed. Confirm to send everything to the Trash — never a hard delete.'
  },
  {
    n: '04',
    title: 'Audited, recoverable',
    body:
      'Every cleanup produces a detailed audit record. Anything in the Trash can be restored in a single click from Finder.'
  }
] as const
</script>

<template>
  <section class="py-24 sm:py-32">
    <div class="container-page">
      <div class="max-w-2xl">
        <span class="eyebrow">How it works</span>
        <h2 class="heading-section mt-4 text-balance">
          From cluttered to cleaned in
          <span class="text-ink-500">four calm steps.</span>
        </h2>
        <p class="lede mt-4 text-pretty">
          No upsells, no "boost your RAM" nonsense. The app respects your
          machine: it scans read-only, explains every byte it touches, and
          keeps a full audit log.
        </p>
      </div>

      <ol class="mt-14 grid gap-px overflow-hidden rounded-2xl border border-ink-200 bg-ink-200 sm:grid-cols-2 lg:grid-cols-4">
        <li
          v-for="step in steps"
          :key="step.n"
          class="relative flex flex-col gap-3 bg-white p-6"
        >
          <span class="font-mono text-[11px] tracking-[0.18em] text-ink-400">
            STEP {{ step.n }}
          </span>
          <h3 class="text-base font-semibold text-ink-900">{{ step.title }}</h3>
          <p class="text-sm leading-relaxed text-ink-600">{{ step.body }}</p>
        </li>
      </ol>
    </div>
  </section>
</template>
