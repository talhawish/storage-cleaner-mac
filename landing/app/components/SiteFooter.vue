<script setup lang="ts">
const year = new Date().getFullYear()
</script>

<template>
  <footer class="border-t border-ink-200 bg-ink-50/60">
    <div class="container-page py-14">
      <div class="grid gap-10 lg:grid-cols-[1.6fr_1fr_1fr]">
        <div>
          <div class="flex items-center gap-2.5">
            <img
              src="/icon-128.png"
              alt=""
              width="32"
              height="32"
              class="h-8 w-8 rounded-[8px] shadow-[0_4px_12px_-4px_rgba(15,23,42,0.25)]"
            />
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
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-ink-500">Company</h3>
          <ul class="mt-4 space-y-2.5 text-sm">
            <li><NuxtLink to="/contact" class="text-ink-700 hover:text-ink-900">Contact us</NuxtLink></li>
            <li>
              <a href="mailto:support@storagecleaner.app" class="text-ink-700 hover:text-ink-900">
                support@storagecleaner.app
              </a>
            </li>
            <li><NuxtLink to="/terms" class="text-ink-700 hover:text-ink-900">Terms &amp; Conditions</NuxtLink></li>
            <li><NuxtLink to="/privacy" class="text-ink-700 hover:text-ink-900">Privacy Policy</NuxtLink></li>
          </ul>
        </div>
      </div>

      <div class="mt-12 flex flex-col items-start justify-between gap-4 border-t border-ink-200 pt-6 text-xs text-ink-500 sm:flex-row sm:items-center">
        <p>© {{ year }} Storage Cleaner for Developers. All rights reserved.</p>
        <p>Built with care on macOS.</p>
      </div>
    </div>
  </footer>
</template>
