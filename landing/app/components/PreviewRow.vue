<script setup lang="ts">
type Tone = 'blue' | 'cyan' | 'mint' | 'orange' | 'pink' | 'rose' | 'indigo' | 'teal' | 'violet' | 'amber' | 'gray'

defineProps<{
  name: string
  path: string
  size: string
  count?: string
  tone: Tone
  safe?: boolean
}>()

const toneStyles: Record<Tone, { dot: string; bar: string; chip: string }> = {
  blue:   { dot: 'bg-domain-apple',  bar: 'bg-domain-apple',  chip: 'text-domain-apple bg-domain-apple/10' },
  cyan:   { dot: 'bg-domain-web',    bar: 'bg-domain-web',    chip: 'text-domain-web bg-domain-web/10' },
  mint:   { dot: 'bg-domain-mobile', bar: 'bg-domain-mobile', chip: 'text-domain-mobile bg-domain-mobile/10' },
  orange: { dot: 'bg-domain-ai',     bar: 'bg-domain-ai',     chip: 'text-domain-ai bg-domain-ai/10' },
  pink:   { dot: 'bg-domain-media',  bar: 'bg-domain-media',  chip: 'text-domain-media bg-domain-media/10' },
  rose:   { dot: 'bg-domain-photo',  bar: 'bg-domain-photo',  chip: 'text-domain-photo bg-domain-photo/10' },
  indigo: { dot: 'bg-domain-shot',   bar: 'bg-domain-shot',   chip: 'text-domain-shot bg-domain-shot/10' },
  teal:   { dot: 'bg-domain-browser',bar: 'bg-domain-browser',chip: 'text-domain-browser bg-domain-browser/10' },
  violet: { dot: 'bg-domain-docker', bar: 'bg-domain-docker', chip: 'text-domain-docker bg-domain-docker/10' },
  amber:  { dot: 'bg-domain-leftover',bar:'bg-domain-leftover',chip: 'text-domain-leftover bg-domain-leftover/10' },
  gray:   { dot: 'bg-domain-trash',  bar: 'bg-domain-trash',  chip: 'text-domain-trash bg-domain-trash/10' }
}
</script>

<template>
  <div class="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-ink-50/70">
    <span :class="['size-2.5 shrink-0 rounded-full', toneStyles[tone].dot]" aria-hidden="true" />
    <div class="min-w-0 flex-1">
      <div class="flex items-center justify-between gap-3">
        <p class="truncate text-[13px] font-medium text-ink-900">{{ name }}</p>
        <p class="font-mono text-[12px] tabular-nums text-ink-700">{{ size }}</p>
      </div>
      <div class="mt-1.5 flex items-center gap-2">
        <p class="truncate font-mono text-[11px] text-ink-400">{{ path }}</p>
        <span
          v-if="count"
          :class="['ml-auto inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[10px] font-medium', toneStyles[tone].chip]"
        >
          {{ count }}
        </span>
        <span
          v-if="safe !== undefined"
          :class="[
            'ml-auto inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[10px] font-medium',
            safe ? 'bg-emerald-50 text-emerald-700' : 'bg-amber-50 text-amber-700'
          ]"
        >
          <span
            :class="['size-1.5 rounded-full', safe ? 'bg-emerald-500' : 'bg-amber-500']"
            aria-hidden="true"
          />
          {{ safe ? 'Safe' : 'Review' }}
        </span>
      </div>
    </div>
  </div>
</template>
