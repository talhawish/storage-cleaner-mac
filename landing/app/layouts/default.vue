<template>
  <div class="min-h-screen flex flex-col bg-white text-ink-900">
    <SiteHeader />
    <main id="content" class="flex-1">
      <slot />
    </main>
    <SiteFooter />
  </div>
</template>
