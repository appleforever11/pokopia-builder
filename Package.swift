// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PokopiaBuilder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PokopiaBuilder", targets: ["PokopiaBuilder"])
    ],
    targets: [
        .executableTarget(
            name: "PokopiaBuilder",
            path: "Sources/PokopiaBuilder",
            exclude: ["Info.plist"],
            resources: [.copy("Resources")]
        )
    ]
)
