#!/usr/bin/env bash
# Consolidated one-shot Vontar: existing AS2K core PC wakeup, then ASPRO stable.
# All long-running work unattended and sequential on one ARM64 MAME checkout.
set -Eeuo pipefail; umask 077
ROOT="$HOME/Projects/alphasmart/aspro-stable-pack"
mkdir -p "$ROOT" "$HOME/.local/share/alphasmart/private/aspro/logs"
exec > >(tee -a "$HOME/.local/share/alphasmart/private/aspro/logs/vontar-consolidated.log") 2>&1
TARGET="$HOME/.local/share/alphasmart/private/aspro/logs/vontar-consolidated.status"
AS2K_URL="https://raw.githubusercontent.com/SamDelorean/AS2K-Emulator/36dc94abfc8079fd494d0f27a0001d29c80912c5/scripts/resume-vontar-as2k-pc-20261021.sh"
ASPRO_URL="https://raw.githubusercontent.com/SamDelorean/ASPRO-emu/418458ef510d390651cfd6dc454a97d1ac16dd56/stable/deploy_vontar_autonomous.sh"
finish(){ rc=$?; trap - EXIT; echo "OVERALL_EXIT=$rc" >> "$TARGET"; exit "$rc"; }
trap finish EXIT
command -v flock >/dev/null || { echo "BLOCKED flock required"; exit 2; }
exec 9>"$ROOT/consolidated.lock"
flock -n 9 || { echo "BLOCKED another Vontar build owns deployment lock"; exit 2; }
for kind in as2k aspro; do
  if [ "$kind" = as2k ]; then url=$AS2K_URL; else url=$ASPRO_URL; fi
  curl -fLsS --retry 2 --connect-timeout 15 --max-time 120 "$url" -o "$ROOT/$kind-resume.sh"
  bash -n "$ROOT/$kind-resume.sh"
done
# Secure seed file contains no user secrets and is removed after extraction.
# Device-only staging script has absolute destinations inside authorized Vontar.
# Normalize two legacy relative destination entries before interpreting them.
sed -i 's@../../../Projects/alphasmart/aspro-stable-pack/stable/@/home/spc/Projects/alphasmart/aspro-stable-pack/stable/@g' "$ROOT/stable/seed_assets.py"
python3 "$ROOT/stable/seed_assets.py"
rm -f "$ROOT/stable/seed_assets.py"
echo "AS2K_BEGIN"
if bash "$ROOT/as2k-resume.sh"; then AS2K_STATUS=PASS; else AS2K_STATUS=FAIL; fi
echo "ASPRO_BEGIN"
if bash "$ROOT/aspro-resume.sh"; then ASPRO_STATUS=PASS; else ASPRO_STATUS=FAIL; fi
printf 'AS2K=%s\nASPRO=%s\n' "$AS2K_STATUS" "$ASPRO_STATUS" >"$TARGET"
if [ "$AS2K_STATUS" = PASS ] && [ "$ASPRO_STATUS" = PASS ]; then
   echo "VONTAR_CONSOLIDATED_BOTH_PASS"
else
   echo "VONTAR_CONSOLIDATED_PARTIAL AS2K=$AS2K_STATUS ASPRO=$ASPRO_STATUS"
   exit 5
fi
