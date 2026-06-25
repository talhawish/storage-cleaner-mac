// https://nuxt.com/docs/api/configuration/nuxt-config
import tailwindcss from '@tailwindcss/vite'

export default defineNuxtConfig({
  compatibilityDate: '2025-12-01',
  devtools: { enabled: false },
  ssr: true,

  modules: [
    '@nuxt/fonts',
    '@nuxtjs/sitemap',
    '@nuxt/image',
    '@vueuse/nuxt'
  ],

  css: ['~/assets/css/main.css'],

  app: {
    head: {
      htmlAttrs: { lang: 'en' },
      bodyAttrs: { class: 'antialiased text-ink-900 bg-white' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
        { name: 'theme-color', content: '#ffffff' },
        { name: 'format-detection', content: 'telephone=no' },
        { name: 'color-scheme', content: 'light' }
      ],
      link: [
        { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/icon-32.png' },
        { rel: 'icon', type: 'image/png', sizes: '128x128', href: '/icon-128.png' },
        { rel: 'icon', type: 'image/png', sizes: '256x256', href: '/icon-256.png' },
        { rel: 'apple-touch-icon', sizes: '512x512', href: '/icon-512.png' },
        { rel: 'mask-icon', href: '/safari-pinned-tab.svg', color: '#1f3fce' }
      ]
    }
  },

  site: {
    url: 'https://storagecleaner.horizm.com',
    name: 'Storage Cleaner for Developers',
    description: 'A native macOS app that helps developers understand, scan and safely reclaim storage used by build artifacts, caches, simulators, Docker, and more.',
    defaultLocale: 'en',
    /** Primary contact email — read at runtime via `useSiteConfig().email`. */
    email: 'info@horizam.com'
  },

  ogImage: {
    enabled: false
  },

  fonts: {
    families: [
      { name: 'Inter', provider: 'google', weights: [400, 600, 700] }
    ]
  },

  sitemap: {
    sources: ['/api/__sitemap__/urls']
  },

  nitro: {
    prerender: {
      crawlLinks: true,
      routes: ['/', '/terms', '/privacy', '/contact', '/sitemap.xml', '/robots.txt']
    }
  },

  image: {
    quality: 90,
    format: ['webp', 'avif', 'png']
  },

  vite: {
    plugins: [tailwindcss()]
  },

  typescript: {
    strict: true,
    typeCheck: false
  }
})
