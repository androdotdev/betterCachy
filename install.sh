#!/usr/bin/env bash
# Restore this betterCachy repo into $HOME.
#
#   ./install.sh                  select items, preview, then confirm
#   ./install.sh --dry-run        preview all changes (no writes)
#   ./install.sh --system         also install the SDDM login theme (needs sudo)
#   ./install.sh -y               restore everything without prompting
#   ./install.sh --select         force interactive item selection
#
# Existing files are backed up under:
#   ~/.betterCachy-backup/<timestamp>/
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
        -n|--dry-run) DRY_RUN=true ;;
        --system)     WITH_SYSTEM=true ;;
        -y|--yes)     YES=true ;;
        -i|--select)  INTERACTIVE=true ;;
        -h|--help)    usage 0 ;;
        *)
            echo "Unknown option: $arg" >&2
            usage 1
            ;;
    esac
done

command -v rsync >/dev/null 2>&1 || {
    echo "Error: rsync is required." >&2
    exit 1
}

[[ -d "$REPO/home" ]] || {
    echo "Error: $REPO/home does not exist." >&2
    exit 1
}

mapfile -t ITEMS < <(cd "$REPO/home" && ls -A | sort)

((${#ITEMS[@]} > 0)) || {
    echo "Error: no entries found under $REPO/home." >&2
    exit 1
}

declare -a SRC=()
declare -a LABELS=()

if [[ "$DRY_RUN" == true || "$YES" == true ]]; then
    for item in "${ITEMS[@]}"; do
        SRC+=("$REPO/home/$item")
        LABELS+=("$item")
    done
elif [[ "$INTERACTIVE" == true || -t 0 ]]; then
    while :; do
        PS3="Select an item, 'a' for all, or 'd' when done: "
        select opt in "${ITEMS[@]}" "All" "Done"; do
            case "${REPLY,,}" in
                a|all) opt="All" ;;
                d|done) opt="Done" ;;
            esac

            case "$opt" in
                "All")
                    for item in "${ITEMS[@]}"; do
                        SRC+=("$REPO/home/$item")
                        LABELS+=("$item")
                    done
                    break 2
                    ;;
                "Done")
                    break 2
                    ;;
                "")
                    echo "Choose a listed number, 'a' for all, or 'd' to finish."
                    ;;
                *)
                    SRC+=("$REPO/home/$opt")
                    LABELS+=("$opt")
                    break
                    ;;
            esac
        done
    done
else
    echo "Error: run this in a terminal, or use -y to restore everything." >&2
    exit 1
fi

((${#SRC[@]} > 0)) || {
    echo "No items selected; nothing to do."
    exit 0
}

echo "Selected ${#SRC[@]} item(s):"
printf '  - %s\n' "${LABELS[@]}"

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo "Preview of file changes in $HOME:"
    rsync -a --dry-run --itemize-changes "${SRC[@]}" "$HOME/"

    if [[ "$WITH_SYSTEM" == true ]]; then
        echo
        echo "Would also run the SDDM installer with sudo."
    fi

    echo
    echo "Dry run complete; nothing was changed."
    exit 0
fi

if [[ "$YES" != true ]]; then
    echo
    echo "Existing files will be backed up under:"
    echo "  $BACKUP_DIR"

    read -r -p "Continue with restore? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || {
        echo "Cancelled; nothing was changed."
        exit 0
    }
fi

mkdir -p "$BACKUP_DIR"
rsync -a --backup --backup-dir="$BACKUP_DIR" --human-readable \
    "${SRC[@]}" "$HOME/"

# Restore executable bits on the theming entry points, if present.
for script in "$HOME/.local/bin/theme-apply" "$HOME/.local/bin/kvantum-apply"; do
    [[ ! -f "$script" ]] || chmod +x "$script"
done

if [[ "$WITH_SYSTEM" == true ]]; then
    SDDM_INSTALLER="$HOME/.config/sddm-matugen/install.sh"

    if [[ -x "$SDDM_INSTALLER" ]]; then
        echo "Installing SDDM login theme (sudo)..."
        sudo "$SDDM_INSTALLER"
    else
        echo "Warning: SDDM installer not found or not executable:"
        echo "  $SDDM_INSTALLER"
    fi
fi

echo "Restore complete. Backup: $BACKUP_DIR"
echo "Next: install packages from README.md, then run theme-apply with a wallpaper."

