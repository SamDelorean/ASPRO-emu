#!/usr/bin/env bash
# Autonomous ASPRO-STABLE aarch64 Vontar: reuse AS2K MAME build and UI model.
# No supervision/polling. AS2K's installed core and GTK resources not modified.
set -Eeuo pipefail
umask 077
TAG=ASPRO_VONTAR_STABLE_20261021
BASE="$HOME/Projects/alphasmart"
STAGE="$BASE/aspro-stable-pack"
MAME="$HOME/projects/mame-as2k-stable-arm64"
PRIV="$HOME/.local/share/alphasmart/private/aspro"
# Proprietary assets and tested CPU sources are seeded securely by Commander
# from the already-verified private Drive archive. No remote rclone needed.
REF="35fdf9bc72f2501f30dad5c7fffd2182c5b04c0c"
mkdir -p "$STAGE/stable" "$PRIV/logs" "$PRIV/roms" "$PRIV/payload" "$PRIV/binaries/stable-aarch64"
LOG="$PRIV/logs/vontar-stable.log"
exec > >(tee -a "$LOG") 2>&1
STEP=INIT
backups="$STAGE/backup-mame"
restore(){
    if [ -d "$backups" ]; then
        for f in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h; do
            [ ! -f "$backups/$f" ] || cp -p "$backups/$f" "$MAME/$f"
        done
    fi
}
finish(){
    local rc=$?
    trap - EXIT
    restore || :
    printf 'TASK=%s\nSTEP=%s\nEXIT=%s\n' "$TAG" "$STEP" "$rc" >"$PRIV/logs/vontar-stable.status"
    exit "$rc"
}
trap finish EXIT
[ "$(uname -m)" = aarch64 ] || { echo BAD_ARCH; exit 2; }
sudo -n true || { echo NO_SUDO; exit 2; }
test -f "$MAME/makefile" && test -f "$MAME/src/mame/skeleton/alphasma.cpp" || {
    echo "Missing previously built AS2K MAME tree"; exit 2;
}
# Called after AS2K resumed build is finished by the consolidated launcher.
STEP=FETCH_STABLE_SOURCE
for name in alphasma.cpp aspro_ui.py aspro_session.py install_stable.sh; do
    curl -fLsS --retry 2 --connect-timeout 20 \
      "https://raw.githubusercontent.com/SamDelorean/ASPRO-emu/$REF/stable/$name" \
      -o "$STAGE/stable/$name"
done
python3 -m py_compile "$STAGE/stable/aspro_ui.py" "$STAGE/stable/aspro_session.py"
STEP=PRIVATE_ASSETS
for f in "$PRIV/roms/firmware.bin" "$PRIV/roms/ks0066_f05.bin" "$PRIV/payload/payload0_pro.bin"; do
    test -s "$f" && test ! -L "$f" || { echo "BLOCKED private staging missing: $f"; exit 5; }
done
python3 - "$PRIV" <<'PY'
from pathlib import Path
import sys,hashlib
p=Path(sys.argv[1])
for name,size,sha in [
("roms/firmware.bin",32768,"c3c6a421c9ced92db97431d04b4a3f09a39de716"),
("roms/ks0066_f05.bin",4096,"0196e871584ee5d370856e7307c0f9d1466e3e51")]:
    b=(p/name).read_bytes()
    assert len(b)==size and hashlib.sha1(b).hexdigest()==sha,name
b=(p/"payload/payload0_pro.bin").read_bytes()
assert len(b)==121 and hashlib.sha256(b).hexdigest()=="25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53"
print("PRIVATE_ROM_AND_BOOTSTRAP_SHA_PASS")
PY
STEP=PINNED_PRO_CPU
# Use the CPU sources from the ACTUAL functional ASPRO-DIAG MAME checkout.
mkdir -p "$backups/src/mame/skeleton" "$backups/src/devices/cpu/mc68hc11"
for f in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h; do
    [ -f "$MAME/$f" ] && [ ! -L "$MAME/$f" ] || { echo "Unsafe CPU/driver file"; exit 4; }
    cp -p "$MAME/$f" "$backups/$f"
done
for name in mc68hc11.cpp mc68hc11.h; do
    test -s "$STAGE/stable/$name" && test ! -L "$STAGE/stable/$name" ||
        { echo "BLOCKED verified AP07 D0 CPU missing: $name"; exit 5; }
    cp "$STAGE/stable/$name" "$MAME/src/devices/cpu/mc68hc11/$name"
done
grep -q 'diag_bootstrap_tx_bit' "$MAME/src/devices/cpu/mc68hc11/mc68hc11.cpp" || {
    echo "Expected tested SCI RX/TXD CPU implementation absent"; exit 4;
}
cp "$STAGE/stable/alphasma.cpp" "$MAME/src/mame/skeleton/alphasma.cpp"
STEP=BUILD_REDUCED_PRO
cd "$MAME"
make -j2 SUBTARGET=aspro SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 USE_QTDEBUG=0
test -x "$MAME/aspro"
STEP=VALIDATE_CORE
"$MAME/aspro" -validate
"$MAME/aspro" -listfull | grep -q '^asmapro '
file "$MAME/aspro" | grep -qi aarch64
STEP=HEADLESS_PRO_ROM
mkdir -p "$STAGE/roms"
python3 - "$PRIV/roms" "$STAGE/roms" <<'PY'
import zipfile,sys
from pathlib import Path
src,dst=map(Path,sys.argv[1:])
for archive,name,path in [
 ("asmapro.zip","alphasmartpro212.rom","firmware.bin"),
 ("ks0066.zip","ks0066_f05.bin","ks0066_f05.bin")]:
    with zipfile.ZipFile(dst/archive,"w",zipfile.ZIP_STORED) as z:
        z.write(src/path,arcname=name)
PY
SDL_VIDEODRIVER=dummy timeout 45s "$MAME/aspro" asmapro -rompath "$STAGE/roms" \
    -sound none -video none -nothrottle -seconds_to_run 2 -skip_gameinfo
STEP=INSTALL
if [ -x /usr/local/libexec/aspro/aspro-bin ]; then
    cp -p /usr/local/libexec/aspro/aspro-bin "$PRIV/binaries/stable-aarch64/aspro-bin.previous"
fi
sudo -n sh "$STAGE/stable/install_stable.sh" "$MAME/aspro"
cmp "$MAME/aspro" /usr/local/libexec/aspro/aspro-bin
cp -p "$MAME/aspro" "$PRIV/binaries/stable-aarch64/aspro-bin"
sha256sum "$PRIV/binaries/stable-aarch64/aspro-bin" > "$PRIV/binaries/stable-aarch64/aspro-bin.sha256"
STEP=PASS
echo "ASPRO_STABLE_VONTAR_PASS: ROM, bootstrap, PC core, GTK launcher, exact binary identity; local private backups"
