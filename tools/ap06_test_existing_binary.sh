#!/usr/bin/env bash
# AP-06: rerun ONLY the Pro PC Send dynamic test against the already-built
# ASPRO-DIAG binary. Never invoke make/AS2K or export private firmware.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$ROOT"
OUT="$ROOT/private/ap06"
BIN="$ROOT/build/send-mame/asprodiag"
[[ -x "$BIN" && ! -L "$BIN" ]] || { echo "BLOCKED: already-built independent ASPRO-DIAG binary missing"; exit 3; }
[[ -f "$ROOT/build/send-mame/.aspro-binary.json" ]] || { echo "BLOCKED: binary manifest missing"; exit 3; }
mkdir -p "$OUT"
INPUT=$(mktemp -d "$ROOT/private/ap06-inputs-XXXXXXXX")
trap 'rm -rf -- "$INPUT"' EXIT
rclone copyto "googledrive:ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom" "$INPUT/alphasmartpro212.rom" --retries 1 --timeout 60s
rclone copyto "googledrive:ALPHASMART/private/roms/ks0066/ks0066_f05.bin" "$INPUT/ks0066_f05.bin" --retries 1 --timeout 60s

set +e
python3 "$ROOT/tools/ap06_send_campaign.py" \
    --rom "$INPUT/alphasmartpro212.rom" \
    --lcd-rom "$INPUT/ks0066_f05.bin" \
    --bin "$BIN" >"$OUT/report.latest.json"
rc=$?
set -e
[[ -s "$OUT/report.latest.json" ]] || { echo "BLOCKED: campaign failed before report rc=$rc"; exit "$rc"; }
RUN=$(python3 - "$OUT/report.latest.json" <<'PY'
import json,sys
with open(sys.argv[1]) as stream:
    report=json.load(stream)
print(report["run_dir"])
PY
)
case "$RUN" in "$ROOT"/private/ap06/send-*) ;; *) echo "BLOCKED unsafe report output path"; exit 8;; esac
KEY="ASPRO_AP06_$(basename "$RUN")"
RESULTS="googledrive:AS2K_TEMP/COMMANDER_PIPELINE/outbox"
PRIVATE="googledrive:ALPHASMART/Alphasmart Pro/ASPRO_DIAG_PRIVATE"
rclone copyto "$OUT/report.latest.json" "$RESULTS/$KEY.report.json" --retries 1 --timeout 60s
[[ ! -f "$RUN/observations.log" ]] || rclone copyto "$RUN/observations.log" "$RESULTS/$KEY.observations.txt" --retries 1 --timeout 60s
for name in ready typed_abc host_attached after_send after_disconnect; do
    img="$RUN/snap/$name.png"
    [[ ! -f "$img" ]] || rclone copyto "$img" "$PRIVATE/$KEY.$name.png" --retries 1 --timeout 60s
done
if ((rc==0)); then
    python3 - "$RUN/snap/send.txt" <<'PY'
from pathlib import Path
import sys
assert Path(sys.argv[1]).read_bytes()==b"abcabc", "incorrect PC output"
PY
    rclone copyto "$RUN/snap/send.txt" "$PRIVATE/$KEY.send.txt" --retries 1 --timeout 60s
    echo "AP06_TXT_PASS=$PRIVATE/$KEY.send.txt"
else
    echo "AP06_TXT_UNVERIFIED; report and observations saved in Drive"
fi
echo "AP06_RUN_KEY=$KEY"
echo "AP06_TEST_ONLY_EXIT=$rc"
exit "$rc"
