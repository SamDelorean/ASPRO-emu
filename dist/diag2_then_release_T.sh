#!/usr/bin/env bash
# T640: record system-library evidence (read-only), then run the release script.
set -u
VER=v0.1.1
WORK="$HOME/Projects/alphasmart/aspro-release-$VER"
OUT="$WORK/diag"; mkdir -p "$OUT"; R="$OUT/diag2_syslibs.txt"
{
  date -Is
  dpkg-query -W -f='${Package} ${Version} ${Status}\n' libc6 libudev1 libsystemd0 systemd coreutils rust-coreutils libsdl2-2.0-0 2>&1
  for l in /usr/lib/x86_64-linux-gnu/libudev.so.1 /usr/lib/x86_64-linux-gnu/libsystemd.so.0 "$(command -v tail)"; do
    echo "== $l"; ls -lL "$l" 2>&1; sha256sum "$(readlink -f "$l")" 2>&1
    p=$(dpkg -S "$(readlink -f "$l")" 2>/dev/null | cut -d: -f1 | head -n1); echo "pkg=${p:-unknown}"
    [ -n "$p" ] && dpkg --verify "$p" 2>&1
    readelf -d "$(readlink -f "$l")" 2>&1 | grep -Ei 'relr|relacount|flags' 
  done
  echo "== udev load test"; python3 -c 'import ctypes;ctypes.CDLL("libudev.so.1");print("libudev load OK")' 2>&1; echo "rc=$?"
} > "$R" 2>&1
rclone copy "$OUT" "googledrive:ASPRO_TEMP/dist/$VER/diag" --retries 2 --timeout 120s
exec bash "$WORK/build_release_T.v4.sh"
