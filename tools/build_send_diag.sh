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
# One targeted repair is permitted only after the exact observed libemu
# archive relocation-corruption signature. Never clean/rebuild the entire
# AS2K donor, and never remove unrelated ASPRO objects or libraries.
build_mame() {
    CCACHE_DISABLE=1 MAKEFLAGS= make -C "$TREE" -j"$JOBS" TARGET=mame SUBTARGET=asprodiag \
        SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 TOOLS=0 USE_QTDEBUG=0
}
FIRST="$TREE/.ap07-first-link.log"
if build_mame >"$FIRST" 2>&1; then
    cat "$FIRST"
else
    cat "$FIRST"
    if grep -Fq 'libemu.a(dvtext.o): bad reloc symbol index' "$FIRST"; then
        # The existing AS2K-derived archive may contain a dvtext.o whose
        # standalone object is absent from this independent build tree.
        # Force exactly ONE debugger source rebuild through MAME's own
        # generated makefile; never guess/remove arbitrary object paths.
        SRC="$TREE/src/emu/debug/dvtext.cpp"
        LIB="$TREE/linux_gcc/bin/x64/Release/libemu.a"
        BACKUP="$TREE/.ap07-libemu-corrupt-preserved.a"
        if [[ ! -f "$SRC" || ! -f "$LIB" || -L "$SRC" || -L "$LIB" || -e "$BACKUP" ]]; then
            echo "AP07_BLOCKED_PRIVATE_DVTEXT_OR_LIBEMU_NOT_SAFE" >&2
            exit 6
        fi
        sha256sum "$SRC" "$LIB" > "$TREE/.ap07-dvtext-pre-repair.sha256"
        mv -- "$LIB" "$BACKUP"
        touch -- "$SRC"
        echo "AP07_REBUILD_FROM_PINNED_DEBUG_DVTEXT_SOURCE" >&2
        # Recreating libemu.a after touching precisely this one source
        # instructs MAME make to build dvtext.o and rearchive objects.
        build_mame
    else
        echo "AP07_BLOCKED_UNRECOGNIZED_MAME_BUILD_ERROR" >&2
        exit 7
    fi
fi
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
