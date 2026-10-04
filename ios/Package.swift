// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MnesiaCore",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "MnesiaCore",
      targets: ["MnesiaCore"]
    ),
  ],
  targets: [
    .target(
      name: "MnesiaCore",
      path: "Sources/Core"
    ),
    .testTarget(
      name: "MnesiaCoreTests",
      dependencies: ["MnesiaCore"],
      path: "Tests/MnesiaCoreTests"
    ),
  ]
)
