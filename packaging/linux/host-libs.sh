# SPDX-License-Identifier: GPL-2.0-or-later
# Libraries the AppImage deliberately leaves to the host. Bundling drivers, the Vulkan loader, the
# display stack or audio backends breaks them on the player's machine. Shared by build-kzsf.sh
# (what not to copy recursively) and smoke-test-kzsf.sh (what may stay unresolved in a container).
KZSF_HOST_LIBS=(
    'ld-linux.*' 'libc' 'libm' 'libdl' 'librt' 'libpthread' 'libresolv' 'libutil' 'libnsl' 'libanl'
    'libvulkan' 'libGL' 'libGLX' 'libGLdispatch' 'libEGL' 'libOpenGL' 'libgbm' 'libdrm.*'
    'libX11' 'libX11-xcb' 'libxcb.*' 'libXau' 'libXdmcp' 'libXext' 'libXfixes' 'libXrender'
    'libXi' 'libXcursor' 'libXrandr' 'libwayland-.*' 'libasound' 'libudev' 'libpulse.*'
    'libfontconfig' 'libfreetype' 'libOpenCL' 'libva.*' 'libvdpau' 'libvpl'
    'libnvidia-.*' 'libcuda' 'libz'
)
# The C++ runtime is the exception: it is copied explicitly from the build host, so bundle() must
# not copy it recursively, but the smoke test still requires it in the AppImage.
KZSF_BUNDLE_EXCLUDES=("${KZSF_HOST_LIBS[@]}" 'libstdc\+\+' 'libgcc_s')

kzsf_library_regex() {
    local IFS='|'
    printf '^(%s)[.]so' "$*"
}
KZSF_HOST_LIBS_REGEX=$(kzsf_library_regex "${KZSF_HOST_LIBS[@]}")
KZSF_BUNDLE_EXCLUDES_REGEX=$(kzsf_library_regex "${KZSF_BUNDLE_EXCLUDES[@]}")
