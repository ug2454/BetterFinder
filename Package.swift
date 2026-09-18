// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterFinder",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "BetterFinder", targets: ["BetterFinder"])],
    targets: [
        .target(name: "DirectoryCore"),
        .executableTarget(name: "BetterFinder", dependencies: ["DirectoryCore"]),
        .testTarget(name: "DirectoryCoreTests", dependencies: ["DirectoryCore"])
    ]
)
