<script setup lang="ts">
const year = new Date().getFullYear()
</script>

<template>
  <footer class="border-t border-ink-200 bg-ink-50/60">
    <div class="container-page py-14">
      <div class="grid gap-10 lg:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <div class="flex items-center gap-2.5">
            <span
              class="grid h-8 w-8 place-items-center rounded-lg bg-ink-900 text-white"
              aria-hidden="true"
            >
              <svg viewBox="0 0 24 24" class="h-4 w-4">
                <path
                  fill="currentColor"
                  d="M4 7a3 3 0 0 1 3-3h7l5 5v8a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3V7Zm12 .5V4l4 4h-3.5A.5.5 0 0 1 16 7.5ZM7 11.5a.75.75 0 0 0 0 1.5h6a.75.75 0 0 0 0-1.5H7Zm0 3.5a.75.75 0 0 0 0 1.5h4a.75.75 0 0 0 0-1.5H7Z"
                />
              </svg>
            </span>
            <span class="text-[15px] font-semibold tracking-[-0.01em] text-ink-900">
              Storage Cleaner
              <span class="ml-1 text-ink-500 font-normal">for Developers</span>
            </span>
          </div>
          <p class="mt-4 max-w-sm text-sm leading-relaxed text-ink-600">
            A native macOS utility that helps developers see where every gigabyte
            goes — and safely reclaim the ones they don't need.
          </p>
          <p class="mt-5 inline-flex items-center gap-2 text-xs text-ink-500">
            <span class="size-1.5 rounded-full bg-emerald-500" aria-hidden="true" />
            macOS 14 Sonoma or later · Apple silicon & Intel
          </p>
        </div>

        <div>
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-ink-500">Product</h3>
          <ul class="mt-4 space-y-2.5 text-sm">
            <li><NuxtLink to="/#features" class="text-ink-700 hover:text-ink-900">Features</NuxtLink></li>
            <li><NuxtLink to="/#coverage" class="text-ink-700 hover:text-ink-900">Detection coverage</NuxtLink></li>
            <li><NuxtLink to="/#workflow" class="text-ink-700 hover:text-ink-900">How it works</NuxtLink></li>
            <li><NuxtLink to="/#pricing" class="text-ink-700 hover:text-ink-900">Pricing</NuxtLink></li>
            <li><NuxtLink to="/#faq" class="text-ink-700 hover:text-ink-900">FAQ</NuxtLink></li>
          </ul>
        </div>

        <div>
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-ink-500">Resources</h3>
          <ul class="mt-4 space-y-2.5 text-sm">
            <li>
              <a href="https://github.com/talhawish/storage-cleaner-mac" class="text-ink-700 hover:text-ink-900">
                Source on GitHub
              </a>
            </li>
            <li>
              <a href="https://github.com/talhawish/storage-cleaner-mac/releases" class="text-ink-700 hover:text-ink-900">
                Release notes
              </a>
            </li>
            <li>
              <a href="mailto:support@storagecleaner.app" class="text-ink-700 hover:text-ink-900">
                support@storagecleaner.app
              </a>
            </li>
          </ul>
        </div>

        <div>
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-ink-500">Legal</h3>
          <ul class="mt-4 space-y-2.5 text-sm">
            <li><NuxtLink to="/terms" class="text-ink-700 hover:text-ink-900">Terms & Conditions</NuxtLink></li>
            <li><NuxtLink to="/privacy" class="text-ink-700 hover:text-ink-900">Privacy Policy</NuxtLink></li>
            <li><NuxtLink to="/contact" class="text-ink-700 hover:text-ink-900">Contact us</NuxtLink></li>
          </ul>
        </div>
      </div>

      <div class="mt-12 flex flex-col items-start justify-between gap-4 border-t border-ink-200 pt-6 text-xs text-ink-500 sm:flex-row sm:items-center">
        <p>© {{ year }} Storage Cleaner for Developers. All rights reserved.</p>
        <p class="flex items-center gap-2">
          <span>Built with care on macOS.</span>
          <span aria-hidden="true">·</span>
          <a href="https://github.com/talhawish/storage-cleaner-mac" class="hover:text-ink-900">
            v0.9.0
          </a>
        </p>
      </div>
    </div>
  </footer>
</template>
