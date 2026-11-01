#!/usr/bin/env bash
# Builds dist/KillzoneShadowFall-v<version>-x86_64.AppImage from the Linux build.
# Run `bash build.sh` in the repository root first. Libraries are bundled except the ones that
# must come from the host (glibc, Vulkan loader/drivers, X11/Wayland, GL, audio). The Tk launcher
# is frozen with PyInstaller, so players need no Python or GTK/Qt.
#
# Needs: ldd, objdump, patchelf, curl (appimagetool), python3 with PyInstaller, tk and pillow.
# .github/workflows/kzsf-linux-appimage.yml installs them with packaging/linux/ci-deps.sh.
set -euo pipefail
cd -- "$(dirname -- "$0")/../.."
[[ -f out/gow3-probe && -f out/gpu/libgow3gpu.so ]] || {
    echo 'Build first: bash build.sh' >&2
    exit 1
}

version=$(sed -n "s/^VERSION = '\\(.*\\)'/\\1/p" launcher/kzsf_launcher.py)
[[ -n $version ]] || { echo 'Could not read VERSION from launcher/kzsf_launcher.py' >&2; exit 1; }
name='Killzone Shadow Fall'
appdir=out/kzsf-AppDir
share=$appdir/usr/share/killzone-shadowfall

rm -rf -- "$appdir"
mkdir -p "$share/bin/gpu" "$share/launcher" "$share/multiplayer/server/fixtures" \
         "$appdir/usr/lib" "$appdir/usr/share/applications" \
         "$appdir/usr/share/icons/hicolor/256x256/apps"

install -m755 out/gow3-probe "$share/bin/KillzoneShadowFall"
install -m755 out/gpu/libgow3gpu.so "$share/bin/gpu/"
cp run.py LICENSE "$share/"
cp -r scripts patches "$share/"
cp multiplayer/*.py multiplayer/README.md "$share/multiplayer/"
cp multiplayer/server/fixtures/* "$share/multiplayer/server/fixtures/"
for source in multiplayer/server/*.py; do
    [[ $(basename "$source") == test_* ]] || cp "$source" "$share/multiplayer/server/"
done
cp launcher/kzsf.png "$share/launcher/"
cp packaging/linux/kzsf/README.txt "$share/README.txt"

# FSR 4 optimized passes (tools/fsr4_optimize.sh): optional, but they remove the 1080p pass 11
# race and make the post passes much faster. The launcher downloads the rest of the model into
# the writable data folder at first use; AppRun copies these 24 passes there.
if command -v spirv-cross >/dev/null && command -v glslangValidator >/dev/null; then
    if bash tools/fetch_fsr4_assets.sh; then
        opt_count=$(find fsr4_shaders/opt -maxdepth 1 -name '*.spv' 2>/dev/null | wc -l || true)
        if [[ $opt_count == 24 ]]; then
            mkdir -p "$share/fsr4_shaders"
            cp -a fsr4_shaders/opt "$share/fsr4_shaders/"
            cp fsr4_shaders/LICENSE-FSR4-v07.txt "$share/fsr4_shaders/"
        else
            echo "FSR 4: optimized passes incomplete ($opt_count/24); the launcher fetches the originals" >&2
        fi
    else
        echo 'FSR 4: optimized passes skipped (download failed); the launcher can fetch the originals' >&2
    fi
else
    echo 'FSR 4: optimized passes skipped (spirv-cross/glslangValidator missing)' >&2
fi

# The launcher is frozen with PyInstaller: players need no Python. The Windows package uses the
# same hidden imports, because run.py and the preparation scripts run inside the frozen executable.
python=${PYTHON:-}
if [[ -z $python ]]; then
    if [[ -x out/venv/bin/python ]]; then
        python=$PWD/out/venv/bin/python
    else
        python=$(command -v python3 || true)
    fi
fi
[[ -n $python ]] || { echo 'Need Python 3 with PyInstaller (see packaging/linux/ci-deps.sh)' >&2; exit 1; }
"$python" -c 'import PyInstaller, PIL, tkinter' 2>/dev/null || {
    echo "Need PyInstaller, Pillow and tkinter in $python (see packaging/linux/ci-deps.sh)" >&2
    exit 1
}

hidden=()
for module in argparse base64 binascii collections contextlib copy csv dataclasses datetime \
              email.parser gzip hashlib http.client http.cookies http.server io ipaddress json \
              queue re secrets shlex shutil socket ssl stat struct tempfile threading time \
              urllib.parse urllib.request uuid xml.etree.ElementTree zipfile zlib \
              tkinter tkinter.filedialog tkinter.messagebox tkinter.ttk PIL PIL.Image PIL.ImageTk \
              iced_x86 kzsf_update kzsf_fsr4 kzsf_web; do
    hidden+=(--hidden-import "$module")
done
"$python" -m PyInstaller --noconfirm --clean --log-level WARN --windowed --copy-metadata pillow \
    --name "$name" --distpath out/kzsf-pyi-dist --workpath out/kzsf-pyi-work \
    --specpath out/kzsf-pyi-work --paths "$PWD/launcher" --paths "$PWD/scripts" \
    --paths "$PWD/multiplayer" --add-data "$PWD/launcher/web:web" "${hidden[@]}" \
    "$PWD/launcher/kzsf_launcher.py"

[[ -x "out/kzsf-pyi-dist/$name/$name" ]] || { echo 'PyInstaller did not produce the launcher' >&2; exit 1; }
cp -r "out/kzsf-pyi-dist/$name/." "$share/"
find "$share" -name __pycache__ -prune -exec rm -r {} +

install -m755 packaging/linux/kzsf/AppRun "$appdir/AppRun"
install -m644 packaging/linux/kzsf/kzsf.desktop "$appdir/killzone-shadowfall.desktop"
install -m644 launcher/kzsf.png "$appdir/killzone-shadowfall.png"
ln -sf killzone-shadowfall.png "$appdir/.DirIcon"
install -m644 launcher/kzsf.png "$appdir/usr/share/icons/hicolor/256x256/apps/killzone-shadowfall.png"
install -m644 packaging/linux/kzsf/kzsf.desktop "$appdir/usr/share/applications/killzone-shadowfall.desktop"

# Host-provided libraries: the smoke test uses the same list, so both agree on what stays out.
source packaging/linux/host-libs.sh
declare -A seen
bundle() {
    local elf=$1 line lib name deps
    deps=$(ldd "$elf") || true
    if grep -q 'not found' <<<"$deps"; then
        echo "Missing shared libraries for $elf:" >&2
        grep 'not found' <<<"$deps" >&2
        exit 1
    fi
    while read -r line; do
        lib=$(awk '/=> \//{print $3}' <<<"$line")
        [[ -n $lib ]] || continue
        name=$(basename -- "$lib")
        [[ ${seen[$name]:-} ]] && continue
        seen[$name]=1
        [[ $name =~ $KZSF_BUNDLE_EXCLUDES_REGEX ]] && continue
        [[ $name == libgow3gpu.so ]] && continue  # it stays in bin/gpu, found by the probe's RUNPATH
        install -m755 "$lib" "$appdir/usr/lib/$name"
        bundle "$lib"
    done <<<"$deps"
}
bundle "$share/bin/KillzoneShadowFall"
bundle "$share/bin/gpu/libgow3gpu.so"
# libstdc++/libgcc come from the build host: the same glibc generation as the one that runs the
# AppImage is assumed, and a newer libstdc++ than Mesa's is the safe direction.
for name in libstdc++.so.6 libgcc_s.so.1; do
    library=$(ldd "$share/bin/gpu/libgow3gpu.so" | awk -v n="$name" '$1==n{print $3}')
    [[ -n $library ]] && install -m755 "$library" "$appdir/usr/lib/$name"
done
find "$appdir/usr/lib" -name '*.so*' -exec strip --strip-unneeded {} + 2>/dev/null || true

# The newest glibc symbol in the bundle is the oldest glibc players can have. Ubuntu 24.04
# (glibc 2.39) is the reference: SteamOS, Bazzite/Fedora, Debian 13 and Ubuntu 24.04+ work.
# KZSF_MAX_GLIBC raises the limit for local builds.
max_glibc=${KZSF_MAX_GLIBC:-2.39}
need=$(find "$appdir" -type f \( -name '*.so*' -o -perm -u+x \) -exec objdump -T {} + 2>/dev/null |
       grep -o 'GLIBC_2\.[0-9.]*' | sed 's/GLIBC_//' | sort -uV | tail -1 || true)
if [[ -n $need && $(printf '%s\n' "$need" "$max_glibc" | sort -V | tail -1) != "$max_glibc" ]]; then
    echo "The bundle needs glibc $need, newer than $max_glibc: build on Ubuntu 24.04" \
         "(packaging/linux/ci-deps.sh) or set KZSF_MAX_GLIBC" >&2
    exit 1
fi
[[ -n $need ]] && echo "Minimum glibc: $need"

tool=${APPIMAGETOOL:-$(command -v appimagetool || true)}
if [[ -z $tool ]]; then
    tool=out/appimagetool-x86_64.AppImage
    if [[ ! -x $tool ]]; then
        curl -fL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
        chmod +x "$tool"
    fi
fi
mkdir -p dist
output="dist/KillzoneShadowFall-v$version-x86_64.AppImage"
# Written aside and moved over: replacing a running AppImage in place fails ("Text file busy").
rm -f -- "$output.new"
ARCH=x86_64 "$tool" --appimage-extract-and-run "$appdir" "$output.new"
mv -f "$output.new" "$output"
(cd dist && sha256sum "$(basename "$output")" > "$(basename "$output").sha256")
ls -lh "$output" "$output.sha256"
