/**
 * Static OG image generator. Produces a 1200x630 PNG for the home page
 * and a per-page variant for legal/marketing pages. Run as part of the
 * build pipeline.
 *
 * The site's deploy URL is read from `nuxt.config.ts → site.url` so
 * there's only one place to change it. The display label on each card
 * is the host portion of that URL (e.g. `storagecleaner.horizam.com`).
 */
import { promises as fs } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import satori from 'satori'
import { Resvg } from '@resvg/resvg-js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const root = join(__dirname, '..')
const publicDir = join(root, 'public')

const nuxtConfig = await import('../nuxt.config.ts')
  .then((m) => m.default?.())
  .catch(async () => {
    // tsx/esm can't import .ts directly; fall back to a regex scrape
    // of the source. The script is invoked from npm, so node --import
    // tsx is wired in by the package's devDependency graph.
    const source = await fs.readFile(join(root, 'nuxt.config.ts'), 'utf8')
    const match = source.match(/url:\s*['"`]([^'"`]+)['"`]/)
    if (!match) throw new Error('Could not read site.url from nuxt.config.ts')
    return { url: match[1] }
  })

const SITE_URL = nuxtConfig.site?.url ?? nuxtConfig.url
const SITE_HOST = new URL(SITE_URL).host

const interRegular = await fs.readFile(
  join(root, 'node_modules/@fontsource/inter/files/inter-latin-400-normal.woff')
)
const interSemibold = await fs.readFile(
  join(root, 'node_modules/@fontsource/inter/files/inter-latin-600-normal.woff')
)
const interBold = await fs.readFile(
  join(root, 'node_modules/@fontsource/inter/files/inter-latin-700-normal.woff')
)
const jetbrainsMono = await fs.readFile(
  join(root, 'node_modules/@fontsource/jetbrains-mono/files/jetbrains-mono-latin-500-normal.woff')
).catch(() => null)
const appIconData = `data:image/png;base64,${await fs
  .readFile(join(publicDir, 'icon-128.png'))
  .then((data) => data.toString('base64'))}`

const fonts = [
  { name: 'Inter', data: interRegular, weight: 400, style: 'normal' },
  { name: 'Inter', data: interSemibold, weight: 600, style: 'normal' },
  { name: 'Inter', data: interBold, weight: 700, style: 'normal' },
  ...(jetbrainsMono
    ? [{ name: 'JetBrains Mono', data: jetbrainsMono, weight: 500, style: 'normal' }]
    : [])
]

const render = async (node) => {
  const svg = await satori(node, {
    width: 1200,
    height: 630,
    fonts,
    embedFont: true
  })
  const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } })
  return resvg.render().asPng()
}

const Card = ({ children, accent = false }) => ({
  type: 'div',
  props: {
    style: {
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'space-between',
      width: '1200px',
      height: '630px',
      background: accent
        ? 'linear-gradient(135deg, #0e1116 0%, #182866 100%)'
        : 'linear-gradient(135deg, #ffffff 0%, #f1f3f7 100%)',
      color: accent ? '#ffffff' : '#0e1116',
      fontFamily: 'Inter',
      padding: '72px 80px',
      position: 'relative',
      overflow: 'hidden'
    },
    children
  }
})

const HomeBackdrop = () => ({
  type: 'div',
  props: {
    style: {
      position: 'absolute',
      inset: 0,
      display: 'flex',
      backgroundImage:
        'linear-gradient(rgba(14,17,22,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(14,17,22,0.035) 1px, transparent 1px), radial-gradient(circle at 84% 46%, rgba(183,204,255,0.75) 0%, rgba(238,244,255,0.5) 28%, transparent 55%)',
      backgroundSize: '48px 48px, 48px 48px, 100% 100%'
    },
    children: ''
  }
})

const Wordmark = (props) => {
  const inverse = props?.inverse === true
  return {
    type: 'div',
    props: {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: '14px',
        color: inverse ? '#ffffff' : '#0e1116'
      },
      children: [
        {
          type: 'img',
          props: {
            src: appIconData,
            style: {
              width: '44px',
              height: '44px',
              borderRadius: '10px',
              boxShadow: '0 8px 20px rgba(15,23,42,0.18)'
            }
          }
        },
        {
          type: 'div',
          props: {
            style: { display: 'flex', flexDirection: 'column', lineHeight: 1.1 },
            children: [
              {
                type: 'div',
                props: {
                  style: { fontSize: '22px', fontWeight: 600, letterSpacing: '-0.01em' },
                  children: 'Storage Cleaner'
                }
              },
              {
                type: 'div',
                props: {
                  style: {
                    fontSize: '13px',
                    fontWeight: 500,
                    color: inverse ? 'rgba(255,255,255,0.6)' : '#6a7280',
                    letterSpacing: '0.02em'
                  },
                  children: 'for Developers'
                }
              }
            ]
          }
        }
      ]
    }
  }
}

const HomePreviewRow = ({ name, size, width, color }) => ({
  type: 'div',
  props: {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: '7px'
    },
    children: [
      {
        type: 'div',
        props: {
          style: {
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            fontSize: '14px'
          },
          children: [
            {
              type: 'div',
              props: {
                style: { display: 'flex', alignItems: 'center', gap: '9px', color: '#2f3540' },
                children: [
                  {
                    type: 'div',
                    props: {
                      style: {
                        width: '8px',
                        height: '8px',
                        borderRadius: '50%',
                        background: color
                      },
                      children: ''
                    }
                  },
                  { type: 'span', props: { children: name } }
                ]
              }
            },
            {
              type: 'span',
              props: {
                style: {
                  color: '#4a5160',
                  fontFamily: jetbrainsMono ? 'JetBrains Mono' : 'Inter',
                  fontSize: '13px'
                },
                children: size
              }
            }
          ]
        }
      },
      {
        type: 'div',
        props: {
          style: {
            display: 'flex',
            width: '100%',
            height: '6px',
            borderRadius: '999px',
            background: '#f1f3f7',
            overflow: 'hidden'
          },
          children: {
            type: 'div',
            props: {
              style: { display: 'flex', width, height: '100%', background: color },
              children: ''
            }
          }
        }
      }
    ]
  }
})

const HomeOg = () =>
  Card({
    accent: false,
    children: [
      HomeBackdrop(),
      {
        type: 'div',
        props: {
          style: {
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            position: 'relative'
          },
          children: [
            Wordmark(),
            {
              type: 'div',
              props: {
                style: {
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '6px 14px',
                  borderRadius: '9999px',
                  background: 'rgba(255,255,255,0.82)',
                  border: '1px solid #d1d6df',
                  fontSize: '14px',
                  fontWeight: 500,
                  color: '#4a5160'
                },
                children: [
                  {
                    type: 'div',
                    props: {
                      style: {
                        width: '8px',
                        height: '8px',
                        borderRadius: '50%',
                        background: '#34c08f'
                      }
                    }
                  },
                  { type: 'span', props: { children: 'Native macOS · Private by design' } }
                ]
              }
            }
          ]
        }
      },
      {
        type: 'div',
        props: {
          style: {
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '48px',
            position: 'relative'
          },
          children: [
            {
              type: 'div',
              props: {
                style: {
                  display: 'flex',
                  flexDirection: 'column',
                  width: '650px'
                },
                children: [
                  {
                    type: 'div',
                    props: {
                      style: {
                        display: 'flex',
                        flexDirection: 'column',
                        fontSize: '62px',
                        fontWeight: 700,
                        letterSpacing: '-0.035em',
                        lineHeight: 1.02,
                        color: '#0e1116'
                      },
                      children: [
                        { type: 'div', props: { children: 'Reclaim the space' } },
                        {
                          type: 'div',
                          props: {
                            style: { display: 'flex', gap: '14px' },
                            children: [
                              { type: 'span', props: { children: 'your Mac' } },
                              {
                                type: 'span',
                                props: {
                                  style: { color: '#1f3fce' },
                                  children: 'actually'
                                }
                              }
                            ]
                          }
                        },
                        { type: 'div', props: { children: 'forgot about.' } }
                      ]
                    }
                  },
                  {
                    type: 'div',
                    props: {
                      style: {
                        marginTop: '22px',
                        fontSize: '20px',
                        lineHeight: 1.45,
                        color: '#4a5160',
                        maxWidth: '625px',
                        fontWeight: 400
                      },
                      children:
                        'See exactly which builds, caches, simulators, containers, and AI models are eating your disk — before you clean a thing.'
                    }
                  },
                  {
                    type: 'div',
                    props: {
                      style: {
                        display: 'flex',
                        alignItems: 'center',
                        gap: '10px',
                        marginTop: '28px'
                      },
                      children: ['15+ developer domains', 'Trash-first cleanup', 'Free to scan'].map(
                        (label) => ({
                          type: 'div',
                          props: {
                            style: {
                              display: 'flex',
                              padding: '7px 12px',
                              borderRadius: '999px',
                              background: '#ffffff',
                              border: '1px solid #e6e9ef',
                              color: '#4a5160',
                              fontSize: '13px',
                              fontWeight: 600
                            },
                            children: label
                          }
                        })
                      )
                    }
                  }
                ]
              }
            },
            {
              type: 'div',
              props: {
                style: {
                  display: 'flex',
                  flexDirection: 'column',
                  width: '350px',
                  padding: '25px',
                  borderRadius: '24px',
                  background: 'rgba(255,255,255,0.94)',
                  border: '1px solid #dbe6ff',
                  boxShadow: '0 24px 60px rgba(31,63,206,0.15), 0 6px 18px rgba(15,23,42,0.08)'
                },
                children: [
                  {
                    type: 'div',
                    props: {
                      style: {
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between'
                      },
                      children: [
                        {
                          type: 'span',
                          props: {
                            style: {
                              fontSize: '12px',
                              fontWeight: 700,
                              color: '#6a7280',
                              letterSpacing: '0.08em'
                            },
                            children: 'SCAN COMPLETE'
                          }
                        },
                        {
                          type: 'div',
                          props: {
                            style: {
                              display: 'flex',
                              alignItems: 'center',
                              gap: '6px',
                              color: '#16805d',
                              fontSize: '12px',
                              fontWeight: 600
                            },
                            children: [
                              {
                                type: 'div',
                                props: {
                                  style: {
                                    display: 'flex',
                                    width: '7px',
                                    height: '7px',
                                    borderRadius: '50%',
                                    background: '#34c08f'
                                  },
                                  children: ''
                                }
                              },
                              { type: 'span', props: { children: 'Local only' } }
                            ]
                          }
                        }
                      ]
                    }
                  },
                  {
                    type: 'div',
                    props: {
                      style: {
                        display: 'flex',
                        alignItems: 'baseline',
                        gap: '10px',
                        marginTop: '18px'
                      },
                      children: [
                        {
                          type: 'span',
                          props: {
                            style: {
                              fontFamily: jetbrainsMono ? 'JetBrains Mono' : 'Inter',
                              fontSize: '43px',
                              fontWeight: 600,
                              letterSpacing: '-0.04em',
                              color: '#0e1116'
                            },
                            children: '87.4 GB'
                          }
                        },
                        {
                          type: 'span',
                          props: { style: { fontSize: '13px', color: '#6a7280' }, children: 'reclaimable' }
                        }
                      ]
                    }
                  },
                  {
                    type: 'div',
                    props: {
                      style: {
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '17px',
                        marginTop: '23px'
                      },
                      children: [
                        HomePreviewRow({ name: 'Xcode', size: '32.1 GB', width: '92%', color: '#2f57f0' }),
                        HomePreviewRow({ name: 'Web', size: '18.7 GB', width: '64%', color: '#2bb4d8' }),
                        HomePreviewRow({ name: 'Docker', size: '12.3 GB', width: '44%', color: '#9461f5' }),
                        HomePreviewRow({ name: 'Mobile', size: '8.9 GB', width: '32%', color: '#34c08f' }),
                        HomePreviewRow({ name: 'AI & ML', size: '7.2 GB', width: '26%', color: '#f5914a' })
                      ]
                    }
                  },
                  {
                    type: 'div',
                    props: {
                      style: {
                        display: 'flex',
                        justifyContent: 'center',
                        marginTop: '22px',
                        padding: '9px 12px',
                        borderRadius: '10px',
                        background: '#eef4ff',
                        color: '#1f3fce',
                        fontSize: '13px',
                        fontWeight: 600
                      },
                      children: 'Preview everything · Clean safely'
                    }
                  }
                ]
              }
            }
          ]
        }
      },
      {
        type: 'div',
        props: {
          style: {
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-start',
            color: '#6a7280',
            fontSize: '14px',
            position: 'relative'
          },
          children: SITE_HOST
        }
      }
    ]
  })

const PageOg = (props) => {
  const title = props.title
  const eyebrow = props.eyebrow
  return Card({
    accent: false,
    children: [
      {
        type: 'div',
        props: {
          style: { display: 'flex', flexDirection: 'column', gap: '20px' },
          children: [
            {
              type: 'div',
              props: {
                style: {
                  display: 'flex',
                  alignItems: 'center',
                  padding: '6px 14px',
                  borderRadius: '9999px',
                  background: '#f1f3f7',
                  border: '1px solid #e6e9ef',
                  fontSize: '14px',
                  fontWeight: 500,
                  color: '#4a5160',
                  width: 160
                },
                children: eyebrow
              }
            },
            {
              type: 'div',
              props: {
                style: {
                  fontSize: '64px',
                  fontWeight: 700,
                  letterSpacing: '-0.025em',
                  lineHeight: 1.05,
                  color: '#0e1116',
                  maxWidth: '980px'
                },
                children: title
              }
            },
            {
              type: 'div',
              props: {
                style: {
                  fontSize: '20px',
                  lineHeight: 1.5,
                  color: '#4a5160',
                  maxWidth: '780px',
                  fontWeight: 400
                },
                children:
                  'A native macOS storage inspector built for the way developers actually work.'
              }
            }
          ]
        }
      },
      {
        type: 'div',
        props: {
          style: {
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between'
          },
          children: [Wordmark(), { type: 'div', props: { children: SITE_HOST } }]
        }
      }
    ]
  })
}

const targets = [
  { file: 'og-image.png', tree: HomeOg() },
  { file: 'og-image-terms.png', tree: PageOg({ title: 'Terms & Conditions', eyebrow: 'Legal' }) },
  { file: 'og-image-privacy.png', tree: PageOg({ title: 'Privacy Policy', eyebrow: 'Legal' }) },
  { file: 'og-image-contact.png', tree: PageOg({ title: 'Contact us', eyebrow: 'Get in touch' }) }
]

await fs.mkdir(publicDir, { recursive: true })
for (const target of targets) {
  const png = await render(target.tree)
  await fs.writeFile(join(publicDir, target.file), png)
  console.log(`✓ ${target.file} (${png.length} bytes)`)
}
