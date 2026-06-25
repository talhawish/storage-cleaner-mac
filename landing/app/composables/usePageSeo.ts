/**
 * Single source of truth for the site's SEO.
 * Update values here — every page picks them up via the `usePageSeo` helper.
 *
 * The site's `url` is defined in nuxt.config.ts → `site.url` and pulled
 * at runtime via `useSiteConfig()`. This composable is the only place
 * that re-exports the derived helpers (full URL, absolute OG image, etc.)
 * so call sites never duplicate the deploy target.
 */
/**
 * Copy-only constants. Anything that varies per-deploy (the URL and the
 * contact email) lives in `nuxt.config.ts → site` and is read at runtime
 * via `useSiteConfig()`.
 */
export const site = {
  name: 'Storage Cleaner for Developers',
  shortName: 'Storage Cleaner',
  tagline: 'Reclaim the space your Mac actually forgot about.',
  description:
    'A native macOS app that helps developers understand and safely reclaim storage used by build artifacts, package caches, simulators, Docker, runtime versions, and other development tools.',
  ogImage: '/og-image.png',
  locale: 'en_US',
  twitter: '@storagecleaner',
  twitterId: 'storagecleaner',
  author: 'Storage Cleaner',
  keywords: [
    'mac storage cleaner',
    'developer tools',
    'macos storage',
    'Xcode DerivedData',
    'node_modules cleaner',
    'Docker cleanup',
    'simulator cleanup',
    'duplicate file finder',
    'system junk',
    'build cache',
    'browser cache',
    'large file finder',
    'mac developer utility',
    'native mac app'
  ] as const
} as const

export type SeoOptions = {
  title?: string
  description?: string
  image?: string
  path?: string
  type?: 'website' | 'article'
  publishedTime?: string
  modifiedTime?: string
  noindex?: boolean
  keywords?: string[]
}

const truncate = (value: string, max = 160) =>
  value.length > max ? `${value.slice(0, max - 1).trimEnd()}…` : value

export const usePageSeo = (options: SeoOptions = {}) => {
  const route = useRoute()
  const config = useSiteConfig()

  const path = options.path ?? route.path
  const isHome = path === '/'
  const baseTitle = options.title ?? site.tagline
  const fullTitle = isHome ? site.name : `${baseTitle} — ${site.name}`
  const description = truncate(options.description ?? site.description, 160)
  const url = new URL(path, config.url).toString()
  const image = options.image
    ? new URL(options.image, config.url).toString()
    : new URL(site.ogImage, config.url).toString()
  const authorUrl = new URL('/', config.url).toString().replace(/\/$/, '')
  const type = options.type ?? 'website'
  const keywords = (options.keywords ?? site.keywords).join(', ')

  useSeoMeta({
    title: fullTitle,
    description,
    applicationName: site.name,
    author: site.author,
    generator: 'Nuxt',
    keywords,
    referrer: 'strict-origin-when-cross-origin',
    colorScheme: 'light',
    themeColor: '#ffffff',
    formatDetection: 'telephone=no',
    ogTitle: fullTitle,
    ogDescription: description,
    ogType: type,
    ogUrl: url,
    ogSiteName: site.name,
    ogLocale: site.locale,
    ogImage: image,
    ogImageAlt: fullTitle,
    ogImageWidth: 1200,
    ogImageHeight: 630,
    ogImageType: 'image/png',
    twitterCard: 'summary_large_image',
    twitterSite: site.twitter,
    twitterCreator: site.twitter,
    twitterTitle: fullTitle,
    twitterDescription: description,
    twitterImage: image,
    twitterImageAlt: fullTitle,
    ...(options.publishedTime ? { articlePublishedTime: options.publishedTime } : {}),
    ...(options.modifiedTime ? { articleModifiedTime: options.modifiedTime } : {}),
    ...(options.noindex ? { robots: 'noindex,nofollow' } : { robots: 'index,follow' })
  })

  useHead({
    htmlAttrs: { lang: 'en' },
    titleTemplate: (chunk?: string) => (chunk ? chunk : site.name),
    link: [
      { rel: 'canonical', href: url }
    ],
    script: [
      {
        type: 'application/ld+json',
        innerHTML: JSON.stringify({
          '@context': 'https://schema.org',
          '@type': 'SoftwareApplication',
          name: site.name,
          description: site.description,
          url: config.url,
          applicationCategory: 'DeveloperApplication',
          operatingSystem: 'macOS 14 Sonoma or later',
          offers: {
            '@type': 'Offer',
            price: '0',
            priceCurrency: 'USD',
            category: 'Free with in-app purchases'
          },
          author: { '@type': 'Organization', name: site.author, url: authorUrl }
        })
      }
    ]
  })

  return { title: fullTitle, description, url, image }
}
