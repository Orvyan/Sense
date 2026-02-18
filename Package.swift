// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sense",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Sense", targets: ["Sense"])
    ],
    targets: [
        .executableTarget(
            name: "Sense",
            path: "Sources/Sense"
        )
    ]
)
