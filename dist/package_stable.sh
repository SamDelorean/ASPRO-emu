#!/bin/sh
# Package the INSTALLED ASPRO Stable (AP-10) core + GTK frontend for
# redistribution and upload it to Drive. Runs once per machine, no polling.
# Never packages ROMs, payloads, NVRAM or logs.
#   Vontar (Armbian aarch64)       -> aspro-stable-<VER>-linux-aarch64-glibc
#   Surf   (postmarketOS ARMv7)    -> aspro-stable-<VER>-linux-armv7-musl
set -eu
umask 022
VER=v0.1.1
SRC_REF=c3b1b2bd42788265b44b1a0bbdcc086e22ee3b1c
LIB=/usr/local/libexec/aspro
DRIVE="googledrive:ASPRO_TEMP/dist/$VER"
WORK="${TMPDIR:-/tmp}/aspro-dist.$$"
STATUS="$HOME/.local/share/alphasmart/private/aspro/logs/dist-$VER.status"
mkdir -p "$(dirname "$STATUS")"
fail() { echo "FAIL $*" | tee "$STATUS"; exit 1; }

case "$(uname -m)" in
  aarch64) PLAT=linux-aarch64-glibc; EXPECT=0f801f002175711bb5e6f733d798f2186cdc86cfbf0bda2987793a824c7773de ;;
  armv7l)  PLAT=linux-armv7-musl;    EXPECT=28e13681c57ed1f9e09735f101077aca302b836d82193fc0721dc0ac5c2cfc9b ;;
  *) fail "unsupported arch $(uname -m)" ;;
esac

CORE="$LIB/aspro-bin"
[ -x "$CORE" ] || fail "core missing $CORE"
GOT=$(sha256sum "$CORE" | cut -d' ' -f1)
[ "$GOT" = "$EXPECT" ] || fail "core sha $GOT != manifest $EXPECT"

blob() { python3 -c 'import hashlib,sys;d=open(sys.argv[1],"rb").read();print(hashlib.sha1(b"blob %d\0"%len(d)+d).hexdigest())' "$1"; }
[ "$(blob "$LIB/frontend/aspro_ui.py")" = 64c411a616224d53754e92eef077eaa9a94bf9aa ] || fail "aspro_ui.py blob mismatch"
[ "$(blob "$LIB/frontend/aspro_session.py")" = 873f6263708b58025526bb9d056773b7b3272d40 ] || fail "aspro_session.py blob mismatch"

# GPL-2.0 text from the MAME tree the core was built from.
COPYING=""
for t in "$HOME/projects/mame-as2k-stable-arm64" "$HOME/Projects/alphasmart/as2k-surf-native/sources/mame-as3k"; do
  [ -f "$t/COPYING" ] && COPYING="$t/COPYING" && break
done
[ -n "$COPYING" ] || fail "MAME COPYING not found"

NAME="aspro-stable-$VER-$PLAT"
P="$WORK/$NAME"
mkdir -p "$P/bin"
cp "$CORE" "$P/bin/aspro-bin"
cp "$LIB/frontend/aspro_ui.py" "$LIB/frontend/aspro_session.py" "$P/"
cp "$COPYING" "$P/COPYING"
cat > "$P/install_stable.sh" <<'EOF'
#!/usr/bin/env sh
# Usage: sudo ./install_stable.sh bin/aspro-bin
set -eu
[ "$#" -eq 1 ] || { echo "Usage: install_stable.sh BUILT_ASPRO_BINARY"; exit 2; }
CORE=$1
[ -s "$CORE" ] && [ -x "$CORE" ] || { echo "Unverified ASPRO binary"; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "Root required"; exit 2; }
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
install -d -m 0755 /usr/local/libexec/aspro /usr/local/libexec/aspro/frontend /usr/local/bin /usr/local/share/applications
install -m 0755 "$CORE" /usr/local/libexec/aspro/aspro-bin
install -m 0755 "$DIR/aspro_ui.py" /usr/local/libexec/aspro/frontend/aspro_ui.py
install -m 0755 "$DIR/aspro_session.py" /usr/local/libexec/aspro/frontend/aspro_session.py
printf '#!/bin/sh\nexec /usr/bin/env python3 /usr/local/libexec/aspro/frontend/aspro_session.py "$@"\n' > /usr/local/bin/aspro
chmod 0755 /usr/local/bin/aspro
cat > /usr/local/share/applications/aspro.desktop <<'EOD'
[Desktop Entry]
Type=Application
Name=ASPRO Emulator
Comment=AlphaSmart Pro emulator
Exec=/usr/local/bin/aspro
Icon=input-keyboard
Terminal=false
Categories=Education;Utility;
EOD
echo "ASPRO_STABLE_INSTALLED: /usr/local/bin/aspro"
EOF
chmod 0755 "$P/install_stable.sh"
{
  echo "ASPRO Stable $VER ($PLAT)"
  echo "Source: https://github.com/SamDelorean/ASPRO-emu (stable/ at $SRC_REF)"
  echo "Built on: $(uname -srm); $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
  echo "Core SHA-256: $GOT"
  echo "Shared libraries:"; (ldd "$CORE" 2>&1 || :) | sed 's/^/  /'
} > "$P/BUILD_INFO.txt"
(cd "$P" && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS)
(cd "$WORK" && tar -czf "$NAME.tar.gz" "$NAME" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
rclone copyto "$WORK/$NAME.tar.gz" "$DRIVE/$NAME.tar.gz" --retries 2 --timeout 180s || fail "rclone tar"
rclone copyto "$WORK/$NAME.tar.gz.sha256" "$DRIVE/$NAME.tar.gz.sha256" --retries 2 || fail "rclone sha"
echo "PASS $NAME $(cut -d' ' -f1 "$WORK/$NAME.tar.gz.sha256")" | tee "$STATUS"
rclone copyto "$STATUS" "$DRIVE/$NAME.status" --retries 2 || :
rm -rf "$WORK"
