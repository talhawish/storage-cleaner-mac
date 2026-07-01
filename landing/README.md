# Landing — Storage Cleaner for Developers

A statically generated Nuxt 4 site that hosts the marketing pages, legal
documents, and contact flow for the Storage Cleaner for Developers macOS app.

## Stack

- **Nuxt 4** (`4.4.x`) with the `app/` source layout
- **Vue 3.5** + **TypeScript**
- **Tailwind CSS 4** via `@tailwindcss/vite` — all design tokens (colors,
  radii, typography, domain accents) live in a single `@theme` block in
  `app/assets/css/main.css`
- **@nuxt/fonts** for the Inter web font (Google)
- **@nuxtjs/sitemap** for `sitemap.xml`
- **Satori + @resvg/resvg-js** for the static Open Graph cards
  (`scripts/og-image.mjs`)
- **@vueuse/nuxt** for a couple of small interactive primitives

The output is a fully static site: every HTML page, asset, and image is
pre-rendered into `.output/public/` at build time and can be served from
any static host (Vercel, Netlify, Cloudflare Pages, S3 + CloudFront, …).

---

## 0 · Single source of truth for the deploy URL & contact email

Two values are common to every page: the **deploy URL** and the
**contact email**. Both are declared exactly once — in
`nuxt.config.ts → site` — and every other module reads them at runtime
via `useSiteConfig()`.

### What reads `site.url`

| What | Where it reads from |
| --- | --- |
| Sitemap `<loc>` entries | `useSiteConfig().url` (via `@nuxtjs/sitemap`) |
| `<link rel="canonical">`, `og:url`, `og:image`, `twitter:image` | `useSiteConfig().url` (via `usePageSeo`) |
| `robots.txt` `Sitemap:` pointer | `useSiteConfig().url` (via `server/routes/robots.txt.ts`) |
| `SoftwareApplication` JSON-LD `url` / `author.url` | `useSiteConfig().url` |
| OG card footer label | `scripts/og-image.mjs` imports `nuxt.config.ts` and reads `site.url`, then displays its `host` |
| Contact form "Sent from" prefill | `useSiteConfig().url` |

### What reads `site.email`

| What | Where it reads from |
| --- | --- |
| SiteFooter "Company" column mailto + label | `useSiteConfig().email` |
| SectionFaq "Email us at" link | `useSiteConfig().email` |
| Contact page mailto (submit handler + 3 channel cards + response-time link + consent line) | `useSiteConfig().email` |
| Terms section 11 ("Contact") | `useSiteConfig().email` |
| Privacy sections 5, 8, 10 ("Crash reports", "Your rights", "Contact") | `useSiteConfig().email` |

### To move the site or change the contact email

Edit **two lines** in `nuxt.config.ts`:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  // ...
  site: {
    url:   'https://your-new-domain.example.com',  // ← change here
    email: 'support@your-new-domain.example.com',  // ← and here
    // ...
  }
})
```

Then `npm run build`. The sitemap, robots, canonical, OG tags, JSON-LD,
and the four OG cards all pick up the new host on the next build. The
macOS app reads its own copy of the terms/privacy URLs from
`StorageCleaner/Core/Models/AppLinks.swift` — keep that in sync manually.

---

## 1 · Setup

### Prerequisites

- **Node.js 20.x or 22.x** (LTS)
- **npm 10+** (ships with the Node releases above)

No other system tooling is required. The site is fully self-contained — no
database, no external API, no environment variables.

### Install

```bash
cd landing
npm install
```

`postinstall` runs `nuxt prepare` automatically, which generates the
`.nuxt/` type definitions and Nitro stubs.

### Develop

```bash
npm run dev
# → http://localhost:3000
```

The dev server uses on-demand SSR. Edits to any `.vue` or `.css` file
hot-reload instantly; the OG image, sitemap, and prerender are only
recomputed on a real `npm run build`.

### Build

```bash
npm run build
# → static site written to .output/public
```

`build` is a two-stage pipeline:

1. `npm run og:image` — regenerates the static OG cards (see §3 below)
2. `npx nuxt build --preset=static` — prerenders every page and emits
   `sitemap.xml` + `robots.txt` to `.output/public/`

To skip the OG image step during iteration, run `nuxt build` directly:

```bash
npx nuxt build --preset=static
```

### Preview the production output

```bash
npx serve .output/public
# → http://localhost:3000
```

Any static-file server works. There is no Node runtime required in
production.

---

## 2 · Sitemap

### How it works

The sitemap is generated automatically at build time by
**`@nuxtjs/sitemap`** (configured in `nuxt.config.ts`). It reads URL
definitions from `server/api/__sitemap__/urls.ts`:

```ts
// server/api/__sitemap__/urls.ts
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
```

`site.url` from `nuxt.config.ts` (`https://storagecleaner.horizm.com`) is
prepended to every relative path, so each entry resolves to its full
absolute URL. **This file is the single source of truth for the deploy
URL** — see the box below.

### Output

After `npm run build` you will find:

```text
.output/public/sitemap.xml    # generated, served at /sitemap.xml
.output/public/robots.txt     # generated by server/routes/robots.txt.ts
```

`robots.txt` is generated at build time by
`server/routes/robots.txt.ts`, which reads `site.url` from
`nuxt.config.ts` so the sitemap pointer can never drift:

```text
User-agent: *
Allow: /

Sitemap: https://storagecleaner.horizm.com/sitemap.xml
```

### Adding or changing a page

1. Create the page under `app/pages/`
2. Add an entry to `server/api/__sitemap__/urls.ts` (with the right
   `changefreq` and `priority` for that page's role in the site)
3. Run `npm run build` — the sitemap updates on the next build

There is no need to run a separate script; the sitemap is always in sync
with the prerender.

---

## 3 · Open Graph images (social cards)

The site ships with four pre-rendered 1200 × 630 PNG social cards, one per
page. They are committed to the repo under `public/`:

```text
public/og-image.png           # / (home)
public/og-image-terms.png     # /terms
public/og-image-privacy.png   # /privacy
public/og-image-contact.png   # /contact
```

Each page references its own card from `usePageSeo({ image: '/og-image-…' })`
so the right preview is shown on Twitter, LinkedIn, iMessage, Slack, etc.

### How they are generated

OG cards are produced by `scripts/og-image.mjs` using **Satori**
(Vercel's SVG-from-React renderer) plus **`@resvg/resvg-js`** to rasterise
the SVG into a PNG. The script is a single self-contained Node file — no
browser, no headless Chrome, no external API.

It runs:

- **Automatically** as the first step of `npm run build` (see
  `scripts.og:image` in `package.json`)
- **Manually** with `npm run og:image` whenever the home/legal/contact
  headlines change

```bash
# Re-generate the four OG cards after editing copy or layout
npm run og:image
# → public/og-image.png            (~200 KB, dark home card)
# → public/og-image-terms.png      (~70 KB, light legal card)
# → public/og-image-privacy.png    (~70 KB, light legal card)
# → public/og-image-contact.png    (~70 KB, light card)
```

The script reads Inter from `node_modules/@fontsource/inter/` (the same
web font used by the site), so the rendered text matches the page
typography exactly. To change a headline, edit the relevant `PageOg({...})`
call at the bottom of `scripts/og-image.mjs` and re-run.

### Favicons & touch icons

The favicon set lives next to the OG images and is wired in
`nuxt.config.ts → app.head.link`:

| File | Size | Purpose |
| --- | --- | --- |
| `public/icon-16.png` | 16 × 16 | browser tab |
| `public/icon-32.png` | 32 × 32 | browser tab (HiDPI) |
| `public/icon-128.png` | 128 × 128 | header / footer logo |
| `public/icon-256.png` | 256 × 256 | PWA / app launchers |
| `public/icon-512.png` | 512 × 512 | `apple-touch-icon` |
| `public/icon-1024.png` | 1024 × 1024 | App Store / largest landing icon |
| `public/safari-pinned-tab.svg` | — | Safari pinned-tab (monochrome) |

The master artwork is `../Assets/storage-cleaner-app-icon-2026.png`. The
landing icons are scaled from the same source as
`../StorageCleaner/Assets.xcassets/AppIcon.appiconset/`, so the marketing site,
the macOS app, and the DMG volume icon generated by `../build.sh` share the same
artwork.

---

## Project layout

```text
landing/
├── app/
│   ├── app.vue                  # Root component
│   ├── error.vue                # 404 / 500 page
│   ├── assets/css/main.css      # Tailwind 4 entry + design tokens
│   ├── components/              # Site sections + shared UI
│   │   ├── SiteHeader.vue
│   │   ├── SiteFooter.vue
│   │   ├── SectionFeatures.vue
│   │   ├── SectionCoverage.vue
│   │   ├── SectionWorkflow.vue
│   │   ├── SectionSafety.vue
│   │   ├── SectionPricing.vue
│   │   ├── SectionFaq.vue
│   │   ├── SectionCta.vue
│   │   ├── AppWindow.vue
│   │   ├── DashboardPreview.vue
│   │   └── PreviewRow.vue
│   ├── composables/
│   │   └── usePageSeo.ts        # Single source of truth for page SEO
│   ├── layouts/
│   │   └── default.vue
│   └── pages/
│       ├── index.vue            # Landing
│       ├── terms.vue
│       ├── privacy.vue
│       └── contact.vue
├── public/
│   ├── icon-*.png               # AppIcon assets (favicons / apple-touch-icon)
│   ├── og-image*.png            # Pre-generated social cards
│   └── safari-pinned-tab.svg
├── scripts/
│   └── og-image.mjs             # Satori + resvg static OG image generator
├── server/
│   ├── api/__sitemap__/urls.ts  # Sitemap source-of-truth
│   └── routes/
│       ├── robots.txt.ts        # Built from nuxt.config.ts → site.url
│       └── firebase-messaging-sw.js.ts   # 204 stub for dev tooling probes
├── nuxt.config.ts
└── package.json
```

## Design tokens

Colors, radii, and typography are defined once in
`app/assets/css/main.css` inside the `@theme { ... }` block. Custom
component primitives (`.btn`, `.btn-primary`, `.btn-secondary`,
`.container-page`, `.eyebrow`, etc.) are also declared there so they
stay in sync with the rest of the design system.

Domain accent colors mirror the macOS app's `AppTheme` palette (Apple,
Web, Docker, Mobile, AI, Media, Photo, Browser, etc.) so the marketing
site and the in-app dashboard feel like one product.

## SEO

Every page calls `usePageSeo({ title, description, path, image })` from
`app/composables/usePageSeo.ts`. The composable is the single source of
truth for:

- `<title>` and `titleTemplate`
- `<meta name="description">` and per-page keywords
- All `og:*` tags (title, description, type, url, site_name, locale, image
  with explicit 1200 × 630 dimensions, image alt)
- All `twitter:*` tags (card, site, creator, title, description, image,
  image alt)
- `<link rel="canonical">`
- A `SoftwareApplication` JSON-LD block for rich results

The per-page OG image is selected by passing `image: '/og-image-…'`. New
pages should ship a matching pre-rendered card in `public/`.
