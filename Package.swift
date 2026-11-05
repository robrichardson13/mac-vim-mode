// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "mac-vim-mode",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "vim-mode", targets: ["VimMode"]),
    .executable(name: "vim-verify", targets: ["VimVerify"]),
  ],
  targets: [
    .target(name: "VimCore"),
    .executableTarget(name: "VimMode", dependencies: ["VimCore"]),
    .executableTarget(name: "VimVerify", dependencies: ["VimCore"]),
    .testTarget(name: "VimCoreTests", dependencies: ["VimCore"]),
  ]
)
