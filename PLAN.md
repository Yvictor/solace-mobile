# solace-swift — 開發計畫 (PLAN)

Swift bindings for the Solace PubSub+ C API (`libsolclient` 7.25.0.10),
targeting macOS + iOS with a modern `async/await` surface.

本文件記錄**專案所需條件**與**完整實作規劃**。實作進度見 `README.md` 的 roadmap。

---

## 1. 專案需要的東西 (Prerequisites)

### 1.1 工具鏈
- **Xcode** + Command Line Tools(`xcodebuild`, `lipo`, `clang`)
- **Swift 5.9+**(SwiftPM,需要 `binaryTarget` / macro-free)
- `gh` CLI(已登入 `Yvictor`)— repo 操作

### 1.2 Vendored SDK（不進版控,見 `.gitignore`）
商用授權二進位,需自行向 Solace 取得並解壓到專案根目錄:

```
solace-swift/
├─ solclient_macos/solclient_Darwin-universal2_opt_7.25.0.10/
│  ├─ include/solclient/{solClient,solClientMsg,solCache,solClientDeprecated}.h
│  └─ lib/  libsolclient.a (universal2), libssl.a, libcrypto.a, *.dylib
└─ solclient_ios/solclient-7.25.0.10/
   ├─ include/solclient/… (同上 4 個 header)
   └─ lib/  libsolclient.a (arm64 device + 舊 32-bit/x86_64 切片),
            libssl-universal.a, libcrypto-universal.a
```

### 1.3 SDK 關鍵事實（決定架構）
- **Callback 都帶 `void *user_p`**:每個 C callback(例如
  `solClient_session_eventCallbackFunc_t(opaqueSession, eventInfo, void *user_p)`)
  都留有 user context 欄位 → 這是把 C callback 橋接回 Swift 物件的乾淨前提。
- **4 個 header**:`solClient.h`(5706 行,核心)、`solClientMsg.h`(3982,訊息)、
  `solCache.h`(360,快取)、`solClientDeprecated.h`(786,舊 API,不包)。
- **OpenSSL 1.1 依賴**:SDK 自帶 `libssl`/`libcrypto`,需**靜態連結**避免
  runtime 找不到 dylib(沙盒/上架痛點)。
- **Callback 執行緒**:callback 跑在 Solace 的 context thread,不是 main/actor
  thread → 中階層負責 thread hop。

### 1.4 測試資源
- Solace **PubSub+ Cloud** 免費 broker,或本機 `solace/solace-pubsub-standard`
  docker broker(整合測試用:connect → publish → subscribe → 收到)。

---

## 2. 架構:三層

絕不把 C API 直接攤給 app。三層各自可獨立編譯/測試:

```
┌─────────────────────────────────────────┐
│  SolaceKit   高階, Swift-native, async    │  ← app 用這層
│  Session / Message 物件、async/await、     │
│  AsyncThrowingStream                       │
├─────────────────────────────────────────┤
│  SolaceCore  中階, safe wrapper            │  ← opaque pointer 生命週期、
│  C-callback ↔ Swift 橋接、Error 收斂        │     return code → Swift Error
├─────────────────────────────────────────┤
│  CSolace     低階, C interop               │  ← module.modulemap 暴露 header
└─────────────────────────────────────────┘
        libsolclient.a + libssl.a + libcrypto.a
```

### Package 佈局 (SwiftPM)
```
solace-swift/
├─ Package.swift
├─ scripts/
│  └─ build-xcframework.sh        # Phase 0:合成 xcframework
├─ Sources/
│  ├─ CSolace/                    # C interop shim
│  │  ├─ include/
│  │  │  ├─ module.modulemap
│  │  │  └─ shim.h                # #include 3 個官方 header
│  │  └─ shim.c                   # static inline / 包不動的橋接
│  ├─ SolaceCore/                 # import CSolace
│  └─ SolaceKit/                  # import SolaceCore,對外 API
├─ Frameworks/
│  └─ libsolclient.xcframework    # 產生物 (gitignored)
└─ Tests/
```

`Package.swift`:`binaryTarget` 指向 xcframework;`CSolace` 以 `.unsafeFlags`
靜態連結 OpenSSL `.a`。

---

## 3. 技術設計重點

### 3.1 二進位封裝 — xcframework（Phase 0,最大風險）
手上是裸 `.a`/`.dylib`,直接塞 SPM 會在跨平台/架構踩雷。做法:
1. `xcodebuild -create-xcframework`,合成
   `macos-arm64_x86_64`(universal2)+ `ios-arm64`(device 切片)。
2. **明確不假裝支援 simulator**:7.25.0.10 沒有 `arm64-apple-ios-simulator`
   切片,且無原料可自行合成。xcframework 只放上述兩個 slice;README 寫清楚
   「模擬器請用實機或 Rosetta(x86_64)」,讓限制在文件層面而非 link 時爆。
3. OpenSSL(libssl/libcrypto 1.1)一併靜態進去。

> 這步不過,上層 Swift 寫再漂亮整合都會崩 → 列為 Phase 0,先驗 link。

### 3.2 C callback → Swift 橋接（核心技術點）
利用每個 callback 的 `user_p`:
```swift
let ctx = Unmanaged.passRetained(self).toOpaque()      // connect 時
funcInfo.rxMsgInfo.callback_p = { _, msg_p, user_p in
    let me = Unmanaged<Session>.fromOpaque(user_p!).takeUnretainedValue()
    me.handleMessage(msg_p)
    return SOLCLIENT_CALLBACK_OK                        // 不 TAKE_MSG,讓 API 回收
}
funcInfo.rxMsgInfo.user_p = ctx
```
- C function pointer 在 Swift 只能是**不捕獲**的 closure → context 一律走
  `user_p`,絕不靠捕獲。
- `Unmanaged` 精準控生命週期:`passRetained` 於 connect、`release` 於 destroy。

### 3.3 非同步模型(SolaceKit 賣點)
- **一次性操作**(connect / send guaranteed 等回 ACK)→
  `withCheckedThrowingContinuation`,在 event callback 裡 resume。
- **持續訊息流**(訂閱)→ `AsyncThrowingStream<Message, Error>`,rxMsg callback
  裡 `continuation.yield()`,斷線時 `finish(throwing:)`。
- `Session` 設計成 `actor`(或 `@unchecked Sendable` box)確保跨 thread 安全。

目標對外 API:
```swift
let session = try await client.connect(host:…, vpn:…, user:…, pass:…)
try await session.subscribe(topic: "market/>")
for try await msg in session.messages {
    print(msg.topicString, msg.payloadData)
}
```

### 3.4 錯誤處理
`solClient_returnCode_t` + `subCode` + last-error 字串 → 統一收斂成
`enum SolaceError: Error`;每個可能失敗的呼叫點用 `try check(rc) { solClient_… }`
helper 包,不讓 return code 漏到上層。

### 3.5 記憶體與訊息所有權
`solClient_opaqueMsg_pt` 的所有權規則最易 leak/UAF:
- 收訊息時**立刻 copy** payload/topic 到 Swift 記憶體,**不持有 C 指標越過
  callback 邊界**(callback return 後 API 即回收)。
- 發訊息用 RAII 風格 builder:`alloc → 設值 → send → free` 包在單一函式。

---

## 4. 執行階段 (Phased)

| Phase | 內容 | 驗收 |
|---|---|---|
| **0** | `scripts/build-xcframework.sh` 合成 xcframework + 靜態連結 OpenSSL;`Package.swift` 骨架 + CSolace target | 空 Swift 檔能 link 並跑通 `solClient_initialize()` |
| **1** | CSolace `module.modulemap` 暴露 3 個 header | Swift 端 call 得到 C 符號、編譯過 |
| **2** | SolaceCore:context/session 生命週期、callback 橋接、Error 收斂 | 同步式 connect 成功、收得到 event |
| **3** | SolaceKit:async/await + `AsyncThrowingStream` 高階 API | `for try await msg in session.messages` 跑得動 |
| **4** | Guaranteed messaging / flow、reconnect、文件、範例 app | 整合測試綠燈 |

---

## 5. 測試策略
- **CSolace 層**:link + `solClient_initialize()` 成功的 smoke test → 先確認
  xcframework / OpenSSL 連結正確。
- **SolaceCore / Kit**:對 PubSub+ Cloud 或本機 docker broker 做整合測試。
- **CI**:只能用 macOS runner(iOS device 測試需實機,接受此限制)。

---

## 6. 已知限制
- **iOS 模擬器(Apple Silicon)不支援**:SDK 無 arm64-sim 切片 → 開發期用實機,
  或 `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` 走 Rosetta(慢、SwiftUI
  Preview 可能出狀況)。
- 商用 SDK 二進位不可重新散布 → 永遠 gitignore,private repo。
- 綁定 7.25.0.10;若 Solace 之後出含 simulator 切片的官方 xcframework,Phase 0
  可大幅簡化,屆時重評。
