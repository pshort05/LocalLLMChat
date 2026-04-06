#!/bin/bash
################################################################################
# LocalLLMChat Service Installer for Linux
#
# Installs LocalLLMChat and Ollama as persistent background services that
# start automatically at boot. Supports both system-wide (server) and
# per-user (workstation) service modes.
#
# Usage:
#   ./install-service-linux.sh               # system service (default, needs sudo)
#   ./install-service-linux.sh --user        # user service (no sudo required)
#   ./install-service-linux.sh --uninstall   # remove services and files
#
# System service installs to: /opt/local-llm-chat
# User service installs to:   ~/.local/share/local-llm-chat
################################################################################

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
APP_NAME="local-llm-chat"
SERVICE_NAME="local-llm-chat"
OLLAMA_INSTALL_URL="https://ollama.com/install.sh"
DEFAULT_PORT=5000

SYSTEM_INSTALL_DIR="/opt/local-llm-chat"
SYSTEM_SERVICE_USER="local-llm-chat"
SYSTEM_UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

USER_INSTALL_DIR="${HOME}/.local/share/local-llm-chat"
USER_UNIT_DIR="${HOME}/.config/systemd/user"
USER_UNIT_FILE="${USER_UNIT_DIR}/${SERVICE_NAME}.service"

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

# Detect the primary local network IP (the one used to reach the internet)
get_local_ip() {
    local ip
    # Try ip route first (most reliable on modern Linux)
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7; exit}')
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return
    fi
    # Fallback: hostname -I (first non-loopback address)
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return
    fi
    echo "YOUR_SERVER_IP"
}

# Open a TCP port in the active firewall (ufw / firewalld / iptables)
open_firewall_port() {
    local port="$1"
    local desc="${2:-port $port}"

    # ── ufw ───────────────────────────────────────────────────────────────────
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        info "Opening $desc in ufw..."
        if sudo ufw allow "${port}/tcp" comment "LocalLLMChat" 2>/dev/null; then
            ok "ufw: port $port open"
        else
            warn "ufw rule may already exist for port $port"
        fi
        return
    fi

    # ── firewalld ─────────────────────────────────────────────────────────────
    if command -v firewall-cmd &>/dev/null && firewall-cmd --state 2>/dev/null | grep -q "running"; then
        info "Opening $desc in firewalld..."
        sudo firewall-cmd --permanent --add-port="${port}/tcp" 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        ok "firewalld: port $port open (permanent)"
        return
    fi

    # ── iptables fallback ─────────────────────────────────────────────────────
    if command -v iptables &>/dev/null; then
        # Only add if the rule doesn't already exist
        if ! sudo iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            info "Opening $desc in iptables..."
            sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            # Persist if iptables-save is available
            if command -v iptables-save &>/dev/null && [ -d /etc/iptables ]; then
                sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null 2>&1 || true
            fi
            ok "iptables: port $port open"
        else
            ok "iptables: port $port already open"
        fi
        return
    fi

    warn "No recognised firewall found. If connections from other machines fail, open port $port manually."
}

# Remove a firewall rule added by open_firewall_port
close_firewall_port() {
    local port="$1"

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        sudo ufw delete allow "${port}/tcp" 2>/dev/null || true
        ok "ufw: rule for port $port removed"
        return
    fi

    if command -v firewall-cmd &>/dev/null && firewall-cmd --state 2>/dev/null | grep -q "running"; then
        sudo firewall-cmd --permanent --remove-port="${port}/tcp" 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        ok "firewalld: rule for port $port removed"
        return
    fi

    if command -v iptables &>/dev/null; then
        sudo iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
        ok "iptables: rule for port $port removed"
    fi
}

# ── Argument parsing ───────────────────────────────────────────────────────────
INSTALL_MODE="system"   # system | user
UNINSTALL=false

for arg in "$@"; do
    case "$arg" in
        --user)        INSTALL_MODE="user" ;;
        --uninstall)   UNINSTALL=true ;;
        --help|-h)
            echo "Usage: $0 [--user] [--uninstall]"
            echo "  (no flags)    System-wide service install (requires sudo)"
            echo "  --user        Per-user service install (no sudo needed for app)"
            echo "  --uninstall   Remove services and installed files"
            exit 0 ;;
        *) err "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Uninstall ──────────────────────────────────────────────────────────────────
if [ "$UNINSTALL" = true ]; then
    step "Uninstalling LocalLLMChat service"

    # System service
    if [ -f "$SYSTEM_UNIT_FILE" ]; then
        info "Stopping and removing system service..."
        sudo systemctl stop "$SERVICE_NAME"  2>/dev/null || true
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        sudo rm -f "$SYSTEM_UNIT_FILE"
        sudo systemctl daemon-reload
        ok "System service removed"
    fi

    # User service
    if [ -f "$USER_UNIT_FILE" ]; then
        info "Stopping and removing user service..."
        systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "$USER_UNIT_FILE"
        systemctl --user daemon-reload
        ok "User service removed"
    fi

    # Files
    if [ -d "$SYSTEM_INSTALL_DIR" ]; then
        warn "Remove installed files at $SYSTEM_INSTALL_DIR? (y/n) \c"
        read -r -n 1; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo rm -rf "$SYSTEM_INSTALL_DIR"
            ok "Removed $SYSTEM_INSTALL_DIR"
        fi
    fi

    if [ -d "$USER_INSTALL_DIR" ]; then
        warn "Remove installed files at $USER_INSTALL_DIR? (y/n) \c"
        read -r -n 1; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$USER_INSTALL_DIR"
            ok "Removed $USER_INSTALL_DIR"
        fi
    fi

    # Service user
    if id "$SYSTEM_SERVICE_USER" &>/dev/null; then
        warn "Remove service user '$SYSTEM_SERVICE_USER'? (y/n) \c"
        read -r -n 1; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo userdel "$SYSTEM_SERVICE_USER" 2>/dev/null || true
            ok "Removed user '$SYSTEM_SERVICE_USER'"
        fi
    fi

    # Firewall rules
    warn "Remove firewall rule for port ${DEFAULT_PORT}? (y/n) \c"
    read -r -n 1; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        close_firewall_port "$DEFAULT_PORT"
    fi

    ok "Uninstall complete"
    exit 0
fi

# ── Pre-flight checks ──────────────────────────────────────────────────────────
hr
echo -e "${BOLD}  LocalLLMChat — Linux Service Installer${NC}"
echo -e "  Mode: ${CYAN}$([ "$INSTALL_MODE" = "system" ] && echo "System service (starts at boot for all users)" || echo "User service (starts at login for current user)")${NC}"
hr

# Must not be run as root directly (we'll use sudo where needed)
if [ "$EUID" -eq 0 ] && [ "$INSTALL_MODE" = "user" ]; then
    err "Do not run as root when using --user mode."
    exit 1
fi

# Check systemd is available
if ! command -v systemctl &>/dev/null; then
    err "systemd is not available on this system."
    info "This installer requires systemd. For other init systems, run:"
    echo "  local-llm-chat --host 0.0.0.0 --port $DEFAULT_PORT --foreground"
    exit 1
fi

# Check we're in the LocalLLMChat source directory
if [ ! -f "pyproject.toml" ] || ! grep -q "local-llm-chat" pyproject.toml; then
    err "Run this script from the LocalLLMChat source directory."
    exit 1
fi

SOURCE_DIR="$(pwd)"

# ── Python check ───────────────────────────────────────────────────────────────
step "Checking Python"

PYTHON=""
for cmd in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do
    if command -v "$cmd" &>/dev/null; then
        VER=$("$cmd" --version 2>&1 | awk '{print $2}')
        MAJOR=$(echo "$VER" | cut -d. -f1)
        MINOR=$(echo "$VER" | cut -d. -f2)
        if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 8 ]; then
            PYTHON="$cmd"
            ok "Found $cmd ($VER)"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    err "Python 3.8+ is required but was not found."
    info "Install it with:"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-venv python3-pip"
    echo "  Fedora:        sudo dnf install python3"
    echo "  Arch:          sudo pacman -S python"
    exit 1
fi

# Check venv module
if ! "$PYTHON" -m venv --help &>/dev/null; then
    err "Python venv module not found."
    info "Install it with:"
    echo "  Ubuntu/Debian: sudo apt install python3-venv"
    exit 1
fi

# ── Ollama ─────────────────────────────────────────────────────────────────────
step "Checking Ollama"

if command -v ollama &>/dev/null; then
    OLLAMA_VER=$(ollama --version 2>&1 | head -n1)
    ok "Ollama already installed: $OLLAMA_VER"
else
    warn "Ollama is not installed."
    info "Downloading and installing the latest Ollama release..."
    echo
    curl -fsSL "$OLLAMA_INSTALL_URL" | sh
    echo
    if command -v ollama &>/dev/null; then
        ok "Ollama installed: $(ollama --version 2>&1 | head -n1)"
    else
        err "Ollama installation failed. Check the output above."
        exit 1
    fi
fi

# Ensure Ollama service is enabled and running
step "Ensuring Ollama service is running"

if systemctl is-active --quiet ollama 2>/dev/null; then
    ok "Ollama service is already running"
elif systemctl list-unit-files ollama.service &>/dev/null 2>&1 | grep -q ollama; then
    info "Enabling and starting Ollama service..."
    sudo systemctl enable ollama
    sudo systemctl start ollama
    sleep 2
    if systemctl is-active --quiet ollama; then
        ok "Ollama service started"
    else
        warn "Ollama service may not have started. Check: sudo journalctl -u ollama"
    fi
else
    # Ollama installed but no systemd unit (e.g. manual install without service)
    warn "No Ollama systemd unit found — starting ollama serve in background"
    nohup ollama serve >/tmp/ollama.log 2>&1 &
    sleep 2
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        ok "Ollama is responding on port 11434"
    else
        warn "Ollama may still be starting. Check: curl http://localhost:11434/api/tags"
    fi
fi

# ── Install LocalLLMChat ───────────────────────────────────────────────────────
if [ "$INSTALL_MODE" = "system" ]; then
    INSTALL_DIR="$SYSTEM_INSTALL_DIR"
else
    INSTALL_DIR="$USER_INSTALL_DIR"
fi

VENV_DIR="$INSTALL_DIR/venv"
EXECUTABLE="$VENV_DIR/bin/local-llm-chat"

step "Installing LocalLLMChat to $INSTALL_DIR"

if [ "$INSTALL_MODE" = "system" ]; then
    # Create install directory owned by root, writable during install
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$USER":"$USER" "$INSTALL_DIR"
else
    mkdir -p "$INSTALL_DIR"
fi

# Create/refresh virtualenv
info "Creating virtual environment at $VENV_DIR..."
"$PYTHON" -m venv "$VENV_DIR"
ok "Virtual environment ready"

# Install the package
info "Installing LocalLLMChat package..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet "$SOURCE_DIR"
ok "LocalLLMChat installed"

# Verify executable
if [ ! -f "$EXECUTABLE" ]; then
    err "Executable not found at $EXECUTABLE after install."
    exit 1
fi

# ── Create systemd service ─────────────────────────────────────────────────────
step "Creating systemd service"

if [ "$INSTALL_MODE" = "system" ]; then

    # Create a dedicated service user if it doesn't exist
    if ! id "$SYSTEM_SERVICE_USER" &>/dev/null; then
        info "Creating service user '$SYSTEM_SERVICE_USER'..."
        sudo useradd \
            --system \
            --no-create-home \
            --shell /usr/sbin/nologin \
            --comment "LocalLLMChat service account" \
            "$SYSTEM_SERVICE_USER"
        ok "Service user created"
    else
        ok "Service user '$SYSTEM_SERVICE_USER' already exists"
    fi

    # Hand ownership of the install dir to the service user
    sudo chown -R "$SYSTEM_SERVICE_USER":"$SYSTEM_SERVICE_USER" "$INSTALL_DIR"

    # Conversation storage dir for the service user
    STORAGE_DIR="/var/lib/local-llm-chat/conversations"
    sudo mkdir -p "$STORAGE_DIR"
    sudo chown -R "$SYSTEM_SERVICE_USER":"$SYSTEM_SERVICE_USER" "/var/lib/local-llm-chat"

    info "Writing $SYSTEM_UNIT_FILE..."
    sudo tee "$SYSTEM_UNIT_FILE" > /dev/null <<EOF
[Unit]
Description=LocalLLMChat — Web Interface for Local LLMs
Documentation=https://github.com/yourusername/LocalLLMChat
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=${SYSTEM_SERVICE_USER}
Group=${SYSTEM_SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${EXECUTABLE} --host 0.0.0.0 --port ${DEFAULT_PORT} --foreground
Restart=always
RestartSec=5
# Give Ollama time to start on a fresh boot before we try to connect
ExecStartPre=/bin/sleep 3

# Resource limits
LimitNOFILE=65536

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=${INSTALL_DIR} /var/lib/local-llm-chat

# Logging goes to journald
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

    ok "System service unit written"

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl restart "$SERVICE_NAME"

    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        ok "Service is running"
    else
        err "Service failed to start. Check logs with:"
        echo "  sudo journalctl -u ${SERVICE_NAME} -n 50"
        exit 1
    fi

else
    # ── User service ─────────────────────────────────────────────────────────

    mkdir -p "$USER_UNIT_DIR"

    # For user services, lingering lets the service survive logout
    if command -v loginctl &>/dev/null; then
        info "Enabling systemd lingering for $USER (keeps service running after logout)..."
        sudo loginctl enable-linger "$USER" 2>/dev/null || \
            warn "Could not enable lingering (service will stop on logout). Run: sudo loginctl enable-linger $USER"
    fi

    info "Writing $USER_UNIT_FILE..."
    cat > "$USER_UNIT_FILE" <<EOF
[Unit]
Description=LocalLLMChat — Web Interface for Local LLMs
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${EXECUTABLE} --host 0.0.0.0 --port ${DEFAULT_PORT} --foreground
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=default.target
EOF

    ok "User service unit written"

    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user restart "$SERVICE_NAME"

    sleep 2

    if systemctl --user is-active --quiet "$SERVICE_NAME"; then
        ok "Service is running"
    else
        err "Service failed to start. Check logs with:"
        echo "  journalctl --user -u ${SERVICE_NAME} -n 50"
        exit 1
    fi
fi

# ── Firewall ───────────────────────────────────────────────────────────────────
step "Opening firewall for network access"
open_firewall_port "$DEFAULT_PORT" "LocalLLMChat (port ${DEFAULT_PORT})"

# ── Verify HTTP ────────────────────────────────────────────────────────────────
step "Verifying web interface"

for i in 1 2 3 4 5; do
    if curl -sf "http://localhost:${DEFAULT_PORT}" >/dev/null 2>&1; then
        ok "LocalLLMChat is responding on port $DEFAULT_PORT"
        break
    fi
    [ "$i" -lt 5 ] && sleep 2
done

if ! curl -sf "http://localhost:${DEFAULT_PORT}" >/dev/null 2>&1; then
    warn "Web interface not yet responding — it may still be starting."
    info "Check status with: $([ "$INSTALL_MODE" = "system" ] && echo "sudo systemctl status $SERVICE_NAME" || echo "systemctl --user status $SERVICE_NAME")"
fi

LOCAL_IP=$(get_local_ip)

# ── Summary ────────────────────────────────────────────────────────────────────
hr
echo -e "${BOLD}${GREEN}  Installation complete!${NC}"
hr
echo
echo -e "  ${BOLD}Access URLs:${NC}"
echo -e "    This machine:   ${CYAN}http://localhost:${DEFAULT_PORT}${NC}"
echo -e "    Local network:  ${CYAN}http://${LOCAL_IP}:${DEFAULT_PORT}${NC}"
echo
echo -e "  ${YELLOW}Share the local network URL with other devices on your network.${NC}"
echo
echo -e "  ${BOLD}Service management:${NC}"
if [ "$INSTALL_MODE" = "system" ]; then
    echo "    Status:   sudo systemctl status ${SERVICE_NAME}"
    echo "    Stop:     sudo systemctl stop ${SERVICE_NAME}"
    echo "    Start:    sudo systemctl start ${SERVICE_NAME}"
    echo "    Restart:  sudo systemctl restart ${SERVICE_NAME}"
    echo "    Logs:     sudo journalctl -u ${SERVICE_NAME} -f"
    echo "    Disable:  sudo systemctl disable ${SERVICE_NAME}"
else
    echo "    Status:   systemctl --user status ${SERVICE_NAME}"
    echo "    Stop:     systemctl --user stop ${SERVICE_NAME}"
    echo "    Start:    systemctl --user start ${SERVICE_NAME}"
    echo "    Restart:  systemctl --user restart ${SERVICE_NAME}"
    echo "    Logs:     journalctl --user -u ${SERVICE_NAME} -f"
    echo "    Disable:  systemctl --user disable ${SERVICE_NAME}"
fi
echo
echo -e "  ${BOLD}Ollama:${NC}"
echo "    Status:   sudo systemctl status ollama"
echo "    Models:   ollama list"
echo "    Pull:     ollama pull llama3.2"
echo
echo -e "  ${BOLD}Uninstall:${NC}"
echo "    ./install-service-linux.sh --uninstall"
echo
hr
