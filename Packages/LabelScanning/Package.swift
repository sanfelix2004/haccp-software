// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LabelScanning",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "LabelScanningContract", targets: ["LabelScanningContract"]),
        .library(name: "LabelScannerV2", targets: ["LabelScannerV2"])
    ],
    targets: [
        .target(name: "LabelScanningContract"),
        .target(
            name: "LabelScannerV2",
            dependencies: ["LabelScanningContract"]
        ),
        .testTarget(
            name: "LabelScannerV2Tests",
            dependencies: ["LabelScannerV2", "LabelScanningContract"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
