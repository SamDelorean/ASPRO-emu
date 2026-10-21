#!/usr/bin/env bash
# Only T640. Reuse ARMv7 toolchain, sysroot and MAME objects; correct local
# "png.h" precedence. Distribute ONLY publicly redistributable core/UI.
set -Eeuo pipefail
umask 077
BASE="$HOME/Projects/alphasmart"
CROSS="$BASE/as2k-surface-cross"
MAME="$CROSS/work/mame-as3k"
SDK="$CROSS/armv7-eabihf--musl--stable-2025.08-1"
SYS="$CROSS/alpine-armv7-sysroot"
WORK="$CROSS/aspro-stable"
DIAG="$BASE/ASPRO-emu"
STABLE="$WORK/stable"
WRAP="$WORK/wrappers-v2"
DIST="$WORK/dist"
NAME=aspro-stable_0.1.0_surface-rt_armv7-musl
REPORT=googledrive:AS2K_TEMP/DEPLOY_20261021
mkdir -p "$STABLE" "$WRAP" "$DIST"
LOG="$WORK/surf-recovery.log"
exec > >(tee -a "$LOG") 2>&1
STEP=PREFLIGHT
BACK="$WORK/previous-sources"
restore(){
 for f in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h; do
  if test -f "$BACK/$f"; then cp -p "$BACK/$f" "$MAME/$f"; fi
 done
}
finish(){
 rc=$?
 trap - EXIT
 restore || :
 printf 'TASK=ASPRO_SURF_CROSS_RECOVERY\nSTEP=%s\nEXIT=%s\n' "$STEP" "$rc" >"$WORK/surf-recovery.status"
 for f in "$WORK/surf-recovery.status" "$LOG"; do
  rclone copyto "$f" "$REPORT/$(basename "$f")" --retries 1 --timeout 90s || :
 done
 exit "$rc"
}
trap finish EXIT
test "$(uname -m)" = x86_64
for f in "$MAME/makefile" "$SDK/bin/arm-linux-g++" "$MAME/src/lib/util/png.h" "$SYS/usr/include/png.h" "$DIAG/build/send-mame/src/devices/cpu/mc68hc11/mc68hc11.cpp"; do
 test -e "$f" || { echo "MISSING_EXISTING_TOOLCHAIN_RESOURCE $f"; exit 3; }
done
STEP=FETCH_ONLY_RELEASE_FILES
REF=5c4a4ef29d721090f4c4316ef932198e897e6270
for f in alphasma.cpp aspro_ui.py aspro_session.py; do
 curl -fLsS --retry 2 "https://raw.githubusercontent.com/SamDelorean/ASPRO-emu/$REF/stable/$f" -o "$STABLE/$f"
done
python3 -m py_compile "$STABLE/aspro_ui.py" "$STABLE/aspro_session.py"
STEP=OVERLAY_ONLY_THREE_SOURCES
for f in src/mame/skeleton/alphasma.cpp src/devices/cpu/mc68hc11/mc68hc11.cpp src/devices/cpu/mc68hc11/mc68hc11.h; do
 mkdir -p "$BACK/$(dirname "$f")"
 test -f "$MAME/$f" && test ! -L "$MAME/$f" || exit 4
 cp -p "$MAME/$f" "$BACK/$f"
done
cp "$STABLE/alphasma.cpp" "$MAME/src/mame/skeleton/alphasma.cpp"
for f in mc68hc11.cpp mc68hc11.h; do
 cp "$DIAG/build/send-mame/src/devices/cpu/mc68hc11/$f" "$MAME/src/devices/cpu/mc68hc11/$f"
done
grep -q diag_bootstrap_tx_bit "$MAME/src/devices/cpu/mc68hc11/mc68hc11.cpp"
# This source alone failed in the previous compile due to Alpine png.h shadowing.
touch "$MAME/src/emu/recording.cpp"
STEP=ARMV7_CROSS_HEADER_FIX
cat >"$WRAP/cc" <<EOF
#!/bin/sh
exec "$SDK/bin/arm-linux-gcc" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -iquote "$MAME/src/lib/util" -I"$SYS/usr/include" -L"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/lib" "\$@"
EOF
cat >"$WRAP/cxx" <<EOF
#!/bin/sh
exec "$SDK/bin/arm-linux-g++" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -iquote "$MAME/src/lib/util" -I"$SYS/usr/include" -L"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/usr/lib" -Wl,-rpath-link,"$SYS/lib" "\$@" -O0 -fno-inline-functions
EOF
chmod 0755 "$WRAP/cc" "$WRAP/cxx"
export PKG_CONFIG_SYSROOT_DIR="$SYS"
export PKG_CONFIG_LIBDIR="$SYS/usr/lib/pkgconfig:$SYS/usr/share/pkgconfig"
unset PKG_CONFIG_PATH || :
export CROSS_BUILD=1 PTR64=0 PLATFORM=arm NOASM=1 FORCE_DRC_C_BACKEND=1
export OVERRIDE_CC="$WRAP/cc" OVERRIDE_CXX="$WRAP/cxx" OVERRIDE_LD="$WRAP/cxx"
export OVERRIDE_AR="$SDK/bin/arm-linux-ar"
export BUILDDIR=build/as2k-surface-armv7-cross
export NO_OPENGL=1 USE_QTDEBUG=0 NO_USE_XINPUT=1 NO_USE_PORTAUDIO=1
export NO_USE_PULSEAUDIO=1 NO_USE_PIPEWIRE=1 NO_USE_MIDI=1 USE_TAPTUN=0 USE_PCAP=0
export TOOLS=0 TESTS=0 BENCHMARKS=0 SYMBOLS=0 STRIP_SYMBOLS=0
export OPTIMIZE=2 SSE2=0 NOWERROR=1
export MAKEFLAGS='ARCHITECTURE='
STEP=BUILD_INCREMENTAL_ARMV7
cd "$MAME"
make -j3 TARGET=mame SUBTARGET=aspro SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1
test -s "$MAME/aspro"
STEP=VERIFY_ELF
file "$MAME/aspro" | grep -Eq 'ELF 32-bit.*ARM'
readelf -l "$MAME/aspro" | grep -q 'ld-musl-armhf.so.1'
"$SDK/bin/arm-linux-strip" -s "$MAME/aspro"
sha256sum "$MAME/aspro"
STEP=PACKAGE_FOR_SURF
OUT="$WORK/package/$NAME"
mkdir -p "$OUT/root/usr/local/libexec/aspro/frontend" "$OUT/root/usr/local/bin" "$OUT/root/usr/local/share/applications"
cp "$MAME/aspro" "$OUT/root/usr/local/libexec/aspro/aspro-bin"
cp "$STABLE/aspro_ui.py" "$STABLE/aspro_session.py" "$OUT/root/usr/local/libexec/aspro/frontend/"
cat > "$OUT/root/usr/local/bin/aspro" <<'EOS'
#!/bin/sh
exec /usr/bin/env python3 /usr/local/libexec/aspro/frontend/aspro_session.py "$@"
EOS
chmod 0755 "$OUT/root/usr/local/bin/aspro" "$OUT/root/usr/local/libexec/aspro/aspro-bin" "$OUT/root/usr/local/libexec/aspro/frontend/"*.py
cat > "$OUT/root/usr/local/share/applications/aspro.desktop" <<'EOS'
[Desktop Entry]
Type=Application
Name=ASPRO Emulator
Comment=AlphaSmart Pro — reduced GTK, bootstrap, PC connection
Exec=/usr/local/bin/aspro
Icon=input-keyboard
Terminal=false
Categories=Education;Utility;
EOS
cat > "$OUT/install.sh" <<'EOS'
#!/bin/sh
set -eu
test "$(uname -m)" = armv7l
sudo -n true
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
SOURCE="$HERE/root/usr/local"
test -x "$SOURCE/libexec/aspro/aspro-bin"
sudo -n install -d /usr/local/libexec/aspro/frontend /usr/local/bin /usr/local/share/applications
if test -f /usr/local/libexec/aspro/aspro-bin; then
 mkdir -p "$HOME/.local/share/alphasmart/private/aspro/binaries/stable-armv7-musl"
 cp -p /usr/local/libexec/aspro/aspro-bin "$HOME/.local/share/alphasmart/private/aspro/binaries/stable-armv7-musl/aspro-bin.previous"
fi
sudo -n install -m 0755 "$SOURCE/libexec/aspro/aspro-bin" /usr/local/libexec/aspro/aspro-bin.next
sudo -n mv -f /usr/local/libexec/aspro/aspro-bin.next /usr/local/libexec/aspro/aspro-bin
sudo -n install -m 0755 "$SOURCE/libexec/aspro/frontend/aspro_ui.py" /usr/local/libexec/aspro/frontend/aspro_ui.py
sudo -n install -m 0755 "$SOURCE/libexec/aspro/frontend/aspro_session.py" /usr/local/libexec/aspro/frontend/aspro_session.py
sudo -n install -m 0755 "$SOURCE/bin/aspro" /usr/local/bin/aspro
sudo -n install -m 0644 "$SOURCE/share/applications/aspro.desktop" /usr/local/share/applications/aspro.desktop
cmp "$SOURCE/libexec/aspro/aspro-bin" /usr/local/libexec/aspro/aspro-bin
echo "ASPRO_SURF_INSTALLED_PASS"
EOS
chmod 0755 "$OUT/install.sh"
tar -C "$WORK/package" -czf "$DIST/$NAME.tar.gz" "$NAME"
(cd "$DIST"; sha256sum "$NAME.tar.gz" >"$NAME.tar.gz.sha256")
STEP=BACKUP_TO_DRIVE
rclone copyto "$DIST/$NAME.tar.gz" "googledrive:AS2K_TEMP/surface-rt/packages/$NAME.tar.gz" --retries 2 --timeout 180s
rclone copyto "$DIST/$NAME.tar.gz.sha256" "googledrive:AS2K_TEMP/surface-rt/packages/$NAME.tar.gz.sha256" --retries 2
STEP=SERVE_NONPROPRIETARY_PACKAGE
# This directory contains NO ROM, no credentials, no personal data.
# Only Surf 192.168.100.15 is allowed; service expires in 90 minutes.
cat > "$WORK/package_server.py" <<'PY'
import http.server,os,socketserver,sys,time
os.chdir(sys.argv[1])
class Handler(http.server.SimpleHTTPRequestHandler):
 def do_GET(self):
  if self.client_address[0]!="192.168.100.15":self.send_error(403);return
  if not self.path.startswith("/aspro-stable_0.1.0_surface-rt_armv7-musl.tar.gz"):self.send_error(404);return
  super().do_GET()
 def log_message(self,*a):pass
class Server(socketserver.TCPServer):allow_reuse_address=True
with Server(("192.168.100.7",18743),Handler) as server:
 server.timeout=5
 until=time.monotonic()+5400
 while time.monotonic()<until:server.handle_request()
PY
nohup python3 "$WORK/package_server.py" "$DIST" </dev/null > "$WORK/package-server.log" 2>&1 &
echo "ASPRO_SURF_PUBLIC_PACKAGE_HTTP_PID=$!"
STEP=PASS_ARMV7_PACKAGE_AVAILABLE
echo "ASPRO_SURF_ARMV7_CROSS_PACKAGE_PASS; Surf installer may fetch it"
