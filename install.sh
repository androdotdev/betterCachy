#!/usr/bin/env bash
# Restore this betterCachy repo into $HOME.
#
#   ./install.sh                  restore (asks for confirmation first)
#   ./install.sh --dry-run        preview what would change (no writes)
#   ./install.sh --system         also install the SDDM login theme (needs sudo)
#   ./install.sh -y               answer "yes" to every confirmation
#   ./install.sh --select         force interactive item selection
#
# Backups: every file that would be overwritten is preserved under
#   ~/.betterCachy-backup/<timestamp>/ BEFORE anything is written.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.betterCachy-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
WITH_SYSTEM=false
YES=false
INTERACTIVE=false

usage() {
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

for arg in "$@"; do
    case "$arg" in
        -n|--dry-run)  DRY_RUN=true ;;
        --system)      WITH_SYSTEM=true ;;
        -y|--yes)      YES=true ;;
        -i|--select)   INTERACTIVE=true ;;
        -h|--help)     usage 0 ;;
        *)             echo "unknown option: $arg" >&2; usage 1 ;;
    esac
done

command -v rsync >/dev/null 2>&1 || { echo "rsync is required" >&2; exit 1; }

# Top-level entries inside home/ (the candidate restore sources).
mapfile -t ITEMS < <(cd "$REPO/home" && ls -A | sort)
[[ ${#ITEMS[@]} -gt 0 ]] || { echo "no entries found under $REPO/home" >&2; exit 1; }

declare -a SRC=()    # absolute repo sources to restore
declare -a LABELS=() # labels shown to the user

# ---- decide what to restore ----
if [[ "$DRY_RUN" == true || "$YES" == true ]]; then
    SELECT_ALL=true
elif [[ "$INTERACTIVE" == true || -t 0 ]]; then
    SELECT_ALL=false
else
    SELECT_ALL=true
fi

if [[ "$SELECT_ALL" == true ]]; then
    for it in "${ITEMS[@]}"; do
        SRC+=("$REPO/home/$it")
        LABELS+=("$it")
    done
else
    # Interactive picker (only when a TTY and not forced -y).
    while :; do
        PS3="Choose a home/ item to restore (number), 'a' = all, 'done' to finish: "
        select opt in "${ITEMS[@]}" "All" "Done"; do
            case "$opt" in
                "All")
                    for it in "${ITEMS[@]}"; do
                        SRC+=("$REPO/home/$it")
                        LABELS+=("$it")
                    done
                    break 2
                    ;;
                "Done")
                    break 2
                    ;;
                "") echo "  (pick a number, or 'a' = all / 'done' to finish)";;
                *)
                    SRC+=("$REPO/home/$opt")
                    LABELS+=("$opt")
                    ;;
            esac
        done
    done
fi

# Sanity: never restore nothing.
[[ ${#SRC[@]} -gt 0 ]] || { echo "no items selected; aborting." >&2; exit 1; }

# ---- backup BEFORE anything is written ----
echo "==> Backing up existing files to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# ---- show what will be restored ----
echo "==> Restoring these items into $HOME:"
for lab in "${LABELS[@]}"; do
    echo "    - $lab"
done
if [[ "$DRY_RUN" == true ]]; then
    echo "==> (dry run - nothing written)"
    exit 0
fi

# ---- perform the restore ----
rsync -a --backup --backup-dir="$BACKUP_DIR" --human-readable \
    "${SRC[@]}" "$HOME/"

# Restore exec bit on the theming entry points.
chmod +x "$HOME/.local/bin/theme-apply" "$HOME/.local/bin/kvantum-apply" 2>/dev/null || true

if [[ "$WITH_SYSTEM" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "==> Would run: sudo $HOME/.config/sddm-matugen/install.sh"
    else
        echo "==> Installing SDDM login theme (sudo)"
        sudo "$HOME/.config/sddm-matugen/install.sh"
    fi
fi

echo "==> Done. Overwritten files backed up under $BACKUP_DIR"
echo
echo "Next steps:"
echo "  1. Install packages -> see README.md (pacman / AUR / flatpak)"
echo "  2. Generate theme  -> theme-apply /path/to/wallpaper.jpg"
echo "  3. SDDM theme (root) -> sudo ~/.config/sddm-matugen/install.sh"
echo "  4. User services -> systemctl --user enable --now quickshell.service vicinae.service swayosd.service"
echo "  5. Default shell  -> chsh -s /usr/bin/fish"
