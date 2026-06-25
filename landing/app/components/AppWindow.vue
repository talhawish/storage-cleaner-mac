<script setup lang="ts">
/**
 * AppWindow — a faux native macOS window chrome used in the hero.
 * Pure CSS/SVG so it renders crisp on every device and stays under 1KB.
 */
defineProps<{
  title?: string
}>()
</script>

<template>
  <div
    class="overflow-hidden rounded-xl border border-ink-200 bg-white shadow-[0_1px_0_rgba(15,23,42,0.04),0_24px_60px_-20px_rgba(15,23,42,0.25),0_8px_20px_-8px_rgba(15,23,42,0.12)]"
  >
    <div class="flex items-center gap-2 border-b border-ink-200/80 bg-ink-50/70 px-4 py-2.5">
      <span class="size-2.5 rounded-full bg-[#ff5f57] shadow-[inset_0_0_0_0.5px_rgba(0,0,0,0.1)]" />
      <span class="size-2.5 rounded-full bg-[#febc2e] shadow-[inset_0_0_0_0.5px_rgba(0,0,0,0.1)]" />
      <span class="size-2.5 rounded-full bg-[#28c840] shadow-[inset_0_0_0_0.5px_rgba(0,0,0,0.1)]" />
      <p class="ml-3 truncate text-[12px] font-medium text-ink-500">
        {{ title ?? 'Storage Cleaner — Dashboard' }}
      </p>
      <span class="ml-auto inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-medium text-emerald-700">
        <span class="size-1.5 rounded-full bg-emerald-500" /> Scan complete
      </span>
    </div>
    <slot />
  </div>
</template>
