<script setup lang="ts">
const props = defineProps<{ error: { statusCode?: number; statusMessage?: string; message?: string } }>()
const code = computed(() => props.error?.statusCode ?? 500)
const title = computed(() =>
  code.value === 404 ? "We couldn't find that page." : 'Something went wrong.'
)
const subtitle = computed(() =>
  code.value === 404
    ? 'The page you were looking for has moved, was renamed, or never existed.'
    : props.error?.statusMessage || 'An unexpected error occurred. We\u2019ve been notified.'
)

usePageSeo({
  title: code.value === 404 ? 'Page not found' : 'Something went wrong',
  description: subtitle.value,
  noindex: true
})

const handleHome = () => clearError({ redirect: '/' })
</script>

<template>
  <div class="grid min-h-screen place-items-center bg-white px-6 text-ink-900">
    <div class="text-center">
      <p class="font-mono text-sm tracking-[0.18em] text-ink-400">ERROR {{ code }}</p>
      <h1 class="mt-4 text-3xl font-semibold tracking-[-0.02em] sm:text-4xl">
        {{ title }}
      </h1>
      <p class="lede mx-auto mt-3 max-w-md">{{ subtitle }}</p>
      <button type="button" class="btn-primary mt-8 px-5 py-2.5" @click="handleHome">
        Back to home
      </button>
    </div>
  </div>
</template>
