#!/usr/bin/env bash
set -euo pipefail

SRC="$SDSM_HOME/.config/sddm-matugen/theme"
COLORS="$SDSM_HOME/.config/sddm-matugen/Colors.qml"
BG="$SDSM_HOME/.config/sddm-matugen/background"
DEST="/usr/share/sddm/themes/matugen"
CONF="/etc/sddm.conf.d/zz-matugen-theme.conf"

install -d -m 0755 "$DEST"
install -m 0644 "$SRC/Main.qml" "$SRC/InputField.qml" "$SRC/ActionButton.qml" \
                "$SRC/LinkButton.qml" "$SRC/metadata.desktop" "$SRC/theme.conf" "$DEST/"
install -m 0644 "$COLORS" "$DEST/Colors.qml"

# Fresh file sorts after kde_settings.conf so this Current= wins.
cat > "$CONF" <<'CONF_EOF'
[Theme]
Current=matugen
CONF_EOF
chmod 0644 "$CONF"

# The greeter runs as the unprivileged "sddm" user. Let it traverse the home
# directory (execute-only) and read the generated palette + wallpaper.
if id sddm >/dev/null 2>&1; then
    setfacl -m u:sddm:--x "$SDSM_HOME"
    setfacl -m u:sddm:rx  "$SDSM_HOME/.config/sddm-matugen"
    setfacl -d -m u:sddm:rX "$SDSM_HOME/.config/sddm-matugen"
    setfacl -m u:sddm:r  "$COLORS"
    runuser -u sddm -- /usr/bin/test -r "$COLORS"
fi

# Seed the login wallpaper from the current Hyprland wallpaper if missing.
if [ ! -e "$BG" ]; then
    CUR_WP=$(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' \
        "$SDSM_HOME/.config/hypr/hyprpaper.conf" | head -n1)
    if [ -n "$CUR_WP" ] && [ -r "$CUR_WP" ]; then
        install -m 0644 "$CUR_WP" "$BG"
    fi
fi
if [ -e "$BG" ] && id sddm >/dev/null 2>&1; then
    setfacl -m u:sddm:r "$BG"
    runuser -u sddm -- /usr/bin/test -r "$BG"
fi

echo
echo "OK: theme -> $DEST"
echo "OK: config -> $CONF"
echo "OK: sddm can read $COLORS"
echo "OK: sddm background -> $BG"
ls -la "$DEST"
