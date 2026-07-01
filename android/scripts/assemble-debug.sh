set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH="$JAVA_HOME/bin:$PATH"

gradle -p "$repo_root" :app:assembleDebug --no-daemon
