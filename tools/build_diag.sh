#!/usr/bin/env bash
# Only this ASPRO checkout's owned build tree may receive make outputs.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# Historical AP02 entrypoint retained for provenance only: no second build tree.
echo "BLOCKED_LEGACY_DIAG_BUILD: use tools/build_send_diag.sh and existing build/send-mame; do not create build/mame" >&2
exit 2
MAME_ROOT=${1:-${ASPRO_MAME_ROOT:-"$ROOT/build/mame"}}
JOBS=${2:-2}
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo 'BLOCKED: JOBS must be positive' >&2; exit 2; }
python3 "$ROOT/tools/prepare_mame.py" --check --dest "$MAME_ROOT"
MAME_ROOT=$(realpath -e -- "$MAME_ROOT")
for tool in make g++ pkg-config; do
    command -v "$tool" >/dev/null || { echo "COMPILE_PENDING: missing $tool" >&2; exit 2; }
done
pkg-config --exists sdl2 SDL2_ttf fontconfig || {
    echo 'COMPILE_PENDING: missing MAME SDL2/SDL2_ttf/fontconfig development packages' >&2; exit 2;
}
printf '%s\n' 'ASPRO-DIAG reduced build; no changes to reference source'
# Never use symlinked/hardlinked AS2K caches. This export has its own build/.
CCACHE_DIR="$MAME_ROOT/build/ccache" CCACHE_LOGFILE=/dev/null CCACHE_DISABLE=1 MAKEFLAGS= make -C "$MAME_ROOT" -j"$JOBS" TARGET=mame SUBTARGET=asprodiag \
    SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 TOOLS=0 USE_QTDEBUG=0
[[ -x "$MAME_ROOT/asprodiag" && ! -L "$MAME_ROOT/asprodiag" ]] || {
    echo 'COMPILE_PENDING: asprodiag output missing/aliased' >&2; exit 4;
}
python3 - "$MAME_ROOT" "$ROOT" <<'PYCODE'
import hashlib,json,pathlib,subprocess,sys
root=pathlib.Path(sys.argv[1]); product=pathlib.Path(sys.argv[2])
binary=root/'asprodiag'
with binary.open('rb') as f:
    if f.read(4)!=b'\x7fELF': raise SystemExit('BLOCKED: asprodiag is not a native ELF executable')
h=hashlib.sha256()
with binary.open('rb') as f:
    for data in iter(lambda:f.read(1024*1024),b''): h.update(data)
info=json.loads((root/'.aspro-source.json').read_text())
info.update(binary_sha256=h.hexdigest(),target='mame',subtarget='asprodiag',
            product_sha=subprocess.check_output(['git','-C',str(product),'rev-parse','HEAD'],text=True).strip())
(root/'.aspro-binary.json').write_text(json.dumps(info,indent=2)+'\n')
print('ASPRO-DIAG binary SHA256: '+h.hexdigest())
PYCODE
echo 'COMPILED_ONLY: functional execution still required'
