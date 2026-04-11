#!/bin/bash
# ============================================================================
# SSH UI Manager — tmux Session Management
# ============================================================================

CURRENT_TMUX_SESSION=""

tmux_session_exists() {
    local session="$1"
    tmux has-session -t "$session" 2>/dev/null
}

# Create a new tmux session with the first host
tmux_create_session() {
    local ssh_cmd="$1"
    local hostname="${2:-}"
    local host_tag="${hostname:0:5}"
    local session="${TMUX_SESSION_PREFIX}-${host_tag}-$$"

    # Kill stale session if exists
    tmux_session_exists "$session" && tmux kill-session -t "$session" 2>/dev/null

    tmux new-session -d -s "$session" -n "$hostname"
    tmux send-keys -t "$session" "$ssh_cmd" Enter

    CURRENT_TMUX_SESSION="$session"
    log_info "Created tmux session: $session (first host: $hostname)"
}

# Add a new pane to existing session
tmux_add_pane() {
    local ssh_cmd="$1"
    local session="${CURRENT_TMUX_SESSION:-}"

    [[ -z "$session" ]] && { log_error "No active tmux session"; return 1; }

    tmux split-window -t "$session" -h
    tmux send-keys -t "$session" "$ssh_cmd" Enter

    log_info "Added pane to $session"
}

# Tile all panes evenly
tmux_tile_panes() {
    local session="${CURRENT_TMUX_SESSION:-}"
    [[ -z "$session" ]] && return 1
    tmux select-layout -t "$session" tiled
    log_info "Tiled panes in $session"
}

# Toggle synchronized panes
tmux_sync_toggle() {
    local session="${CURRENT_TMUX_SESSION:-}"
    [[ -z "$session" ]] && return 1
    tmux setw -t "$session" synchronize-panes
    log_info "Toggled sync-panes in $session"
}

tmux_sync_on() {
    local session="${CURRENT_TMUX_SESSION:-}"
    [[ -z "$session" ]] && return 1
    tmux setw -t "$session" synchronize-panes on
}

tmux_sync_off() {
    local session="${CURRENT_TMUX_SESSION:-}"
    [[ -z "$session" ]] && return 1
    tmux setw -t "$session" synchronize-panes off
}

# Send a command to all panes
tmux_send_command() {
    local cmd="$1"
    local session="${CURRENT_TMUX_SESSION:-}"
    [[ -z "$session" ]] && return 1

    local pane_count
    pane_count=$(tmux list-panes -t "$session" 2>/dev/null | wc -l)

    local i
    for ((i = 0; i < pane_count; i++)); do
        tmux send-keys -t "${session}:0.${i}" "$cmd" Enter
    done
    log_info "Sent command to $pane_count panes: $cmd"
}

# Attach to current session
tmux_attach() {
    local session="${CURRENT_TMUX_SESSION:-}"
    [[ -z "$session" ]] && { log_error "No active tmux session"; return 1; }

    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session"
    else
        tmux attach-session -t "$session"
    fi
}

# Kill current session
tmux_cleanup_session() {
    local session="${CURRENT_TMUX_SESSION:-}"
    [[ -z "$session" ]] && return 0
    tmux_session_exists "$session" && tmux kill-session -t "$session" 2>/dev/null
    CURRENT_TMUX_SESSION=""
    log_info "Cleaned up tmux session: $session"
}

# List all ssh-mgr sessions
tmux_list_sessions() {
    tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${TMUX_SESSION_PREFIX}-" || true
}

# Connect to multiple hosts with tmux
tmux_connect_hosts() {
    local -n indices_ref=$1
    local override_user="${2:-}"
    local count=${#indices_ref[@]}

    if [[ $count -eq 0 ]]; then
        dialog --msgbox "No hosts selected." 6 30
        return 1
    fi

    if [[ $count -eq 1 ]]; then
        # Single host — direct SSH, no tmux
        local idx="${indices_ref[0]}"
        local ssh_cmd
        ssh_cmd="$(inventory_ssh_cmd "$idx" "$override_user")"

        # Check for password auth
        local use_sshpass=false
        local saved_pass=""
        if cred_has_entry "${INV_HOSTNAME[$idx]}" 2>/dev/null || false; then
            local cred_data=""
            cred_data="$(cred_fetch "${INV_HOSTNAME[$idx]}" 2>/dev/null || true)"
            if [[ -n "$cred_data" ]]; then
                saved_pass="$(echo "$cred_data" | cut -d'|' -f2)"
                [[ -n "$saved_pass" ]] && use_sshpass=true
            fi
        fi

        clear
        echo "Connecting to: ${INV_HOSTNAME[$idx]} (${INV_HOST_IP[$idx]})"
        echo "Command: $ssh_cmd"
        echo "---"
        log_info "Direct SSH to ${INV_HOSTNAME[$idx]}: $ssh_cmd"

        if [[ "$use_sshpass" == true ]]; then
            export SSHPASS="$saved_pass"
            sshpass -e $ssh_cmd
            unset SSHPASS
        else
            eval "$ssh_cmd"
        fi
        return $?
    fi

    # Multi-host — tmux
    local first=true
    for idx in "${indices_ref[@]}"; do
        local ssh_cmd
        ssh_cmd="$(inventory_ssh_cmd "$idx" "$override_user")"

        # Prepend sshpass if password exists
        if cred_has_entry "${INV_HOSTNAME[$idx]}" 2>/dev/null || false; then
            local cred_data=""
            cred_data="$(cred_fetch "${INV_HOSTNAME[$idx]}" 2>/dev/null || true)"
            if [[ -n "$cred_data" ]]; then
                local saved_pass
                saved_pass="$(echo "$cred_data" | cut -d'|' -f2)"
                if [[ -n "$saved_pass" ]]; then
                    ssh_cmd="SSHPASS='${saved_pass}' sshpass -e ${ssh_cmd}"
                fi
            fi
        fi

        if [[ "$first" == true ]]; then
            tmux_create_session "$ssh_cmd" "${INV_HOSTNAME[$idx]}"
            first=false
        else
            tmux_add_pane "$ssh_cmd"
        fi
    done

    tmux_tile_panes

    clear
    echo "Connecting to $count hosts via tmux..."
    log_info "tmux multi-connect: $count hosts"
    tmux_attach
}
