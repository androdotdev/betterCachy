#!/usr/bin/env bash
# Restore this betterCachy repo into $HOME.
#
#   ./install.sh              copy home/ -> $HOME (existing files backed up)
#   ./install.sh --dry-run    show what would change
#   ./install.sh --system     also install the SDDM theme (uses sudo)
#
# Existing files that would be overwritten are preserved under
# ~/.betterCachy-backup/<timestamp>/ with the same relative paths.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.betterCachy-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
WITH_SYSTEM=false

usage() {
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        --system)     WITH_SYSTEM=true ;;
        -h|--help)    usage 0 ;;
        *)            echo "unknown option: $arg" >&2; usage 1 ;;
    esac
done

command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }

RSYNC=(rsync -a --backup --backup-dir="$BACKUP_DIR" --human-readable)
$DRY_RUN && RSYNC+=(--dry-run --itemize-changes)

echo "==> Restoring $REPO/home -> $HOME"
$DRY_RUN || mkdir -p "$BACKUP_DIR"
"${RSYNC[@]}" "$REPO/home/" "$HOME/"

if ! $DRY_RUN; then
    chmod +x "$HOME/.local/bin/theme-apply" "$HOME/.local/bin/kvantum-apply" 2>/dev/null || true
    echo "==> Existing files (if any) backed up under $BACKUP_DIR"
fi

if $WITH_SYSTEM; then
    if $DRY_RUN; then
        echo "==> Would run: sudo $HOME/.config/sddm-matugen/install.sh"
    else
        echo "==> Installing SDDM theme (sudo)"
        sudo "$HOME/.config/sddm-matugen/install.sh"
    fi
fi

cat <<'EOF'

Next steps:
  1. Install packages     -> see README.md (pacman / AUR / flatpak)
  2. Generate theme       -> theme-apply /path/to/wallpaper.jpg
  3. SDDM theme (root)    -> sudo ~/.config/sddm-matugen/install.sh
  4. User services        -> systemctl --user enable --now \
                               quickshell.service vicinae.service swayosd.service
  5. Default shell        -> chsh -s /usr/bin/fish
EOF
