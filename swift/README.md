# solace-mobile Swift

Swift bindings for the [Solace PubSub+](https://solace.com/) C messaging API
(`libsolclient`), targeting **macOS** and **iOS** with a modern Swift-native,
`async/await` surface.

> Status: **Current mobile PoC roadmap complete — macOS broker smoke, macOS
> SwiftUI example app, and Intel iOS Simulator direct subscribe are verified.** The
> live broker smokes use `SolaceKit -> SolaceCore -> CSolace` with native
> compression.

## Why

The Solace C SDK is a classic callback-based C API (opaque pointers,
`void *user_p` context on every callback). This package wraps it in three
layers so application code never touches raw C:

```
┌─────────────────────────────────────────┐
│  SolaceKit   high-level, async/await      │  ← app uses this
│  Session / Message, AsyncStream           │
├─────────────────────────────────────────┤
│  SolaceCore  safe wrapper                  │  ← opaque-pointer lifetime,
│  C-callback ↔ Swift bridging, Error map    │     return-code → Swift Error
├─────────────────────────────────────────┤
│  CSolace     C interop (module.modulemap)  │  ← exposes the 4 headers
└─────────────────────────────────────────┘
        libsolclient.a + libssl.a + libcrypto.a
```

## Platform support

| Target | Status | Notes |
|--------|--------|-------|
| macOS (arm64 + x86_64) | ✅ | universal2 static lib; SwiftPM smoke test passes on arm64 |
| iOS device (arm64) | ✅ | device-only static slice |
| iOS Simulator (Intel x86_64) | ✅ | `SolaceMobileIOS` Xcode app wrapper build/install/launch/direct-subscribe tested on iPhone SE simulator |
| iOS Simulator (Apple Silicon arm64) | ❌ | SDK 7.25.0.10 ships **no** `arm64-apple-ios-simulator` slice — use a physical device, or run the simulator under Rosetta/x86_64 |

## Vendored SDK (not in this repo)

The Solace SDK is proprietary licensed software and is **not committed** (see
`.gitignore`). To build, obtain the C SDK from Solace and extract it here:

```
solace-mobile/
├─ solclient_macos/   # solclient_Darwin-universal2_opt_<version>/
└─ solclient_ios/     # solclient-<version>/
```

This package was developed against **solclient 7.25.0.10**. Each extracted SDK
provides `include/solclient/{solClient,solClientMsg,solCache,solClientDeprecated}.h`
and `lib/` with `libsolclient.a`, `libssl.a`, `libcrypto.a`.

## macOS smoke test

The local SDK smoke verifies the first binding layer:

- `CSolace` imports the Solace C headers through a small C shim.
- `SolaceMacSmoke` statically links `libsolclient.a`, `libssl.a`, and
  `libcrypto.a`.
- The smoke executable calls `solClient_initialize()`,
  `solClient_version_get()`, and `solClient_cleanup()`.

Run it from the repository root:

```bash
swift run --package-path swift SolaceMacSmoke
```

Expected result:

```text
solClient_initialize: Ok
solClient_version_get: Ok
Solace C SDK version: 7.25.0.10
Variant: Darwin-arm64_opt - C SDK
solClient_cleanup: Ok
```

On macOS the static Solace library still references Kerberos/GSS symbols, so
the package links `gssapi_krb5` in addition to zlib and the bundled OpenSSL
archives.

## iOS packaging

For local iOS device integration, generate a proprietary local xcframework:

```bash
bash swift/scripts/build-xcframework.sh
```

Details and simulator limits are documented in
[`Docs/iOSPackaging.md`](Docs/iOSPackaging.md).

## iOS simulator smoke app

The `ios/` folder contains an XcodeGen project wrapper for a real iOS app
target that depends on this Swift package's `SolaceKit` product.

Generate the project:

```bash
cd ios
xcodegen generate
```

Build the Intel simulator target from the repository root:

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

This has been verified locally with iOS Simulator 18.1. The app launches and
renders a SwiftUI screen that imports `SolaceKit`, links the native Solace iOS
SDK through the Swift package, connects with compression, subscribes to
`TIC/v1/FOP/*/TFE/TXFG6`, and receives live direct messages. The app leaves the
password blank for manual entry.

Successful subscription is visible in the app's `Quote Status` section:
`Received` increments above zero and the latest received topic/byte count is
shown without scrolling. The detailed message log includes lines such as:

```text
connect: Ok
subscribe: Ok TIC/v1/FOP/*/TFE/TXFG6
message: TIC/v1/FOP/BCDMZPCR01/TFE/TXFG6, bytes=125
```

See `../ios/README.md` for the end-to-end simulator workflow.

## SwiftUI example app

`SolaceSwiftExampleApp` is a macOS SwiftUI example that exercises the public
`SolaceKit` API. It supports:

- native connect/disconnect with compression
- direct topic subscribe
- optional publish to a topic
- durable queue flow receive with client ack when a broker queue is available
- session and flow event logs

Build it from the repository root:

```bash
swift build --package-path swift --product SolaceSwiftExampleApp
```

Run it locally:

```bash
swift run --package-path swift SolaceSwiftExampleApp
```

## macOS broker connect smoke

`SolaceMacConnectSmoke` performs a real native Solace connection using values
from environment variables or a local `.env` file. It does not store
credentials in the repository.

```bash
SOLACE_HOST='host:port' \
SOLACE_VPN='vpn' \
SOLACE_USERNAME='username' \
SOLACE_PASSWORD='password' \
SOLACE_TOPIC='TIC/v1/FOP/*/TFE/TXFG6' \
SOLACE_PUBLISH_TOPIC='api/test' \
SOLACE_PUBLISH_TEXT='solace-mobile swift smoke' \
SOLACE_COMPRESSION_LEVEL='3' \
SOLACE_WAIT_SECONDS='10' \
SOLACE_EXPECT_DIRECT_MESSAGES='1' \
swift run --package-path swift SolaceMacConnectSmoke
```

The smoke uses the public `SolaceKit` API and does:

- async `SolaceClient.connect(...)`
- optional direct publish when `SOLACE_PUBLISH_TOPIC` is set
- `SolaceKitSession.subscribe(...)`
- `for try await` over `session.messages`
- unsubscribe/disconnect/destroy/cleanup

Set `SOLACE_QUEUE` to bind a durable queue with client acknowledgements instead
of direct topic subscribe. The queue must already exist on the broker and the
username must be allowed to consume it.

```bash
SOLACE_QUEUE='queue/name' \
SOLACE_EXPECT_QUEUE_MESSAGES='1' \
swift run --package-path swift SolaceMacConnectSmoke
```

`SOLACE_EXPECT_DIRECT_MESSAGES` and `SOLACE_EXPECT_QUEUE_MESSAGES` turn the
smoke into a pass/fail gate. The command exits non-zero if fewer messages are
received than expected.

For a self-contained guaranteed flow test, set `SOLACE_FLOW_TOPIC` instead of
`SOLACE_QUEUE`. This creates a non-durable Topic Endpoint flow, publishes
persistent messages to the same topic, receives them on the flow, and sends
client acknowledgements:

```bash
SOLACE_FLOW_TOPIC='api/test' \
SOLACE_EXPECT_QUEUE_MESSAGES='1' \
SOLACE_FLOW_PUBLISH_COUNT='1' \
swift run --package-path swift SolaceMacConnectSmoke
```

This optional guaranteed flow path requires the connected broker/client profile
to report all of:

- `PUB_GUARANTEED=true`
- `SUB_FLOW_GUARANTEED=true`
- `TEMP_ENDPOINT=true`

The currently provided broker profile connects successfully with compression
and receives direct messages. Guaranteed queue flow/ack is intentionally not a
required gate for the current mobile PoC.

## macOS reconnect stress smoke

`SolaceMacReconnectSmoke` keeps a native Solace session open with automatic
reconnect enabled and counts reconnect lifecycle events. To validate reconnect
handling, run it against a broker or network path you can deliberately interrupt
and restore during the wait window:

```bash
SOLACE_HOST='host:port' \
SOLACE_VPN='vpn' \
SOLACE_USERNAME='username' \
SOLACE_PASSWORD='password' \
SOLACE_TOPIC='TIC/v1/FOP/*/TFE/TXFG6' \
SOLACE_COMPRESSION_LEVEL='3' \
SOLACE_RECONNECT_RETRIES='-1' \
SOLACE_RECONNECT_RETRY_WAIT_MS='1000' \
SOLACE_RECONNECT_WAIT_SECONDS='60' \
SOLACE_EXPECT_RECONNECTS='1' \
swift run --package-path swift SolaceMacReconnectSmoke
```

The smoke exits non-zero when the observed `reconnected` event count is lower
than `SOLACE_EXPECT_RECONNECTS`.

The latest live run against the provided broker returned `connect: Ok`,
`publish: Ok` to `api/test`, `subscribe: Ok`, and received 11 direct messages
in a 10-second window with compression level `3`.

## Library API

Minimal high-level usage:

```swift
let client = SolaceClient()
let session = try await client.connect(
    SolaceConfiguration(
        host: "host:port",
        vpn: "vpn",
        username: "username",
        password: "password",
        compressionLevel: 3
    )
)

try await session.subscribe("TIC/v1/FOP/*/TFE/TXFG6")
try await session.publish(
    topic: "api/test",
    payload: Data("hello".utf8),
    deliveryMode: .direct
)

for try await message in session.messages {
    print(message.topic ?? "", message.payload.count)
}

for await event in session.events {
    print(event.name, event.detail)
}
```

Guaranteed queue receive uses a flow and client ack:

```swift
let flow = try await session.createQueueFlow(
    QueueFlowConfiguration(queueName: "queue/name")
)

for try await message in flow.messages {
    print(message.messageID, message.payload.count)
    try message.acknowledge()
}
```

`SolaceCore` owns native context/session lifetime, maps return codes to
`SolaceError`, bridges C callbacks through `user_p`, and copies topic/payload
data before returning from the C callback.

## Roadmap

- [x] **Phase 0** — verify `solClient_initialize()` links and runs on macOS
- [x] **Phase 1** — `CSolace` C interop target exposing the required headers
- [x] **Phase 2a** — native broker connect/subscribe smoke with compression
- [x] **Phase 2b** — `SolaceCore`: context/session lifecycle, callback bridging
  via `Unmanaged` + `user_p`, return-code → `SolaceError`
- [x] **Phase 3** — `SolaceKit`: `async/await` connect/subscribe,
  `AsyncThrowingStream<Message>` for received messages
- [x] **Phase 4a** — publish foundation: direct/persistent/non-persistent
  delivery mode API, live direct publish smoke, reconnect subscription reapply
- [x] **Phase 4b** — iOS packaging strategy and reconnect/session event stream
- [x] **Phase 4c.1** — guaranteed queue flow receive/ack API foundation
- [x] **Phase 4c.2a** — SwiftUI example app
- [x] **Phase 4c.2b** — queue/reconnect pass-fail smoke harnesses
- [x] **Phase 4c.2c** — Intel iOS Simulator direct subscribe app with visible
  received quote count and latest message summary

Deferred, not required for the current mobile PoC:

- broker-backed guaranteed queue bind/ack live gate on a broker/client profile
  with guaranteed flow support
- induced reconnect live gate against a controllable broker/network path

## License

The Swift binding code in this repository is the project's own. The vendored
Solace SDK and its bundled OpenSSL are covered by their respective licenses
(see the SDK's `licenses.txt`) and are **not** redistributed here.
