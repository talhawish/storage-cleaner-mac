<script setup lang="ts">
const contactEmail = useSiteConfig().email

const faqs = [
  {
    q: 'Will Storage Cleaner delete my source code or active projects?',
    a: 'No. Source files are never a target. Inactive projects are surfaced as review items with their full path, size, and last-opened date — you decide.'
  },
  {
    q: 'How is this different from the macOS Storage Management pane?',
    a: "Apple's tool is great for casual users. Storage Cleaner understands the developer filesystem: DerivedData, node_modules, Docker layers, sim runtimes, AI model caches, language runtime versions, and more — all with full paths, exact sizes, and safety tagging."
  },
  {
    q: 'What about photos, videos, and screenshots?',
    a: 'They are always review-first. The scanner shows their full path and size, but never one-click-deletes user-created media. Cleanup is a confirmation step away, every time.'
  },
  {
    q: 'Do I need to grant Full Disk Access?',
    a: 'Only for protected developer folders (Xcode, sim runtimes, etc.). The app explains exactly which folders it needs, and you can use the rest of the inventory without granting it.'
  },
  {
    q: 'Does it upload anything?',
    a: 'No. All scanning happens locally. There is no account, no telemetry, no remote call home. The privacy policy has the details.'
  },
  {
    q: 'What happens to the free version over time?',
    a: 'The Free plan is intentionally complete for casual use. It will never nag, watermark, or hide findings. Pro exists for users who want automation.'
  }
] as const

const open = ref<number | null>(0)
const toggle = (i: number) => (open.value = open.value === i ? null : i)
</script>

<template>
  <section id="faq" class="bg-ink-50/40 py-24 sm:py-32">
    <div class="container-page">
      <div class="grid gap-12 lg:grid-cols-[1fr_1.6fr]">
        <div>
          <span class="eyebrow">FAQ</span>
          <h2 class="heading-section mt-4 text-balance">
            Everything you might want to know.
          </h2>
          <p class="lede mt-4 text-pretty">
            Still curious? Email us at
            <a :href="`mailto:${contactEmail}`" class="text-ink-900 underline decoration-ink-300 underline-offset-4 hover:decoration-ink-700">
              {{ contactEmail }}
            </a>
            — there's a real person on the other end.
          </p>
        </div>

        <ul class="divide-y divide-ink-200 border-y border-ink-200">
          <li v-for="(item, i) in faqs" :key="item.q">
            <button
              type="button"
              class="flex w-full items-start justify-between gap-6 py-5 text-left"
              :aria-expanded="open === i"
              @click="toggle(i)"
            >
              <span class="text-[15px] font-semibold tracking-[-0.01em] text-ink-900">
                {{ item.q }}
              </span>
              <span
                :class="[
                  'mt-0.5 grid size-6 shrink-0 place-items-center rounded-full border border-ink-200 text-ink-500 transition-transform',
                  open === i ? 'rotate-45 border-ink-900 bg-ink-900 text-white' : ''
                ]"
                aria-hidden="true"
              >
                <svg viewBox="0 0 16 16" class="size-3">
                  <path
                    fill="currentColor"
                    d="M8 1.5a.75.75 0 0 1 .75.75v5h5a.75.75 0 0 1 0 1.5h-5v5a.75.75 0 0 1-1.5 0v-5h-5a.75.75 0 0 1 0-1.5h5v-5A.75.75 0 0 1 8 1.5Z"
                  />
                </svg>
              </span>
            </button>
            <p
              v-show="open === i"
              class="pb-5 pr-12 text-sm leading-relaxed text-ink-600"
            >
              {{ item.a }}
            </p>
          </li>
        </ul>
      </div>
    </div>
  </section>
</template>
