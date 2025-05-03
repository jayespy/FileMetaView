// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "FileMetaView",
    platforms: [
        .macOS(.v12) // Monterey or later for better file metadata access APIs
    ],
    products: [
        .executable(name: "FileMetaView", targets: ["FileMetaView"])
    ],
    dependencies: [
        // Dependencies will be added here as needed
    ],
    targets: [
        .executableTarget(
            name: "FileMetaView",
            dependencies: [],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
                // Removed unsafe flags that might cause compatibility issues
            ]
        ),
        .testTarget(
            name: "FileMetaViewTests",
            dependencies: ["FileMetaView"]
        )
    ]
)
