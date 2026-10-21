#!/usr/bin/env bash
# AP-07 one autonomous ASPRO-DIAG job. Archive evidence even on failure.
# Commander only after explicit authorization. No polling. No AS2K writes.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
REF="${1:?Usage: ap07_run_once.sh READ_ONLY_MAME_TREE [jobs]}"
JOBS="${2:-3}"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo AP07_BLOCKED_BAD_JOBS; exit 2; }
cd "$ROOT"
OUT="$ROOT/private/ap07"
[[ ! -L "$ROOT/private" && ! -L "$ROOT/build" ]] || { echo AP07_BLOCKED_SYMLINK; exit 2; }
mkdir -p "$OUT"
INPUT=""
REMOTE="googledrive:AS2K_TEMP/COMMANDER_PIPELINE/outbox"
PRIVATE="googledrive:ALPHASMART/Alphasmart Pro/ASPRO_DIAG_PRIVATE"

finalize() {
    local rc=$?
    trap - EXIT
    printf 'AP07_JOB_EXIT=%s\n' "$rc" > "$OUT/final.status"
    printf 'AP07_SCI=8N1_CPU_BEHAVIORAL_MODEL; SILICON_BOOT_ROM_UNVERIFIED\n' >> "$OUT/final.status"
    for name in d0_datasheet_tests.log payload_static_tests.log build.log \
                campaign.latest.json final.status; do
        [[ -s "$OUT/$name" ]] || continue
        rclone copyto "$OUT/$name" "$REMOTE/ASPRO_AP07_$name" \
            --retries 1 --timeout 60s || echo "AP07_REPORT_UPLOAD_FAILED: $name" >&2
    done
    if [[ -s "$OUT/campaign.latest.json" ]]; then
        python3 - "$OUT/campaign.latest.json" > "$OUT/screenshots.txt" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    for kind in ("bootstrap","normal"):
        p=d.get(kind,{}).get("run_dir")
        if not p: continue
        for name in ("bootstrap.png","normal_before.png"):
            print(kind+"|"+p+"/snap/"+name+"|"+name)
except (OSError,ValueError,KeyError):
    pass
PY
        while IFS='|' read -r kind path name; do
            [[ -f "$path" ]] || continue
            rclone copyto "$path" "$PRIVATE/AP07_${kind}_${name}" \
                --retries 1 --timeout 60s || echo "AP07_SCREENSHOT_UPLOAD_FAILED: $kind $name" >&2
        done < "$OUT/screenshots.txt"
    fi
    if [[ -n "$INPUT" && "$INPUT" == "$OUT"/roms-* ]]; then
        rm -rf -- "$INPUT"
    fi
    printf 'AP07_ONE_SHOT_EXIT=%s\n' "$rc"
    exit "$rc"
}
trap finalize EXIT

# Clear only current reports, never previous experiment directories.
rm -f -- "$OUT/campaign.latest.json" "$OUT/final.status" "$OUT/screenshots.txt"
echo AP07_INTEGRAL_INCREMENT_START
python3 tools/ap07_static_selftest.py > "$OUT/d0_datasheet_tests.log" 2>&1
python3 tools/ap07_static_campaign.py > "$OUT/payload_static_tests.log" 2>&1
HOLD=$(awk -F= '$1=="hold_pc" {gsub(/\$/,"",$2); print $2}' "$OUT/payload0/manifest.txt")
[[ "$HOLD" =~ ^[[:xdigit:]]{4}$ ]] || { echo AP07_BLOCKED_INVALID_HOLD_PC; exit 5; }

INPUT=$(mktemp -d "$OUT/roms-XXXXXXXX")
PRO="googledrive:ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom"
LCD="googledrive:ALPHASMART/private/roms/ks0066/ks0066_f05.bin"
rclone copyto "$PRO" "$INPUT/alphasmartpro212.rom" --retries 1 --timeout 60s
rclone copyto "$LCD" "$INPUT/ks0066_f05.bin" --retries 1 --timeout 60s
bash tools/build_send_diag.sh "$REF" "$JOBS" > "$OUT/build.log" 2>&1
python3 tools/ap07_campaign.py \
    --rom "$INPUT/alphasmartpro212.rom" \
    --lcd-rom "$INPUT/ks0066_f05.bin" \
    --hold "$HOLD" \
    --bin "$ROOT/build/send-mame/asprodiag" > "$OUT/campaign.latest.json" 2>&1
echo AP07_CAMPAIGN_COMPLETED
