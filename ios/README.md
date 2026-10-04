# mnesia iOS

Native SwiftUI app for the on-device version of `mnesia`.

## Structure

- `App/`: SwiftUI app layer — feature screens, `AppModel`, PhotoKit access (`PhotoLibraryService`), Vision analysis, and the adapter that feeds both into the core indexer.
- `Sources/Core/` (`MnesiaCore`): platform-independent models, incremental indexer (`LibraryIndexer`), query parsing, ranking, and JSON persistence. Everything here is unit tested.
- `Tests/MnesiaCoreTests/`: Swift Testing suites for parsing, tokenization, date filters, ranking/sorting, indexing, and persistence.
- `project.yml`: XcodeGen spec for generating `Mnesia.xcodeproj` (the project file is generated and git-ignored).
- `Package.swift`: Swift package for building and testing the core outside Xcode.
- `scripts/typecheck-app.sh`: compiles the App layer (Swift 6, strict concurrency) against the Mac Catalyst SDK when full Xcode is not installed.

## Generate the Xcode project

```sh
cd ios
xcodegen generate
open Mnesia.xcodeproj
```

## Verify without Xcode

```sh
cd ios
swift build
swift test
scripts/typecheck-app.sh
```

With Command Line Tools only, SwiftPM may fail to locate the Swift Testing macro plugin
(`plugin for module 'TestingMacros' not found`). Point it at the plugin explicitly:

```sh
swift test -Xswiftc -plugin-path -Xswiftc "$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
```

## Runtime notes

- Search and analysis are fully on-device; every PhotoKit request sets `isNetworkAccessAllowed = false`.
- Indexing is incremental: unchanged assets (same `assetVersion`) reuse their stored analysis, removed assets are dropped, and only new or edited assets go through Vision. Runs can be stopped; finished work is kept.
- Vision receives downsampled frames (max 1600 px) rather than full-resolution originals.
- Assets whose pixels are only in iCloud are skipped and reported in the UI; they are retried on the next update. Photos' local derivatives often make "Optimize iPhone Storage" assets indexable anyway.
- The index is stored in Application Support as JSON, written atomically with `completeUntilFirstUserAuthentication` file protection, and excluded from device backups (it is derived, device-specific data containing OCR text).
- A damaged index file is detected on launch and reset; the user is asked to rebuild.
