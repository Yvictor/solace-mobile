# solace-mobile

Mobile experiments and bindings for Solace PubSub+ native messaging with
compression support.

This repository is organized by platform:

- `android/` - Android proof of concept using the Solace PubSub+ Messaging API
  for Java with native Solace compression.
- `swift/` - Swift/iOS/macOS binding plan for the Solace C SDK.

## Current Status

### Android

The Android PoC has been validated on an Android emulator:

- Connects to a Solace broker with the Java native API.
- Enables native Solace compression via `withMessageCompression(3)`.
- Subscribes to a wildcard topic.
- Receives live `TXFG6` data.

The Solace Java SDK jars are proprietary and are not committed. See
`android/README.md` for setup.

### Swift

The Swift side is still in planning/bootstrap. The Solace C SDK currently being
evaluated does not include an Apple Silicon iOS Simulator slice, so iOS testing
requires a physical device or an alternate SDK release.

See `swift/README.md` and `swift/PLAN.md`.

## Repository Hygiene

Solace SDK archives, extracted proprietary SDKs, Android local jars, Gradle
build output, Android Studio workspace files, and generated binary artifacts are
excluded from git.
