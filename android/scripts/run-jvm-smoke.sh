set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
libs_dir="$repo_root/app/libs"
build_dir="$repo_root/jvm-smoke/build/classes"
classpath="$libs_dir/*"

if ! ls "$libs_dir"/*.jar >/dev/null 2>&1; then
  echo "No jars found in $libs_dir" >&2
  echo "Run: bash android/scripts/install-solace-jars.sh /Users/ec666/Downloads/solace-messaging-client-1.10.0.zip" >&2
  exit 1
fi

rm -rf "$repo_root/jvm-smoke/build"
mkdir -p "$build_dir"

javac -cp "$classpath" \
  -d "$build_dir" \
  "$repo_root/app/src/main/java/com/example/solacepoc/SolaceProbe.java" \
  "$repo_root/jvm-smoke/src/main/java/com/example/solacepoc/JvmSmoke.java"

java -cp "$build_dir:$classpath" com.example.solacepoc.JvmSmoke
