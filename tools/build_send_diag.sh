#!/usr/bin/env bash
# AP-06: compile ONLY ASPRO-DIAG+Send in isolated MAME tree.
set -euo pipefail
umask 077
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TREE="$ROOT/build/send-mame"
REF="${1:?Usage: build_send_diag.sh READ_ONLY_MAME_REPO [jobs]}"
JOBS="${2:-2}"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "BLOCKED bad jobs"; exit 2; }
SOURCE="$ROOT/src/mame/skeleton/alphasma.cpp"
test -f "$SOURCE" && test ! -L "$SOURCE" || { echo "BLOCKED missing ASPRO Pro Send driver"; exit 3; }
SRC_SHA=$(sha256sum "$SOURCE" | cut -d' ' -f1)
MARKER="$TREE/.aspro-send-source.json"

# Prefer existing proven T MAME 0.289 source HEAD; export read-only into ASPRO.
# For future runs, validate exact marker & driver only; no source-tree rebuild.
if [[ -f "$MARKER" ]]; then
    python3 "$ROOT/tools/prepare_send_mame.py" --check
else
    python3 "$ROOT/tools/prepare_send_mame.py" --reference "$REF"
fi

for name in make g++ pkg-config; do command -v "$name" >/dev/null || { echo "BLOCKED missing $name"; exit 4; }; done
pkg-config --exists sdl2 SDL2_ttf fontconfig || { echo "BLOCKED missing MAME SDL2 build dependencies"; exit 4; }
CCACHE_DISABLE=1 MAKEFLAGS= make -C "$TREE" -j"$JOBS" TARGET=mame SUBTARGET=asprodiag \
    SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 TOOLS=0 USE_QTDEBUG=0
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
