// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "WindowMochi", platforms: [.macOS(.v13)], targets: [.executableTarget(name: "WindowMochi", resources: [.process("Resources")])], swiftLanguageVersions: [.v5])
