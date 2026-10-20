#!/usr/bin/env bash
# One grouped AP-06 run: build isolated ASPRO-DIAG Send, transmit physical PC frames,
# compare exact generated TXT and save only derived/private evidence.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
MAME_REFERENCE="${1:?Usage: ap06_run_once.sh READ_ONLY_MAME_TREE [jobs]}"
JOBS="${2:-2}"
cd "$ROOT"
OUT="$ROOT/private/ap06"
mkdir -p "$OUT"
INPUT="$(mktemp -d "$ROOT/private/ap06-inputs-XXXXXXXX")"
trap 'rm -rf -- "$INPUT"' EXIT
PRO="googledrive:ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom"
LCD="googledrive:ALPHASMART/private/roms/ks0066/ks0066_f05.bin"
rclone copyto "$PRO" "$INPUT/alphasmartpro212.rom" --retries 1 --timeout 60s
rclone copyto "$LCD" "$INPUT/ks0066_f05.bin" --retries 1 --timeout 60s

# Referenced AS2K files are read-only; all compilation remains in ASPRO/build/send-mame.
bash "$ROOT/tools/build_send_diag.sh" "$MAME_REFERENCE" "$JOBS" >"$OUT/build.log" 2>&1

set +e
python3 "$ROOT/tools/ap06_send_campaign.py" \
    --rom "$INPUT/alphasmartpro212.rom" \
    --lcd-rom "$INPUT/ks0066_f05.bin" \
    --bin "$ROOT/build/send-mame/asprodiag" >"$OUT/report.latest.json"
rc=$?
set -e
test -s "$OUT/report.latest.json" || { echo "AP06_NO_REPORT exit=$rc" >&2; exit "$rc"; }
RUN=$(python3 - "$OUT/report.latest.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(d["run_dir"])
PY
)
case "$RUN" in "$ROOT"/private/ap06/send-*) ;; *) echo "BLOCKED invalid ASPRO output"; exit 8;; esac
KEY="AP06_$(basename "$RUN")"
REMOTE="googledrive:AS2K_TEMP/COMMANDER_PIPELINE/outbox"
PRIVATE="googledrive:ALPHASMART/Alphasmart Pro/ASPRO_DIAG_PRIVATE"
rclone copyto "$OUT/report.latest.json" "$REMOTE/ASPRO_$KEY.report.json" --retries 1 --timeout 60s
for name in ready typed_abc host_attached after_send after_disconnect; do
    file="$RUN/snap/$name.png"
    [[ -f "$file" ]] || continue
    rclone copyto "$file" "$PRIVATE/$KEY.$name.png" --retries 1 --timeout 60s
done
# Export only if the genuine physical decoder produced the requested exact text.
if [[ "$rc" == 0 && -f "$RUN/snap/send.txt" ]]; then
    test "$(cat "$RUN/snap/send.txt")" = abcabc || { echo "SEND_TXT_MISMATCH"; exit 9; }
    rclone copyto "$RUN/snap/send.txt" "$PRIVATE/$KEY.send.txt" --retries 1 --timeout 60s
    echo "AP06_SEND_TXT_SUCCESS=$PRIVATE/$KEY.send.txt"
else
    echo "AP06_SEND_TXT_NOT_VERIFIED; check private diagnostics"
fi
echo "AP06_EXIT=$rc"
exit "$rc"
