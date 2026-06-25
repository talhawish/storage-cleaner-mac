<script setup lang="ts">
</script>

<template>
  <section class="py-24 sm:py-32">
    <div class="container-page">
      <div class="relative overflow-hidden rounded-3xl border border-ink-200 bg-gradient-to-br from-ink-50 to-white p-10 sm:p-14">
        <div
          class="absolute inset-0 grid-lines opacity-60"
          aria-hidden="true"
        />
        <div class="relative grid items-center gap-10 lg:grid-cols-[1.4fr_1fr]">
          <div>
            <span class="eyebrow">
              <span class="size-1.5 rounded-full bg-brand-500" aria-hidden="true" />
              Ready when you are
            </span>
            <h2 class="mt-5 text-3xl font-semibold tracking-[-0.02em] text-ink-900 text-balance sm:text-4xl">
              Give your Mac back the space
              <span class="text-ink-500">you've already paid for.</span>
            </h2>
            <p class="lede mt-4 max-w-xl text-pretty">
              Download the universal build for Apple silicon and Intel. Free
              forever, no account, no telemetry — the way Mac apps should be.
            </p>
            <div class="mt-8 flex flex-col gap-3 sm:flex-row">
              <a href="#" class="btn-primary shrink-0 px-6 py-3 text-[15px]">
                <svg viewBox="0 0 24 24" class="h-4 w-4 shrink-0" aria-hidden="true">
                  <path
                    fill="currentColor"
                    d="M17.05 12.04c-.03-2.74 2.24-4.06 2.34-4.12-1.27-1.86-3.26-2.12-3.97-2.15-1.69-.17-3.3 1-4.16 1-.86 0-2.18-.97-3.59-.94-1.85.03-3.55 1.08-4.5 2.73-1.92 3.32-.49 8.23 1.38 10.92.91 1.32 2 2.81 3.41 2.76 1.37-.06 1.89-.89 3.54-.89 1.65 0 2.12.89 3.57.86 1.47-.03 2.41-1.34 3.31-2.67 1.05-1.53 1.48-3.02 1.5-3.1-.03-.01-2.88-1.11-2.91-4.4ZM14.32 4.06c.74-.91 1.25-2.17 1.11-3.43-1.07.05-2.38.72-3.16 1.62-.69.8-1.31 2.09-1.15 3.32 1.2.09 2.43-.61 3.2-1.51Z"
                  />
                </svg>
                <span>Download for macOS</span>
              </a>
              <a
                href="https://github.com/talhawish/storage-cleaner-mac"
                class="btn-secondary shrink-0 px-6 py-3 text-[15px]"
              >
                Star on GitHub
              </a>
            </div>
            <p class="mt-5 text-xs text-ink-500">
              Universal binary · macOS 14 Sonoma or later · Notarized &amp; code-signed
            </p>
          </div>

          <ul class="space-y-2 rounded-2xl border border-ink-200 bg-white p-3 text-sm">
            <li v-for="item in [
              { ok: true,  text: 'Read-only inventory of 15+ domains' },
              { ok: true,  text: 'Cancelable, streaming scans' },
              { ok: true,  text: 'Trash-first cleanup' },
              { ok: true,  text: 'Path-validated, audited actions' },
              { ok: false, text: 'No accounts, no telemetry, no upsells' }
            ]" :key="item.text" class="flex items-center gap-3 rounded-lg px-3 py-2">
              <span
                :class="[
                  'grid size-5 shrink-0 place-items-center rounded-full',
                  item.ok ? 'bg-emerald-50 text-emerald-700' : 'bg-ink-100 text-ink-600'
                ]"
                aria-hidden="true"
              >
                <svg viewBox="0 0 20 20" class="size-3">
                  <path
                    v-if="item.ok"
                    fill="currentColor"
                    d="M16.7 5.3a1 1 0 0 1 0 1.4l-7.5 7.5a1 1 0 0 1-1.4 0L3.3 9.7a1 1 0 0 1 1.4-1.4l3.8 3.8 6.8-6.8a1 1 0 0 1 1.4 0Z"
                  />
                  <path
                    v-else
                    fill="currentColor"
                    d="M4 10a6 6 0 1 1 12 0 6 6 0 0 1-12 0Zm6-4.5a.75.75 0 0 0-.75.75v4.5c0 .41.34.75.75.75h3a.75.75 0 0 0 0-1.5H10.75V6.25A.75.75 0 0 0 10 5.5Z"
                  />
                </svg>
              </span>
              <span class="text-ink-700">{{ item.text }}</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </section>
</template>
