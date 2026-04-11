#!/bin/bash
# ============================================================================
# SSH UI Manager — Configuration
# ============================================================================

# ---- Paths ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
DATA_DIR="$SCRIPT_DIR/data"
LOG_DIR="$SCRIPT_DIR/logs"
INVENTORY_CSV="$DATA_DIR/inventory.csv"
CREDENTIALS_DB="$DATA_DIR/credentials.db"
CACHE_FILE="$DATA_DIR/cache.txt"
LOG_FILE="$LOG_DIR/ssh-ui.log"
ROSTER_FILE="/etc/salt/roster"

# ---- Defaults ----
DEFAULT_PORT="22"
DEFAULT_USER="root"
DEFAULT_KEY="/root/.ssh/id_ecdsa"
TMUX_SESSION_PREFIX="ssh-mgr"
APP_VERSION="1.0.0"
APP_TITLE="SSH UI Manager v${APP_VERSION}"

# ---- CSV Header ----
CSV_HEADER="hostname,host_ip,port,user,priv_key,proxy_jump,group,environment,notes"

# ---- Dialog Settings ----
DIALOG_HEIGHT=0
DIALOG_WIDTH=0
DIALOG_MENU_HEIGHT=0
export DIALOGRC=""

# ---- Encryption ----
CIPHER="aes-256-cbc"
PBKDF2_ITER=100000

# ---- Logging ----
log_msg() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
}

log_info()  { log_msg "INFO"  "$@"; }
log_warn()  { log_msg "WARN"  "$@"; }
log_error() { log_msg "ERROR" "$@"; }

# ---- Utilities ----
trim() {
    local s="$*"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    s="${s%\"}"; s="${s#\"}"
    s="${s%\'}"; s="${s#\'}"
    printf '%s' "$s"
}

die() {
    log_error "$@"
    echo "ERROR: $*" >&2
    exit 1
}

check_deps() {
    local missing=()
    for cmd in dialog tmux sqlite3 openssl ssh; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt install ${missing[*]}"
        exit 1
    fi
}

ensure_dirs() {
    mkdir -p "$DATA_DIR" "$LOG_DIR"
    if [[ ! -f "$INVENTORY_CSV" ]]; then
        echo "$CSV_HEADER" > "$INVENTORY_CSV"
        log_info "Created empty inventory: $INVENTORY_CSV"
    fi
}

# ---- Cleanup trap ----
_cleanup_files=()
register_cleanup() { _cleanup_files+=("$1"); }
cleanup() {
    for f in "${_cleanup_files[@]}"; do
        [[ -f "$f" ]] && rm -f "$f"
    done
    unset SSH_UI_MASTER_KEY 2>/dev/null
}
trap cleanup EXIT INT TERM
