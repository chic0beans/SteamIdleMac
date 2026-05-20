// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SteamIdleMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SteamIdleMac", targets: ["SteamIdleMac"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "SteamIdleMac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "SteamIdleMac",
            exclude: ["Info.plist", "SteamIdleMac.entitlements"],
            resources: [
                .copy("Resources/AppIcon.icns"),
            ]
        ),
    ]
)
