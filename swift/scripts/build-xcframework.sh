set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/swift/.build/xcframework"
OUTPUT_DIR="$ROOT_DIR/swift/Frameworks"
OUTPUT="$OUTPUT_DIR/SolaceClientNative.xcframework"

MACOS_SDK="$ROOT_DIR/solclient_macos/solclient_Darwin-universal2_opt_7.25.0.10"
IOS_SDK="$ROOT_DIR/solclient_ios/solclient-7.25.0.10"

MACOS_LIB="$MACOS_SDK/lib/libsolclient.a.7.25.0.10"
MACOS_SSL="$MACOS_SDK/lib/libssl.a"
MACOS_CRYPTO="$MACOS_SDK/lib/libcrypto.a"
IOS_LIB="$IOS_SDK/lib/libsolclient.a"
IOS_SSL="$IOS_SDK/lib/libssl-universal.a"
IOS_CRYPTO="$IOS_SDK/lib/libcrypto-universal.a"

MACOS_HEADERS="$MACOS_SDK/include"
IOS_HEADERS="$IOS_SDK/include"

require_file() {
    if [ ! -f "$1" ]; then
        echo "missing file: $1" >&2
        exit 1
    fi
}

require_dir() {
    if [ ! -d "$1" ]; then
        echo "missing directory: $1" >&2
        exit 1
    fi
}

require_arch() {
    local lib="$1"
    local arch="$2"
    if ! lipo -info "$lib" | grep -q "$arch"; then
        echo "missing $arch slice in $lib" >&2
        lipo -info "$lib" >&2
        exit 1
    fi
}

require_file "$MACOS_LIB"
require_file "$MACOS_SSL"
require_file "$MACOS_CRYPTO"
require_file "$IOS_LIB"
require_file "$IOS_SSL"
require_file "$IOS_CRYPTO"
require_dir "$MACOS_HEADERS"
require_dir "$IOS_HEADERS"

require_arch "$MACOS_LIB" "arm64"
require_arch "$MACOS_LIB" "x86_64"
require_arch "$MACOS_SSL" "arm64"
require_arch "$MACOS_SSL" "x86_64"
require_arch "$MACOS_CRYPTO" "arm64"
require_arch "$MACOS_CRYPTO" "x86_64"
require_arch "$IOS_LIB" "arm64"
require_arch "$IOS_SSL" "arm64"
require_arch "$IOS_CRYPTO" "arm64"

mkdir -p "$BUILD_DIR/macos" "$BUILD_DIR/ios" "$OUTPUT_DIR"
rm -rf "$OUTPUT"

cp "$MACOS_LIB" "$BUILD_DIR/macos/libsolclient.a"
cp "$MACOS_SSL" "$BUILD_DIR/macos/libssl.a"
cp "$MACOS_CRYPTO" "$BUILD_DIR/macos/libcrypto.a"
lipo "$IOS_LIB" -thin arm64 -output "$BUILD_DIR/ios/libsolclient.a"
lipo "$IOS_SSL" -thin arm64 -output "$BUILD_DIR/ios/libssl.a"
lipo "$IOS_CRYPTO" -thin arm64 -output "$BUILD_DIR/ios/libcrypto.a"

libtool -static -o "$BUILD_DIR/macos/libSolaceClientNative.a" \
    "$BUILD_DIR/macos/libsolclient.a" \
    "$BUILD_DIR/macos/libssl.a" \
    "$BUILD_DIR/macos/libcrypto.a"

libtool -static -o "$BUILD_DIR/ios/libSolaceClientNative.a" \
    "$BUILD_DIR/ios/libsolclient.a" \
    "$BUILD_DIR/ios/libssl.a" \
    "$BUILD_DIR/ios/libcrypto.a"

xcodebuild -create-xcframework \
    -library "$BUILD_DIR/macos/libSolaceClientNative.a" \
    -headers "$MACOS_HEADERS" \
    -library "$BUILD_DIR/ios/libSolaceClientNative.a" \
    -headers "$IOS_HEADERS" \
    -output "$OUTPUT"

echo "$OUTPUT"
