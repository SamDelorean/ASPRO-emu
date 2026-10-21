#!/usr/bin/env bash
# AP-06: compile ONLY ASPRO-DIAG+Send in isolated MAME tree.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TREE="$ROOT/build/send-mame"
REF="${1:?Usage: build_send_diag.sh READ_ONLY_MAME_REPO [jobs]}"
JOBS="${2:-3}"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "BLOCKED bad jobs"; exit 2; }
SOURCE="$ROOT/src/mame/skeleton/alphasma.cpp"
test -f "$SOURCE" && test ! -L "$SOURCE" || { echo "BLOCKED missing ASPRO Pro Send driver"; exit 3; }
SRC_SHA=$(sha256sum "$SOURCE" | cut -d' ' -f1)
MARKER="$TREE/.aspro-send-source.json"

# Prefer existing proven T MAME 0.289 source HEAD; export read-only into ASPRO.
# For future runs, verify previous ASPRO copy and refresh ONLY changed Pro driver.
# All existing independent MAME object files remain intact for incremental make.
if [[ -f "$MARKER" ]]; then
    python3 "$ROOT/tools/prepare_send_mame.py" --refresh-driver
else
    python3 "$ROOT/tools/prepare_send_mame.py" --reference "$REF"
fi

# AP-07 integrates the bounded AS2K D0 CPU adapter in ASPRO's *copy* only.
# The original MAME reference and AS2K project remain unmodified.
python3 "$ROOT/tools/ap07_patch_d0_cpu.py" --tree "$TREE"
for name in make g++ pkg-config; do command -v "$name" >/dev/null || { echo "BLOCKED missing $name"; exit 4; }; done
pkg-config --exists sdl2 SDL2_ttf fontconfig || { echo "BLOCKED missing MAME SDL2 build dependencies"; exit 4; }
# Recover only archive members independently identified as damaged by
# GNU ld, within this ASPRO-owned MAME tree. Preserve original archive
# bytes and let the existing MAME make regenerate the specific member.
# Bounded to six attempts: never clean/rebuild a donor MAME tree.
build_mame() {
    CCACHE_DISABLE=1 MAKEFLAGS= make -C "$TREE" -j"$JOBS" TARGET=mame SUBTARGET=asprodiag \
        SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 TOOLS=0 USE_QTDEBUG=0
}
FIRST="$TREE/.ap07-first-link.log"
AP07_LINKED=0
for attempt in $(seq 1 24); do
    if build_mame >"$FIRST" 2>&1; then
        cat "$FIRST"
        AP07_LINKED=1
        break
    fi
    cat "$FIRST"
    echo "AP07_LINK_FAILED_ATTEMPT=$attempt" >&2
    python3 "$ROOT/tools/ap07_archive_repair.py" --tree "$TREE" --link-log "$FIRST" ||
        { echo "AP07_BLOCKED_UNRECOGNIZED_OR_UNSAFE_LINK_FAILURE" >&2; exit 7; }
done
[[ "$AP07_LINKED" == 1 ]] || { echo "AP07_BLOCKED_REPAIR_ATTEMPT_LIMIT" >&2; exit 8; }
test -f "$TREE/asprodiag" && test -x "$TREE/asprodiag" && test ! -L "$TREE/asprodiag" || {
    echo "BLOCKED missing independent ASPRO send binary"; exit 5;
}
python3 - "$TREE" "$ROOT" <<'PY'
import hashlib,json,pathlib,sys
tree=pathlib.Path(sys.argv[1]);root=pathlib.Path(sys.argv[2])
binary=tree/"asprodiag"
if binary.read_bytes()[:4]!=b"\x7fELF": raise SystemExit("BAD_ELF")
info=json.loads((tree/".aspro-send-source.json").read_text())
info.update(binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
            system="asmapro",variant="ASPRO-DIAG",
            feature="PC_SEND_PHYSICAL_SET2_TO_UTF8_TXT",
            functional_pass=False)
(tree/".aspro-binary.json").write_text(json.dumps(info,indent=2)+"\n")
print("AP06_SEND_BINARY_PREPARED",info["binary_sha256"])
PY
echo "AP06_COMPILED_ONLY — PC Send physical behavior must pass ASPRO-DIAG before calling functional"
