// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HopTo",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HopToCore", targets: ["HopToCore"]),
        .executable(name: "HopTo", targets: ["HopTo"]),
    ],
    targets: [
        // Pure logic: index, fuzzy matching, ranking, settings catalogue. Fully unit-tested.
        .target(name: "HopToCore", path: "Sources/HopToCore"),
        // The launcher app: panel, hot key, app scanning. Thin wiring over the core.
        .executableTarget(
            name: "HopTo",
            dependencies: ["HopToCore"],
            path: "Sources/HopTo",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]),
        .testTarget(
            name: "HopToCoreTests",
            dependencies: ["HopToCore"],
            path: "Tests/HopToCoreTests"),
    ]
)
