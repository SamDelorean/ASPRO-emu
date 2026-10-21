#!/usr/bin/env sh
# Install a previously tested ASPRO stable core and reduced GTK frontend.
# Other application names and AS2K assets are not overwritten.
set -eu
[ "$#" -eq 1 ] || { echo "Usage: install_stable.sh BUILT_ASPRO_BINARY"; exit 2; }
CORE=$1
[ -s "$CORE" ] && [ -x "$CORE" ] || { echo "Unverified ASPRO binary"; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "Root required (sudo -n)"; exit 2; }
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
install -d -m 0755 /usr/local/libexec/aspro/frontend /usr/local/bin /usr/local/share/applications
install -m 0755 "$CORE" /usr/local/libexec/aspro/aspro-bin.next
mv -f /usr/local/libexec/aspro/aspro-bin.next /usr/local/libexec/aspro/aspro-bin
install -m 0755 "$DIR/aspro_ui.py" /usr/local/libexec/aspro/frontend/aspro_ui.py
install -m 0755 "$DIR/aspro_session.py" /usr/local/libexec/aspro/frontend/aspro_session.py
cat > /usr/local/bin/aspro <<'EOF'
#!/bin/sh
exec /usr/bin/env python3 /usr/local/libexec/aspro/frontend/aspro_session.py "$@"
EOF
chmod 0755 /usr/local/bin/aspro
cat > /usr/local/share/applications/aspro.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=ASPRO Emulator
Comment=AlphaSmart Pro — stable, SCI bootstrap, PC keyboard
Exec=/usr/local/bin/aspro
Icon=input-keyboard
Terminal=false
Categories=Education;Utility;
StartupNotify=true
EOF
chmod 0644 /usr/local/share/applications/aspro.desktop
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications >/dev/null 2>&1 || :
fi
echo "ASPRO_STABLE_INSTALLED: /usr/local/bin/aspro"
