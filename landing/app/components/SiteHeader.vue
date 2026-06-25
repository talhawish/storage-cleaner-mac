<script setup lang="ts">
const route = useRoute()
const navItems = [
  { label: 'Features', to: '/#features' },
  { label: 'Workflow', to: '/#workflow' },
  { label: 'Coverage', to: '/#coverage' },
  { label: 'Pricing', to: '/#pricing' },
  { label: 'FAQ', to: '/#faq' }
] as const

const isActive = (to: string) => {
  if (to.startsWith('/#')) return route.path === '/' && route.hash === to.slice(1)
  return route.path === to
}
</script>

<template>
  <header
    class="sticky top-0 z-40 border-b border-ink-200/70 bg-white/75 backdrop-blur-xl supports-[backdrop-filter]:bg-white/65"
  >
    <div class="container-page flex h-16 items-center justify-between gap-4 sm:gap-6">
      <NuxtLink
        to="/"
        class="group flex shrink-0 items-center gap-2.5"
        aria-label="Storage Cleaner for Developers — home"
      >
        <img
          src="/icon-128.png"
          alt=""
          width="32"
          height="32"
          class="h-8 w-8 rounded-[8px] shadow-[0_1px_0_rgba(255,255,255,0.06)_inset,0_4px_12px_-4px_rgba(15,23,42,0.25)]"
        />
        <span class="flex flex-col leading-tight">
          <span class="text-[15px] font-semibold tracking-[-0.01em] text-ink-900">
            Storage Cleaner
          </span>
          <span class="text-[11px] font-medium text-ink-500">for Developers</span>
        </span>
      </NuxtLink>

      <nav class="hidden items-center gap-1 md:flex" aria-label="Primary">
        <NuxtLink
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="rounded-full px-3 py-1.5 text-sm text-ink-600 transition-colors hover:bg-ink-100 hover:text-ink-900"
          :class="{ 'text-ink-900 bg-ink-100': isActive(item.to) }"
        >
          {{ item.label }}
        </NuxtLink>
      </nav>

      <div class="flex shrink-0 items-center gap-2">
        <a
          href="#download"
          class="btn-primary shrink-0"
        >
          <svg viewBox="0 0 20 20" class="h-3.5 w-3.5 shrink-0" aria-hidden="true">
            <path
              fill="currentColor"
              d="M10 3a.75.75 0 0 1 .75.75v8.69l2.47-2.47a.75.75 0 1 1 1.06 1.06l-3.75 3.75a.75.75 0 0 1-1.06 0L5.72 11.03a.75.75 0 0 1 1.06-1.06l2.47 2.47V3.75A.75.75 0 0 1 10 3Z"
            />
            <path
              fill="currentColor"
              d="M3.75 15a.75.75 0 0 1 .75.75v.75h11v-.75a.75.75 0 0 1 1.5 0v1.5A1.5 1.5 0 0 1 15.5 18.5h-11A1.5 1.5 0 0 1 3 17.25v-1.5a.75.75 0 0 1 .75-.75Z"
            />
          </svg>
          <span>Download</span>
        </a>
      </div>
    </div>
  </header>
</template>
