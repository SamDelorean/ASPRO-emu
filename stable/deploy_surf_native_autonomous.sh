#!/bin/sh
# ASPRO-STABLE NATIVE Surface RT build/install, not T640/cross-compilation.
# Reuse pinned local AS2K/MAME sources and object cache, -j1, no make clean.
set -eu
umask 077
STAMP=20261021
WORK="$HOME/Projects/alphasmart/as2k-surf-native"
MAME="$WORK/sources/mame-as3k"
AS2K="$WORK/sources/AS2K-Emulator"
PREFIX="$WORK/aspro-stable-native"
APP="$PREFIX/stable"
CPU="$APP/proven_hc11"
PRIVATE="$HOME/.local/share/alphasmart/private/aspro"
LOG="$PRIVATE/logs/surf-native-build-install.log"
STATUS="$PRIVATE/logs/surf-native-build-install.status"
TARGET=/usr/local/libexec/aspro/aspro-bin
# Verified public source bundle (same driver, HC11 and GTK as installed in Surf
# and Vontar, plus the corrected root-directory permissions in installer).
# Pinned stable driver/GTK release after native Pro keyboard/LCD repair.
REF=c3b1b2bd42788265b44b1a0bbdcc086e22ee3b1c
mkdir -p "$APP" "$CPU" "$PRIVATE/logs" "$PRIVATE/binaries/stable-armv7" "$PREFIX/backup"
exec >"$LOG" 2>&1
STEP=PREFLIGHT
OVERLAID=0
INSTALLED=0
BACK="$PREFIX/backup"
finish() {
 rc=$?
 trap - EXIT
 if test "$OVERLAID" -eq 1; then
  for item in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h src/mame/mame.lst 3rdparty/bx/include/bx/platform.h 3rdparty/bx/src/file.cpp 3rdparty/bx/src/thread.cpp; do
   if test -f "$BACK/$item"; then cp -p "$BACK/$item" "$MAME/$item"; fi
  done
 fi
 printf 'TASK=ASPRO_SURF_STABLE_NATIVE\nSTEP=%s\nEXIT=%s\n' "$STEP" "$rc" >"$STATUS"
 if test "$rc" -eq 0; then
   echo "ASPRO_SURF_STABLE_NATIVE_PASS" >>"$STATUS"
 else
   echo "ASPRO_SURF_STABLE_NATIVE_FAILED $rc $STEP" >>"$LOG"
 fi
 exit "$rc"
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
test "$(uname -m)" = armv7l || { echo "BLOCKED_NOT_SURF_ARMV7"; exit 2; }
sudo -n true || { echo "BLOCKED_SUDO_NOT_READY"; exit 2; }
test -e "$MAME/.git" && test -f "$MAME/makefile" && test -e "$AS2K/.git" ||
 { echo "BLOCKED_MISSING_EXISTING_NATIVE_SOURCE"; exit 2; }
test "$(git -C "$MAME" rev-parse HEAD)" = 1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b ||
 { echo "BLOCKED_UNEXPECTED_NATIVE_MAME_COMMIT"; exit 2; }
test ! -L "$MAME" && test ! -L "$MAME/src/mame/skeleton/alphasma.cpp" ||
 { echo "BLOCKED_SYMLINKED_MAME_SOURCE"; exit 2; }
git -C "$MAME" diff --quiet && git -C "$MAME" diff --cached --quiet ||
 { echo "BLOCKED_DONOR_SOURCE_HAS_CHANGES"; exit 3; }
FREE_KB=$(df -Pk "$WORK" | awk 'NR==2 {print $4}')
test "$FREE_KB" -ge 5242880 || { echo "BLOCKED_LESS_THAN_5_GIB_FREE"; exit 3; }
test -x /usr/local/libexec/as2k/as2k-bin || { echo "BLOCKED_AS2K_INSTALLED_CORE_MISSING"; exit 3; }
for f in "$PRIVATE/roms/firmware.bin" "$PRIVATE/roms/ks0066_f05.bin" "$PRIVATE/payload/payload0_pro.bin"; do
 test -s "$f" || { echo "BLOCKED_MISSING_PRIVATE_ASPRO_ASSET $f"; exit 3; }
done
python3 - "$PRIVATE" <<'PY'
import hashlib,sys
from pathlib import Path
p=Path(sys.argv[1])
for name,size,sha in [
 ("roms/firmware.bin",32768,"c3c6a421c9ced92db97431d04b4a3f09a39de716"),
 ("roms/ks0066_f05.bin",4096,"0196e871584ee5d370856e7307c0f9d1466e3e51")]:
 data=(p/name).read_bytes()
 assert len(data)==size and hashlib.sha1(data).hexdigest()==sha,name
data=(p/"payload/payload0_pro.bin").read_bytes()
assert len(data)==121 and hashlib.sha256(data).hexdigest()=="25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53"
print("PRIVATE_ROM_LCD_PAYLOAD_VERIFIED")
PY
STEP=FETCH_ONLY_RELEASE_SOURCE_IN_SURF
BASEURL="https://raw.githubusercontent.com/SamDelorean/ASPRO-emu/$REF/stable"
for name in alphasma.cpp aspro_ui.py aspro_session.py install_stable.sh; do
 wget -q -T 30 -t 3 "$BASEURL/$name" -O "$APP/$name"
 test -s "$APP/$name" || { echo "BLOCKED_RELEASE_SOURCE_MISSING $name"; exit 4; }
done
for name in mc68hc11.cpp mc68hc11.h; do
 wget -q -T 30 -t 3 "$BASEURL/proven_hc11/$name" -O "$CPU/$name"
 test -s "$CPU/$name" || { echo "BLOCKED_PROVEN_D0_SOURCE_MISSING $name"; exit 4; }
done
python3 -m py_compile "$APP/aspro_ui.py" "$APP/aspro_session.py"
mkdir -p "$PREFIX/tools"
wget -q -T 30 -t 3 "https://raw.githubusercontent.com/SamDelorean/ASPRO-emu/$REF/tools/smoke_stable_bridge.py" -O "$PREFIX/tools/smoke_stable_bridge.py"
test -s "$PREFIX/tools/smoke_stable_bridge.py" || { echo "BLOCKED_STABLE_BRIDGE_SMOKE_SOURCE"; exit 4; }
grep -q diag_bootstrap_tx_bit "$CPU/mc68hc11.cpp"
grep -q diagnostic_bootstrap_wait_for_serial "$CPU/mc68hc11.h"
sha256sum "$CPU/"* "$APP/"*.py "$APP/alphasma.cpp" >"$PREFIX/source-sha256.txt"
STEP=BACKUP_NATIVE_DONOR_SOURCES
for item in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h src/mame/mame.lst 3rdparty/bx/include/bx/platform.h 3rdparty/bx/src/file.cpp 3rdparty/bx/src/thread.cpp; do
 test -f "$MAME/$item" && test ! -L "$MAME/$item" ||
  { echo "BLOCKED_UNSAFE_NATIVE_SOURCE $item"; exit 4; }
 mkdir -p "$BACK/$(dirname "$item")"
 cp -p "$MAME/$item" "$BACK/$item"
done
OVERLAID=1
cp "$APP/alphasma.cpp" "$MAME/src/mame/skeleton/alphasma.cpp"
cp "$CPU/mc68hc11.cpp" "$MAME/src/devices/cpu/mc68hc11/mc68hc11.cpp"
cp "$CPU/mc68hc11.h" "$MAME/src/devices/cpu/mc68hc11/mc68hc11.h"
# Keep only Pro from skeleton/alphasma in this transient source list.
awk '
 /^@source:/ {in_pro=($0=="@source:skeleton/alphasma.cpp")}
 in_pro && $0=="asma2k" {next}
 {print}
' "$BACK/src/mame/mame.lst" >"$MAME/src/mame/mame.lst"
# EXACT reusable Surface native musl adaptation of 17-Oct-2026,
# recovered from surface-native-build-musl-v2-20261017.sh (successful AS2K).
# All three donor files were backed up above and are restored by EXIT trap.
STEP=BX_MUSL_NATIVE_V2_20261017
python3 -B - "$MAME/3rdparty/bx/include/bx/platform.h" \
    "$MAME/3rdparty/bx/src/file.cpp" \
    "$MAME/3rdparty/bx/src/thread.cpp" <<'PY_BX_MUSL'
from pathlib import Path
import sys
h,f,th=map(Path,sys.argv[1:])
s=h.read_text()
replacements=[
 ('#define BX_CRT_NEWLIB 0',
  '#define BX_CRT_NEWLIB 0\n#define BX_CRT_MUSL   0'),
 ('#\telif BX_PLATFORM_BSD\n#\t\tundef  BX_CRT_BSD\n#\t\tdefine BX_CRT_BSD 1',
  '#\telif BX_PLATFORM_BSD\n#\t\tundef  BX_CRT_BSD\n#\t\tdefine BX_CRT_BSD 1'
  '\n#\telif BX_PLATFORM_LINUX && !defined(__GLIBC__)'
  '\n#\t\tundef  BX_CRT_MUSL\n#\t\tdefine BX_CRT_MUSL 1'),
 ('\t&& !BX_CRT_NEWLIB',
  '\t&& !BX_CRT_NEWLIB ' + chr(92) + '\n\t&& !BX_CRT_MUSL'),
 ('#elif BX_CRT_NEWLIB',
  '#elif BX_CRT_MUSL\n#\tdefine BX_CRT_NAME "musl libc"\n#elif BX_CRT_NEWLIB'),
]
for before,after in replacements:
    if s.count(before)!=1:
        raise SystemExit("BLOCKED canonical BX platform.h layout changed: "+before[:40])
    s=s.replace(before,after,1)
t=f.read_text()
before='#\telif 0                   '+chr(92)
after=('#\telif BX_CRT_MUSL\n#\t\tdefine fseeko64 fseeko'
       '\n#\t\tdefine ftello64 ftello\n'+before)
if t.count(before)!=1:
    raise SystemExit("BLOCKED canonical BX file.cpp layout changed")
t=t.replace(before,after,1)
q=th.read_text()
thread_before='#\tinclude <pthread.h>\n#\tif BX_PLATFORM_BSD'
thread_after=('#\tinclude <pthread.h>\n'
              '#\tif BX_CRT_MUSL && BX_PLATFORM_LINUX\n'
              '#\t\tinclude <sys/prctl.h>\n'
              '#\tendif\n#\tif BX_PLATFORM_BSD')
if q.count(thread_before)!=1:
    raise SystemExit("BLOCKED canonical BX thread.cpp layout changed")
q=q.replace(thread_before,thread_after,1)
h.write_text(s); f.write_text(t); th.write_text(q)
print("BX_MUSL_V2_CANONICAL_REVERSIBLE_PATCH_APPLIED")
PY_BX_MUSL
# Fast target ABI proof: fail before wasting RAM on the full make.
printf '#include <bx/platform.h>\n#if BX_CRT_NONE || !BX_CRT_MUSL\n#error BX musl CRT misdetected\n#endif\n' |
 c++ -E -x c++ -I"$MAME/3rdparty/bx/include" - >/dev/null
printf '#include <sys/types.h>\nstatic_assert(sizeof(off_t)==8, "musl off_t must be 64bit");\n' |
 c++ -std=c++17 -fsyntax-only -x c++ -
c++ -std=c++17 -DBX_CONFIG_DEBUG=0 -I"$MAME/3rdparty/bx/include" \
 -fsyntax-only "$MAME/3rdparty/bx/src/crtnone.cpp" \
 "$MAME/3rdparty/bx/src/file.cpp" "$MAME/3rdparty/bx/src/thread.cpp"
echo "BX_MUSL_NATIVE_SYNTAX_PASS"
# The original successful build proves that the generated bx target is
# 'mameas2k'; this ASPRO build generates 'mameaspro' itself during make.
# Do not reuse the AS2K-generated bx.make or installed AS2K objects as ASPRO.
STEP=COMPILE_NATIVE_ARMV7_J1
# Existing native build policy: ARMv7/musl, C DRC, no x86 -m32, -j1, no clean.
export MAKEFLAGS='ARCHITECTURE='
export PLATFORM=arm NOASM=1 FORCE_DRC_C_BACKEND=1
export NO_OPENGL=1 NO_USE_XINPUT=1 NO_USE_PORTAUDIO=1
export NO_USE_PULSEAUDIO=1 NO_USE_PIPEWIRE=1 NO_USE_MIDI=1
export USE_QTDEBUG=0 NOWERROR=1 OPTIMIZE=1 REGENIE=1
cd "$MAME"
make -j1 TARGET=mame SUBTARGET=aspro SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 USE_QTDEBUG=0
test -x "$MAME/aspro" || { echo "BLOCKED_ASPRO_BINARY_NOT_PRODUCED"; exit 5; }
STEP=VALIDATE_NATIVE_BINARY
LC_ALL=C file "$MAME/aspro" | grep -Eq 'ELF 32-bit.*ARM'
LC_ALL=C readelf -h "$MAME/aspro" | grep -Eq 'Machine:.*ARM'
"$MAME/aspro" -validate
# Avoid SIGPIPE with status 141 on long driver listings: validate from file.
"$MAME/aspro" -listfull > "$PRIVATE/logs/surf-aspro-drivers.txt" 2>&1
grep -Eq '^asmapro[[:space:]]' "$PRIVATE/logs/surf-aspro-drivers.txt"
if grep -Eq '^asma2k[[:space:]]' "$PRIVATE/logs/surf-aspro-drivers.txt"; then
 echo "BLOCKED_AS2K_DRIVER_IN_ASPRO_STABLE"; exit 5
fi
STEP=TEST_PRIVATE_FIRMWARE_BOOT
mkdir -p "$PREFIX/test/roms" "$PREFIX/test/empty" "$PREFIX/test/snap"
python3 - "$PRIVATE" "$PREFIX/test/roms" <<'PY'
import sys,zipfile
from pathlib import Path
src,dst=map(Path,sys.argv[1:])
for archive,member,filename in (
 ("asmapro.zip","alphasmartpro212.rom","roms/firmware.bin"),
 ("ks0066.zip","ks0066_f05.bin","roms/ks0066_f05.bin")):
 with zipfile.ZipFile(dst/archive,"w",zipfile.ZIP_STORED) as f:
  f.write(src/filename,arcname=member)
print("PRIVATE_ROM_ZIP_READY")
PY
# Short native ROM-boot smoke, never generic MAME or public ROM publication.
SDL_VIDEODRIVER=dummy timeout 50 "$MAME/aspro" asmapro \
 -rompath "$PREFIX/test/roms" -sound none -video none -nothrottle \
 -seconds_to_run 2 -skip_gameinfo -snapshot_directory "$PREFIX/test/snap"
STEP=INSTALL_PRO_STABLE_SEPARATELY
if test -e "$TARGET"; then
 cp -p "$TARGET" "$PRIVATE/binaries/stable-armv7/aspro-bin.before-$STAMP"
fi
sudo -n sh "$APP/install_stable.sh" "$MAME/aspro"
INSTALLED=1
cmp -s "$MAME/aspro" "$TARGET" ||
 { echo "FAIL_DIFFERENT_INSTALLED_ASPRO_BINARY"; exit 6; }
"$TARGET" -listfull > "$PRIVATE/logs/surf-aspro-installed-drivers.txt" 2>&1
grep -Eq '^asmapro[[:space:]]' "$PRIVATE/logs/surf-aspro-installed-drivers.txt"
test -x /usr/local/bin/aspro && test -f /usr/local/share/applications/aspro.desktop
cp -p "$TARGET" "$PRIVATE/binaries/stable-armv7/aspro-bin"
cp -p /usr/local/libexec/as2k/as2k-bin "$PRIVATE/binaries/stable-armv7/as2k-bin.unchanged"
sha256sum "$PRIVATE/binaries/stable-armv7/"* >"$PRIVATE/binaries/stable-armv7/binaries.sha256"
STEP=PASS
echo "ASPRO_SURF_NATIVE_COMPILE_INSTALL_PASS"
echo "MAME_TREE_RESTORED_ON_EXIT; AS2K_INSTALLED_UNCHANGED"
