// swift-tools-version: 6.0
import PackageDescription

// What the app decides, kept apart from the Mac's audio system so that it can
// be tested with `swift test` and no hardware.
let package = Package(
    name: "EmbarrassMeNotCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EmbarrassMeNotCore", targets: ["EmbarrassMeNotCore"])],
    targets: [
        .target(name: "EmbarrassMeNotCore"),
        .testTarget(name: "EmbarrassMeNotCoreTests", dependencies: ["EmbarrassMeNotCore"]),
    ]
)
