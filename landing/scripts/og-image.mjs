/**
 * Static OG image generator. Produces a 1200x630 PNG for the home page
 * and a per-page variant for legal/marketing pages. Run as part of the
 * build pipeline.
 */
import { promises as fs } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import satori from 'satori'
import { Resvg } from '@resvg/resvg-js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const root = join(__dirname, '..')
const publicDir = join(root, 'public')

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

const Watermark = () => ({
  type: 'div',
  props: {
    style: {
      position: 'absolute',
      inset: 0,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      opacity: 0.06
    },
    children: {
      type: 'div',
      props: {
        style: {
          width: '720px',
          height: '720px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, currentColor 0%, transparent 60%)'
        }
      }
    }
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
          type: 'div',
          props: {
            style: {
              width: '44px',
              height: '44px',
              borderRadius: '10px',
              background: inverse ? '#ffffff' : '#0e1116',
              color: inverse ? '#0e1116' : '#ffffff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 700,
              fontSize: '22px'
            },
            children: 'SC'
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

const HomeOg = () =>
  Card({
    accent: true,
    children: [
      Watermark(),
      {
        type: 'div',
        props: {
          style: { display: 'flex', flexDirection: 'column', gap: '20px', position: 'relative' },
          children: [
            {
              type: 'div',
              props: {
                style: {
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '6px 14px',
                  borderRadius: '9999px',
                  background: 'rgba(255,255,255,0.08)',
                  border: '1px solid rgba(255,255,255,0.15)',
                  fontSize: '14px',
                  fontWeight: 500,
                  width: 360
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
                  { type: 'span', props: { children: 'Native macOS · Apple silicon & Intel' } }
                ]
              }
            },
            {
              type: 'div',
              props: {
                style: {
                  fontSize: '76px',
                  fontWeight: 700,
                  letterSpacing: '-0.03em',
                  lineHeight: 1.02,
                  maxWidth: '980px'
                },
                children: 'Reclaim the space your Mac actually forgot about.'
              }
            },
            {
              type: 'div',
              props: {
                style: {
                  fontSize: '22px',
                  lineHeight: 1.4,
                  color: 'rgba(255,255,255,0.7)',
                  maxWidth: '820px',
                  fontWeight: 400
                },
                children:
                  'A native storage inspector for developers. See which builds, caches, simulators, and containers are eating your disk — then clean them with full preview, audit trail, and Trash-based safety.'
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
            position: 'relative'
          },
          children: [Wordmark({ inverse: true }), { type: 'div', props: { children: 'storagecleaner.app' } }]
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
          children: [Wordmark(), { type: 'div', props: { children: 'storagecleaner.app' } }]
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
