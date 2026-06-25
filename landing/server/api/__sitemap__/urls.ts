/**
 * Sitemap source — exposes the static URL list to @nuxtjs/sitemap.
 */
import type { SitemapUrlInput } from '#sitemap/types'

export default defineSitemapEventHandler(() => {
  const now = new Date().toISOString()
  return [
    { loc: '/',        changefreq: 'weekly',  priority: 1.0, lastmod: now },
    { loc: '/terms',   changefreq: 'yearly',  priority: 0.3, lastmod: now },
    { loc: '/privacy', changefreq: 'yearly',  priority: 0.3, lastmod: now },
    { loc: '/contact', changefreq: 'yearly',  priority: 0.5, lastmod: now }
  ] satisfies SitemapUrlInput[]
})
