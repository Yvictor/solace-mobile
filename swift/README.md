# solace-mobile Swift

Swift bindings for the [Solace PubSub+](https://solace.com/) C messaging API
(`libsolclient`), targeting **macOS** and **iOS** with a modern Swift-native,
`async/await` surface.

> Status: **Phase 3 — Swift async subscribe path verified on macOS.** The live
> broker smoke uses `SolaceKit -> SolaceCore -> CSolace` with native compression.

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
| iOS Simulator (Apple Silicon) | ❌ | SDK 7.25.0.10 ships **no** `arm64-apple-ios-simulator` slice — use a physical device, or run the simulator under Rosetta (x86_64) |

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
swift run --package-path swift SolaceMacConnectSmoke
```

The smoke uses the public `SolaceKit` API and does:

- async `SolaceClient.connect(...)`
- optional direct publish when `SOLACE_PUBLISH_TOPIC` is set
- `SolaceKitSession.subscribe(...)`
- `for try await` over `session.messages`
- unsubscribe/disconnect/destroy/cleanup

The latest live run against the provided broker returned `connect: Ok`,
`publish: Ok` to `api/test`, `subscribe: Ok`, and received 20 direct messages
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
- [ ] **Phase 4c** — guaranteed flow receive/ack, reconnect stress tests,
  example app

## License

The Swift binding code in this repository is the project's own. The vendored
Solace SDK and its bundled OpenSSL are covered by their respective licenses
(see the SDK's `licenses.txt`) and are **not** redistributed here.
