// swift-tools-version: 6.0

import PackageDescription

let sdkRoot = "../solclient_macos/solclient_Darwin-universal2_opt_7.25.0.10"
let sdkLib = "\(sdkRoot)/lib"

let package = Package(
    name: "SolaceMobileSwift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CSolace", targets: ["CSolace"]),
        .executable(name: "SolaceMacSmoke", targets: ["SolaceMacSmoke"])
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
        .executableTarget(
            name: "SolaceMacSmoke",
            dependencies: ["CSolace"],
            linkerSettings: [
                .linkedLibrary("gssapi_krb5"),
                .unsafeFlags([
                    "\(sdkLib)/libsolclient.a.7.25.0.10",
                    "\(sdkLib)/libssl.a",
                    "\(sdkLib)/libcrypto.a",
                    "-lz"
                ])
            ]
        )
    ]
)
