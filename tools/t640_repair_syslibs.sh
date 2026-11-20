#!/usr/bin/env bash
# T640 unattended system repair (authorized by user 2026-11-20).
# Reinstalls every Debian/Ubuntu package whose installed files fail the dpkg
# MD5 check (non-conffiles), after finishing any interrupted upgrade.
# No reboot, no dist-upgrade, no file deletion outside apt's own cache.
# Avoids coreutils where possible (rust-coreutils itself is damaged).
set -u
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
TS=$(printf '%(%Y%m%dT%H%M%S)T' -1)
OUT="$HOME/Projects/alphasmart/t640-repair-$TS"
DRIVE="googledrive:ASPRO_TEMP/t640_repair/$TS"
mkdir -p "$OUT" 2>/dev/null || { OUT="/tmp/t640-repair-$TS"; mkdir -p "$OUT"; }
R="$OUT/report.txt"
exec >>"$R" 2>&1
APT=(sudo -n apt-get -y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)
step() { printf '\n===== %s  %(%F %T)T\n' "$1" -1; }
upload() { rclone copy "$OUT" "$DRIVE" --retries 3 --timeout 180s >/dev/null 2>&1 || :; }
trap upload EXIT

step PREFLIGHT
uname -a; sudo -n true && echo "sudo OK" || { echo "BLOCKED sudo -n unavailable"; exit 3; }

step DISK_HEALTH
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINT 2>&1
for d in /dev/nvme0n1 /dev/sda /dev/mmcblk0; do
  [ -e "$d" ] && { echo "--- $d"; sudo -n smartctl -H -A "$d" 2>&1 || echo "smartctl unavailable/failed for $d"; }
done
echo "--- kernel storage/filesystem errors this boot"
sudo -n journalctl -k -b --no-pager 2>/dev/null | grep -iE 'I/O error|EXT4-fs (error|warning)|btrfs.*(error|corrupt)|nvme.*(error|timeout)|ata[0-9].*(error|failed)|mmc.*error|Buffer I/O' | awk 'NR<=60'

step FINISH_INTERRUPTED_UPGRADE
sudo -n dpkg --configure -a; echo "rc=$?"
"${APT[@]}" -f install; echo "rc=$?"
sudo -n dpkg --audit; echo "audit rc=$?"

step APT_REFRESH
sudo -n apt-get clean; "${APT[@]}" update; echo "rc=$?"

verify_list() {  # writes damaged non-conffile paths to $1, packages to $2
  sudo -n dpkg --verify 2>/dev/null | awk '$1 ~ /^..5/ && $2 != "c" {print $NF}' > "$1"
  : > "$2"
  if [ -s "$1" ]; then
    xargs -a "$1" -d '\n' dpkg -S 2>/dev/null | awk -F': ' '/^diversion/{next} {n=split($1,a,", "); for(i=1;i<=n;i++){sub(/:.*/,"",a[i]); if(!s[a[i]]++) print a[i]}}' > "$2"
  fi
  echo "damaged files: $(awk 'END{print NR}' "$1")  packages: $(awk 'END{print NR}' "$2")"
}

step VERIFY_BEFORE
verify_list "$OUT/damaged_files_before.txt" "$OUT/damaged_pkgs_before.txt"
cat "$OUT/damaged_pkgs_before.txt"

step REINSTALL_CORE_FIRST
for p in rust-coreutils coreutils libc6 libc-bin dpkg; do
  if grep -qx "$p" "$OUT/damaged_pkgs_before.txt"; then echo "--- reinstall $p"; "${APT[@]}" install --reinstall "$p"; echo "rc=$?"; fi
done

step REINSTALL_REST
mapfile -t PK < <(grep -vxE 'rust-coreutils|coreutils|libc6|libc-bin|dpkg' "$OUT/damaged_pkgs_before.txt")
if [ "${#PK[@]}" -gt 0 ]; then
  "${APT[@]}" install --reinstall "${PK[@]}"; rc=$?; echo "batch rc=$rc"
  if [ "$rc" -ne 0 ]; then  # retry one by one so one unavailable package does not block the rest
    for p in "${PK[@]}"; do "${APT[@]}" install --reinstall "$p" >/dev/null 2>&1 && echo "OK $p" || echo "FAILED $p"; done
  fi
fi

step VERIFY_AFTER
verify_list "$OUT/damaged_files_after.txt" "$OUT/damaged_pkgs_after.txt"
cat "$OUT/damaged_pkgs_after.txt"

step SMOKE
ls / >/dev/null 2>&1 && echo "ls OK" || echo "ls FAIL rc=$?"
printf 'a\nb\n' | tail -n1 >/dev/null 2>&1 && echo "tail OK" || echo "tail FAIL rc=$?"
python3 -c 'import ctypes;ctypes.CDLL("libudev.so.1");ctypes.CDLL("libsystemd.so.0");print("libudev/libsystemd load OK")' 2>&1
B="$HOME/Projects/alphasmart/aspro-release-v0.1.1/aspro-linux-x86_64"
[ -x "$B" ] && { SDL_VIDEODRIVER=dummy timeout 30 "$B" asmapro -rompath /nonexistent -sound none -video none -seconds_to_run 1 -skip_gameinfo >/dev/null 2>"$OUT/aspro_norom.err"; echo "aspro start rc=$? (rc 2 = ROM missing is the expected result)"; }

step RESULT
if [ ! -s "$OUT/damaged_pkgs_after.txt" ]; then echo "RESULT=PASS system packages verify clean"; else echo "RESULT=PARTIAL remaining damaged packages listed above"; fi
