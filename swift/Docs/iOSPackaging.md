# iOS Packaging

The Solace 7.25.0.10 SDK ships raw static archives rather than a SwiftPM-ready
binary target. The repository keeps those proprietary files out of git and
builds a local xcframework when needed.

Run from the repository root:

```bash
bash swift/scripts/build-xcframework.sh
```

The script validates:

- macOS `libsolclient.a.7.25.0.10` has `arm64` and `x86_64` slices
- iOS `libsolclient.a` has an `arm64` device slice
- bundled OpenSSL archives have the required slices
- Solace headers exist for both platforms

It then combines Solace + OpenSSL into one static archive per platform using
`libtool -static` before creating the xcframework.

It writes:

```text
swift/Frameworks/SolaceClientNative.xcframework
```

`swift/Frameworks/` is ignored because the SDK is proprietary. The generated
xcframework is intended for local app integration, not redistribution.

## Simulator

The SDK also contains legacy `i386` and `x86_64` iOS simulator slices, but it
does not contain `arm64-apple-ios-simulator`. On Apple Silicon, use one of:

- a physical iOS device
- Rosetta/x86_64 simulator with `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`

The current SwiftPM package still links the macOS SDK directly for development
and smoke tests. Moving Package.swift to a committed `binaryTarget` should only
happen if the proprietary xcframework can be distributed through a private
artifact channel.
