#!/usr/bin/env bash
# T640 unattended ARMv7-musl build from existing AS2K cross toolchain.
set -Eeuo pipefail
umask 077
ROOT="$HOME/Projects/alphasmart"
D="$ROOT/as2k-surface-cross"
M="$D/work/mame-as3k"
T="$D/armv7-eabihf--musl--stable-2025.08-1"
S="$D/alpine-armv7-sysroot"
W="$D/aspro-stable"
WR="$W/wrap"
P="$HOME/.local/share/alphasmart/private/aspro"
REPORT="googledrive:AS2K_TEMP/DEPLOY_20261021"
REMOTE="googledrive:AS2K_TEMP/surface-rt/packages"
PRO="googledrive:ALPHASMART/Alphasmart Pro/ASPRO_STABLE_PRIVATE"
REF="35fdf9bc72f2501f30dad5c7fffd2182c5b04c0c"
NAME=aspro-stable_0.1.0_surface-rt_armv7-musl
mkdir -p "$W/stable" "$WR" "$P/logs" "$P/binaries/stable-armv7-musl"
exec > >(tee -a "$P/logs/t640-cross-surf.log") 2>&1
STEP=START
B="$W/backup"
finish(){
 local rc=$?
 trap - EXIT
 for f in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h; do
   if [ -f "$B/$f" ]; then cp -p "$B/$f" "$M/$f"; fi
 done
 printf 'TASK=T640_ASPRO_SURF_CROSS\nSTEP=%s\nEXIT=%s\n' "$STEP" "$rc" > "$P/logs/t640-cross-surf.status"
 for name in t640-cross-surf.status t640-cross-surf.log; do
  rclone copyto "$P/logs/$name" "$REPORT/$name" --retries 1 --timeout 90s || :
 done
 exit "$rc"
}
trap finish EXIT
test "$(uname -m)" = x86_64
for f in "$T/bin/arm-linux-g++" "$T/bin/arm-linux-ar" "$S/usr/lib/libSDL2.so" "$M/makefile"; do
 test -f "$f" || { echo "BLOCKED missing existing tool $f"; exit 4; }
done
STEP=FETCH_STABLE
for f in alphasma.cpp aspro_ui.py aspro_session.py; do
 curl -fLsS --retry 2 "https://raw.githubusercontent.com/SamDelorean/ASPRO-emu/$REF/stable/$f" -o "$W/stable/$f"
done
python3 -m py_compile "$W/stable/aspro_ui.py" "$W/stable/aspro_session.py"
STEP=ISOLATE_SOURCES
mkdir -p "$B/src/mame/skeleton" "$B/src/devices/cpu/mc68hc11"
for f in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h; do
 test -f "$M/$f" && test ! -L "$M/$f"
 cp -p "$M/$f" "$B/$f"
done
cp "$W/stable/alphasma.cpp" "$M/src/mame/skeleton/alphasma.cpp"
for f in mc68hc11.cpp mc68hc11.h; do
 cp "$ROOT/ASPRO-emu/build/send-mame/src/devices/cpu/mc68hc11/$f" "$M/src/devices/cpu/mc68hc11/$f"
done
grep -q diag_bootstrap_tx_bit "$M/src/devices/cpu/mc68hc11/mc68hc11.cpp"
STEP=REUSE_CROSS
cat > "$WR/cc" <<EOF
#!/bin/sh
exec "$T/bin/arm-linux-gcc" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -I"$S/usr/include" -L"$S/usr/lib" -Wl,-rpath-link,"$S/usr/lib" "\$@"
EOF
cat > "$WR/cxx" <<EOF
#!/bin/sh
exec "$T/bin/arm-linux-g++" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -I"$S/usr/include" -L"$S/usr/lib" -Wl,-rpath-link,"$S/usr/lib" "\$@" -O0 -fno-inline-functions
EOF
chmod +x "$WR/cc" "$WR/cxx"
export PKG_CONFIG_SYSROOT_DIR="$S"
export PKG_CONFIG_LIBDIR="$S/usr/lib/pkgconfig:$S/usr/share/pkgconfig"
unset PKG_CONFIG_PATH || :
pkg-config --exists sdl2 SDL2_ttf fontconfig
export CROSS_BUILD=1 PTR64=0 PLATFORM=arm NOASM=1 FORCE_DRC_C_BACKEND=1
export OVERRIDE_CC="$WR/cc" OVERRIDE_CXX="$WR/cxx" OVERRIDE_LD="$WR/cxx" OVERRIDE_AR="$T/bin/arm-linux-ar"
export BUILDDIR=build/as2k-surface-armv7-cross
export NO_OPENGL=1 USE_QTDEBUG=0 NO_USE_XINPUT=1 NO_USE_PORTAUDIO=1 NO_USE_PULSEAUDIO=1 NO_USE_PIPEWIRE=1 NO_USE_MIDI=1 USE_TAPTUN=0 USE_PCAP=0
export TOOLS=0 TESTS=0 BENCHMARKS=0 SYMBOLS=0 STRIP_SYMBOLS=0 OPTIMIZE=2 SSE2=0
export NOWERROR=1
export MAKEFLAGS="ARCHITECTURE= "
STEP=BUILD_ASPRO_ARMV7
make -C "$M" -j3 TARGET=mame SUBTARGET=aspro SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1
BIN="$M/aspro"
test -s "$BIN"
STEP=ELF_VERIFY
file "$BIN" | grep -Eq 'ELF 32-bit.*ARM'
readelf -l "$BIN" | grep -q ld-musl-armhf.so.1
"$T/bin/arm-linux-strip" -s "$BIN"
STEP=PACKAGE
BASE="$W/pkg/$NAME"
LOCAL="$BASE/root/usr/local"
mkdir -p "$LOCAL/libexec/aspro/frontend" "$LOCAL/bin" "$LOCAL/share/applications"
cp "$BIN" "$LOCAL/libexec/aspro/aspro-bin"
cp "$W/stable/aspro_ui.py" "$LOCAL/libexec/aspro/frontend/aspro_ui.py"
cp "$W/stable/aspro_session.py" "$LOCAL/libexec/aspro/frontend/aspro_session.py"
printf '#!/bin/sh\nexec /usr/bin/env python3 /usr/local/libexec/aspro/frontend/aspro_session.py "$@"\n' > "$LOCAL/bin/aspro"
chmod +x "$LOCAL/bin/aspro" "$LOCAL/libexec/aspro/aspro-bin" "$LOCAL/libexec/aspro/frontend/"*.py
cat > "$LOCAL/share/applications/aspro.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=ASPRO Emulator
Exec=/usr/local/bin/aspro
Icon=input-keyboard
Terminal=false
Categories=Education;Utility;
EOF
cat > "$BASE/install.sh" <<'EOF'
#!/bin/sh
set -eu
case "$(uname -m)" in armv7*) ;; *) exit 2;; esac
sudo -n true
D=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
sudo -n install -d /usr/local/libexec/aspro/frontend /usr/local/bin /usr/local/share/applications
sudo -n install -m 0755 "$D/root/usr/local/libexec/aspro/aspro-bin" /usr/local/libexec/aspro/aspro-bin.next
sudo -n mv /usr/local/libexec/aspro/aspro-bin.next /usr/local/libexec/aspro/aspro-bin
sudo -n install -m 0755 "$D/root/usr/local/libexec/aspro/frontend/aspro_ui.py" /usr/local/libexec/aspro/frontend/aspro_ui.py
sudo -n install -m 0755 "$D/root/usr/local/libexec/aspro/frontend/aspro_session.py" /usr/local/libexec/aspro/frontend/aspro_session.py
sudo -n install -m 0755 "$D/root/usr/local/bin/aspro" /usr/local/bin/aspro
sudo -n install -m 0644 "$D/root/usr/local/share/applications/aspro.desktop" /usr/local/share/applications/aspro.desktop
cmp "$D/root/usr/local/libexec/aspro/aspro-bin" /usr/local/libexec/aspro/aspro-bin
echo ASPRO_SURF_INSTALL_PASS
EOF
chmod +x "$BASE/install.sh"
OUT="$W/$NAME.tar.gz"
tar -C "$W/pkg" -czf "$OUT" "$NAME"
(cd "$W" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
cp "$BIN" "$P/binaries/stable-armv7-musl/aspro-bin"
sha256sum "$BIN" > "$P/binaries/stable-armv7-musl/aspro-bin.sha256"
STEP=DRIVE_BACKUP
rclone copyto "$OUT" "$REMOTE/$NAME.tar.gz" --retries 2 --timeout 180s
rclone copyto "$OUT.sha256" "$REMOTE/$NAME.tar.gz.sha256" --retries 1
rclone copyto "$BIN" "$PRO/binaries/stable-armv7-musl/aspro-bin" --retries 2 --timeout 180s
rclone copyto "$P/binaries/stable-armv7-musl/aspro-bin.sha256" "$PRO/binaries/stable-armv7-musl/aspro-bin.sha256" --retries 1
STEP=SURF_SSH
if ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=8 user@surf.local true </dev/null; then
 scp -o BatchMode=yes -o StrictHostKeyChecking=yes "$OUT" "$OUT.sha256" user@surf.local:/home/user/
 ssh -o BatchMode=yes -o StrictHostKeyChecking=yes user@surf.local \
 'mkdir -p /home/user/.local/share/alphasmart/private/aspro/roms /home/user/.local/share/alphasmart/private/aspro/payload /home/user/.local/share/alphasmart/private/aspro/binaries/stable-armv7-musl'
 scp -o BatchMode=yes -o StrictHostKeyChecking=yes "$P/roms/firmware.bin" "$P/roms/ks0066_f05.bin" user@surf.local:/home/user/.local/share/alphasmart/private/aspro/roms/
 scp -o BatchMode=yes -o StrictHostKeyChecking=yes "$P/payload/payload0_pro.bin" user@surf.local:/home/user/.local/share/alphasmart/private/aspro/payload/
 ssh -o BatchMode=yes -o StrictHostKeyChecking=yes user@surf.local \
 "cd /home/user && sha256sum -c $NAME.tar.gz.sha256 && tar -xzf $NAME.tar.gz && cd $NAME && sh install.sh && cp -p /usr/local/libexec/aspro/aspro-bin /home/user/.local/share/alphasmart/private/aspro/binaries/stable-armv7-musl/aspro-bin"
 STEP=PASS
 echo SURF_ASPRO_STABLE_PASS
else
 STEP=BUILT_SURF_SSH_UNAVAILABLE
 echo "SURF_SSH_UNAVAILABLE; ARMv7 package and private executable backed up in Drive"
 exit 31
fi
