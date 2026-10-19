#!/usr/bin/env bash
# One grouped T640 job. Invoking it is not Commander authorization.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
SOURCE= REMOTE= JOBS=2 CAPTURE=auto
usage() {
    echo 'Usage: ap02_run_once.sh --mame-source EXISTING_GIT_REFERENCE --drive-remote NAME: [--jobs N] [--capture auto|none|soft]' >&2
}
while (($#)); do
    case "$1" in
        --mame-source|--drive-remote|--jobs|--capture)
            (($#>=2)) || { usage; exit 2; }
            case "$1" in
                --mame-source) SOURCE=$2;; --drive-remote) REMOTE=$2;;
                --jobs) JOBS=$2;; --capture) CAPTURE=$2;;
            esac; shift 2;;
        *) usage; exit 2;;
    esac
done
[[ -n "$SOURCE" && "$REMOTE" =~ ^[A-Za-z0-9_-]+:$ && "$JOBS" =~ ^[1-9][0-9]*$ ]] || { usage; exit 2; }
[[ "$CAPTURE" == auto || "$CAPTURE" == none || "$CAPTURE" == soft ]] || { usage; exit 2; }
for tool in python3 git rclone tail sed grep; do
    command -v "$tool" >/dev/null || { echo "BLOCKED_DEPENDENCY: $tool" >&2; exit 2; }
done
# Existing names only; no config/credential dump or interactive login.
rclone listremotes 2>/dev/null | grep -Fx -- "$REMOTE" >/dev/null || {
    echo 'BLOCKED_DRIVE_REMOTE: provide an already configured rclone remote name' >&2; exit 2;
}
# Avoid demanding compiler/SDL development packages if the existing DIAG engine qualifies.
PRIVATE="$ROOT/private/ap02"
# Prevent symlink aliases into a reference tree; this directory is never uploaded.
python3 - "$ROOT" "$PRIVATE" <<'PY'
import pathlib,sys
root=pathlib.Path(sys.argv[1]).resolve(); path=pathlib.Path(sys.argv[2]).resolve()
if not path.is_relative_to(root): raise SystemExit('BLOCKED_PRIVATE_PATH: escapes ASPRO')
path.mkdir(parents=True,exist_ok=True,mode=0o700)
PY
RUN=$(mktemp -d "$PRIVATE/job-XXXXXXXX")
INPUTS= PHASE=PREPARE_MAME STATUS=BLOCKED COMPILE=COMPILE_PENDING
finish() {
    rc=$?
    trap - EXIT
    CLEANUP=COMPLETE
    if [[ -n "$INPUTS" ]] && ! rm -rf -- "$INPUTS"; then
        CLEANUP=FAILED; STATUS=INPUT_CLEANUP_FAILED; rc=5
    fi
    python3 - "$RUN" "$PHASE" "$STATUS" "$rc" "$ROOT" "$COMPILE" "$CLEANUP" <<'PY'
import hashlib,json,pathlib,subprocess,sys
out,phase,status,rc,root,compile_status,cleanup=sys.argv[1:]
root=pathlib.Path(root); out=pathlib.Path(out)
def git(*args): return subprocess.check_output(['git','-C',str(root),*args],text=True).strip()
report={'phase':phase,'status':status,'exit_code':int(rc),'product_sha':git('rev-parse','HEAD'),
        'product_dirty':bool(git('status','--porcelain')),'functional_pass':False,
        'compile':compile_status,
        'dynamic':'UNVERIFIED' if phase in ('DIAG','DONE') else 'DYNAMIC_PENDING',
        'inputs_cleanup':cleanup,'result_dir':str(out)}
for path in sorted(out.glob('*.log')):
    report.setdefault('log_sha256',{})[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
(out/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
PY
    # Derived evidence only: no ROM, CGROM, NVRAM, images or debugger traces.
    key="ASPRO_AP02_${RUN##*/}"
    if [[ -f "$RUN/summary.json" ]]; then
        rclone copyto "$RUN/summary.json" "${REMOTE}AS2K_TEMP/COMMANDER_PIPELINE/outbox/${key}.summary.json" --retries 1 --timeout 45s || echo "WARN: summary upload failed" >&2
    fi
    if [[ -f "$RUN/diag-report.json" ]]; then
        rclone copyto "$RUN/diag-report.json" "${REMOTE}AS2K_TEMP/COMMANDER_PIPELINE/outbox/${key}.diag.json" --retries 1 --timeout 45s || echo "WARN: diagnostic manifest upload failed" >&2
    fi
    exit "$rc"
}
trap finish EXIT
trap 'STATUS=INTERRUPTED; exit 130' INT
trap 'STATUS=INTERRUPTED; exit 143' TERM HUP
{
    python3 --version
    make --version | sed -n '1p'
    g++ --version | sed -n '1p'
    rclone version | sed -n '1,2p'
} >"$RUN/tool-versions.log"
PHASE=ADOPT_ENGINE
ENGINE="$ROOT/build/prebuilt/asprodiag"
if python3 "$ROOT/tools/adopt_engine.py" --reference-bin "$SOURCE/as2kdiag" >"$RUN/engine.json" 2>"$RUN/adopt.log"; then
    COMPILE=PREBUILT_ADOPTED
    printf '%s\n' 'MAME reference engine copied and checked: no rebuild needed' >"$RUN/build.log"
else
    PHASE=BUILD
    for tool in make g++ pkg-config; do
        command -v "$tool" >/dev/null || { echo "COMPILE_PENDING: missing $tool" >&2; exit 2; }
    done
    pkg-config --exists sdl2 SDL2_ttf fontconfig || {
        echo 'COMPILE_PENDING: missing SDL2/SDL2_ttf/fontconfig dev packages' >&2; exit 2;
    }
    python3 "$ROOT/tools/prepare_mame.py" --source "$SOURCE" --dest "$ROOT/build/mame" >"$RUN/source.json"
    bash "$ROOT/tools/build_diag.sh" "$ROOT/build/mame" "$JOBS" 2>&1 | tail -c 1048576 >"$RUN/build.log"
    COMPILE=COMPILED_ONLY
    ENGINE="$ROOT/build/mame/asprodiag"
fi
PHASE=FETCH_PRIVATE
INPUTS=$(mktemp -d "$RUN/inputs-XXXXXXXX")
PRO_PATH='ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom'
LCD_PATH='ALPHASMART/private/roms/ks0066/ks0066_f05.bin'
# Verify the exact existing remote paths, then fetch only those files.
for path in "$PRO_PATH" "$LCD_PATH"; do
    rclone lsjson --stat "$REMOTE$path" --retries 1 --timeout 30s --contimeout 10s >>"$RUN/remote-metadata.jsonl"
done
rclone copyto "$REMOTE$PRO_PATH" "$INPUTS/alphasmartpro212.rom" --retries 1 --timeout 30s --contimeout 10s
rclone copyto "$REMOTE$LCD_PATH" "$INPUTS/ks0066_f05.bin" --retries 1 --timeout 30s --contimeout 10s
PHASE=INPUT_IDENTITY
python3 "$ROOT/tools/rom_audit.py" --rom "$INPUTS/alphasmartpro212.rom" --require-212 --json >"$RUN/rom-audit.json"
PHASE=DIAG
python3 "$ROOT/tools/run_diag.py" --rom "$INPUTS/alphasmartpro212.rom" \
    --lcd-rom "$INPUTS/ks0066_f05.bin" --bin "$ENGINE" \
    --out "$RUN" --seconds 8 --capture "$CAPTURE" >"$RUN/diag-report.json"
PHASE=DONE STATUS=DIAG_COMPLETED_FUNCTIONAL_UNVERIFIED
echo 'No functional PASS claimed; inspect private DIAG evidence before classification.'
