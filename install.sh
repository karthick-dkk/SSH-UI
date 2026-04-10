#!/bin/bash
# ============================================================================
# SSH UI Manager — Installer
# ============================================================================

set -euo pipefail

INSTALL_DIR="/opt/ssh-ui"
BIN_LINK="/usr/local/bin/ssh-ui"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  SSH UI Manager — Installation"
echo "============================================"
echo ""

# ---- Check root ----
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root: sudo bash install.sh"
    exit 1
fi

# ---- Check dependencies ----
echo "[1/5] Checking dependencies..."
DEPS=(dialog tmux sqlite3 openssl ssh)
OPTIONAL_DEPS=(sshpass jq)
MISSING=()
MISSING_OPT=()

for cmd in "${DEPS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    else
        echo "  ✓ $cmd"
    fi
done

for cmd in "${OPTIONAL_DEPS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_OPT+=("$cmd")
        echo "  ○ $cmd (optional, not found)"
    else
        echo "  ✓ $cmd"
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo "Missing required packages: ${MISSING[*]}"
    read -rp "Install now? (y/N) " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        apt-get update -qq
        apt-get install -y -qq "${MISSING[@]}"
        echo "  Installed: ${MISSING[*]}"
    else
        echo "Cannot continue without: ${MISSING[*]}"
        exit 1
    fi
fi

if [[ ${#MISSING_OPT[@]} -gt 0 ]]; then
    read -rp "Install optional packages (${MISSING_OPT[*]})? (y/N) " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        apt-get install -y -qq "${MISSING_OPT[@]}" 2>/dev/null || true
    fi
fi

# ---- Backup existing data ----
echo ""
echo "[2/5] Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

if [[ -f "$INSTALL_DIR/data/inventory.csv" ]]; then
    echo "  Preserving existing inventory.csv"
    cp "$INSTALL_DIR/data/inventory.csv" /tmp/_ssh-ui-inventory.csv.bak
fi
if [[ -f "$INSTALL_DIR/data/credentials.db" ]]; then
    echo "  Preserving existing credentials.db"
    cp "$INSTALL_DIR/data/credentials.db" /tmp/_ssh-ui-credentials.db.bak
fi

# ---- Copy files ----
cp -r "$SOURCE_DIR"/lib "$INSTALL_DIR/"
cp -r "$SOURCE_DIR"/scripts "$INSTALL_DIR/"
cp "$SOURCE_DIR"/ssh-ui.sh "$INSTALL_DIR/"

# ---- Set permissions ----
echo "[3/5] Setting permissions..."
chmod 755 "$INSTALL_DIR/ssh-ui.sh"
chmod 755 "$INSTALL_DIR"/scripts/*.sh
chmod 644 "$INSTALL_DIR"/lib/*.sh
find "$INSTALL_DIR" -type d -exec chmod 755 {} \;

# ---- Create data directories ----
echo "[4/5] Creating data directories..."
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/logs"
chmod 700 "$INSTALL_DIR/data"
chmod 755 "$INSTALL_DIR/logs"

# Restore preserved data
if [[ -f /tmp/_ssh-ui-inventory.csv.bak ]]; then
    cp /tmp/_ssh-ui-inventory.csv.bak "$INSTALL_DIR/data/inventory.csv"
    rm -f /tmp/_ssh-ui-inventory.csv.bak
    echo "  Restored inventory.csv ($(tail -n +2 "$INSTALL_DIR/data/inventory.csv" | wc -l) hosts)"
fi
if [[ -f /tmp/_ssh-ui-credentials.db.bak ]]; then
    cp /tmp/_ssh-ui-credentials.db.bak "$INSTALL_DIR/data/credentials.db"
    chmod 600 "$INSTALL_DIR/data/credentials.db"
    rm -f /tmp/_ssh-ui-credentials.db.bak
    echo "  Restored credentials.db"
fi

# ---- Create symlink ----
echo "[5/5] Creating command symlink..."
ln -sf "$INSTALL_DIR/ssh-ui.sh" "$BIN_LINK"
echo "  Linked: $BIN_LINK → $INSTALL_DIR/ssh-ui.sh"

echo ""
echo "============================================"
echo "  Installation complete!"
echo "============================================"
echo ""
echo "  Usage:"
echo "    ssh-ui                    # Launch interactive UI"
echo "    ssh-ui -r                 # Refresh from salt roster"
echo "    ssh-ui -l                 # List all hosts"
echo "    ssh-ui -c <hostname>      # Direct connect"
echo "    ssh-ui -h                 # Help"
echo ""
echo "  Data:   $INSTALL_DIR/data/"
echo "  Logs:   $INSTALL_DIR/logs/"
echo ""

# ---- Auto-import roster if available ----
if [[ -f "/etc/salt/roster" ]]; then
    read -rp "Import hosts from /etc/salt/roster now? (y/N) " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        bash "$INSTALL_DIR/ssh-ui.sh" -r
    fi
fi

echo "Done. Run 'ssh-ui' to start."
