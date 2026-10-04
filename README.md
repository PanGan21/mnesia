# mnesia

Find any photo or video by describing it. Photos are indexed and searched on your device; nothing
is uploaded.

The repository has two apps:

- **Web app** (repo root): runs entirely in the browser with an on-device CLIP model.
- **iOS app** (`ios/`): SwiftUI, PhotoKit and Apple Vision, with a separate `MnesiaCore` package.

## Web app

Requires Node 22+ and pnpm (the exact version is pinned in `package.json`).

```bash
corepack enable
pnpm install
pnpm dev
```

| Command        | What it does                                     |
| -------------- | ------------------------------------------------ |
| `pnpm dev`     | Development server with hot reload               |
| `pnpm build`   | Type-checks, then builds to `dist/`              |
| `pnpm preview` | Serves `dist/` with the production headers       |
| `pnpm test`    | Unit tests (Vitest)                              |
| `pnpm check`   | Formatting, lint, type-check and tests, as in CI |
| `pnpm format`  | Formats the code with Prettier                   |

### How it works

1. Added files get a small JPEG preview (`src/media/previews.ts`).
2. A Web Worker runs CLIP (8-bit, on the CPU; `src/model/model.worker.ts`) and turns each preview
   into an embedding.
   The model downloads once from Hugging Face, pinned to a specific commit, and is then cached by
   the browser. The ONNX runtime is bundled with the app.
3. Records are kept in IndexedDB (`src/storage/library-store.ts`) if "Keep library after closing
   the tab" is on, and only in memory otherwise.
4. A query is split into filter words ("videos", "last summer") and a description
   (`src/search/query-parser.ts`). The description is embedded and ranked against the library,
   blended with file-name matches (`src/search/ranking.ts`). Until the model is ready, search
   matches file names and dates. Only close matches are shown; the
   similarity cut-off (`MATCHING` in `src/config.ts`) was calibrated on labelled photos for this
   model, and the rest are offered as "other photos that might match".

```
src/
  main.ts            entry point
  app.ts             wires the library, model and views together
  importer.ts        import pipeline: dedupe, preview, embed, save
  library.ts         in-memory library mirrored to IndexedDB
  search/            query parsing, time filters, ranking
  storage/           IndexedDB store and settings
  model/             worker protocol, worker and client
  media/             file selection and previews
  ui/                views: results, viewer, dialogs, feedback
```

### Privacy and security

- Media never leaves the browser. The only network traffic is the one-time model download from
  `huggingface.co`, made by the worker.
- Production builds include a strict Content Security Policy `<meta>` tag for the page.
- When hosting, send the headers in `HOSTING_HEADERS` (`vite.config.ts`). The CSP header also
  covers the model worker, which a `<meta>` tag can't. `pnpm preview` serves them, so you can test
  production behaviour locally.
- Dependencies are pinned exactly. pnpm only installs versions published at least a day ago, blocks
  install scripts, and fails if a package's provenance gets weaker (`pnpm-workspace.yaml`).
- CI runs `pnpm audit`, all checks and the build, with GitHub Actions pinned to commit SHAs.

## iOS app

```bash
cd ios
xcodegen generate
open Mnesia.xcodeproj
```

The core package builds and tests without Xcode:

```bash
cd ios
swift test
```

With only the Command Line Tools installed, SwiftPM can't find the Swift Testing macro plugin; add
`-Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`.
`ios/scripts/typecheck-app.sh` type-checks the app layer without Xcode (see `ios/README.md`).
