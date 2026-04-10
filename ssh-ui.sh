#!/bin/bash
# ============================================================================
#  SSH UI Manager v1.0.0
#  Multi-host SSH via dialog + tmux
#  Author: Karthick-Dkk
# ============================================================================

set -euo pipefail

# ---- Resolve script location (follow symlinks) ----
_SELF="${BASH_SOURCE[0]}"
while [[ -L "$_SELF" ]]; do
    _DIR="$(cd "$(dirname "$_SELF")" && pwd)"
    _SELF="$(readlink "$_SELF")"
    [[ "$_SELF" != /* ]] && _SELF="$_DIR/$_SELF"
done
SCRIPT_DIR="$(cd "$(dirname "$_SELF")" && pwd)"
unset _SELF _DIR

# ---- Source all modules ----
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/inventory.sh"
source "$SCRIPT_DIR/lib/credentials.sh"
source "$SCRIPT_DIR/lib/tmux_session.sh"
source "$SCRIPT_DIR/lib/commands.sh"
source "$SCRIPT_DIR/scripts/import-roster.sh"
source "$SCRIPT_DIR/lib/dialog_ui.sh"

# ---- CLI Arguments ----
show_help() {
    cat <<'EOF'
SSH UI Manager v1.0.0

Usage: ssh-ui [OPTIONS]

Options:
  -h, --help        Show this help
  -v, --version     Show version
  -r, --refresh     Refresh inventory from salt roster
  -i, --import FILE Import from custom roster file
  -l, --list        List inventory hosts (no UI)
  -c, --connect HOST Connect directly to a host by name

Environment:
  SSH_UI_ROSTER     Override roster file path (default: /etc/salt/roster)
  SSH_UI_DATA       Override data directory (default: ./data)

Examples:
  ssh-ui                     # Launch interactive UI
  ssh-ui -r                  # Refresh from salt roster
  ssh-ui -i /path/roster     # Import custom roster
  ssh-ui -l                  # List all hosts
  ssh-ui -c elk-node-01      # Direct SSH to host

EOF
}

# ---- Direct Connect (by hostname) ----
direct_connect() {
    local target="$1"
    inventory_load

    local found=false
    for i in "${!INV_HOSTNAME[@]}"; do
        if [[ "${INV_HOSTNAME[$i]}" == "$target" ]]; then
            local ssh_cmd
            ssh_cmd="$(inventory_ssh_cmd "$i")"
            echo "Connecting to $target (${INV_HOST_IP[$i]})..."
            log_info "Direct connect: $target"
            eval "$ssh_cmd"
            found=true
            break
        fi
    done

    if [[ "$found" != true ]]; then
        echo "Host not found: $target"
        echo "Use 'ssh-ui -l' to list available hosts."
        exit 1
    fi
}

# ---- List hosts (CLI) ----
list_hosts() {
    inventory_load
    printf "%-25s %-16s %-6s %-12s %-12s %-12s\n" \
        "HOSTNAME" "IP" "PORT" "USER" "GROUP" "ENV"
    printf "%s\n" "$(printf '%.0s-' {1..90})"

    for i in "${!INV_HOSTNAME[@]}"; do
        printf "%-25s %-16s %-6s %-12s %-12s %-12s\n" \
            "${INV_HOSTNAME[$i]}" "${INV_HOST_IP[$i]}" "${INV_PORT[$i]}" \
            "${INV_USER[$i]}" "${INV_GROUP[$i]}" "${INV_ENV[$i]}"
    done
    echo ""
    echo "Total: $(inventory_count) hosts"
}

# ---- Process CLI args ----
process_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_help; exit 0 ;;
            -v|--version) echo "SSH UI Manager v${APP_VERSION}"; exit 0 ;;
            -r|--refresh)
                ensure_dirs
                local roster="${SSH_UI_ROSTER:-$ROSTER_FILE}"
                if [[ ! -f "$roster" ]]; then
                    echo "ERROR: Roster file not found: $roster"
                    echo ""
                    echo "Options:"
                    echo "  1. Check the file exists:  ls -la $roster"
                    echo "  2. Use a custom path:      SSH_UI_ROSTER=/path/to/roster ssh-ui -r"
                    echo "  3. Import manually:        ssh-ui -i /path/to/roster"
                    exit 1
                fi
                echo "Refreshing inventory from: $roster"
                echo "Output CSV: $INVENTORY_CSV"
                echo ""
                import_salt_roster "$roster" "$INVENTORY_CSV" "true"
                inventory_load
                echo ""
                echo "Total hosts in inventory: $(inventory_count)"
                shift
                ;;
            -i|--import)
                ensure_dirs
                [[ -z "${2:-}" ]] && { echo "ERROR: -i requires a file path"; exit 1; }
                [[ ! -f "$2" ]] && { echo "ERROR: File not found: $2"; exit 1; }
                echo "Importing from: $2"
                echo "Output CSV: $INVENTORY_CSV"
                echo ""
                import_salt_roster "$2" "$INVENTORY_CSV" "true"
                inventory_load
                echo ""
                echo "Total hosts: $(inventory_count)"
                shift 2
                ;;
            -l|--list)
                ensure_dirs
                list_hosts
                exit 0
                ;;
            -c|--connect)
                ensure_dirs
                [[ -z "${2:-}" ]] && { echo "ERROR: -c requires a hostname"; exit 1; }
                direct_connect "$2"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ---- Main Loop ----
main() {
    [[ -n "${SSH_UI_ROSTER:-}" ]] && ROSTER_FILE="$SSH_UI_ROSTER"
    [[ -n "${SSH_UI_DATA:-}" ]]   && DATA_DIR="$SSH_UI_DATA"

    process_args "$@"

    check_deps
    ensure_dirs
    cred_init_db
    inventory_load

    log_info "SSH UI Manager started ($(inventory_count) hosts)"

    while true; do
        local choice
        choice="$(ui_main_menu)"

        case "$choice" in
            1) ui_host_checklist ;;
            2) cmd_execute_on_session ;;
            3) ui_reattach_menu ;;
            4) ui_inventory_menu ;;
            5) ui_import_roster ;;
            6) ui_credential_menu ;;
            7) ui_kill_sessions ;;
            0|"")
                local active
                active="$(tmux_list_sessions | wc -l)"
                if [[ "$active" -gt 0 ]]; then
                    dialog --yesno "There are $active active SSH session(s).\n\nSessions will persist in background.\nReattach later with: ssh-ui\n\nExit?" 10 50 || continue
                fi
                clear
                echo "SSH UI Manager — Goodbye!"
                log_info "SSH UI Manager exited"
                exit 0
                ;;
        esac
    done
}

main "$@"
