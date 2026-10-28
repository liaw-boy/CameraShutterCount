// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CameraShutterCount",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CameraShutterCount",
            targets: ["CameraShutterCount"]
        ),
        .library(
            name: "CameraShutterCore",
            targets: ["CameraShutterCore"]
        )
    ],
    targets: [
        .target(
            name: "CameraShutterCore",
            path: "Sources/CameraShutterCore",
            linkerSettings: [
                .linkedFramework("ImageCaptureCore")
            ]
        ),
        .executableTarget(
            name: "CameraShutterCount",
            dependencies: [
                "CameraShutterCore"
            ],
            path: "Sources/CameraShutterCount",
            linkerSettings: [
                .linkedFramework("ImageCaptureCore")
            ]
        ),
        .testTarget(
            name: "CameraShutterCountTests",
            dependencies: [
                "CameraShutterCore"
            ],
            path: "Tests/CameraShutterCountTests"
        )
    ]
)
