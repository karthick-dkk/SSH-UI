#!/bin/bash
# ============================================================================
# SSH UI Manager — Dialog UI
# ============================================================================

# ---- Main Menu ----
ui_main_menu() {
    local host_count
    host_count="$(inventory_count)"
    local active_sessions
    active_sessions="$(tmux_list_sessions | wc -l)"

    local choice
    choice=$(dialog --title "$APP_TITLE" \
        --menu "\n  Hosts: $host_count  |  Active tmux sessions: $active_sessions\n" \
        20 65 10 \
        "1" "Connect to Hosts           [SSH + tmux]" \
        "2" "Quick Commands             [on active session]" \
        "3" "Reattach tmux Session      [existing]" \
        "4" "Manage Inventory           [add/edit/delete]" \
        "5" "Import from Salt Roster    [/etc/salt/roster]" \
        "6" "Manage Credentials         [encrypted vault]" \
        "7" "Kill All SSH Sessions      [cleanup]" \
        "0" "Exit" \
        3>&1 1>&2 2>&3)

    echo "$choice"
}

# ---- Filter Selector ----
ui_filter_menu() {
    local choice
    choice=$(dialog --title "Filter Hosts" --menu "Select filter:" \
        12 45 5 \
        "all"    "Show all hosts" \
        "group"  "Filter by group" \
        "env"    "Filter by environment" \
        "search" "Search by keyword" \
        3>&1 1>&2 2>&3)

    [[ -z "$choice" ]] && { echo "all|"; return; }

    case "$choice" in
        all)
            echo "all|"
            ;;
        group)
            local groups
            groups="$(inventory_groups)"
            local args=()
            while IFS= read -r g; do
                [[ -n "$g" ]] && args+=("$g" "$g")
            done <<< "$groups"

            if [[ ${#args[@]} -eq 0 ]]; then
                dialog --msgbox "No groups found." 6 30
                echo "all|"
                return
            fi

            local selected
            selected=$(dialog --title "Select Group" --menu "Choose group:" \
                15 40 8 "${args[@]}" 3>&1 1>&2 2>&3)
            echo "group|${selected}"
            ;;
        env)
            local envs
            envs="$(inventory_envs)"
            local args=()
            while IFS= read -r e; do
                [[ -n "$e" ]] && args+=("$e" "$e")
            done <<< "$envs"

            if [[ ${#args[@]} -eq 0 ]]; then
                dialog --msgbox "No environments found." 6 30
                echo "all|"
                return
            fi

            local selected
            selected=$(dialog --title "Select Environment" --menu "Choose environment:" \
                15 40 8 "${args[@]}" 3>&1 1>&2 2>&3)
            echo "env|${selected}"
            ;;
        search)
            local keyword
            keyword=$(dialog --inputbox "Search keyword:" 8 40 3>&1 1>&2 2>&3)
            echo "search|${keyword}"
            ;;
    esac
}

# ---- Host Selection (Single=menu, Multi=checklist) ----
ui_host_checklist() {
    # Get filter
    local filter_result filter_type filter_value
    filter_result="$(ui_filter_menu)"
    filter_type="${filter_result%%|*}"
    filter_value="${filter_result#*|}"

    # Get matching indices
    local indices_str
    indices_str="$(inventory_filter_indices "$filter_type" "$filter_value")"
    read -ra filtered_indices <<< "$indices_str"

    if [[ ${#filtered_indices[@]} -eq 0 ]]; then
        dialog --msgbox "No hosts match the filter." 6 35
        return 1
    fi

    # Build menu arguments with multi-select option at top
    local args=()
    args+=("MULTI" ">>> Multi-Select Mode (tmux) <<<")
    for idx in "${filtered_indices[@]}"; do
        local label="${INV_HOSTNAME[$idx]}"
        local desc="${INV_HOST_IP[$idx]}  [${INV_GROUP[$idx]}/${INV_ENV[$idx]}]"
        args+=("$idx" "${label}  ${desc}")
    done

    # Show menu — highlight a host and Enter to connect directly
    local choice
    choice=$(dialog --title "Select Host  |  Hosts: ${#filtered_indices[@]}  |  Filter: ${filter_type} ${filter_value}" \
        --menu "\n  Enter = Connect to highlighted host\n  MULTI = Select multiple hosts with * for tmux\n" \
        25 80 15 \
        "${args[@]}" \
        3>&1 1>&2 2>&3)

    [[ -z "$choice" ]] && return 1

    if [[ "$choice" == "MULTI" ]]; then
        # --- Multi-Select Mode: show checklist ---
        _ui_multi_select_checklist
    else
        # --- Single Host: connect directly ---
        local default_user="${INV_USER[$choice]}"
        local prefill_user=""

        # Check for stored credential — auto-fill username
        cred_init_db
        if cred_has_entry "${INV_HOSTNAME[$choice]}" 2>/dev/null || false; then
            local cred_data=""
            cred_data="$(cred_fetch "${INV_HOSTNAME[$choice]}" 2>/dev/null || true)"
            if [[ -n "$cred_data" ]]; then
                local stored_user
                stored_user="$(echo "$cred_data" | cut -d'|' -f1)"
                [[ -n "$stored_user" ]] && prefill_user="$stored_user"
            fi
        fi

        local override_user
        if [[ -n "$prefill_user" ]]; then
            override_user=$(dialog --inputbox \
                "Stored credential user: $prefill_user\nInventory default: $default_user\n\nUsername (blank = use stored: $prefill_user):" \
                10 60 "$prefill_user" 3>&1 1>&2 2>&3)
            override_user="${override_user:-$prefill_user}"
        else
            override_user=$(dialog --inputbox \
                "Username override (blank = default: $default_user):" \
                8 55 "" 3>&1 1>&2 2>&3)
        fi

        local -a single_idx=("$choice")
        tmux_connect_hosts single_idx "${override_user:-}"
    fi
}

# ---- Multi-Select Checklist (called from host menu) ----
_ui_multi_select_checklist() {
    local args=()
    for idx in "${filtered_indices[@]}"; do
        local label="${INV_HOSTNAME[$idx]}"
        local desc="${INV_HOST_IP[$idx]}  [${INV_GROUP[$idx]}/${INV_ENV[$idx]}]"
        args+=("$idx" "${label}  ${desc}" "off")
    done

    local selected
    selected=$(dialog --title "Multi-Select (SPACE=mark *, ENTER=confirm)" \
        --checklist "\nUse SPACE to mark hosts with *, then ENTER to connect all marked.\n${#filtered_indices[@]} hosts available:" \
        25 80 15 \
        "${args[@]}" \
        3>&1 1>&2 2>&3)

    [[ -z "$selected" ]] && { dialog --msgbox "No hosts selected." 6 30; return 1; }

    local -a selected_indices
    read -ra selected_indices <<< "$(echo "$selected" | tr -d '"')"

    local override_user
    override_user=$(dialog --inputbox \
        "Username override for ${#selected_indices[@]} hosts (blank = default):" \
        8 55 "" 3>&1 1>&2 2>&3)

    local sync_choice
    sync_choice=$(dialog --title "tmux Options" --menu \
        "Connecting ${#selected_indices[@]} hosts via tmux:" \
        10 50 3 \
        "nosync" "Independent panes (default)" \
        "sync"   "Synchronized — type once, all receive" \
        3>&1 1>&2 2>&3)

    tmux_connect_hosts selected_indices "${override_user:-}"

    [[ "${sync_choice:-}" == "sync" ]] && tmux_sync_on
}

# ---- Reattach to existing tmux session ----
ui_reattach_menu() {
    local sessions
    sessions="$(tmux_list_sessions)"

    if [[ -z "$sessions" ]]; then
        dialog --msgbox "No active SSH Manager sessions found." 6 45
        return 1
    fi

    local args=()
    while IFS= read -r s; do
        local pane_count
        pane_count=$(tmux list-panes -t "$s" 2>/dev/null | wc -l)
        args+=("$s" "$pane_count panes")
    done <<< "$sessions"

    local choice
    choice=$(dialog --title "Reattach tmux Session" --menu \
        "Select session to reattach:" \
        15 50 8 "${args[@]}" 3>&1 1>&2 2>&3)

    [[ -z "$choice" ]] && return 1

    CURRENT_TMUX_SESSION="$choice"
    clear
    tmux_attach
}

# ---- Kill All Sessions ----
ui_kill_sessions() {
    local sessions
    sessions="$(tmux_list_sessions)"

    if [[ -z "$sessions" ]]; then
        dialog --msgbox "No active sessions to kill." 6 40
        return 0
    fi

    local count
    count=$(echo "$sessions" | wc -l)

    dialog --yesno "Kill $count SSH Manager session(s)?\n\nThis will disconnect all hosts." 8 50 || return 0

    while IFS= read -r s; do
        tmux kill-session -t "$s" 2>/dev/null
        log_info "Killed session: $s"
    done <<< "$sessions"

    CURRENT_TMUX_SESSION=""
    dialog --msgbox "All sessions terminated." 6 35
}

# ---- Inventory Management ----
ui_inventory_menu() {
    while true; do
        local choice
        choice=$(dialog --title "Manage Inventory" --menu \
            "Host count: $(inventory_count)" \
            15 55 7 \
            "1" "View all hosts" \
            "2" "Add new host" \
            "3" "Edit host" \
            "4" "Delete host" \
            "5" "Sort inventory" \
            "0" "Back to main menu" \
            3>&1 1>&2 2>&3)

        case "$choice" in
            1) ui_view_hosts ;;
            2) ui_add_host ;;
            3) ui_edit_host ;;
            4) ui_delete_host ;;
            5) inventory_sort; dialog --msgbox "Inventory sorted." 6 30 ;;
            *) return ;;
        esac
    done
}

ui_view_hosts() {
    local tmpfile
    tmpfile="$(mktemp)"
    register_cleanup "$tmpfile"

    printf "%-25s %-16s %-6s %-12s %-12s %-12s\n" \
        "HOSTNAME" "IP" "PORT" "USER" "GROUP" "ENV" > "$tmpfile"
    printf "%s\n" "$(printf '%.0s-' {1..90})" >> "$tmpfile"

    for i in "${!INV_HOSTNAME[@]}"; do
        printf "%-25s %-16s %-6s %-12s %-12s %-12s\n" \
            "${INV_HOSTNAME[$i]}" "${INV_HOST_IP[$i]}" "${INV_PORT[$i]}" \
            "${INV_USER[$i]}" "${INV_GROUP[$i]}" "${INV_ENV[$i]}" >> "$tmpfile"
    done

    dialog --title "Inventory ($(inventory_count) hosts)" --textbox "$tmpfile" 25 100
}

ui_add_host() {
    local result
    result=$(dialog --title "Add New Host" --form "Enter host details:" 20 60 10 \
        "Hostname:"    1 1 "" 1 15 30 100 \
        "IP/Host:"     2 1 "" 2 15 30 100 \
        "Port:"        3 1 "22" 3 15 10 5 \
        "User:"        4 1 "deploy" 4 15 20 50 \
        "SSH Key:"     5 1 "$DEFAULT_KEY" 5 15 40 200 \
        "ProxyJump:"   6 1 "" 6 15 40 200 \
        "Group:"       7 1 "ungrouped" 7 15 20 50 \
        "Environment:" 8 1 "production" 8 15 20 50 \
        "Notes:"       9 1 "" 9 15 40 200 \
        3>&1 1>&2 2>&3)

    [[ -z "$result" ]] && return

    local -a fields
    mapfile -t fields <<< "$result"

    inventory_add "${fields[0]:-}" "${fields[1]:-}" "${fields[2]:-}" "${fields[3]:-}" \
                  "${fields[4]:-}" "${fields[5]:-}" "${fields[6]:-}" "${fields[7]:-}" "${fields[8]:-}"

    local rc=$?
    case $rc in
        0) dialog --msgbox "Host '${fields[0]:-}' added." 6 40 ;;
        1) dialog --msgbox "Error: hostname and IP are required." 6 45 ;;
        2) dialog --msgbox "Error: hostname '${fields[0]:-}' already exists." 6 50 ;;
    esac
}

ui_edit_host() {
    local args=()
    for i in "${!INV_HOSTNAME[@]}"; do
        args+=("$i" "${INV_HOSTNAME[$i]}  ${INV_HOST_IP[$i]}")
    done

    [[ ${#args[@]} -eq 0 ]] && { dialog --msgbox "No hosts in inventory." 6 35; return; }

    local idx
    idx=$(dialog --title "Select Host to Edit" --menu "Choose host:" \
        20 60 12 "${args[@]}" 3>&1 1>&2 2>&3)
    [[ -z "$idx" ]] && return

    local result
    result=$(dialog --title "Edit: ${INV_HOSTNAME[$idx]}" --form "Modify fields:" 20 60 10 \
        "Hostname:"    1 1 "${INV_HOSTNAME[$idx]}" 1 15 30 100 \
        "IP/Host:"     2 1 "${INV_HOST_IP[$idx]}" 2 15 30 100 \
        "Port:"        3 1 "${INV_PORT[$idx]}" 3 15 10 5 \
        "User:"        4 1 "${INV_USER[$idx]}" 4 15 20 50 \
        "SSH Key:"     5 1 "${INV_PRIV[$idx]}" 5 15 40 200 \
        "ProxyJump:"   6 1 "${INV_PROXY[$idx]}" 6 15 40 200 \
        "Group:"       7 1 "${INV_GROUP[$idx]}" 7 15 20 50 \
        "Environment:" 8 1 "${INV_ENV[$idx]}" 8 15 20 50 \
        "Notes:"       9 1 "${INV_NOTES[$idx]}" 9 15 40 200 \
        3>&1 1>&2 2>&3)

    [[ -z "$result" ]] && return

    local -a fields
    mapfile -t fields <<< "$result"

    inventory_update "${INV_HOSTNAME[$idx]}" \
        "${fields[0]:-}" "${fields[1]:-}" "${fields[2]:-}" "${fields[3]:-}" \
        "${fields[4]:-}" "${fields[5]:-}" "${fields[6]:-}" "${fields[7]:-}" "${fields[8]:-}"

    dialog --msgbox "Host updated." 6 30
}

ui_delete_host() {
    local args=()
    for i in "${!INV_HOSTNAME[@]}"; do
        args+=("$i" "${INV_HOSTNAME[$i]}  ${INV_HOST_IP[$i]}")
    done

    [[ ${#args[@]} -eq 0 ]] && { dialog --msgbox "No hosts in inventory." 6 35; return; }

    local idx
    idx=$(dialog --title "Delete Host" --menu "Select host to remove:" \
        20 60 12 "${args[@]}" 3>&1 1>&2 2>&3)
    [[ -z "$idx" ]] && return

    dialog --yesno "Delete '${INV_HOSTNAME[$idx]}' (${INV_HOST_IP[$idx]})?\n\nThis cannot be undone." 8 50 || return

    inventory_delete "${INV_HOSTNAME[$idx]}"
    dialog --msgbox "Host deleted." 6 30
}

# ---- Credential Management UI ----
ui_credential_menu() {
    cred_init_db
    while true; do
        local choice
        choice=$(dialog --title "Credential Vault" --menu \
            "Manage encrypted credentials:" \
            15 55 6 \
            "1" "Store new credential" \
            "2" "View stored credentials" \
            "3" "Delete credential" \
            "4" "Change master password" \
            "0" "Back to main menu" \
            3>&1 1>&2 2>&3)

        case "$choice" in
            1) ui_store_credential ;;
            2) ui_view_credentials ;;
            3) ui_delete_credential ;;
            4) ui_change_master ;;
            *) return ;;
        esac
    done
}

ui_store_credential() {
    cred_unlock || return

    local args=()
    for i in "${!INV_HOSTNAME[@]}"; do
        local tag=""
        cred_has_entry "${INV_HOSTNAME[$i]}" 2>/dev/null && tag=" [saved]"
        args+=("$i" "${INV_HOSTNAME[$i]}  ${INV_HOST_IP[$i]}${tag}")
    done

    local idx
    idx=$(dialog --title "Store Credential" --menu "Select host:" \
        20 60 12 "${args[@]}" 3>&1 1>&2 2>&3)
    [[ -z "$idx" ]] && return

    local result
    result=$(dialog --title "Credentials for: ${INV_HOSTNAME[$idx]}" \
        --insecure --mixedform "Enter credentials:" 14 55 4 \
        "Username:" 1 1 "${INV_USER[$idx]}" 1 15 30 100 0 \
        "Password:" 2 1 "" 2 15 30 100 1 \
        "SSH Key:"  3 1 "${INV_PRIV[$idx]}" 3 15 35 200 0 \
        "Key Pass:" 4 1 "" 4 15 30 100 1 \
        3>&1 1>&2 2>&3)

    [[ -z "$result" ]] && return

    local -a fields
    mapfile -t fields <<< "$result"

    cred_store "${INV_HOSTNAME[$idx]}" "${fields[0]:-}" "${fields[1]:-}" "${fields[2]:-}" "${fields[3]:-}"
    dialog --msgbox "Credentials saved for ${INV_HOSTNAME[$idx]}." 6 50
}

ui_view_credentials() {
    cred_unlock || return

    local entries
    entries="$(cred_list)"

    if [[ -z "$entries" ]]; then
        dialog --msgbox "No stored credentials." 6 35
        return
    fi

    local tmpfile
    tmpfile="$(mktemp)"
    register_cleanup "$tmpfile"

    printf "%-25s %-15s %-35s %s\n" "HOSTNAME" "USER" "KEY PATH" "UPDATED" > "$tmpfile"
    printf "%s\n" "$(printf '%.0s-' {1..85})" >> "$tmpfile"

    while IFS='|' read -r hostname username key_path updated; do
        printf "%-25s %-15s %-35s %s\n" "$hostname" "$username" "$key_path" "$updated" >> "$tmpfile"
    done <<< "$entries"

    dialog --title "Stored Credentials" --textbox "$tmpfile" 20 95
}

ui_delete_credential() {
    local entries
    entries="$(cred_list)"

    if [[ -z "$entries" ]]; then
        dialog --msgbox "No stored credentials." 6 35
        return
    fi

    local args=()
    while IFS='|' read -r hostname username key_path updated; do
        args+=("$hostname" "$username  [$updated]")
    done <<< "$entries"

    local choice
    choice=$(dialog --title "Delete Credential" --menu "Select credential to remove:" \
        15 60 8 "${args[@]}" 3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return

    dialog --yesno "Delete credential for '$choice'?" 7 45 || return
    cred_delete "$choice"
    dialog --msgbox "Credential deleted." 6 30
}

ui_change_master() {
    cred_unlock || return

    local new_pass confirm_pass

    new_pass=$(dialog --insecure --passwordbox "Enter NEW master password:" 10 50 3>&1 1>&2 2>&3)
    [[ -z "$new_pass" ]] && return

    confirm_pass=$(dialog --insecure --passwordbox "Confirm NEW master password:" 10 50 3>&1 1>&2 2>&3)

    if [[ "$new_pass" != "$confirm_pass" ]]; then
        dialog --msgbox "Passwords do not match." 6 35
        return
    fi

    local old_key="${SSH_UI_MASTER_KEY:-}"
    local entries
    entries=$(sqlite3 -separator '|' "$CREDENTIALS_DB" \
        "SELECT hostname, username, password, key_path, passphrase FROM credentials;")

    local new_salt new_hash
    new_salt=$(openssl rand -hex 16)
    new_hash=$(echo -n "${new_pass}${new_salt}" | openssl dgst -sha256 -hex 2>/dev/null | awk '{print $NF}')
    sqlite3 "$CREDENTIALS_DB" "UPDATE master_key SET key_hash='$new_hash', salt='$new_salt' WHERE id=1;"

    export SSH_UI_MASTER_KEY="$new_pass"

    while IFS='|' read -r hostname username enc_pass key_path enc_phrase; do
        [[ -z "$hostname" ]] && continue
        local plain_pass="" plain_phrase=""

        if [[ -n "$enc_pass" ]]; then
            plain_pass=$(echo -n "$enc_pass" | openssl enc -${CIPHER} -pbkdf2 -iter ${PBKDF2_ITER} \
                -pass "pass:${old_key}" -a -d 2>/dev/null)
        fi
        if [[ -n "$enc_phrase" ]]; then
            plain_phrase=$(echo -n "$enc_phrase" | openssl enc -${CIPHER} -pbkdf2 -iter ${PBKDF2_ITER} \
                -pass "pass:${old_key}" -a -d 2>/dev/null)
        fi

        cred_store "$hostname" "$username" "$plain_pass" "$key_path" "$plain_phrase"
    done <<< "$entries"

    dialog --msgbox "Master password changed.\nAll credentials re-encrypted." 7 45
    log_info "Master password changed"
}

# ---- Import Roster UI ----
ui_import_roster() {
    local roster="${ROSTER_FILE}"

    if [[ ! -f "$roster" ]]; then
        roster=$(dialog --inputbox "Roster file path:" 8 55 "$ROSTER_FILE" 3>&1 1>&2 2>&3)
        [[ -z "$roster" || ! -f "$roster" ]] && { dialog --msgbox "File not found: $roster" 6 50; return; }
    fi

    local mode
    mode=$(dialog --title "Import Mode" --menu \
        "Import from:\n$roster" 12 55 3 \
        "merge"   "Merge — keep existing, add new only" \
        "force"   "Force — wipe CSV, reimport everything" \
        "debug"   "Debug — show parsing details (dry run)" \
        3>&1 1>&2 2>&3)
    [[ -z "$mode" ]] && return

    local force="false"
    [[ "$mode" == "force" ]] && force="true"

    if [[ "$mode" == "debug" ]]; then
        IMPORT_DEBUG=true
        local tmplog
        tmplog="$(mktemp)"
        import_salt_roster "$roster" "$INVENTORY_CSV" "false" 2>"$tmplog"
        IMPORT_DEBUG=false
        dialog --title "Import Debug Output" --textbox "$tmplog" 25 80
        rm -f "$tmplog"
        return
    fi

    if [[ "$force" == true ]]; then
        dialog --yesno "WARNING: This will DELETE all existing hosts\nand reimport from roster.\n\nContinue?" 9 50 || return
    fi

    import_salt_roster "$roster" "$INVENTORY_CSV" "$force"

    inventory_load

    dialog --msgbox "Import complete.\n\nTotal hosts: $(inventory_count)" 8 40
    log_info "Roster import ($mode): $(inventory_count) hosts from $roster"
}
