/**
 * /robots.txt — built from the same `site.url` declared in
 * nuxt.config.ts so the sitemap pointer never drifts.
 */
export default defineEventHandler((event) => {
  const config = getSiteConfig(event)
  const sitemapUrl = new URL('/sitemap.xml', config.url).toString()
  setResponseHeader(event, 'Content-Type', 'text/plain; charset=utf-8')
  return `User-agent: *
Allow: /

Sitemap: ${sitemapUrl}
`
})
