#!/usr/bin/env bash
# T640 only, read-only diagnosis for the v0.1.1 release failure:
#  - ld.so "R_X86_64_RELATIVE" assertion when asmapro starts with ROM
#  - "Segmentation fault" printed before make starts
# Writes evidence to Drive; changes nothing on the system.
set -u
VER=v0.1.1
WORK="$HOME/Projects/alphasmart/aspro-release-$VER"
TREE="$HOME/Projects/alphasmart/ASPRO-emu/build/send-mame"
OUT="$WORK/diag"; mkdir -p "$OUT"
DRIVE="googledrive:ASPRO_TEMP/dist/$VER/diag"
R="$OUT/diag_ldso.txt"
run() { echo "### $*"; "$@" 2>&1; echo "### rc=$?"; }
{
  echo "date: $(date -Is)  host: $(hostname)  kernel: $(uname -r)"
  run ldd --version
  echo "== core dumps (which program segfaulted)"
  run coredumpctl list --no-pager --since=-2d
  echo "== release binary"
  B="$WORK/aspro-linux-x86_64"
  run file "$B"; run sha256sum "$B" "$TREE/aspro"
  run "$B" -validate
  echo "== ROM start with LD_DEBUG=files (last libraries opened)"
  ( cd "$WORK" && LD_DEBUG=files LD_DEBUG_OUTPUT="$OUT/lddebug" SDL_VIDEODRIVER=dummy timeout 60 \
      "$B" asmapro -rompath smoke/roms -sound none -video none -nothrottle -seconds_to_run 2 \
      -skip_gameinfo -snapshot_directory smoke/snap > "$OUT/romrun.out" 2>&1; echo "romrun rc=$?" )
  tail -20 "$OUT/romrun.out"
  for f in "$OUT"/lddebug.*; do [ -f "$f" ] && { echo "--- $f"; grep -E 'file=|calling init' "$f" | tail -25; }; done
  echo "== same start without ROM (OSD/SDL only)"
  ( cd "$WORK" && SDL_VIDEODRIVER=dummy timeout 30 "$B" asmapro -rompath /nonexistent -sound none -video none \
      -seconds_to_run 1 -skip_gameinfo > "$OUT/norom.out" 2>&1; echo "norom rc=$?" ); tail -5 "$OUT/norom.out"
  echo "== unstripped tree binary with ROM"
  ( cd "$WORK" && SDL_VIDEODRIVER=dummy timeout 60 "$TREE/aspro" asmapro -rompath smoke/roms -sound none -video none \
      -nothrottle -seconds_to_run 2 -skip_gameinfo -snapshot_directory smoke/snap > "$OUT/tree.out" 2>&1; echo "tree rc=$?" ); tail -5 "$OUT/tree.out"
  echo "== integrity of libraries opened last"
  libs=$(cat "$OUT"/lddebug.* 2>/dev/null | sed -n 's/.*file=\([^ ]*\) .*/\1/p' | grep '^/' | sort -u | tail -15)
  for l in $libs; do p=$(dpkg -S "$l" 2>/dev/null | head -1 | cut -d: -f1); echo "$l pkg=${p:-?}"; [ -n "$p" ] && dpkg --verify "$p" 2>&1 | head -5; done
} > "$R" 2>&1
rclone copy "$OUT" "$DRIVE" --exclude 'smoke/**' --retries 2 --timeout 120s
echo DIAG_UPLOADED
