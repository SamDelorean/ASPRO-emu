#!/usr/bin/env bash
# Vontar Armbian aarch64: reproduce the proven AS2K Stable single-machine
# build/validation/install sequence, replacing ONLY the model-specific driver
# and CPU with previously tested ASPRO-DIAG derivatives.
# Reuse the existing native MAME tree/objects; DO NOT touch installed AS2K.
set -Eeuo pipefail
umask 077
ROOT="$HOME/projects/mame-as2k-stable-arm64"
STAGE="$HOME/Projects/alphasmart/aspro-stable-pack"
FRONTEND="$STAGE/stable"
PRIVATE="$HOME/.local/share/alphasmart/private/aspro"
LOGDIR="$PRIVATE/logs"
DEST=/usr/local/libexec/aspro/aspro-bin
AS2K=/usr/local/libexec/as2k/as2k-bin
mkdir -p "$LOGDIR" "$PRIVATE/binaries/stable-aarch64"
exec > >(tee -a "$LOGDIR/vontar-as2k-method-reuse.log") 2>&1
STATUS="$LOGDIR/vontar-as2k-method-reuse.status"
STEP=INIT
BACK=""
DID_OVERLAY=0
AS2K_SHA_BEFORE=""
finish() {
  rc=$?
  trap - EXIT
  if [ "$DID_OVERLAY" = 1 ] && [ -n "$BACK" ]; then
    for f in src/mame/skeleton/alphasma.cpp \
             src/devices/cpu/mc68hc11/mc68hc11.cpp \
             src/devices/cpu/mc68hc11/mc68hc11.h \
             src/mame/mame.lst; do
      if [ -f "$BACK/$f" ]; then
        cp -p "$BACK/$f" "$ROOT/$f" || rc=15
      fi
    done
  fi
  if [ -n "$AS2K_SHA_BEFORE" ] && [ -s "$AS2K" ]; then
    after=$(sha256sum "$AS2K" | cut -d' ' -f1)
    if [ "$after" != "$AS2K_SHA_BEFORE" ]; then
      echo "CRITICAL_AS2K_INSTALLED_CORE_HASH_CHANGED" >&2
      rc=16
    fi
  fi
  printf 'TASK=ASPRO_VONTAR_AS2K_METHOD_REUSE\nSTEP=%s\nEXIT=%s\n' "$STEP" "$rc" > "$STATUS"
  if [ "$rc" = 0 ]; then
    printf 'ASPRO_CORE_SHA256=%s\n' "$(sha256sum "$DEST" | cut -d' ' -f1)" >> "$STATUS"
    echo "ASPRO_VONTAR_STABLE_NATIVE_INSTALL_PASS"
  else
    echo "ASPRO_VONTAR_STABLE_NATIVE_INSTALL_FAILED step=$STEP rc=$rc" >&2
  fi
  exit "$rc"
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
STEP=CANONICAL_PREFLIGHT
test "$(uname -m)" = aarch64
sudo -n true
test -f "$ROOT/makefile" && test -f "$ROOT/src/mame/mame.lst"
test -x "$AS2K" && test -s "$ROOT/aspro"
test ! -L "$ROOT" && test ! -L "$ROOT/src/mame/mame.lst"
AS2K_SHA_BEFORE=$(sha256sum "$AS2K" | cut -d' ' -f1)
for f in "$FRONTEND/alphasma.cpp" "$FRONTEND/mc68hc11.cpp" \
         "$FRONTEND/mc68hc11.h" "$FRONTEND/aspro_ui.py" \
         "$FRONTEND/aspro_session.py" "$PRIVATE/roms/firmware.bin" \
         "$PRIVATE/roms/ks0066_f05.bin" "$PRIVATE/payload/payload0_pro.bin"; do
  test -s "$f" && test ! -L "$f" || { echo "MISSING_PINNED_INPUT: $f"; exit 3; }
done
python3 - "$PRIVATE" "$FRONTEND" <<'PY'
import hashlib,sys
from pathlib import Path
private,frontend=map(Path,sys.argv[1:])
for name,size,digest in [
 ("roms/firmware.bin",32768,"c3c6a421c9ced92db97431d04b4a3f09a39de716"),
 ("roms/ks0066_f05.bin",4096,"0196e871584ee5d370856e7307c0f9d1466e3e51")]:
 raw=(private/name).read_bytes()
 assert len(raw)==size and hashlib.sha1(raw).hexdigest()==digest,name
payload=(private/"payload/payload0_pro.bin").read_bytes()
assert len(payload)==121 and hashlib.sha256(payload).hexdigest()=="25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53"
for name in ("aspro_session.py","aspro_ui.py"):
 compile((frontend/name).read_bytes(),str(frontend/name),"exec")
assert "W,H=240,36" in (frontend/"aspro_ui.py").read_text()
assert "PC conectado" in (frontend/"aspro_ui.py").read_text()
assert "ASPRO_BOOTSTRAP_FILE" in (frontend/"alphasma.cpp").read_text()
assert "diag_bootstrap_tx_bit" in (frontend/"mc68hc11.cpp").read_text()
print("ASPRO_PRIVATE_SHA_AND_UI_CONTRACT_STATIC_PASS")
PY
command -v flock >/dev/null
exec 9>"$STAGE/vontar-as2k-method-reuse.lock"
flock -n 9 || { echo "CONCURRENT_ASPRO_BUILD_LOCK"; exit 4; }
if pgrep -x cc1plus >/dev/null || pgrep -x make >/dev/null; then
  echo "OTHER_MAME_COMPILER_ACTIVE; avoid overlap"; exit 4
fi
STEP=SNAPSHOT_PROVEN_SOURCES
BACK=$(mktemp -d "$STAGE/vontar-pro-restore.XXXXXXXX")
for f in src/mame/skeleton/alphasma.cpp \
         src/devices/cpu/mc68hc11/mc68hc11.cpp \
         src/devices/cpu/mc68hc11/mc68hc11.h src/mame/mame.lst; do
  test -f "$ROOT/$f" && test ! -L "$ROOT/$f" || { echo "UNSAFE_DONOR_SOURCE: $f"; exit 4; }
  mkdir -p "$BACK/$(dirname "$f")"
  cp -p "$ROOT/$f" "$BACK/$f"
done
DID_OVERLAY=1
STEP=OVERLAY_EXACT_PRO_AND_SINGLE_DRIVER
cp "$FRONTEND/alphasma.cpp" "$ROOT/src/mame/skeleton/alphasma.cpp"
cp "$FRONTEND/mc68hc11.cpp" "$ROOT/src/devices/cpu/mc68hc11/mc68hc11.cpp"
cp "$FRONTEND/mc68hc11.h" "$ROOT/src/devices/cpu/mc68hc11/mc68hc11.h"
# Mirror AS2K Stable's exact mame.lst filtering, but inverse machine:
# the ASPRO Stable binary contains asmapro alone, never asma2k.
awk '
  /^@source:/ { pro_source = ($0 == "@source:skeleton/alphasma.cpp") }
  pro_source && $0 == "asma2k" { next }
  { print }
' "$BACK/src/mame/mame.lst" > "$ROOT/src/mame/mame.lst"
test "$(awk '/^@source:skeleton\/alphasma.cpp$/ {b=1;next} b && /^@source:/ {exit} b && /^asmapro$/ {n++} END{print n+0}' "$ROOT/src/mame/mame.lst")" = 1
if grep -q '^asma2k$' <(awk '/^@source:skeleton\/alphasma.cpp$/ {b=1;next} b && /^@source:/ {exit} b {print}' "$ROOT/src/mame/mame.lst"); then
  echo "BLOCKED_AS2K_DRIVER_IN_ASPRO_BUILD"; exit 5
fi
# Preserve earlier native MAME dependencies and generated archives.  This is
# an incremental compile of ASPRO only, not a fresh or cross-machine build.
STEP=REUSE_EXISTING_ARM64_BUILD_OBJECTS
cd "$ROOT"
make -j2 NOWERROR=1 SUBTARGET=aspro \
  SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 USE_QTDEBUG=0
test -x "$ROOT/aspro"
STEP=VALIDATE_SINGLE_DRIVER
LC_ALL=C file "$ROOT/aspro" | grep -q 'ARM aarch64'
"$ROOT/aspro" -validate >"$LOGDIR/vontar-aspro-core-validate.log" 2>&1
# Redirect to a file rather than '-listfull | grep -q' under pipefail:
# the previous deployment erroneously failed with SIGPIPE, exit 141.
"$ROOT/aspro" -listfull >"$LOGDIR/vontar-aspro-driver-list.txt" 2>&1
grep -Eq '^asmapro[[:space:]]' "$LOGDIR/vontar-aspro-driver-list.txt"
if grep -Eq '^asma2k[[:space:]]' "$LOGDIR/vontar-aspro-driver-list.txt"; then
  echo "BLOCKED_AS2K_DRIVER_IN_ASPRO_BINARY"; exit 6
fi
sha256sum "$ROOT/aspro" >"$LOGDIR/vontar-aspro-candidate.sha256"
# AS2K Stable validates the reduced executable BEFORE installation.
STEP=INSTALL_SEPARATELY_AS_ASPRO
# Pin installer to the corrected canonical version with traversable root
# directories.  Do not touch AS2K core/frontend or its desktop launcher.
curl -fLsS --retry 2 --connect-timeout 20 --max-time 120 \
  "https://raw.githubusercontent.com/SamDelorean/ASPRO-emu/eaeb8b03fc32009477313f91767e60211c54aecd/stable/install_stable.sh" \
  -o "$STAGE/stable/install_stable.canonical.sh"
sh -n "$STAGE/stable/install_stable.canonical.sh"
if [ -e "$DEST" ]; then
  test -f "$DEST" && test ! -L "$DEST"
  cp -p "$DEST" "$PRIVATE/binaries/stable-aarch64/aspro-bin.before-as2k-method"
fi
sudo -n sh "$STAGE/stable/install_stable.canonical.sh" "$ROOT/aspro"
sudo -n chmod 0755 /usr/local/libexec/aspro /usr/local/libexec/aspro/frontend
test -x "$DEST" && test -x /usr/local/bin/aspro
test -r /usr/local/libexec/aspro/frontend/aspro_ui.py
test -r /usr/local/libexec/aspro/frontend/aspro_session.py
test -f /usr/local/share/applications/aspro.desktop
cmp "$ROOT/aspro" "$DEST"
"$DEST" -validate >"$LOGDIR/vontar-aspro-installed-validate.log" 2>&1
"$DEST" -listfull >"$LOGDIR/vontar-aspro-installed-listfull.txt" 2>&1
grep -Eq '^asmapro[[:space:]]' "$LOGDIR/vontar-aspro-installed-listfull.txt"
python3 - <<'PY'
import ast
from pathlib import Path
p=Path("/usr/local/libexec/aspro/frontend")
for name in ("aspro_ui.py","aspro_session.py"):
    ast.parse((p/name).read_text())
print("ASPRO_INSTALLED_GTK_SOURCE_STATIC_PASS")
PY
cp -p "$DEST" "$PRIVATE/binaries/stable-aarch64/aspro-bin"
sha256sum "$DEST" >"$PRIVATE/binaries/stable-aarch64/aspro-bin.sha256"
STEP=PASS
echo "ASPRO_VONTAR_ARM64_REDUCED_SINGLE_DRIVER_PASS"
