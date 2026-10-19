#!/usr/bin/env bash
# Construcción reducida MAME en workspace ASPRO EXCLUSIVO, AS2K sólo referencia de código; NO compilar en AS2K.
set -euo pipefail
MAME_ROOT="${1:-${ASPRO_MAME_ROOT:-}}"
if [[ -z "$MAME_ROOT" ]]; then
  echo "BLOCKED: indicar árbol MAME de construcción ASPRO independiente como arg1 o ASPRO_MAME_ROOT; AS2K es sólo referencia" >&2
  exit 2
fi
MAME_ROOT="$(realpath -m "$MAME_ROOT")"
case "${MAME_ROOT,,}" in
  *mame-as2k*|*as2k-stable*|*as2k-diag*)
    echo "BLOCKED: nunca compilar dentro de AS2K; árbol prohibido: $MAME_ROOT" >&2
    exit 2;;
esac
JOBS="${2:-2}"
if [[ ! -d "$MAME_ROOT" || ! -f "$MAME_ROOT/makefile" ]]; then
  echo "BLOCKED: falta árbol canónico MAME: $MAME_ROOT" >&2; exit 2
fi
if ! grep -q 'ROM_START( asmapro )' "$MAME_ROOT/src/mame/skeleton/alphasma.cpp"; then
  echo "BLOCKED: fuente MAME no contiene asmapro, no inventar driver" >&2; exit 3
fi
if [[ ! "$JOBS" =~ ^[1-9][0-9]*$ ]]; then echo "JOBS inválido" >&2; exit 2; fi
echo "ASPRO-DIAG: MAME reducido existente, fuente alphasma.cpp, jobs=$JOBS"
echo "Source SHA256: $(sha256sum "$MAME_ROOT/src/mame/skeleton/alphasma.cpp" | cut -d' ' -f1)"
make -C "$MAME_ROOT" -j"$JOBS" TARGET=mame SUBTARGET=asprodiag \
  SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 TOOLS=0
if [[ ! -x "$MAME_ROOT/asprodiag" ]]; then
  echo "BLOCKED: subtarget compilado no localizado en $MAME_ROOT/asprodiag" >&2; exit 4
fi
echo "ASPRO-DIAG BIN SHA256: $(sha256sum "$MAME_ROOT/asprodiag" | cut -d' ' -f1)"
echo "COMPILED_ONLY: sin calificación funcional"
