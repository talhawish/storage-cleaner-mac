<script setup lang="ts">
/**
 * The dashboard preview that anchors the hero.
 * Stays hand-rolled (no real screenshots yet) — uses the same
 * domain palette and row UI as the real macOS app.
 */
</script>

<template>
  <AppWindow title="Storage Cleaner — Dashboard">
    <div class="grid grid-cols-[200px_1fr]">
      <!-- Sidebar -->
      <aside class="hidden border-r border-ink-200/80 bg-ink-50/40 p-3 sm:block">
        <p class="px-2 pb-2 text-[10px] font-semibold uppercase tracking-[0.14em] text-ink-400">
          Overview
        </p>
        <ul class="space-y-0.5 text-[13px]">
          <li v-for="item in [
            { label: 'Dashboard', active: true,  dot: 'bg-ink-700' },
            { label: 'Apple',     active: false, dot: 'bg-domain-apple' },
            { label: 'Web',       active: false, dot: 'bg-domain-web' },
            { label: 'Docker',    active: false, dot: 'bg-domain-docker' },
            { label: 'Mobile',    active: false, dot: 'bg-domain-mobile' },
            { label: 'AI & ML',   active: false, dot: 'bg-domain-ai' },
            { label: 'Media',     active: false, dot: 'bg-domain-media' },
            { label: 'Browser',   active: false, dot: 'bg-domain-browser' }
          ]" :key="item.label">
            <span
              :class="[
                'flex items-center gap-2 rounded-md px-2 py-1.5',
                item.active ? 'bg-white text-ink-900 shadow-sm' : 'text-ink-600'
              ]"
            >
              <span :class="['size-1.5 rounded-full', item.dot]" />
              {{ item.label }}
            </span>
          </li>
        </ul>
      </aside>

      <!-- Main -->
      <div class="p-4 sm:p-5">
        <!-- Donut + breakdown -->
        <div class="flex items-start gap-5">
          <div class="relative grid size-[112px] place-items-center">
            <svg viewBox="0 0 36 36" class="size-full -rotate-90">
              <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#e6e9ef" stroke-width="3" />
              <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#2f57f0" stroke-width="3" stroke-dasharray="38 100" stroke-linecap="round" />
              <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#2bb4d8" stroke-width="3" stroke-dasharray="22 100" stroke-dashoffset="-38" stroke-linecap="round" />
              <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#9461f5" stroke-width="3" stroke-dasharray="14 100" stroke-dashoffset="-60" stroke-linecap="round" />
              <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#f5b52f" stroke-width="3" stroke-dasharray="10 100" stroke-dashoffset="-74" stroke-linecap="round" />
              <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#34c08f" stroke-width="3" stroke-dasharray="8 100" stroke-dashoffset="-84" stroke-linecap="round" />
              <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#f56a78" stroke-width="3" stroke-dasharray="8 100" stroke-dashoffset="-92" stroke-linecap="round" />
            </svg>
            <div class="absolute text-center">
              <p class="text-[10px] uppercase tracking-wide text-ink-500">Reclaim</p>
              <p class="font-mono text-[15px] font-semibold text-ink-900">87.4 GB</p>
            </div>
          </div>

          <div class="min-w-0 flex-1 space-y-1.5">
            <div v-for="(item, i) in [
              { label: 'Apple',    value: '32.1 GB', pct: 92, dot: 'bg-domain-apple' },
              { label: 'Web',      value: '18.7 GB', pct: 64, dot: 'bg-domain-web' },
              { label: 'Docker',   value: '12.3 GB', pct: 44, dot: 'bg-domain-docker' },
              { label: 'Mobile',   value: '8.9 GB',  pct: 32, dot: 'bg-domain-mobile' },
              { label: 'AI & ML',  value: '7.2 GB',  pct: 26, dot: 'bg-domain-ai' },
              { label: 'Media',    value: '5.4 GB',  pct: 20, dot: 'bg-domain-media' },
              { label: 'Junk',     value: '2.8 GB',  pct: 12, dot: 'bg-domain-photo' }
            ]" :key="i" class="flex items-center gap-2.5">
              <span :class="['size-2 rounded-full shrink-0', item.dot]" />
              <span class="w-12 text-[12px] text-ink-600">{{ item.label }}</span>
              <span class="h-1.5 flex-1 overflow-hidden rounded-full bg-ink-100">
                <span :class="['block h-full', item.dot]" :style="{ width: item.pct + '%' }" />
              </span>
              <span class="w-14 text-right font-mono text-[11px] tabular-nums text-ink-700">{{ item.value }}</span>
            </div>
          </div>
        </div>

        <!-- Divider -->
        <div class="my-4 h-px w-full bg-ink-200/80" />

        <!-- Rows -->
        <div class="-mx-2 divide-y divide-ink-200/80">
          <PreviewRow
            name="Xcode DerivedData"
            path="~/Library/Developer/Xcode/DerivedData"
            size="22.4 GB"
            count="12 projects"
            tone="blue"
            safe
          />
          <PreviewRow
            name="node_modules"
            path="~/Code/**/node_modules"
            size="14.6 GB"
            count="184 dirs"
            tone="cyan"
            safe
          />
          <PreviewRow
            name="Docker builder cache"
            path="~/Library/Containers/com.docker.docker"
            size="11.8 GB"
            count="32 layers"
            tone="violet"
            safe
          />
          <PreviewRow
            name="Simulator runtimes"
            path="~/Library/Developer/CoreSimulator/Runtimes"
            size="9.2 GB"
            count="4 runtimes"
            tone="blue"
            :safe="false"
          />
          <PreviewRow
            name="Inactive projects"
            path="~/Code/old-dashboard"
            size="6.4 GB"
            count="last opened 187d"
            tone="gray"
            :safe="false"
          />
          <PreviewRow
            name="Ollama models"
            path="~/.ollama/models"
            size="5.1 GB"
            count="6 models"
            tone="orange"
            :safe="false"
          />
        </div>
      </div>
    </div>
  </AppWindow>
</template>
