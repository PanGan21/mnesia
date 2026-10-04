# mnesia Architecture Plan

This document captures the current `mnesia` architecture, the target product direction, and the remaining work required to turn the repo into a fully validated native app.

## Product Goal

`mnesia` is a privacy-first photo and video search app.

The long-term product goal is:

- local-first indexing and search
- user media stays on the device
- search and ranking run on-device
- great UI and UX across import, indexing, search, preview, and privacy controls
- native iPhone experience backed by a structured, testable codebase

## Current Repo Shape

This repo currently has two product layers:

- `web/` equivalent at repo root:
  - Vite-based local-first web prototype
  - browser worker runs a local semantic model with `@huggingface/transformers`
- `ios/`:
  - native iOS app scaffold using SwiftUI
  - PhotoKit-based asset access
  - local JSON persistence
  - on-device Apple Vision analysis
  - separate core search/index module

## Current State Summary

### Web App

The web prototype already supports:

- local file import
- browser-side persistence
- local semantic search
- browser worker embedding generation
- first-run model download and local inference

Current local model path:

- `ml-worker.js`
- `@huggingface/transformers`
- `Xenova/clip-vit-base-patch32`

Behavior:

- no cloud inference API is called
- model assets are downloaded on first use
- inference then runs locally in the browser

### iOS App

The iOS app currently includes:

- SwiftUI shell and tab structure
- local photo permissions flow
- PhotoKit asset enumeration
- local thumbnail and preview loading
- local index persistence in Application Support JSON
- search parsing, ranking, and storage in a separate core module
- on-device Vision-based tagging, OCR, and face detection

Important current limitation:

- the iOS app is on-device only, but it does **not yet** use a custom bundled model
- it currently relies on Apple Vision APIs rather than a dedicated Core ML model that we ship

## Target Architecture

## Layer 1: Native App Shell

Purpose:

- host the product experience
- manage permissions
- present search, library, privacy, and settings flows

Key paths:

- `ios/App/AppEntry`
- `ios/App/Features`
- `ios/App/Shared`
- `ios/App/ViewModels`

Responsibilities:

- SwiftUI navigation and screens
- user state presentation
- selection, preview, and user actions
- accessibility and visual polish

## Layer 2: App Services

Purpose:

- bridge Apple frameworks to app-facing abstractions

Key paths:

- `ios/App/Services/Photos`
- `ios/App/Services/Indexing`
- `ios/App/Services/Vision`

Responsibilities:

- PhotoKit reads and permissions
- local preview and thumbnail loading
- video frame extraction
- image analysis input preparation
- indexing orchestration
- on-device semantic extraction

Desired shape:

- protocols at the boundary
- testable fake implementations
- minimal framework coupling inside view models

## Layer 3: Core Module

Purpose:

- hold pure domain logic that should be testable outside the app target

Key paths:

- `ios/Sources/Core/Models`
- `ios/Sources/Core/Search`
- `ios/Sources/Core/Persistence`
- `ios/Sources/Core/Utilities`

Responsibilities:

- search query parsing
- ranking and sorting
- index record modeling
- JSON snapshot storage
- reusable domain types

This should remain:

- framework-like
- deterministic
- highly testable
- independent of SwiftUI, PhotoKit, and Vision

## Layer 4: Local AI / Semantic Understanding

### Current iOS State

Current implementation:

- `VisionSemanticAnalyzer.swift`

Current behavior:

- `VNClassifyImageRequest`
- `VNRecognizeTextRequest`
- `VNDetectFaceRectanglesRequest`

This satisfies:

- on-device analysis
- no cloud inference

This does not yet satisfy the stricter version of the original vision:

- shipping our own dedicated local model
- using a custom embedding pipeline for semantic retrieval

### Target iOS AI State

Target direction:

- replace or augment the Vision layer with a dedicated Core ML model
- keep inference entirely on-device
- optionally bundle weights in app resources or support first-download with local caching

Desired components:

- `SemanticEmbeddingProvider`
- `ImageEmbeddingGenerator`
- `QueryEmbeddingGenerator`
- `EmbeddingIndexStore`
- optional reranker or hybrid lexical + semantic ranker

Potential target architecture:

1. PhotoKit loads asset input
2. local model generates image embeddings
3. query model generates text embeddings
4. local index stores embeddings and metadata
5. search engine performs nearest-neighbor retrieval
6. local reranking combines embeddings with OCR, tags, dates, and favorites

## Privacy Model

Privacy guarantees we want to preserve:

- no cloud inference for search
- no upload of the user photo library
- local metadata persistence only
- iCloud-only assets are skipped when network access is disabled
- clear local index action does not mutate Photos library contents

Current repo already aligns with this:

- `PhotoLibraryService.swift` disables network access for image/video fetch requests
- local JSON index persistence is already in place
- current iOS semantic analysis is on-device

## Current File Architecture

### iOS App

- `ios/App/AppEntry`
  - app bootstrap and root container
- `ios/App/Features/Search`
  - main search experience
- `ios/App/Features/Library`
  - browse indexed assets
- `ios/App/Features/Privacy`
  - privacy and trust messaging
- `ios/App/Features/Settings`
  - rebuild and clear controls
- `ios/App/Services/Photos`
  - PhotoKit access
- `ios/App/Services/Indexing`
  - index orchestration
- `ios/App/Services/Vision`
  - on-device analysis
- `ios/App/ViewModels`
  - app state coordination
- `ios/App/Shared`
  - reusable components and style

### iOS Core Module

- `ios/Sources/Core/Models`
- `ios/Sources/Core/Search`
- `ios/Sources/Core/Persistence`
- `ios/Sources/Core/Utilities`

### Tests

Current tests:

- `ios/Tests/MnesiaCoreTests`

Coverage today:

- search query parsing
- search ranking behavior
- JSON persistence round-trip

## What Is Already Done

- web prototype exists and runs locally
- native iOS scaffold exists
- XcodeGen spec exists
- app icon and resource catalog exist
- Info.plist exists
- core package structure exists
- core tests exist
- local indexing/search UX exists at scaffold level
- iOS indexing is on-device and privacy-first

## What Is Left To Do

## A. Local Machine Setup

These are required before full native testing can happen locally.

1. Install full Xcode from the Mac App Store
2. Switch active developer directory to Xcode
3. Run first-launch setup
4. Install at least one iOS Simulator runtime
5. Verify `xcodebuild` and `simctl` work

Suggested commands:

```bash
sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
xcrun simctl list devices
```

## B. Repo-Level Build and Test Setup

1. Add shared Xcode schemes to `ios/project.yml`
2. Regenerate `ios/Mnesia.xcodeproj`
3. Ensure CLI build/test works with `xcodebuild`
4. Keep generated Xcode project out of git and regenerate from spec

## C. App-Level Testing

Add a dedicated app unit test target for:

- `AppModel`
- indexing state transitions
- permission state handling
- rebuild flow
- clear-index flow
- search result refresh logic
- fake analyzer/photo service behavior

Add a UI test target for:

- first launch permission gate
- permission denied flow
- rebuild local index flow
- local search flow
- asset preview opening
- clear local index flow
- empty states and failure states

## D. Manual Validation

Run simulator validation for:

- app launch
- indexing flow
- search flow
- privacy screen
- settings actions

Run real-device validation for:

- limited photo library access
- denied photo access
- screenshots and videos
- iCloud-only assets
- large library behavior
- memory/performance of indexing

## E. AI Architecture Decision

Choose between these two product directions:

### Option 1: Vision-backed local intelligence

Keep the current iOS design:

- use Apple Vision for tags/OCR/faces
- keep search lexical + structured
- preserve on-device privacy

Pros:

- lower complexity
- faster shipping
- less model packaging work

Cons:

- weaker semantic retrieval than a custom embedding pipeline
- not truly "our own" local model stack

### Option 2: Custom on-device model pipeline

Implement a dedicated Core ML-based semantic stack:

- bundled or locally cached model weights
- image embeddings
- text embeddings
- local nearest-neighbor search
- optional hybrid reranking

Pros:

- closer to the original vision
- stronger semantic search
- more product differentiation

Cons:

- more implementation complexity
- more testing and performance work
- larger app footprint

## Recommended Execution Order

1. Install Xcode locally
2. Finish Xcode/simulator setup
3. Add shared schemes to `ios/project.yml`
4. Run `xcodegen generate`
5. Run `swift build`
6. Run `swift test`
7. Add app unit test target
8. Add UI test target
9. Run simulator builds and tests
10. Run real-device validation
11. Decide whether to keep Vision or move to custom Core ML
12. If needed, implement dedicated local model layer
13. Polish UI/UX and performance

## Immediate TODOs

- [ ] Install full Xcode locally
- [ ] Run `sudo xcode-select --switch /Applications/Xcode.app`
- [ ] Run `sudo xcodebuild -runFirstLaunch`
- [ ] Install iOS Simulator runtime
- [ ] Verify `xcrun simctl list devices`
- [ ] Add shared scheme definitions to `ios/project.yml`
- [ ] Regenerate `ios/Mnesia.xcodeproj`
- [ ] Run `swift build`
- [ ] Run `swift test`
- [ ] Add app unit test target
- [ ] Add UI test target
- [ ] Run simulator build
- [ ] Run simulator tests
- [ ] Run real-device validation
- [ ] Decide whether to keep Vision or implement custom Core ML model pipeline

## Nice-to-Have Follow-Ups

- add benchmark coverage for indexing large libraries
- add accessibility audit and VoiceOver pass
- add import/export or index migration strategy
- add richer ranking explanations in the UI
- add background refresh/index invalidation strategy
- add optional custom model packaging and cache management

## Source of Truth

For now, the architecture source of truth is:

- this file for product/engineering planning
- `ios/project.yml` for native project generation
- `ios/Sources/Core` for reusable domain logic
- `ios/App` for native product implementation
