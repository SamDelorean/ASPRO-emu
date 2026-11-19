#!/usr/bin/env bash
# T640 only. Build, package and publish ASPRO Stable (AP-10 sources) for
#   linux-x86_64  (native, isolated copy of the ASPRO MAME 0.289 tree)
#   linux-armv7-musl (existing T640 cross toolchain + Surf musl v2 bx fix)
# Unattended, no polling. Donor trees are restored by the EXIT trap.
# Never packages ROMs, payloads, NVRAM or logs with private data.
set -Eeuo pipefail
umask 022
VER=v0.1.1
SRC_REF=f196e57f6fc36f065f53579a1e358ea92e45c68e   # ASPRO-emu main, AP-10 stable sources
REPO=SamDelorean/ASPRO-emu
BASE="$HOME/Projects/alphasmart"
X86_TREE="$BASE/ASPRO-emu/build/send-mame"
CROSS="$BASE/as2k-surface-cross"
ARM_TREE="$CROSS/work/mame-as3k"
SDK="$CROSS/armv7-eabihf--musl--stable-2025.08-1"
SYS="$CROSS/alpine-armv7-sysroot"
PRIV="$HOME/.local/share/alphasmart/private/aspro"
WORK="$BASE/aspro-release-$VER"
DRIVE="googledrive:ASPRO_TEMP/dist/$VER"
LOG="$WORK/build_release_T.log"
STATUS="$WORK/build_release_T.status"
mkdir -p "$WORK/src" "$WORK/dist" "$WORK/backup"
exec > >(tee -a "$LOG") 2>&1
STEP=START
OVERLAID=""
FILES="src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h src/mame/mame.lst 3rdparty/bx/include/bx/platform.h 3rdparty/bx/src/file.cpp 3rdparty/bx/src/thread.cpp"

restore() {
  for t in $OVERLAID; do
    for f in $FILES; do
      b="$WORK/backup/$(basename "$t")/$f"
      [ -f "$b" ] && cp -p "$b" "$t/$f"
    done
  done
}
finish() {
  rc=$?
  trap - EXIT
  restore || :
  printf 'TASK=ASPRO_RELEASE_%s\nSTEP=%s\nEXIT=%s\n' "$VER" "$STEP" "$rc" > "$STATUS"
  rclone copyto "$STATUS" "$DRIVE/build_release_T.status" --retries 2 --timeout 90s || :
  rclone copyto "$LOG" "$DRIVE/build_release_T.log" --retries 2 --timeout 180s || :
  exit "$rc"
}
trap finish EXIT

STEP=PREFLIGHT
[ "$(uname -m)" = x86_64 ]
for f in "$X86_TREE/makefile" "$X86_TREE/COPYING" "$ARM_TREE/makefile" "$ARM_TREE/COPYING" \
         "$SDK/bin/arm-linux-g++" "$SDK/bin/arm-linux-strip" "$SYS/usr/lib/libSDL2.so"; do
  [ -e "$f" ] || { echo "BLOCKED missing $f"; exit 3; }
done
for c in make g++ pkg-config curl rclone python3 file readelf; do command -v "$c" >/dev/null || { echo "BLOCKED missing $c"; exit 3; }; done

STEP=FETCH_SOURCES
for f in alphasma.cpp aspro_ui.py aspro_session.py proven_hc11/mc68hc11.cpp proven_hc11/mc68hc11.h; do
  mkdir -p "$WORK/src/$(dirname "$f")"
  curl -fLsS --retry 2 "https://raw.githubusercontent.com/$REPO/$SRC_REF/stable/$f" -o "$WORK/src/$f"
done
blob() { python3 -c 'import hashlib,sys;d=open(sys.argv[1],"rb").read();print(hashlib.sha1(b"blob %d\0"%len(d)+d).hexdigest())' "$1"; }
[ "$(blob "$WORK/src/alphasma.cpp")" = 75e2d5ff78f89b6bc49d429b53b72a51bd953637 ]
[ "$(blob "$WORK/src/aspro_ui.py")" = 64c411a616224d53754e92eef077eaa9a94bf9aa ]
[ "$(blob "$WORK/src/aspro_session.py")" = 873f6263708b58025526bb9d056773b7b3272d40 ]
[ "$(blob "$WORK/src/proven_hc11/mc68hc11.cpp")" = f25752fc03165c9938a456ae9c0d6d9e9b5841f0 ]
[ "$(blob "$WORK/src/proven_hc11/mc68hc11.h")" = fb08eb8386b9c06712c34d883f91199160132d4b ]
python3 -m py_compile "$WORK/src/aspro_ui.py" "$WORK/src/aspro_session.py"
echo "SOURCES_MATCH_AP10_MANIFEST"

overlay() {  # $1 = MAME tree
  t=$1; b="$WORK/backup/$(basename "$t")"
  for f in $FILES; do mkdir -p "$b/$(dirname "$f")"; [ -f "$b/$f" ] || cp -p "$t/$f" "$b/$f"; done
  OVERLAID="$OVERLAID $t"
  cp "$WORK/src/alphasma.cpp" "$t/src/mame/skeleton/alphasma.cpp"
  cp "$WORK/src/proven_hc11/mc68hc11.cpp" "$WORK/src/proven_hc11/mc68hc11.h" "$t/src/devices/cpu/mc68hc11/"
  # Stable product exposes only asmapro (same rule as Surf/Vontar builds).
  awk '/^@source:/ {in_pro=($0=="@source:skeleton/alphasma.cpp")} in_pro && $0=="asma2k" {next} {print}' \
    "$b/src/mame/mame.lst" > "$t/src/mame/mame.lst"
}

check_drivers() {  # $1 = binary runnable on this host
  "$1" -listfull > "$WORK/drivers.txt" 2>&1
  grep -Eq '^asmapro[[:space:]]' "$WORK/drivers.txt"
  if grep -Eq '^asma2k[[:space:]]' "$WORK/drivers.txt"; then echo BLOCKED_AS2K_DRIVER_PRESENT; exit 5; fi
}

package() {  # $1 = binary, $2 = platform, $3 = MAME tree
  name="aspro-stable-$VER-$2"; p="$WORK/pkg/$name"
  rm -rf "$p"; mkdir -p "$p/bin"
  cp "$1" "$p/bin/aspro-bin"; chmod 0755 "$p/bin/aspro-bin"
  cp "$WORK/src/aspro_ui.py" "$WORK/src/aspro_session.py" "$p/"
  cp "$3/COPYING" "$p/COPYING"
  cat > "$p/install_stable.sh" <<'EOF'
#!/usr/bin/env sh
# Usage: sudo ./install_stable.sh bin/aspro-bin
set -eu
[ "$#" -eq 1 ] || { echo "Usage: install_stable.sh BUILT_ASPRO_BINARY"; exit 2; }
CORE=$1
[ -s "$CORE" ] && [ -x "$CORE" ] || { echo "Unverified ASPRO binary"; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "Root required"; exit 2; }
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
install -d -m 0755 /usr/local/libexec/aspro /usr/local/libexec/aspro/frontend /usr/local/bin /usr/local/share/applications
install -m 0755 "$CORE" /usr/local/libexec/aspro/aspro-bin
install -m 0755 "$DIR/aspro_ui.py" /usr/local/libexec/aspro/frontend/aspro_ui.py
install -m 0755 "$DIR/aspro_session.py" /usr/local/libexec/aspro/frontend/aspro_session.py
printf '#!/bin/sh\nexec /usr/bin/env python3 /usr/local/libexec/aspro/frontend/aspro_session.py "$@"\n' > /usr/local/bin/aspro
chmod 0755 /usr/local/bin/aspro
cat > /usr/local/share/applications/aspro.desktop <<'EOD'
[Desktop Entry]
Type=Application
Name=ASPRO Emulator
Comment=AlphaSmart Pro emulator
Exec=/usr/local/bin/aspro
Icon=input-keyboard
Terminal=false
Categories=Education;Utility;
EOD
echo "ASPRO_STABLE_INSTALLED: /usr/local/bin/aspro"
EOF
  chmod 0755 "$p/install_stable.sh"
  cat > "$p/README.txt" <<EOF
ASPRO Stable $VER ($2) - emulador AlphaSmart Pro con interfaz GTK3.

Instalar:   sudo ./install_stable.sh bin/aspro-bin
Ejecutar:   aspro   (o "ASPRO Emulator" en el menu)
Requisitos: python3, PyGObject (GTK3), SDL2, SDL2_ttf, fontconfig.
ROM:        NO incluida. Use su propio volcado de AlphaSmart Pro 2.1.2
            (SHA-1 c3c6a421c9ced92db97431d04b4a3f09a39de716) y KS0066 F05;
            selecciónelos en Archivo > Abrir ROM Pro.
Fuente:     https://github.com/$REPO/tree/$SRC_REF/stable
Licencia:   MAME, GPL-2.0-or-later (ver COPYING).
EOF
  {
    echo "ASPRO Stable $VER ($2)"
    echo "Source: https://github.com/$REPO (stable/ at $SRC_REF)"
    echo "Built on: $(hostname) $(uname -srm)"
    echo "Core SHA-256: $(sha256sum "$p/bin/aspro-bin" | cut -d' ' -f1)"
    echo "ELF: $(file -b "$p/bin/aspro-bin")"
    echo "Needed libraries:"; readelf -d "$p/bin/aspro-bin" | awk '/NEEDED/ {print "  " $NF}'
  } > "$p/BUILD_INFO.txt"
  (cd "$p" && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS)
  tar -C "$WORK/pkg" -czf "$WORK/dist/$name.tar.gz" "$name"
  echo "PACKAGED $name"
}

# ---------------------------------------------------------------- x86_64
STEP=X86_OVERLAY
overlay "$X86_TREE"
STEP=X86_BUILD
(
  cd "$X86_TREE"
  unset MAKEFLAGS
  CCACHE_DISABLE=1 make -j3 TARGET=mame SUBTARGET=aspro SOURCES=src/mame/skeleton/alphasma.cpp \
    REGENIE=1 TOOLS=0 USE_QTDEBUG=0 BUILDDIR=build/aspro-stable-x86_64
)
[ -x "$X86_TREE/aspro" ]
STEP=X86_VERIFY
file -b "$X86_TREE/aspro" | grep -Eq 'ELF 64-bit.*x86-64'
"$X86_TREE/aspro" -validate
check_drivers "$X86_TREE/aspro"
strip -s "$X86_TREE/aspro"
cp "$X86_TREE/aspro" "$WORK/aspro-linux-x86_64"
if [ -s "$PRIV/roms/firmware.bin" ] && [ -s "$PRIV/roms/ks0066_f05.bin" ]; then
  STEP=X86_ROM_SMOKE
  mkdir -p "$WORK/smoke/roms" "$WORK/smoke/snap"
  python3 - "$PRIV" "$WORK/smoke/roms" <<'PY'
import sys,zipfile
from pathlib import Path
src,dst=map(Path,sys.argv[1:])
for a,m,f in (("asmapro.zip","alphasmartpro212.rom","roms/firmware.bin"),("ks0066.zip","ks0066_f05.bin","roms/ks0066_f05.bin")):
    with zipfile.ZipFile(dst/a,"w",zipfile.ZIP_STORED) as z: z.write(src/f,arcname=m)
PY
  SDL_VIDEODRIVER=dummy timeout 60 "$WORK/aspro-linux-x86_64" asmapro -rompath "$WORK/smoke/roms" \
    -sound none -video none -nothrottle -seconds_to_run 2 -skip_gameinfo -snapshot_directory "$WORK/smoke/snap"
  echo "X86_ROM_SMOKE_PASS"
fi
restore; OVERLAID=""
STEP=X86_PACKAGE
package "$WORK/aspro-linux-x86_64" linux-x86_64 "$X86_TREE"

# ---------------------------------------------------------------- ARMv7 musl
STEP=ARM_OVERLAY
overlay "$ARM_TREE"
STEP=ARM_BX_MUSL_V2
# Same reversible bx musl adaptation as stable/deploy_surf_native_autonomous.sh (Surf AP-10 PASS).
python3 -B - "$ARM_TREE/3rdparty/bx/include/bx/platform.h" "$ARM_TREE/3rdparty/bx/src/file.cpp" "$ARM_TREE/3rdparty/bx/src/thread.cpp" <<'PY_BX_MUSL'
from pathlib import Path
import sys
h,f,th=map(Path,sys.argv[1:])
s=h.read_text()
for before,after in [
 ('#define BX_CRT_NEWLIB 0','#define BX_CRT_NEWLIB 0\n#define BX_CRT_MUSL   0'),
 ('#\telif BX_PLATFORM_BSD\n#\t\tundef  BX_CRT_BSD\n#\t\tdefine BX_CRT_BSD 1',
  '#\telif BX_PLATFORM_BSD\n#\t\tundef  BX_CRT_BSD\n#\t\tdefine BX_CRT_BSD 1'
  '\n#\telif BX_PLATFORM_LINUX && !defined(__GLIBC__)\n#\t\tundef  BX_CRT_MUSL\n#\t\tdefine BX_CRT_MUSL 1'),
 ('\t&& !BX_CRT_NEWLIB','\t&& !BX_CRT_NEWLIB '+chr(92)+'\n\t&& !BX_CRT_MUSL'),
 ('#elif BX_CRT_NEWLIB','#elif BX_CRT_MUSL\n#\tdefine BX_CRT_NAME "musl libc"\n#elif BX_CRT_NEWLIB')]:
    if s.count(before)!=1: raise SystemExit("BLOCKED bx platform.h layout: "+before[:40])
    s=s.replace(before,after,1)
t=f.read_text(); before='#\telif 0                   '+chr(92)
if t.count(before)!=1: raise SystemExit("BLOCKED bx file.cpp layout")
t=t.replace(before,'#\telif BX_CRT_MUSL\n#\t\tdefine fseeko64 fseeko\n#\t\tdefine ftello64 ftello\n'+before,1)
q=th.read_text(); tb='#\tinclude <pthread.h>\n#\tif BX_PLATFORM_BSD'
if q.count(tb)!=1: raise SystemExit("BLOCKED bx thread.cpp layout")
q=q.replace(tb,'#\tinclude <pthread.h>\n#\tif BX_CRT_MUSL && BX_PLATFORM_LINUX\n#\t\tinclude <sys/prctl.h>\n#\tendif\n#\tif BX_PLATFORM_BSD',1)
h.write_text(s); f.write_text(t); th.write_text(q)
print("BX_MUSL_V2_APPLIED")
PY_BX_MUSL
WRAP="$WORK/wrap-armv7"; mkdir -p "$WRAP"
cat > "$WRAP/cc" <<EOF
#!/bin/sh
exec "$SDK/bin/arm-linux-gcc" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -iquote "$ARM_TREE/src/lib/util" -I"$SYS/usr/include" -L"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/lib" "\$@"
EOF
cat > "$WRAP/cxx" <<EOF
#!/bin/sh
exec "$SDK/bin/arm-linux-g++" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -iquote "$ARM_TREE/src/lib/util" -I"$SYS/usr/include" -L"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/lib" "\$@" -O0 -fno-inline-functions
EOF
chmod 0755 "$WRAP/cc" "$WRAP/cxx"
printf '#include <bx/platform.h>\n#if BX_CRT_NONE || !BX_CRT_MUSL\n#error BX musl CRT misdetected\n#endif\n' |
  "$WRAP/cxx" -E -x c++ -I"$ARM_TREE/3rdparty/bx/include" - >/dev/null
echo "BX_MUSL_CROSS_PREFLIGHT_PASS"
STEP=ARM_BUILD
(
  cd "$ARM_TREE"
  export PKG_CONFIG_SYSROOT_DIR="$SYS" PKG_CONFIG_LIBDIR="$SYS/usr/lib/pkgconfig:$SYS/usr/share/pkgconfig"
  unset PKG_CONFIG_PATH || :
  export CROSS_BUILD=1 PTR64=0 PLATFORM=arm NOASM=1 FORCE_DRC_C_BACKEND=1
  export OVERRIDE_CC="$WRAP/cc" OVERRIDE_CXX="$WRAP/cxx" OVERRIDE_LD="$WRAP/cxx" OVERRIDE_AR="$SDK/bin/arm-linux-ar"
  export NO_OPENGL=1 USE_QTDEBUG=0 NO_USE_XINPUT=1 NO_USE_PORTAUDIO=1 NO_USE_PULSEAUDIO=1 NO_USE_PIPEWIRE=1 NO_USE_MIDI=1 USE_TAPTUN=0 USE_PCAP=0
  export TOOLS=0 TESTS=0 BENCHMARKS=0 SYMBOLS=0 STRIP_SYMBOLS=0 OPTIMIZE=2 SSE2=0 NOWERROR=1
  export MAKEFLAGS='ARCHITECTURE='
  make -j3 TARGET=mame SUBTARGET=aspro SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 BUILDDIR=build/aspro-stable-armv7-musl
)
[ -s "$ARM_TREE/aspro" ]
STEP=ARM_VERIFY
file -b "$ARM_TREE/aspro" | grep -Eq 'ELF 32-bit.*ARM'
readelf -l "$ARM_TREE/aspro" | grep -q 'ld-musl-armhf.so.1'
"$SDK/bin/arm-linux-strip" -s "$ARM_TREE/aspro"
cp "$ARM_TREE/aspro" "$WORK/aspro-linux-armv7-musl"
restore; OVERLAID=""
STEP=ARM_PACKAGE
package "$WORK/aspro-linux-armv7-musl" linux-armv7-musl "$ARM_TREE"

# ---------------------------------------------------------------- publish
STEP=CHECKSUMS
(cd "$WORK/dist" && sha256sum *.tar.gz > SHA256SUMS.txt && cat SHA256SUMS.txt)
STEP=DRIVE_UPLOAD
rclone copy "$WORK/dist" "$DRIVE" --retries 2 --timeout 300s
STEP=GITHUB_RELEASE
cat > "$WORK/notes.md" <<EOF
ASPRO Stable $VER: emulador AlphaSmart Pro (MAME 0.289, driver \`asmapro\`) con interfaz GTK3.

Fuentes AP-10: \`stable/\` en $SRC_REF (driver con matriz Pro de 78 teclas, LCD GTK optimizado).
Paquetes compilados en T640:
- \`linux-x86_64\`: nativo; \`-validate\` y listado \`asmapro\` PASS.
- \`linux-armv7-musl\`: compilación cruzada (postmarketOS/Alpine ARMv7). No probado en Surf todavía:
  el binario instalado en Surf es la compilación nativa AP-10 (SHA-256 28e13681…).

Instalación: \`tar xzf <paquete>.tar.gz && cd <paquete> && sudo ./install_stable.sh bin/aspro-bin\`.
No incluye ROMs. Pendiente: prueba interactiva GTK posinstalación (teclado, PC, bootstrap).
Licencia MAME GPL-2.0-or-later (COPYING en cada paquete).
EOF
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh release create "$VER" "$WORK"/dist/*.tar.gz "$WORK/dist/SHA256SUMS.txt" \
    --repo "$REPO" --target main --title "ASPRO Stable $VER" --notes-file "$WORK/notes.md"
  echo "GITHUB_RELEASE_PASS https://github.com/$REPO/releases/tag/$VER"
else
  echo "GITHUB_RELEASE_SKIPPED gh unavailable or not authenticated; packages are in $DRIVE"
  rclone copyto "$WORK/notes.md" "$DRIVE/RELEASE_NOTES.md" --retries 2 || :
  STEP=PASS_NO_GH
  exit 0
fi
STEP=PASS
