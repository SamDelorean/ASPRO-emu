#!/usr/bin/env bash
# T640 only. Build, package and publish ASPRO Stable (AP-10 sources) for
#   linux-x86_64   (native, GTK3 frontend) - always
#   windows-x86_64 (MinGW-w64 cross, MAME UI only) - only if MinGW-w64 posix is installed
# Other architectures are private user platforms and are NOT published.
# Unattended, no polling. Donor trees are restored by the EXIT trap.
# Never packages ROMs, payloads, NVRAM or logs with private data.
set -Eeuo pipefail
umask 022
VER=v0.1.1
SRC_REF=f196e57f6fc36f065f53579a1e358ea92e45c68e   # ASPRO-emu main, AP-10 stable sources
REPO=SamDelorean/ASPRO-emu
BASE="$HOME/Projects/alphasmart"
X86_TREE="$BASE/ASPRO-emu/build/send-mame"
PRIV="$HOME/.local/share/alphasmart/private/aspro"
WORK="$BASE/aspro-release-$VER"
DRIVE="googledrive:ASPRO_TEMP/dist/$VER"
LOG="$WORK/build_release_T.log"
STATUS="$WORK/build_release_T.status"
mkdir -p "$WORK/src" "$WORK/dist" "$WORK/backup"
exec > >(tee -a "$LOG") 2>&1
STEP=START
OVERLAID=""
FILES="src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h src/mame/mame.lst"

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
for f in "$X86_TREE/makefile" "$X86_TREE/COPYING"; do
  [ -e "$f" ] || { echo "BLOCKED missing $f"; exit 3; }
done
for c in make g++ pkg-config curl rclone python3 file readelf; do command -v "$c" >/dev/null || { echo "BLOCKED missing $c"; exit 3; }; done

STEP=FETCH_SOURCES
for f in alphasma.cpp aspro_ui.py aspro_session.py install_stable.sh proven_hc11/mc68hc11.cpp proven_hc11/mc68hc11.h; do
  mkdir -p "$WORK/src/$(dirname "$f")"
  curl -fLsS --retry 2 "https://raw.githubusercontent.com/$REPO/$SRC_REF/stable/$f" -o "$WORK/src/$f"
done
blob() { python3 -c 'import hashlib,sys;d=open(sys.argv[1],"rb").read();print(hashlib.sha1(b"blob %d\0"%len(d)+d).hexdigest())' "$1"; }
[ "$(blob "$WORK/src/alphasma.cpp")" = 75e2d5ff78f89b6bc49d429b53b72a51bd953637 ]
[ "$(blob "$WORK/src/aspro_ui.py")" = 64c411a616224d53754e92eef077eaa9a94bf9aa ]
[ "$(blob "$WORK/src/aspro_session.py")" = 873f6263708b58025526bb9d056773b7b3272d40 ]
[ "$(blob "$WORK/src/install_stable.sh")" = 3f7692fc1aef76c2b2dbab767606bc6a4eae5c7a ]
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
  # Same installer used for the Surf/Vontar AP-10 installs (reference layout).
  cp "$WORK/src/install_stable.sh" "$p/install_stable.sh"
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

# ---------------------------------------------------------------- Windows x86_64 (optional)
WIN_OK=0
STEP=WIN_TOOLCHAIN
if command -v x86_64-w64-mingw32-g++-posix >/dev/null && command -v x86_64-w64-mingw32-windres >/dev/null; then
  MW="$WORK/mingw64"; mkdir -p "$MW/bin"
  for t in gcc g++ gcc-ar; do ln -sf "$(command -v x86_64-w64-mingw32-$t-posix)" "$MW/bin/x86_64-w64-mingw32-$t"; done
  for t in windres strip ar; do ln -sf "$(command -v x86_64-w64-mingw32-$t)" "$MW/bin/x86_64-w64-mingw32-$t"; done
  overlay "$X86_TREE"
  STEP=WIN_BUILD
  if (cd "$X86_TREE" && unset MAKEFLAGS && CCACHE_DISABLE=1 make -j3 TARGET=mame SUBTARGET=aspro \
        SOURCES=src/mame/skeleton/alphasma.cpp TARGETOS=windows PTR64=1 MINGW64="$MW" \
        REGENIE=1 TOOLS=0 USE_QTDEBUG=0 BUILDDIR=build/aspro-stable-win64) \
     && [ -s "$X86_TREE/aspro.exe" ] && file -b "$X86_TREE/aspro.exe" | grep -q 'PE32+.*x86-64'; then
    "$MW/bin/x86_64-w64-mingw32-strip" -s "$X86_TREE/aspro.exe"
    cp "$X86_TREE/aspro.exe" "$WORK/aspro-windows-x86_64.exe"
    WIN_OK=1
  else
    echo "WINDOWS_BUILD_FAILED; Linux release continues"
  fi
  restore; OVERLAID=""
else
  echo "WINDOWS_SKIPPED_NO_MINGW (x86_64-w64-mingw32-g++-posix/windres not installed on T)"
fi
if [ "$WIN_OK" = 1 ]; then
  STEP=WIN_PACKAGE
  wn="aspro-stable-$VER-windows-x86_64"; wp="$WORK/pkg/$wn"; rm -rf "$wp"; mkdir -p "$wp"
  cp "$WORK/aspro-windows-x86_64.exe" "$wp/aspro.exe"
  cp "$X86_TREE/COPYING" "$wp/COPYING.txt"
  printf '%s\r\n' "ASPRO Stable $VER (Windows x86_64) - nucleo MAME del AlphaSmart Pro, sin interfaz GTK." "" \
    "Uso:  aspro.exe asmapro -rompath roms" \
    "ROM:  NO incluida. Coloque asmapro.zip (alphasmartpro212.rom) y ks0066.zip (ks0066_f05.bin) en la carpeta roms." \
    "Fuente: https://github.com/$REPO/tree/$SRC_REF/stable" "Licencia: MAME, GPL-2.0-or-later (COPYING.txt)." > "$wp/README.txt"
  (cd "$wp" && sha256sum aspro.exe COPYING.txt README.txt > SHA256SUMS.txt)
  python3 - "$WORK/pkg" "$wn" "$WORK/dist/$wn.zip" <<'PYZIP'
import sys,zipfile,pathlib
base,name,out=pathlib.Path(sys.argv[1]),sys.argv[2],sys.argv[3]
with zipfile.ZipFile(out,"w",zipfile.ZIP_DEFLATED) as z:
    for f in sorted((base/name).rglob("*")): z.write(f,f.relative_to(base))
PYZIP
  echo "PACKAGED $wn"
fi

# ---------------------------------------------------------------- publish
STEP=CHECKSUMS
(cd "$WORK/dist" && sha256sum *.tar.gz $(ls *.zip 2>/dev/null) > SHA256SUMS.txt && cat SHA256SUMS.txt)
STEP=DRIVE_UPLOAD
rclone copy "$WORK/dist" "$DRIVE" --retries 2 --timeout 300s
STEP=GITHUB_RELEASE
cat > "$WORK/notes.md" <<EOF
ASPRO Stable $VER: emulador AlphaSmart Pro (MAME 0.289, driver \`asmapro\`) con interfaz GTK3.

Fuentes AP-10: \`stable/\` en $SRC_REF (driver con matriz Pro de 78 teclas, LCD GTK optimizado).
Paquetes compilados en T640:
- \`linux-x86_64\`: nativo con interfaz GTK3; \`-validate\` y listado \`asmapro\` PASS.
- \`windows-x86_64\` (si se adjunta): núcleo MAME con MinGW-w64, interfaz propia de MAME, sin GTK; no probado en Windows.

Instalación: \`tar xzf <paquete>.tar.gz && cd <paquete> && sudo ./install_stable.sh bin/aspro-bin\`.
No incluye ROMs. Pendiente: prueba interactiva GTK posinstalación (teclado, PC, bootstrap).
Licencia MAME GPL-2.0-or-later (COPYING en cada paquete).
EOF
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh release create "$VER" "$WORK"/dist/*.tar.gz $(ls "$WORK"/dist/*.zip 2>/dev/null) "$WORK/dist/SHA256SUMS.txt" \
    --repo "$REPO" --target main --title "ASPRO Stable $VER" --notes-file "$WORK/notes.md"
  echo "GITHUB_RELEASE_PASS https://github.com/$REPO/releases/tag/$VER"
else
  echo "GITHUB_RELEASE_SKIPPED gh unavailable or not authenticated; packages are in $DRIVE"
  rclone copyto "$WORK/notes.md" "$DRIVE/RELEASE_NOTES.md" --retries 2 || :
  STEP=PASS_NO_GH
  exit 0
fi
STEP=PASS
