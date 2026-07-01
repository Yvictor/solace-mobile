# solace-mobile Swift

Swift bindings for the [Solace PubSub+](https://solace.com/) C messaging API
(`libsolclient`), targeting **macOS** and **iOS** with a modern Swift-native,
`async/await` surface.

> Status: **Phase 1 — macOS C binding smoke passed.** SwiftPM can build and run
> against the Solace C SDK on macOS arm64.

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

## macOS broker connect smoke

`SolaceMacConnectSmoke` performs a real native Solace connection using values
from environment variables. It does not store credentials in the repository.

```bash
SOLACE_HOST='host:port' \
SOLACE_VPN='vpn' \
SOLACE_USERNAME='username' \
SOLACE_PASSWORD='password' \
SOLACE_TOPIC='TIC/v1/FOP/*/TFE/TXFG6' \
SOLACE_COMPRESSION_LEVEL='3' \
SOLACE_WAIT_SECONDS='10' \
swift run --package-path swift SolaceMacConnectSmoke
```

The smoke does:

- `solClient_initialize()`
- context/session creation
- blocking `solClient_session_connect()`
- `solClient_session_topicSubscribeExt(...WAITFORCONFIRM...)`
- waits for direct messages
- unsubscribe/disconnect/destroy/cleanup

The first live run against the provided broker returned `Session up`,
`solClient_session_connect: Ok`, and `solClient_session_topicSubscribeExt: Ok`
with compression level `3`. No messages arrived during the 10-second wait
window.

## Roadmap

- [x] **Phase 0** — verify `solClient_initialize()` links and runs on macOS
- [x] **Phase 1** — `CSolace` C interop target exposing the required headers
- [x] **Phase 2a** — native broker connect/subscribe smoke with compression
- [ ] **Phase 2b** — `SolaceCore`: context/session lifecycle, callback bridging
  via `Unmanaged` + `user_p`, return-code → `SolaceError`
- [ ] **Phase 3** — `SolaceKit`: `async/await` connect/subscribe,
  `AsyncThrowingStream<Message>` for received messages
- [ ] **Phase 4** — iOS packaging strategy, guaranteed messaging / flows,
  reconnect, docs, example app

## License

The Swift binding code in this repository is the project's own. The vendored
Solace SDK and its bundled OpenSSL are covered by their respective licenses
(see the SDK's `licenses.txt`) and are **not** redistributed here.
