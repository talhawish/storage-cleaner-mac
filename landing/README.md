# Landing — Storage Cleaner for Developers

A statically generated Nuxt 4 site that hosts the marketing pages, legal
documents, and contact flow for the Storage Cleaner for Developers macOS app.

## Stack

- **Nuxt 4** (latest, `4.4.8`) with the `app/` source layout
- **Vue 3.5** + **TypeScript**
- **Tailwind CSS 4** (via `@tailwindcss/vite`) — theme tokens live in a single
  `@theme` block in `app/assets/css/main.css`
- **@nuxtjs/sitemap** for `sitemap.xml` and **nuxt-og-image** for the dynamic
  OG-image module (we pre-generate static `og-image*.png` files with satori
  for the SSG build)
- **@vueuse/nuxt** for a couple of small interactive primitives

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
│   ├── icon-*.png               # AppIcon assets
│   ├── og-image*.png            # Pre-generated social cards
│   ├── safari-pinned-tab.svg
│   └── robots.txt
├── scripts/
│   └── og-image.mjs             # Satori-based static OG image generator
├── nuxt.config.ts
└── package.json
```

## Local development

```bash
npm install
npm run og:image    # one-off, or run automatically as part of `npm run build`
npm run dev         # http://localhost:3000
```

## Production build

```bash
npm run build       # writes static site to .output/public
npm run preview     # serve the built site
```

## Design tokens

Colors, radii, and typography are defined once in `app/assets/css/main.css`
inside the `@theme { ... }` block. Custom component primitives (`.btn`,
`.btn-primary`, `.btn-secondary`, `.container-page`, `.eyebrow`, etc.) are
also declared there so they stay in sync with the rest of the design system.

Domain accent colors mirror the macOS app's `AppTheme` palette (Apple, Web,
Docker, Mobile, AI, Media, Photo, Browser, etc.) so the marketing site and
the in-app dashboard feel like one product.

## SEO

Every page calls `usePageSeo({ title, description, path, image })` from
`app/composables/usePageSeo.ts`. The composable:

- Sets the document title and `titleTemplate`
- Emits all `og:*` and `twitter:*` tags (with 1200×630 image, alt text, and
  explicit `og:type`)
- Sets `link rel="canonical"`
- Injects a `SoftwareApplication` JSON-LD block

`sitemap.xml` is produced by `@nuxtjs/sitemap` from
`server/api/__sitemap__/urls.ts`, and `robots.txt` lives in `public/`.
