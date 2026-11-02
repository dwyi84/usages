// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Usages",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Usages",
            targets: ["Usages"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Usages",
            path: "Sources/Usages",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
