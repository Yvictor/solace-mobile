# Android Solace Native Compression PoC

This is a minimal Android proof of concept for the Solace PubSub+ Messaging API
for Java (`solace-messaging-client-1.10.0`) with native Solace compression
enabled.

Status: validated on an Android emulator with compression level `3`, Basic
auth, wildcard topic subscription, and live `TXFG6` message receipt.

The Solace jars are proprietary and are not committed. Install them locally:

```sh
bash android/scripts/install-solace-jars.sh /Users/ec666/Downloads/solace-messaging-client-1.10.0.zip
```

Then open `android/` in Android Studio and run the `app` module.

Or build from the command line with the installed Android SDK/JDK:

```sh
bash android/scripts/assemble-debug.sh
```

The debug APK is written to:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

## Runtime Inputs

The app UI asks for:

- Host, for example `tcps://broker.example.com:55443` or `tcp://broker.example.com:55555`
- VPN
- Username
- Password
- Subscribe topic, wildcards allowed
- Publish topic, concrete topic only
- Compression level, usually `0` to disable or `1..9` to enable

The PoC uses:

- `MessagingService.builder(ConfigurationProfile.V1)`
- `withMessageCompression(compressionLevel)`
- Basic username/password auth
- Direct message publisher and receiver

It intentionally avoids Kerberos, JMX/management, client certificate auth, and
Netty's Linux epoll native jar.

## Android Compatibility Notes

JCSMP references Java SE GSS/Kerberos classes during static initialization even
when Basic auth is used. Android does not ship `org.ietf.jgss.*`, so this PoC
includes narrow Android-only shims under:

```text
app/src/main/java/org/ietf/jgss/
```

Those shims exist only to let the unused Kerberos metadata path load. Kerberos
auth is not supported by this PoC.

## JVM Smoke Test

If Android Studio/Android SDK is not available, this verifies classpath and
basic Solace builder initialization on the desktop JVM:

```sh
bash android/scripts/run-jvm-smoke.sh
```

To actually connect from the JVM smoke test, provide environment variables:

```sh
SOLACE_HOST='tcp://host:55555' \
SOLACE_VPN='default' \
SOLACE_USER='user' \
SOLACE_PASSWORD='pass' \
SOLACE_SUBSCRIBE_TOPIC='android/poc' \
SOLACE_PUBLISH_TOPIC='android/poc' \
SOLACE_COMPRESSION_LEVEL='3' \
bash android/scripts/run-jvm-smoke.sh
```

The JVM smoke test is not a replacement for Android DEX/runtime validation.
