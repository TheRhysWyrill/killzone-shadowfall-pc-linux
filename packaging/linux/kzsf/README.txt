Killzone Shadow Fall for Linux (AppImage)
=========================================

Killzone Shadow Fall (PS4, version 01.81) running natively on Linux: no Wine, no emulator. You
need your own, legally obtained, decrypted game dump:

  * the CUSA00190 release (or CUSA00191 / CUSA00002 / CUSA00085, untested) at version 01.81
  * the folder that holds eboot.bin and sce_sys/param.sfo

Nothing in your game folder is modified or copied. The launcher accepts the base game and its
update folder; the game itself can also be a base folder that already is 01.81.

Start
-----
Make the AppImage executable and run it:

  chmod +x KillzoneShadowFall-v<version>-x86_64.AppImage
  ./KillzoneShadowFall-v<version>-x86_64.AppImage

This opens the same launcher as the Windows build, with every page the port has:

  GAME        dump folder, update folder, player name, FOV, saves/screenshots/logs and cache
  GRAPHICS    display mode, output and render resolution, ultrawide, FPS limit, frame generation,
              upscaler quality, anisotropy, texture sharpness, LOD, VSync, FSR 1, effects
  CONTROLS    keyboard, mouse, controller mapping, dead zone, speaker, prompts, quick menu
  CHEATS      the port's debug switches (god mode, ammo, sprint, tactical echo, chapters)
  MULTIPLAYER private rooms over Radmin VPN or a LAN (beta), with a separate save
  ADVANCED    shader precompile, performance options, upscaler method (FSR 3.1 / FSR 4 / DLSS /
              classic), readback options, update checks and Discord Rich Presence

PLAY prepares the game files and starts the game. SAVE keeps the settings for the next time; they
are also written to launcher.json and settings.ini in the data folder, so an in-game "Apply and
restart" keeps them. The settings map to the runtime's GOW3_* environment variables and to
settings.ini and the patch files.

Data folder
-----------
Settings, the prepared game image, saves, logs, mods and downloaded FSR 4 shaders live in a `data/`
folder beside the AppImage when that folder is writable. If the AppImage is on a read-only or
system folder, they live in ~/.local/share/killzone-shadowfall instead.

To force a portable install, create an empty `portable` file next to the AppImage or set
KZSF_PORTABLE=1. Use KZSF_DATA_DIR or KZSF_USER_DIR to choose another folder, for example:

  KZSF_DATA_DIR="$HOME/Games/Killzone/data" ./KillzoneShadowFall-v<version>-x86_64.AppImage

The game folders are only read; nothing is written into them.

Options
-------
  --play                Start the game with the saved options, without the launcher window.
  --version             Print the launcher version.
  --help                Show this text.

Environment
-----------
  KZSF_DATA_DIR         Data folder (overrides the automatic choice).
  KZSF_USER_DIR         Same as KZSF_DATA_DIR; the launcher's own variable.
  KZSF_PORTABLE=1       Use data/ next to the AppImage.
  GOW3_*                Runtime options; the launcher writes the ones it manages. See the
                        project README for the full list, including diagnostics.

Requirements
------------
x86_64 Linux with a Vulkan 1.3 driver (Mesa RADV/ANV or the NVIDIA proprietary driver). The
AppImage uses the host's glibc, Vulkan loader/driver, X11 stack (XWayland on Wayland desktops) and
audio backends; SDL3, FFmpeg, Zydis and the other non-system libraries are bundled. Without
libfuse2, run it with --appimage-extract-and-run (or APPIMAGE_EXTRACT_AND_RUN=1). The launcher uses
Tk from the bundle, so it needs no GTK, Qt or Python installation. Hosting a multiplayer room also
needs `openssl` in PATH, as the Windows package's bundled OpenSSL does; joining a room does not.

Steam Deck: add the AppImage as a non-Steam game. Gaming Mode works; Desktop Mode can
open the launcher too. The launcher fits an 800p screen and scrolls the longer pages.

Updating
--------
The launcher checks GitHub for releases that include a `KillzoneShadowFall-v*-x86_64.AppImage`
asset. "Update now" downloads it, replaces the AppImage after the launcher exits and starts the
new version. The data folder is untouched. If the update cannot replace the file (read-only
folder), download the new AppImage by hand; your data keeps working.
