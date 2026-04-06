#!/bin/bash
################################################################################
# update-models.sh — Update all installed Ollama models to latest
#
# Pulls every model currently in `ollama list`, then prints a summary of what
# was updated vs already current.
#
# Usage:
#   ./update-models.sh                  # interactive update
#   ./update-models.sh --dry-run        # show what would run, no changes
#   ./update-models.sh --auto           # non-interactive (cron / systemd)
#   ./update-models.sh --install-timer  # install a weekly systemd timer
#   ./update-models.sh --remove-timer   # remove the systemd timer
################################################################################

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓ $*${NC}"; }
err()  { echo -e "${RED}✗ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
info() { echo -e "${BLUE}ℹ $*${NC}"; }
step() { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }
hr()   { echo -e "${BLUE}────────────────────────────────────────────────────${NC}"; }

# ── Argument parsing ───────────────────────────────────────────────────────────
DRY_RUN=false
AUTO=false
INSTALL_TIMER=false
REMOVE_TIMER=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)        DRY_RUN=true ;;
        --auto)           AUTO=true ;;
        --install-timer)  INSTALL_TIMER=true ;;
        --remove-timer)   REMOVE_TIMER=true ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--auto] [--install-timer] [--remove-timer]"
            echo
            echo "  (no flags)        Update all installed Ollama models"
            echo "  --dry-run         Show models that would be updated, make no changes"
            echo "  --auto            Non-interactive mode for cron or systemd timers"
            echo "  --install-timer   Install a weekly systemd timer for automatic updates"
            echo "  --remove-timer    Remove the systemd timer"
            exit 0 ;;
        *) err "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Systemd timer management ───────────────────────────────────────────────────
TIMER_NAME="ollama-model-update"
SCRIPT_PATH="$(realpath "$0")"

install_timer() {
    step "Installing weekly systemd timer"

    # Prefer system timer if running as root or sudo available; else user timer
    if [ "$EUID" -eq 0 ]; then
        UNIT_DIR="/etc/systemd/system"
        SYSTEMCTL="systemctl"
    else
        UNIT_DIR="${HOME}/.config/systemd/user"
        SYSTEMCTL="systemctl --user"
        mkdir -p "$UNIT_DIR"
    fi

    SERVICE_FILE="${UNIT_DIR}/${TIMER_NAME}.service"
    TIMER_FILE="${UNIT_DIR}/${TIMER_NAME}.timer"

    info "Writing service unit..."
    if [ "$EUID" -eq 0 ]; then
        tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Update all installed Ollama models to latest
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} --auto
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${TIMER_NAME}
EOF
    else
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Update all installed Ollama models to latest
After=network.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} --auto
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${TIMER_NAME}
EOF
    fi

    info "Writing timer unit (runs weekly, Sunday 03:00)..."
    if [ "$EUID" -eq 0 ]; then
        tee "$TIMER_FILE" > /dev/null <<EOF
[Unit]
Description=Weekly Ollama model update

[Timer]
OnCalendar=Sun *-*-* 03:00:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
EOF
    else
        cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Weekly Ollama model update

[Timer]
OnCalendar=Sun *-*-* 03:00:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
EOF
    fi

    if [ "$EUID" -eq 0 ]; then
        systemctl daemon-reload
        systemctl enable --now "${TIMER_NAME}.timer"
    else
        systemctl --user daemon-reload
        systemctl --user enable --now "${TIMER_NAME}.timer"
    fi

    ok "Timer installed and enabled"
    echo
    info "Next scheduled run:"
    ${SYSTEMCTL} list-timers "${TIMER_NAME}.timer" --no-pager 2>/dev/null || true
    echo
    info "To run manually: ${SYSTEMCTL} start ${TIMER_NAME}.service"
    info "To check logs:   journalctl $([ "$EUID" -ne 0 ] && echo "--user") -u ${TIMER_NAME}.service"
    exit 0
}

remove_timer() {
    step "Removing systemd timer"

    for scope in "" "--user"; do
        if systemctl $scope list-unit-files "${TIMER_NAME}.timer" &>/dev/null 2>&1 | grep -q "$TIMER_NAME"; then
            systemctl $scope stop "${TIMER_NAME}.timer"   2>/dev/null || true
            systemctl $scope disable "${TIMER_NAME}.timer" 2>/dev/null || true
        fi
    done

    for dir in "/etc/systemd/system" "${HOME}/.config/systemd/user"; do
        rm -f "${dir}/${TIMER_NAME}.service" "${dir}/${TIMER_NAME}.timer" 2>/dev/null || true
    done

    systemctl daemon-reload 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true

    ok "Timer removed"
    exit 0
}

[ "$INSTALL_TIMER" = true ] && install_timer
[ "$REMOVE_TIMER"  = true ] && remove_timer

# ── Pre-flight ─────────────────────────────────────────────────────────────────
hr
if [ "$DRY_RUN" = true ]; then
    echo -e "${BOLD}  Ollama Model Updater${NC}  ${YELLOW}(dry run — no changes will be made)${NC}"
else
    echo -e "${BOLD}  Ollama Model Updater${NC}"
fi
hr

# Check Ollama is installed
if ! command -v ollama &>/dev/null; then
    err "Ollama is not installed or not in PATH."
    info "Install it from https://ollama.com or run: curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
fi

# Check Ollama is reachable
step "Checking Ollama service"
if ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
    warn "Ollama is not responding on :11434. Attempting to start..."
    if command -v systemctl &>/dev/null && systemctl is-enabled ollama &>/dev/null 2>&1; then
        sudo systemctl start ollama 2>/dev/null || true
    else
        nohup ollama serve >/tmp/ollama-update.log 2>&1 &
    fi
    # Wait up to 15 seconds
    for i in $(seq 1 15); do
        sleep 1
        if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
            ok "Ollama started"
            break
        fi
        [ "$i" -eq 15 ] && { err "Ollama did not start. Cannot update models."; exit 1; }
    done
else
    ok "Ollama is running"
fi

# ── Get installed models ───────────────────────────────────────────────────────
step "Reading installed models"

# ollama list output (skip header line):
#   NAME                   ID              SIZE      MODIFIED
#   llama3.2:latest        a80c4f17acd5    2.0 GB    2 weeks ago
MODELS_RAW=$(ollama list 2>/dev/null | tail -n +2)

if [ -z "$MODELS_RAW" ]; then
    warn "No models installed."
    info "Pull a model first:  ollama pull llama3.2"
    exit 0
fi

# Extract name:tag and ID into parallel arrays
MODEL_NAMES=()
MODEL_IDS=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    name=$(echo "$line" | awk '{print $1}')
    id=$(echo "$line"   | awk '{print $2}')
    MODEL_NAMES+=("$name")
    MODEL_IDS+=("$id")
done <<< "$MODELS_RAW"

COUNT=${#MODEL_NAMES[@]}
info "Found $COUNT installed model(s):"
for name in "${MODEL_NAMES[@]}"; do
    echo "    • $name"
done

if [ "$DRY_RUN" = false ] && [ "$AUTO" = false ]; then
    echo
    read -r -p "Update all $COUNT model(s)? [Y/n] " CONFIRM
    CONFIRM="${CONFIRM:-Y}"
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        info "Aborted."
        exit 0
    fi
fi

# ── Update each model ──────────────────────────────────────────────────────────
step "Updating models"

UPDATED=()
CURRENT=()
FAILED=()

for i in "${!MODEL_NAMES[@]}"; do
    name="${MODEL_NAMES[$i]}"
    old_id="${MODEL_IDS[$i]}"

    echo
    echo -e "${BOLD}[$((i+1))/$COUNT] $name${NC}"

    if [ "$DRY_RUN" = true ]; then
        info "(dry run) would run: ollama pull $name"
        continue
    fi

    # Capture pull output to detect whether anything actually downloaded
    PULL_OUTPUT=$(ollama pull "$name" 2>&1) || {
        err "Failed to pull $name"
        echo "$PULL_OUTPUT" | tail -5 | sed 's/^/    /'
        FAILED+=("$name")
        continue
    }

    # Get the new ID after pulling
    new_id=$(ollama list 2>/dev/null | awk -v m="$name" '$1 == m {print $2}')

    if [ "$new_id" != "$old_id" ]; then
        ok "Updated  $name  ($old_id → $new_id)"
        UPDATED+=("$name")
    else
        ok "Already current  $name  ($old_id)"
        CURRENT+=("$name")
    fi
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo
hr
echo -e "${BOLD}  Summary${NC}"
hr

if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}Dry run complete — no models were changed.${NC}"
    echo -e "  Run without --dry-run to apply updates."
else
    echo -e "  Updated:        ${GREEN}${#UPDATED[@]}${NC}"
    echo -e "  Already latest: ${CYAN}${#CURRENT[@]}${NC}"
    echo -e "  Failed:         ${RED}${#FAILED[@]}${NC}"

    if [ ${#UPDATED[@]} -gt 0 ]; then
        echo
        echo -e "  ${GREEN}Updated:${NC}"
        for m in "${UPDATED[@]}"; do echo "    • $m"; done
    fi

    if [ ${#FAILED[@]} -gt 0 ]; then
        echo
        echo -e "  ${RED}Failed:${NC}"
        for m in "${FAILED[@]}"; do echo "    • $m"; done
        echo
        warn "Some models failed to update. Check your network connection and try again."
    fi
fi

echo
info "Installed models after update:"
ollama list
echo
hr

[ ${#FAILED[@]} -gt 0 ] && exit 1
exit 0
