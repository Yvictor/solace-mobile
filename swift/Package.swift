// swift-tools-version: 6.0

import PackageDescription

let sdkRoot = "../solclient_macos/solclient_Darwin-universal2_opt_7.25.0.10"
let sdkLib = "\(sdkRoot)/lib"
let iosSdkRoot = "../solclient_ios/solclient-7.25.0.10"
let iosSdkLib = "\(iosSdkRoot)/lib"
let solclientLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("gssapi_krb5", .when(platforms: [.macOS])),
    .unsafeFlags([
        "\(sdkLib)/libsolclient.a.7.25.0.10",
        "\(sdkLib)/libssl.a",
        "\(sdkLib)/libcrypto.a",
        "-lz"
    ], .when(platforms: [.macOS])),
    .unsafeFlags([
        "\(iosSdkLib)/libsolclient.a",
        "\(iosSdkLib)/libssl-universal.a",
        "\(iosSdkLib)/libcrypto-universal.a",
        "-lz"
    ], .when(platforms: [.iOS]))
]

let package = Package(
    name: "SolaceMobileSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "CSolace", targets: ["CSolace"]),
        .library(name: "SolaceCore", targets: ["SolaceCore"]),
        .library(name: "SolaceKit", targets: ["SolaceKit"]),
        .executable(name: "SolaceMacSmoke", targets: ["SolaceMacSmoke"]),
        .executable(name: "SolaceMacConnectSmoke", targets: ["SolaceMacConnectSmoke"]),
        .executable(name: "SolaceMacReconnectSmoke", targets: ["SolaceMacReconnectSmoke"]),
        .executable(name: "SolaceSwiftExampleApp", targets: ["SolaceSwiftExampleApp"])
    ],
    targets: [
        .target(
            name: "CSolace",
            publicHeadersPath: "include",
            cSettings: [
                .define("SOLCLIENT_EXCLUDE_DEPRECATED"),
                .define("SOLCLIENT_CONST_PROPERTIES")
            ]
        ),
        .target(
            name: "SolaceCore",
            dependencies: ["CSolace"],
            linkerSettings: solclientLinkerSettings
        ),
        .target(
            name: "SolaceKit",
            dependencies: ["SolaceCore"],
            linkerSettings: solclientLinkerSettings
        ),
        .executableTarget(
            name: "SolaceMacSmoke",
            dependencies: ["CSolace"],
            linkerSettings: solclientLinkerSettings
        ),
        .executableTarget(
            name: "SolaceMacConnectSmoke",
            dependencies: ["SolaceKit"],
            linkerSettings: solclientLinkerSettings
        ),
        .executableTarget(
            name: "SolaceMacReconnectSmoke",
            dependencies: ["SolaceKit"],
            linkerSettings: solclientLinkerSettings
        ),
        .executableTarget(
            name: "SolaceSwiftExampleApp",
            dependencies: ["SolaceKit"],
            linkerSettings: solclientLinkerSettings
        ),
        .testTarget(
            name: "SolaceCoreTests",
            dependencies: ["SolaceCore"],
            linkerSettings: solclientLinkerSettings
        )
    ]
)
