<script setup lang="ts">
type Tone =
  | 'apple' | 'web' | 'docker' | 'mobile' | 'ai'
  | 'media' | 'photo' | 'shot' | 'browser' | 'trash'
  | 'cli' | 'leftover' | 'junk' | 'docs' | 'other'

const groups = [
  {
    label: 'Apple & Mobile',
    color: 'bg-domain-apple',
    tone: 'apple' as Tone,
    items: [
      { name: 'Xcode DerivedData',  size: '~22 GB', note: 'Rebuilt on next build' },
      { name: 'Xcode Archives',     size: '~5 GB',  note: 'Old distribution builds' },
      { name: 'iOS Simulators',     size: '~9 GB',  note: 'Runtimes you no longer target' },
      { name: 'Device support',     size: '~3 GB',  note: 'Old iOS / watchOS SDKs' },
      { name: 'SwiftPM checkouts',  size: '~2 GB',  note: 'Cached package sources' },
      { name: 'Flutter pub cache',  size: '~6 GB',  note: 'Dart & Flutter packages' },
      { name: 'Flutter builds',     size: '~4 GB',  note: 'Per-project build output' },
      { name: 'Android SDK',        size: '~8 GB',  note: 'Unused platforms & build-tools' },
      { name: 'Android emulator',   size: '~6 GB',  note: 'System images by API level' },
      { name: 'Gradle caches',      size: '~5 GB',  note: 'Distribution & build cache' },
      { name: 'Loose APKs & AABs',  size: '~1 GB',  note: 'Build outputs, exports' }
    ]
  },
  {
    label: 'Web & Containers',
    color: 'bg-domain-web',
    tone: 'web' as Tone,
    items: [
      { name: 'node_modules',       size: '~14 GB', note: 'Per-project, all folders' },
      { name: 'npm cache',          size: '~2 GB',  note: 'Re-downloaded on demand' },
      { name: 'pnpm store',         size: '~3 GB',  note: 'Content-addressed store' },
      { name: 'yarn cache',         size: '~1 GB',  note: 'Mirror of registry' },
      { name: 'Docker images',      size: '~12 GB', note: 'Tagged & dangling' },
      { name: 'Docker builder',     size: '~6 GB',  note: 'Reclaimable layers' },
      { name: 'OrbStack data',      size: '~4 GB',  note: 'Lightweight Docker alt' },
      { name: 'Colima VM',          size: '~3 GB',  note: 'Lima VM & images' },
      { name: 'Docker volumes',     size: 'varies', note: 'Always review before removing' }
    ]
  },
  {
    label: 'AI, Media & Documents',
    color: 'bg-domain-ai',
    tone: 'ai' as Tone,
    items: [
      { name: 'Ollama models',      size: '~5 GB',  note: 'Pulled LLM weights' },
      { name: 'LM Studio',          size: '~3 GB',  note: 'GGUF & MLX model cache' },
      { name: 'HuggingFace cache',  size: '~4 GB',  note: 'Datasets & transformers' },
      { name: 'Stable Diffusion',   size: '~6 GB',  note: 'Models, LoRAs, outputs' },
      { name: 'Large files',        size: '10 MB+', note: 'PDFs, datasets, disk images' },
      { name: 'Large videos',       size: 'varies', note: 'Screen recordings, exports' },
      { name: 'Large photos',       size: 'varies', note: 'RAW, edited exports' },
      { name: 'Duplicate photos',   size: 'varies', note: 'Repeated imports, edits' },
      { name: 'Duplicate videos',   size: 'varies', note: 'Recordings & captures' },
      { name: 'Duplicate documents',size: 'varies', note: 'Byte-identical PDFs, XLSX' }
    ]
  },
  {
    label: 'Runtimes, Browsers & Junk',
    color: 'bg-domain-browser',
    tone: 'browser' as Tone,
    items: [
      { name: 'Node (nvm/Volta/fnm)', size: '~3 GB', note: 'Keep one, drop the rest' },
      { name: 'Python (pyenv)',       size: '~2 GB', note: 'Old 3.x versions' },
      { name: 'Ruby (rbenv/RVM)',     size: '~2 GB', note: 'Old 2.x / 3.x versions' },
      { name: 'Rust (rustup)',        size: '~3 GB', note: 'Toolchains & targets' },
      { name: 'Go (goenv/GVM)',       size: '~2 GB', note: 'Multiple Go versions' },
      { name: 'Java (jEnv/SDKMAN)',   size: '~5 GB', note: 'JDK 8, 11, 17, 21\u2026' },
      { name: '.NET SDKs',            size: '~3 GB', note: 'Local installs' },
      { name: 'PHP (phpenv/Herd)',    size: '~2 GB', note: 'Versioned formulae' },
      { name: 'Browser caches',       size: '~4 GB', note: 'Safari, Chrome, Edge, Arc, Firefox' },
      { name: 'Trash',                size: '~3 GB', note: 'Already on its way out' },
      { name: 'System junk',          size: '~2 GB', note: 'Logs, crash reports, temp' }
    ]
  }
] as const

const dotClass: Record<Tone, string> = {
  apple:   'bg-domain-apple',
  web:     'bg-domain-web',
  docker:  'bg-domain-docker',
  mobile:  'bg-domain-mobile',
  ai:      'bg-domain-ai',
  media:   'bg-domain-media',
  photo:   'bg-domain-photo',
  shot:    'bg-domain-shot',
  browser: 'bg-domain-browser',
  trash:   'bg-domain-trash',
  cli:     'bg-domain-cli',
  leftover:'bg-domain-leftover',
  junk:    'bg-domain-junk',
  docs:    'bg-domain-docs',
  other:   'bg-domain-other'
}
</script>

<template>
  <section class="bg-ink-50/40 py-24 sm:py-32">
    <div class="container-page">
      <div class="flex flex-wrap items-end justify-between gap-6">
        <div class="max-w-2xl">
          <span class="eyebrow">Detection coverage</span>
          <h2 class="heading-section mt-4 text-balance">
            15+ storage domains,
            <span class="text-ink-500">one inventory.</span>
          </h2>
          <p class="lede mt-4 text-pretty">
            Every scanner is a thin, typed, protocol-driven component that
            reuses a small set of high-performance engines. No black-box
            heuristics, no surprise deletions.
          </p>
        </div>
        <NuxtLink
          to="https://github.com/talhawish/storage-cleaner-mac"
          class="btn-secondary shrink-0 self-end"
        >
          View on GitHub
        </NuxtLink>
      </div>

      <div class="mt-14 grid gap-6 lg:grid-cols-2">
        <div
          v-for="group in groups"
          :key="group.label"
          class="rounded-2xl border border-ink-200 bg-white"
        >
          <div class="flex items-center gap-2.5 border-b border-ink-200/80 px-5 py-4">
            <span :class="['size-2 rounded-full', dotClass[group.tone]]" aria-hidden="true" />
            <h3 class="text-sm font-semibold tracking-[-0.01em] text-ink-900">
              {{ group.label }}
            </h3>
            <span class="ml-auto text-xs text-ink-500">
              {{ group.items.length }} categories
            </span>
          </div>
          <ul class="divide-y divide-ink-200/80">
            <li
              v-for="item in group.items"
              :key="item.name"
              class="flex items-center gap-3 px-5 py-3"
            >
              <p class="min-w-0 flex-1 text-[13px] font-medium text-ink-900">{{ item.name }}</p>
              <p class="hidden font-mono text-[11px] text-ink-500 sm:block">{{ item.note }}</p>
              <p class="w-20 text-right font-mono text-[12px] tabular-nums text-ink-700">
                {{ item.size }}
              </p>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </section>
</template>
