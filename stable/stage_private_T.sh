#!/usr/bin/env bash
# ASPRO private staging and proven D0 CPU source distribution from T640.
# Code may be staged to AS2K_TEMP. Proprietary ROM is PRIVATE only.
set -Eeuo pipefail
umask 077
ROOT="$HOME/Projects/alphasmart"
DIAG="$ROOT/ASPRO-emu"
PRIV="$HOME/.local/share/alphasmart/private/aspro"
PUBLIC="googledrive:AS2K_TEMP/ASPRO_STABLE_BUILD_20261021"
PRIVATE="googledrive:ALPHASMART/Alphasmart Pro/ASPRO_STABLE_PRIVATE"
REPORT="googledrive:AS2K_TEMP/DEPLOY_20261021"
mkdir -p "$PRIV/roms" "$PRIV/payload" "$PRIV/binaries/diag-x86_64" "$PRIV/logs"
LOG="$PRIV/logs/t640-stage.log"
exec > >(tee -a "$LOG") 2>&1
STEP=START
finish(){
  local rc=$?
  trap - EXIT
  printf 'TASK=T640_ASPRO_PRIVATE_STAGE\nSTEP=%s\nEXIT=%s\n' "$STEP" "$rc" >"$PRIV/logs/t640-stage.status"
  rclone copyto "$PRIV/logs/t640-stage.status" "$REPORT/T640_ASPRO_PRIVATE_STAGE.status" --retries 1 --timeout 90s || :
  rclone copyto "$LOG" "$REPORT/T640_ASPRO_PRIVATE_STAGE.log" --retries 1 --timeout 90s || :
  exit "$rc"
}
trap finish EXIT
test "$(uname -m)" = x86_64
SRC="$DIAG/build/send-mame/src/devices/cpu/mc68hc11"
test -s "$SRC/mc68hc11.cpp" && test -s "$SRC/mc68hc11.h"
grep -q 'diag_bootstrap_tx_bit' "$SRC/mc68hc11.cpp" || {
  echo "BLOCKED CPU not proven SCI variant"; exit 4;
}
STEP=CPU_SOURCE
for f in mc68hc11.cpp mc68hc11.h; do
  sha256sum "$SRC/$f"
  rclone copyto "$SRC/$f" "$PUBLIC/$f" --retries 2 --timeout 90s
done
STEP=ROM_PAYLOAD
rclone copyto "googledrive:ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom" "$PRIV/roms/firmware.bin" --retries 2 --timeout 90s
rclone copyto "googledrive:ALPHASMART/private/roms/ks0066/ks0066_f05.bin" "$PRIV/roms/ks0066_f05.bin" --retries 2 --timeout 90s
PAYLOAD="$DIAG/private/ap07/payload0/payload0.bin"
test -s "$PAYLOAD" && test "$(stat -c %s "$PAYLOAD")" = 121 || {
  echo "BLOCKED canonical 121-byte AP07 payload absent"; exit 5;
}
cp -p "$PAYLOAD" "$PRIV/payload/payload0_pro.bin"
python3 - "$PRIV" <<'PY'
import hashlib,sys
from pathlib import Path
p=Path(sys.argv[1])
expected={
 "roms/firmware.bin":(32768,"c3c6a421c9ced92db97431d04b4a3f09a39de716"),
 "roms/ks0066_f05.bin":(4096,"0196e871584ee5d370856e7307c0f9d1466e3e51")
}
for name,(size,sha) in expected.items():
    b=(p/name).read_bytes()
    assert len(b)==size and hashlib.sha1(b).hexdigest()==sha,name
image=(p/"payload/payload0_pro.bin").read_bytes()
assert len(image)==121 and hashlib.sha256(image).hexdigest()=="25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53"
print("PASS private ROM and payload SHA")
PY
for p in roms/firmware.bin roms/ks0066_f05.bin payload/payload0_pro.bin; do
  rclone copyto "$PRIV/$p" "$PRIVATE/$p" --retries 2 --timeout 90s
done
STEP=DIAG_BACKUP
test -x "$DIAG/build/send-mame/asprodiag"
cp -p "$DIAG/build/send-mame/asprodiag" "$PRIV/binaries/diag-x86_64/asprodiag"
sha256sum "$PRIV/binaries/diag-x86_64/asprodiag" >"$PRIV/binaries/diag-x86_64/asprodiag.sha256"
rclone copyto "$PRIV/binaries/diag-x86_64/asprodiag.sha256" "$PRIVATE/binaries/diag-x86_64/asprodiag.sha256" --retries 1
STEP=NETWORK_TO_SURF
# One local reachability check only; never ask Commander to poll either machine.
if getent ahostsv4 surf >/dev/null 2>&1; then
  if ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=accept-new user@surf true </dev/null 2>/dev/null; then
    echo "SURF_SSH_REACHABLE=YES"
  else echo "SURF_SSH_REACHABLE=NO"; fi
else echo "SURF_NAME_RESOLVED=NO"; fi
STEP=PASS
echo "T640_PRIVATE_STAGING_PASS; sources and proprietary assets in restricted Drive"
