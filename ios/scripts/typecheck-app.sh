#!/bin/bash
# Compiles the iOS App layer to SIL (full Swift 6 type + concurrency checking) without Xcode,
# using the Mac Catalyst variant of UIKit/SwiftUI/Photos that ships in the macOS SDK.
#
# Usage: ios/scripts/typecheck-app.sh            (uses the default SDK)
#        SDK=/path/to/MacOSX26.sdk ios/scripts/typecheck-app.sh
#
# Note: Command Line Tools ship without the SwiftUI macro plugin. SDKs whose SwiftUI implements
# @State as a macro (macOS 27+) then report spurious "@State"/"self is immutable" errors; point
# SDK at a macOS 26 SDK in that case.
set -euo pipefail

IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${SDK:-$(xcrun --show-sdk-path)}"
TARGET=arm64-apple-ios17.0-macabi
IOS_SUPPORT="$SDK/System/iOSSupport"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

xcrun swiftc -swift-version 6 -target "$TARGET" -sdk "$SDK" \
  -Fsystem "$IOS_SUPPORT/System/Library/Frameworks" -I "$IOS_SUPPORT/usr/lib/swift" \
  -emit-module -module-name MnesiaCore -emit-module-path "$OUT/MnesiaCore.swiftmodule" \
  -parse-as-library $(find "$IOS_DIR/Sources/Core" -name '*.swift')

xcrun swiftc -swift-version 6 -target "$TARGET" -sdk "$SDK" \
  -Fsystem "$IOS_SUPPORT/System/Library/Frameworks" -I "$IOS_SUPPORT/usr/lib/swift" -I "$OUT" \
  -emit-sil -wmo -o "$OUT/Mnesia.sil" -module-name Mnesia \
  -parse-as-library $(find "$IOS_DIR/App" -name '*.swift')

echo "App layer type-checks (Mac Catalyst, Swift 6)."
