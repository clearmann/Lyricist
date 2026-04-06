// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lyricist",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Lyricist",
            path: "Lyricist",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Lyricist/Info.plist"])
            ]
        ),
        .testTarget(
            name: "LyricistTests",
            dependencies: ["Lyricist"],
            path: "LyricistTests"
        ),
    ]
)
