# Storage Cleaner for Developers — launch film

The finished launch video is `out/storage-cleaner-launch-36s.mp4`.

## Video

- 36 seconds, 1920 × 1080, 30 fps (16:9)
- H.264 video in Rec.709 with AAC stereo audio; lossless PNG frames feed the encoder
- Designed for X, LinkedIn, and product launch pages
- Large Manrope headlines and a focused cleanup preview with readable paths
- Original Three.js models: drive, storage cluster, segmented ring, source folder, runtime tiles, container, AI sphere, and simulator
- Frame-driven 3D animation, lighting, smooth cursor selection, and two blue wipe transitions
- Original 120 BPM stereo score with room reflections, delay, and loudness normalization (target −18 LUFS / −2 dBTP)
- Fonts, product icon, music, and all geometry resolve locally; no remote media is needed at render time

## Storyboard

| Time | Scene | Message |
| --- | --- | --- |
| 0–3 s | Storage pressure | Mac full? Look closer before buying a bigger Mac |
| 3–6 s | Hidden storage | Builds, caches, and models accumulate |
| 6–11 s | Discovery | Find what is filling your Mac, with an illustrative 87.4 GB scan |
| 11–16 s | Hibernation | Keep source; send rebuildable dependencies to Trash |
| 16–20 s | Runtime versions | Review installed versions and choose what stays |
| 20–25 s | Heavy storage | Docker, local AI, simulators, Gradle, builds, APKs, files, and apps |
| 25–30 s | Cleanup preview | Select findings and review exact paths |
| 30–36 s | Resolution and CTA | More room, same Mac; Mac App Store and website |

The scan visualization uses the illustrative values shown on the [product website](https://storagecleaner.horizam.com/). The video labels this an example scan and says actual results vary; it does not promise a specific recovery amount.

## Re-render

From this folder:

```sh
corepack pnpm install
corepack pnpm run lint
corepack pnpm run render
```

The render script regenerates and masters `public/launch-score.wav` using Remotion's bundled FFmpeg, then exports the MP4 to `out/`. ANGLE rendering is configured for Three.js. Remotion may download its Chrome Headless Shell on the first render.

## Project contents

- `src/film/` — the new design system, eight shots, and original 3D models
- `src/scenes/` — retained source for the previous visual direction
- `scripts/make-score.mjs` — deterministic original 36-second music score generator
- `public/app-icon.png` — app icon used in the end card
- `@fontsource-variable/manrope` — the locally packaged OFL typeface used in the rebuilt film
- `public/fonts/` — Inter weights retained for the earlier design; `OFL.txt` contains its font license
- `out/storage-cleaner-launch-36s.mp4` — finished export
- `out/storage-cleaner-launch-v2.mp4` — shareable copy of the rebuilt film
- `out/launch-v2-poster.jpg` — full-size poster extracted from the delivery MP4
- `out/storage-cleaner-launch-previous.mp4` — preserved previous export for comparison
