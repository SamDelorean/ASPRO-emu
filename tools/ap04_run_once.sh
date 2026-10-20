#!/usr/bin/env bash
# AP-04 single grouped job. MAME-DIAG already adopted; no AS2K changes.
set -euo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
REMOTE="${1:-googledrive:}"
[[ "$REMOTE" == "googledrive:" ]] || { echo "BLOCKED: only canonical Drive remote"; exit 2; }
mkdir -p "$ROOT/private"
INPUT="$(mktemp -d "$ROOT/private/ap04-inputs-XXXXXXXX")"
RESULT="$ROOT/private/ap04-last-result.json"
cleanup() { rm -rf -- "$INPUT"; }
trap cleanup EXIT
PRO="ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom"
LCD="ALPHASMART/private/roms/ks0066/ks0066_f05.bin"
rclone copyto "$REMOTE$PRO" "$INPUT/alphasmartpro212.rom" --retries 1 --timeout 50s
rclone copyto "$REMOTE$LCD" "$INPUT/ks0066_f05.bin" --retries 1 --timeout 50s
set +e
python3 tools/ap04_campaign.py \
  --rom "$INPUT/alphasmartpro212.rom" \
  --lcd-rom "$INPUT/ks0066_f05.bin" \
  --bin "$ROOT/build/prebuilt/asprodiag" >"$RESULT"
rc=$?
set -e
if [[ ! -s "$RESULT" ]]; then
    echo "AP04_RUNNER_FAILED_NO_REPORT exit=$rc" >&2
    exit "$rc"
fi
RUN="$(python3 - "$RESULT" <<'PY'
import json,sys,pathlib
d=json.loads(pathlib.Path(sys.argv[1]).read_text())
print(d["run_dir"])
PY
)"
case "$RUN" in "$ROOT"/private/ap04/campaign-*) ;; *) echo "BLOCKED: unsafe AP04 run_dir" >&2; exit 3;; esac
KEY="AP04_$(basename "$RUN")"
rclone copyto "$RUN/report.json" "$REMOTE""AS2K_TEMP/COMMANDER_PIPELINE/outbox/ASPRO_${KEY}.report.json" --retries 1 --timeout 50s
for phase in write verify; do
    for i in 1 2 3 4 5 6 7 8; do
        img="$RUN/$phase/snap/f$i.png"
        [[ -f "$img" ]] || continue
        rclone copyto "$img" "$REMOTE""ALPHASMART/Alphasmart Pro/ASPRO_DIAG_PRIVATE/${KEY}_${phase}_f${i}.png" --retries 1 --timeout 50s
    done
    obs="$RUN/$phase/observations.log"
    if [[ -f "$obs" ]]; then
        rclone copyto "$obs" "$REMOTE""AS2K_TEMP/COMMANDER_PIPELINE/outbox/ASPRO_${KEY}_${phase}.observations.txt" --retries 1 --timeout 50s
    fi
done
echo "AP04_RESULT_KEY=$KEY"
echo "AP04_RUNNER_EXIT=$rc"
echo "AP04_RESULTS_IN_DRIVE=YES"
exit "$rc"
