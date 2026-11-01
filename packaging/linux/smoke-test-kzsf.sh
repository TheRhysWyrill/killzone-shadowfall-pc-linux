#!/usr/bin/env bash
# Opens the Killzone Shadow Fall AppImage on a virtual display and checks that it starts and its
# launcher stays open. Run as root in a fresh container of the distro to check; it installs Xvfb,
# a font and fontconfig, as a desktop has them (.github/workflows/kzsf-linux-appimage.yml).
# Usage: smoke-test-kzsf.sh path/to/KillzoneShadowFall-v*-x86_64.AppImage
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/host-libs.sh"
appimage=$(readlink -f -- "$1")
if command -v apt-get >/dev/null; then
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb fonts-dejavu-core fontconfig >/dev/null
elif command -v dnf >/dev/null; then
    dnf install -y -q xorg-x11-server-Xvfb dejavu-sans-fonts fontconfig >/dev/null
elif command -v zypper >/dev/null; then
    zypper -nq install xorg-x11-server-Xvfb dejavu-fonts fontconfig >/dev/null
elif command -v pacman >/dev/null; then
    pacman -Sy --noconfirm --needed xorg-server-xvfb ttf-dejavu fontconfig >/dev/null
fi
grep -m1 PRETTY_NAME /etc/os-release
ldd --version | sed -n 1p  # head would end ldd with SIGPIPE (pipefail)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
"$appimage" --appimage-extract >/dev/null
appdir=$work/squashfs-root
share=$appdir/usr/share/killzone-shadowfall
# The same library path AppRun exports; ldd does not read AppRun's environment by itself.
export LD_LIBRARY_PATH="$appdir/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

missing=$(
    {
        ldd "$share/Killzone Shadow Fall" 2>/dev/null || true
        ldd "$share/bin/KillzoneShadowFall" 2>/dev/null || true
        ldd "$share/bin/gpu/libgow3gpu.so" 2>/dev/null || true
    } | grep 'not found' || true
)
# Drivers and the font stack stay out of the bundle on purpose; only libraries that should have
# been bundled count as a failure.
host_missing=()
unexpected=()
while read -r name _; do
    [[ -n $name ]] || continue
    if [[ $name =~ $KZSF_HOST_LIBS_REGEX ]]; then
        host_missing+=("$name")
    else
        unexpected+=("$name")
    fi
done <<<"$missing"
if ((${#host_missing[@]})); then
    echo "Host-provided, not bundled (expected): $(printf '%s\n' "${host_missing[@]}" | sort -u | tr '\n' ' ')"
fi
if ((${#unexpected[@]})); then
    echo "FAIL: unresolved shared libraries:" >&2
    printf '\t%s\n' "${unexpected[@]}" | sort -u >&2
    exit 1
fi

status=0
timeout 20 "$appdir/AppRun" --version > version.log 2>&1 || status=$?
cat version.log
if [[ $status != 0 ]] || ! grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' version.log; then
    echo "FAIL: --version exited with $status" >&2
    exit 1
fi

Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
xvfb=$!
trap 'kill "$xvfb" 2>/dev/null || true; rm -rf "$work"' EXIT
export DISPLAY=:99 HOME=$work
sleep 2
status=0
timeout 15 "$appdir/AppRun" > launcher.log 2>&1 || status=$?
cat launcher.log
if [[ $status != 124 ]] || grep -qE 'GLIBC_|ImportError|Traceback|TclError' launcher.log; then
    echo "FAIL: the launcher exited ($status) instead of staying open" >&2
    exit 1
fi
echo "OK: the Killzone Shadow Fall launcher stayed open"
