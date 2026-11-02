// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIUsages",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AIUsages",
            targets: ["AIUsages"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AIUsages",
            path: "Sources/Usages",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
