# Solace Mobile iOS

This is a minimal iOS simulator wrapper around the Swift package's `SolaceKit`
API. It is intended for validating the native Solace C SDK on an Intel
`x86_64` iOS Simulator path.

## Generate the Xcode Project

The committed `.xcodeproj` is generated from `project.yml` with XcodeGen:

```bash
cd ios
xcodegen generate
```

## Build for Intel iOS Simulator

The Solace iOS SDK 7.25.0.10 includes an `x86_64` simulator slice but not an
Apple Silicon `arm64-apple-ios-simulator` slice. Build the simulator app with
`ARCHS=x86_64`:

```bash
xcodebuild \
  -project ios/SolaceMobileIOS.xcodeproj \
  -scheme SolaceMobileIOS \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -sdk iphonesimulator \
  ARCHS=x86_64 \
  ONLY_ACTIVE_ARCH=YES \
  build
```

## Subscribe Test

Run `SolaceMobileIOS` on an Intel/Rosetta iOS Simulator. The app defaults are:

- Host: `210.59.255.161:80`
- VPN: `sinopac`
- Username: `shioaji`
- Topic: `TIC/v1/FOP/*/TFE/TXFG6`
- Compression: `3`

Enter the password manually, then tap `Connect & Subscribe`.

Successful subscription is visible in two places:

- `Quote Status > Received` increments above zero.
- `Quote Status` shows the latest topic and payload byte count.

The scrollable message log should include lines like:

```text
connect: Ok
subscribe: Ok TIC/v1/FOP/*/TFE/TXFG6
message: TIC/v1/FOP/BCDMZPCR01/TFE/TXFG6, bytes=125
```

This confirms the iOS simulator path can link the native Solace SDK, connect
with compression, subscribe to the wildcard topic, and receive live direct
messages. Guaranteed queue flow/ack is outside the current mobile PoC scope.
