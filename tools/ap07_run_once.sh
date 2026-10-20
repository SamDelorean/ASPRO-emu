#!/usr/bin/env bash
# AP-07: one independent ASPRO-DIAG build and dual-mode test, no AS2K modification.
# Requires separately authorized T640 Commander launch. No background polling.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
REF="${1:?Usage: ap07_run_once.sh READ_ONLY_MAME_TREE [jobs]}"
JOBS="${2:-3}"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo 'AP07_BLOCKED_BAD_JOBS' >&2; exit 2; }
cd "$ROOT"
OUT="$ROOT/private/ap07"
mkdir -p "$OUT"
test ! -L "$ROOT/private" && test ! -L "$ROOT/build" || { echo 'AP07_BLOCKED_SYMLINK' >&2; exit 2; }
echo AP07_INCREMENT_START
python3 tools/ap07_static_selftest.py > "$OUT/d0_datasheet_tests.log"
python3 tools/ap07_static_campaign.py > "$OUT/payload_static_tests.log"
INPUT=$(mktemp -d "$OUT/roms-XXXXXXXX")
trap 'rm -rf -- "$INPUT"' EXIT
PRO="googledrive:ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom"
LCD="googledrive:ALPHASMART/private/roms/ks0066/ks0066_f05.bin"
rclone copyto "$PRO" "$INPUT/alphasmartpro212.rom" --retries 1 --timeout 60s
rclone copyto "$LCD" "$INPUT/ks0066_f05.bin" --retries 1 --timeout 60s
# AP06's existing incremental driver build is reused; it now applies the
# pinned D0 CPU bootstrap patch to ASPRO/build/send-mame and nowhere else.
bash tools/build_send_diag.sh "$REF" "$JOBS" > "$OUT/build.log" 2>&1
HOLD=$(awk -F= '$1=="hold_pc" {gsub(/\$/,"",$2);print $2}' "$OUT/payload0/manifest.txt")
test -n "$HOLD" || { echo AP07_NO_HOLD_PC >&2; exit 5; }
set +e
python3 tools/ap07_campaign.py --rom "$INPUT/alphasmartpro212.rom" \
  --lcd-rom "$INPUT/ks0066_f05.bin" --hold "$HOLD" \
  --bin "$ROOT/build/send-mame/asprodiag" > "$OUT/campaign.latest.json"
RC=$?
set -e
# Results, build/status and LCD screenshots only; never upload private ROMs
# nor include MAME executable in a public repository.
REMOTE="googledrive:AS2K_TEMP/COMMANDER_PIPELINE/outbox"
PRIVATE="googledrive:ALPHASMART/Alphasmart Pro/ASPRO_DIAG_PRIVATE"
for name in d0_datasheet_tests.log payload_static_tests.log build.log campaign.latest.json; do
  [[ -f "$OUT/$name" ]] || continue
  rclone copyto "$OUT/$name" "$REMOTE/ASPRO_AP07_$name" --retries 1 --timeout 60s
done
if [[ -s "$OUT/campaign.latest.json" ]]; then
  python3 - "$OUT/campaign.latest.json" > "$OUT/screenshots.txt" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
for kind in ('bootstrap','normal'):
    r=d.get(kind,{})
    p=r.get('run_dir')
    if p: print(kind+'|'+p+'/snap/bootstrap.png')
PY
  while IFS='|' read -r kind p; do
    [[ -f "$p" ]] || continue
    rclone copyto "$p" "$PRIVATE/AP07_${kind}_bootstrap.png" --retries 1 --timeout 60s
  done < "$OUT/screenshots.txt"
fi
echo "AP07_CAMPAIGN_EXIT=$RC"
echo "AP07_SCI_AUTHENTIC_PASS=FALSE"
echo "AP07_POST_SCI_DIAG_EVIDENCE=$REMOTE/ASPRO_AP07_campaign.latest.json"
exit "$RC"
