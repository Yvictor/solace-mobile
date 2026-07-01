set -eu

zip_path="${1:-/Users/ec666/Downloads/solace-messaging-client-1.10.0.zip}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
libs_dir="$repo_root/app/libs"
tmp_dir="${TMPDIR:-/tmp}/solace-mobile-android-jars"

if [ ! -f "$zip_path" ]; then
  echo "Solace zip not found: $zip_path" >&2
  exit 1
fi

rm -rf "$tmp_dir"
mkdir -p "$tmp_dir" "$libs_dir"

unzip -q -o "$zip_path" 'lib/*.jar' -d "$tmp_dir"
find "$libs_dir" -name '*.jar' -delete

for jar in "$tmp_dir"/lib/*.jar; do
  name="$(basename "$jar")"
  case "$name" in
    *javadoc.jar|*linux-x86_64.jar)
      echo "Skipping $name"
      ;;
    *)
      cp "$jar" "$libs_dir/$name"
      echo "Installed $name"
      ;;
  esac
done

for artifact in netty-common netty-buffer; do
  name="$artifact-4.2.13.Final.jar"
  if [ ! -f "$libs_dir/$name" ]; then
    url="https://repo1.maven.org/maven2/io/netty/$artifact/4.2.13.Final/$name"
    echo "Downloading missing dependency $name"
    curl -fL --retry 3 -o "$libs_dir/$name" "$url"
  fi
done

echo "Installed Solace jars into $libs_dir"
