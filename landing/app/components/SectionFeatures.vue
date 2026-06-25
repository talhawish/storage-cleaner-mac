<script setup lang="ts">
const features = [
  {
    title: 'See every gigabyte, mapped to a domain',
    body:
      'A single, focused dashboard breaks your disk into Apple, Web, Docker, Mobile, AI & ML, Media, Browser, and more — so you instantly know which world is using how much.',
    icon: 'chart'
  },
  {
    title: 'Inactive projects, surfaced automatically',
    body:
      'Find projects you haven\u2019t opened in weeks or months. See their size, last activity, and reclaim the disk with one click — without touching active work.',
    icon: 'archive'
  },
  {
    title: 'Simulators, emulators & device support',
    body:
      'Audit iOS simulator runtimes, Android system images, and per-device support files. Apple runtimes re-download; Android images move to the Trash, restorable.',
    icon: 'device'
  },
  {
    title: 'Docker, OrbStack & Colima, untangled',
    body:
      'Inventory images, stopped containers, dangling layers, builder cache, and volumes across Docker, OrbStack, and Colima. Remove what\u2019s safe, keep what\u2019s not.',
    icon: 'docker'
  },
  {
    title: 'Large files, no more guesswork',
    body:
      'A 10 MB floor scanner across Desktop, Downloads, Documents, Pictures, and Movies. PDFs, datasets, disk images, archives, exports — the actual culprits.',
    icon: 'file'
  },
  {
    title: 'Duplicate photos, videos & documents',
    body:
      'Byte-identical duplicates, repeated exports, edited copies, and screen recording backups — grouped with full paths and sizes so you can decide.',
    icon: 'copy'
  },
  {
    title: 'System junk, browser cache & logs',
    body:
      'Temporary files, crash reports, stale logs, Safari / Chrome / Edge / Arc / Firefox caches, and leftover DMG / PKG / IPA installers — surfaced with provenance.',
    icon: 'trash'
  },
  {
    title: 'Build & package caches, cleaned safely',
    body:
      'npm, pnpm, yarn, Gradle, Maven, Composer, pip, Poetry, conda, Cargo, Go module cache, NuGet, and pub cache — sized and separated by safe-to-clear.',
    icon: 'box'
  }
] as const
</script>

<template>
  <section class="py-24 sm:py-32">
    <div class="container-page">
      <div class="max-w-2xl">
        <span class="eyebrow">Features</span>
        <h2 class="heading-section mt-4 text-balance">
          Built for the messy, real-world
          <span class="text-ink-500">developer Mac.</span>
        </h2>
        <p class="lede mt-4 text-pretty">
          Storage Cleaner was designed around the actual data trails left by
          Swift, Node, Docker, Flutter, Android, Xcode, and local AI tools —
          not the things the App Store "optimize your Mac" apps think you have.
        </p>
      </div>

      <div class="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <article
          v-for="feature in features"
          :key="feature.title"
          class="group relative overflow-hidden rounded-2xl border border-ink-200 bg-white p-6 transition-colors hover:border-ink-300"
        >
          <span
            class="absolute right-5 top-5 h-1.5 w-1.5 rounded-full bg-ink-200 transition-colors group-hover:bg-ink-400"
            aria-hidden="true"
          />
          <div
            class="grid size-10 place-items-center rounded-xl bg-ink-900 text-white"
            aria-hidden="true"
          >
            <svg viewBox="0 0 24 24" class="size-5">
              <path
                v-if="feature.icon === 'chart'"
                fill="currentColor"
                d="M3 4.5A1.5 1.5 0 0 1 4.5 3h2A1.5 1.5 0 0 1 8 4.5v15A1.5 1.5 0 0 1 6.5 21h-2A1.5 1.5 0 0 1 3 19.5v-15Zm6.5 4A1.5 1.5 0 0 1 11 7h2a1.5 1.5 0 0 1 1.5 1.5v10A1.5 1.5 0 0 1 13 20h-2a1.5 1.5 0 0 1-1.5-1.5v-10Zm6.5-3A1.5 1.5 0 0 1 17.5 4h2A1.5 1.5 0 0 1 21 5.5v13a1.5 1.5 0 0 1-1.5 1.5h-2a1.5 1.5 0 0 1-1.5-1.5v-13Z"
              />
              <path
                v-else-if="feature.icon === 'archive'"
                fill="currentColor"
                d="M3 5.5A2.5 2.5 0 0 1 5.5 3h13A2.5 2.5 0 0 1 21 5.5V8H3V5.5ZM3 10h18v8.5A2.5 2.5 0 0 1 18.5 21h-13A2.5 2.5 0 0 1 3 18.5V10Zm5 4.5a.75.75 0 0 0 0 1.5h8a.75.75 0 0 0 0-1.5H8Z"
              />
              <path
                v-else-if="feature.icon === 'device'"
                fill="currentColor"
                d="M7 2.5A2.5 2.5 0 0 0 4.5 5v14A2.5 2.5 0 0 0 7 21.5h10A2.5 2.5 0 0 0 19.5 19V5A2.5 2.5 0 0 0 17 2.5H7Zm.75 3.5a.75.75 0 0 0 0 1.5h8.5a.75.75 0 0 0 0-1.5h-8.5Zm0 11a.75.75 0 0 0 0 1.5h5.5a.75.75 0 0 0 0-1.5h-5.5Z"
              />
              <path
                v-else-if="feature.icon === 'docker'"
                fill="currentColor"
                d="M3 11.5h1.7c.1-.9.4-1.7.8-2.4l-1.2-1.2a.75.75 0 1 1 1.06-1.06L6.5 7.95a5.6 5.6 0 0 1 2.5-1V5.5a.75.75 0 1 1 1.5 0v1.5a5.6 5.6 0 0 1 2 .6V6.25a.75.75 0 1 1 1.5 0v2.2a5.6 5.6 0 0 1 1.7 1.55l1.1-1.1a.75.75 0 1 1 1.06 1.06l-1.2 1.2c.4.7.7 1.5.8 2.4H21a.75.75 0 0 1 .75.85c-.2 1.6-1 2.9-2.2 3.8-1.7 1.3-4.2 1.9-7.6 1.9-3.5 0-6.2-.7-8-2-1.4-1-2.2-2.4-2.3-4.05A.75.75 0 0 1 3 11.5Zm4.5-1.5a1 1 0 1 0 0 2 1 1 0 0 0 0-2Zm3.5 0a1 1 0 1 0 0 2 1 1 0 0 0 0-2Zm3.5 0a1 1 0 1 0 0 2 1 1 0 0 0 0-2Z"
              />
              <path
                v-else-if="feature.icon === 'file'"
                fill="currentColor"
                d="M5 2.5A2.5 2.5 0 0 1 7.5 0h6.879a1.5 1.5 0 0 1 1.06.44l3.122 3.12a1.5 1.5 0 0 1 .439 1.06V21.5A2.5 2.5 0 0 1 16.5 24h-9A2.5 2.5 0 0 1 5 21.5v-19Zm10 1.5V3a.5.5 0 0 0-.5-.5h-1A.5.5 0 0 0 13 3v1a.5.5 0 0 0 .5.5H15Zm-7 6a.75.75 0 0 0 0 1.5h8a.75.75 0 0 0 0-1.5H8Zm0 4a.75.75 0 0 0 0 1.5h5a.75.75 0 0 0 0-1.5H8Z"
              />
              <path
                v-else-if="feature.icon === 'copy'"
                fill="currentColor"
                d="M7 3.5A2.5 2.5 0 0 1 9.5 1h7A2.5 2.5 0 0 1 19 3.5v11A2.5 2.5 0 0 1 16.5 17H15v1.5A2.5 2.5 0 0 1 12.5 21h-7A2.5 2.5 0 0 1 3 18.5v-11A2.5 2.5 0 0 1 5.5 5H7V3.5Zm1.5 0V5h6.5A1.5 1.5 0 0 0 16 3.5V3h-7a.5.5 0 0 0-.5.5Zm-3 3a.5.5 0 0 0-.5.5v11a.5.5 0 0 0 .5.5h7a.5.5 0 0 0 .5-.5V7a.5.5 0 0 0-.5-.5h-7Z"
              />
              <path
                v-else-if="feature.icon === 'trash'"
                fill="currentColor"
                d="M9.5 3.5A1.5 1.5 0 0 1 11 2h2a1.5 1.5 0 0 1 1.5 1.5V4h5.25a.75.75 0 0 1 0 1.5H19V19.5A2.5 2.5 0 0 1 16.5 22h-9A2.5 2.5 0 0 1 5 19.5V5.5H4.25a.75.75 0 0 1 0-1.5H9.5v-.5Zm1.5.5h2v-.5h-2V4Zm-3.5 2v13a1 1 0 0 0 1 1h9a1 1 0 0 0 1-1V6h-11Zm3 2.5a.75.75 0 0 1 .75.75v7.5a.75.75 0 0 1-1.5 0v-7.5a.75.75 0 0 1 .75-.75Zm4.25 0a.75.75 0 0 1 .75.75v7.5a.75.75 0 0 1-1.5 0v-7.5a.75.75 0 0 1 .75-.75Z"
              />
              <path
                v-else
                fill="currentColor"
                d="M3 7a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V7Zm3-1.5A1.5 1.5 0 0 0 4.5 7v10A1.5 1.5 0 0 0 6 18.5h12A1.5 1.5 0 0 0 19.5 17V7A1.5 1.5 0 0 0 18 5.5H6Zm2 4a.75.75 0 0 1 .75-.75h6.5a.75.75 0 0 1 0 1.5h-6.5A.75.75 0 0 1 5 9.5Zm0 3a.75.75 0 0 1 .75-.75h3.5a.75.75 0 0 1 0 1.5h-3.5A.75.75 0 0 1 5 12.5Z"
              />
            </svg>
          </div>
          <h3 class="mt-5 text-base font-semibold text-ink-900">{{ feature.title }}</h3>
          <p class="mt-2 text-sm leading-relaxed text-ink-600">{{ feature.body }}</p>
        </article>
      </div>
    </div>
  </section>
</template>
