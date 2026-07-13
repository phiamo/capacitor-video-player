// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrylsherbertCapacitorVideoPlayer",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "BrylsherbertCapacitorVideoPlayer",
            targets: ["CapacitorVideoPlayerPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "CapacitorVideoPlayerPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/CapacitorVideoPlayerPlugin")
    ]
)
