# solace-mobile Swift

Swift bindings for the [Solace PubSub+](https://solace.com/) C messaging API
(`libsolclient`), targeting **macOS** and **iOS** with a modern Swift-native,
`async/await` surface.

> Status: **Phase 0 — bootstrapping.** Repository scaffolding only. The C
> interop and Swift wrapper layers are being built out next.

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
| macOS (arm64 + x86_64) | ✅ | universal2 static lib |
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

## Roadmap

- [ ] **Phase 0** — build an `xcframework` from the static libs (+ statically
  link OpenSSL); verify `solClient_initialize()` links and runs
- [ ] **Phase 1** — `CSolace` module map exposing the 4 headers
- [ ] **Phase 2** — `SolaceCore`: context/session lifecycle, callback bridging
  via `Unmanaged` + `user_p`, return-code → `SolaceError`
- [ ] **Phase 3** — `SolaceKit`: `async/await` connect/subscribe,
  `AsyncThrowingStream<Message>` for received messages
- [ ] **Phase 4** — guaranteed messaging / flows, reconnect, docs, example app

## License

The Swift binding code in this repository is the project's own. The vendored
Solace SDK and its bundled OpenSSL are covered by their respective licenses
(see the SDK's `licenses.txt`) and are **not** redistributed here.
