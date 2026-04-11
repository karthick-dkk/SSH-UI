#!/bin/bash
# ============================================================================
# SSH UI Manager — Quick Commands
# ============================================================================

declare -A CMD_TEMPLATES=(
    ["logstash_status"]="systemctl status logstash --no-pager -l"
    ["logstash_restart"]="sudo systemctl restart logstash"
    ["logstash_logs"]="sudo journalctl -u logstash --no-pager -n 50"
    ["es_status"]="systemctl status elasticsearch --no-pager -l"
    ["es_restart"]="sudo systemctl restart elasticsearch"
    ["es_health"]="curl -sk https://localhost:9200/_cluster/health?pretty 2>/dev/null || curl -s http://localhost:9200/_cluster/health?pretty"
    ["es_indices"]="curl -sk https://localhost:9200/_cat/indices?v\\&s=index 2>/dev/null || curl -s http://localhost:9200/_cat/indices?v\\&s=index"
    ["es_nodes"]="curl -sk https://localhost:9200/_cat/nodes?v 2>/dev/null || curl -s http://localhost:9200/_cat/nodes?v"
    ["es_shards"]="curl -sk 'https://localhost:9200/_cat/shards?v&s=state' 2>/dev/null || curl -s 'http://localhost:9200/_cat/shards?v&s=state'"
    ["disk_usage"]="df -hT | grep -vE 'tmpfs|devtmpfs|squashfs|overlay'"
    ["disk_inodes"]="df -i | grep -vE 'tmpfs|devtmpfs'"
    ["cpu_load"]="top -bn1 | head -20"
    ["mem_usage"]="free -h"
    ["uptime"]="uptime"
    ["who_logged"]="w"
    ["dmesg_errors"]="sudo dmesg -T --level=err,warn | tail -30"
    ["journal_errors"]="sudo journalctl -p err --no-pager -n 30 --since '1 hour ago'"
    ["wazuh_status"]="sudo systemctl status wazuh-agent --no-pager -l 2>/dev/null || sudo systemctl status wazuh-manager --no-pager -l"
    ["filebeat_status"]="systemctl status filebeat --no-pager -l"
    ["salt_minion"]="sudo systemctl status salt-minion --no-pager -l"
    ["zabbix_agent"]="sudo systemctl status zabbix-agent2 --no-pager -l 2>/dev/null || sudo systemctl status zabbix-agent --no-pager -l"
    ["network_listen"]="ss -tlnp"
    ["process_top"]="ps aux --sort=-%mem | head -15"
)

cmd_show_menu() {
    local choice
    choice=$(dialog --title "Quick Commands" --menu \
        "Select command to execute on connected hosts:" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_MENU_HEIGHT \
        "1"  "Logstash — Status" \
        "2"  "Logstash — Restart" \
        "3"  "Logstash — Recent Logs" \
        "4"  "Elasticsearch — Status" \
        "5"  "Elasticsearch — Restart" \
        "6"  "Elasticsearch — Cluster Health" \
        "7"  "Elasticsearch — List Indices" \
        "8"  "Elasticsearch — Node Info" \
        "9"  "Elasticsearch — Shard Status" \
        "10" "Storage — Disk Usage" \
        "11" "Storage — Inode Usage" \
        "12" "System — CPU Load (top)" \
        "13" "System — Memory Usage" \
        "14" "System — Uptime" \
        "15" "System — Logged-in Users" \
        "16" "Logs — dmesg Errors (1hr)" \
        "17" "Logs — Journal Errors (1hr)" \
        "18" "Agent — Wazuh Status" \
        "19" "Agent — Filebeat Status" \
        "20" "Agent — Salt Minion Status" \
        "21" "Agent — Zabbix Agent Status" \
        "22" "Network — Listening Ports" \
        "23" "System — Top Processes by Memory" \
        "24" "Custom Command..." \
        3>&1 1>&2 2>&3)

    [[ -z "$choice" ]] && return 1

    local cmd=""
    case "$choice" in
        1)  cmd="${CMD_TEMPLATES[logstash_status]}" ;;
        2)  cmd="${CMD_TEMPLATES[logstash_restart]}" ;;
        3)  cmd="${CMD_TEMPLATES[logstash_logs]}" ;;
        4)  cmd="${CMD_TEMPLATES[es_status]}" ;;
        5)  cmd="${CMD_TEMPLATES[es_restart]}" ;;
        6)  cmd="${CMD_TEMPLATES[es_health]}" ;;
        7)  cmd="${CMD_TEMPLATES[es_indices]}" ;;
        8)  cmd="${CMD_TEMPLATES[es_nodes]}" ;;
        9)  cmd="${CMD_TEMPLATES[es_shards]}" ;;
        10) cmd="${CMD_TEMPLATES[disk_usage]}" ;;
        11) cmd="${CMD_TEMPLATES[disk_inodes]}" ;;
        12) cmd="${CMD_TEMPLATES[cpu_load]}" ;;
        13) cmd="${CMD_TEMPLATES[mem_usage]}" ;;
        14) cmd="${CMD_TEMPLATES[uptime]}" ;;
        15) cmd="${CMD_TEMPLATES[who_logged]}" ;;
        16) cmd="${CMD_TEMPLATES[dmesg_errors]}" ;;
        17) cmd="${CMD_TEMPLATES[journal_errors]}" ;;
        18) cmd="${CMD_TEMPLATES[wazuh_status]}" ;;
        19) cmd="${CMD_TEMPLATES[filebeat_status]}" ;;
        20) cmd="${CMD_TEMPLATES[salt_minion]}" ;;
        21) cmd="${CMD_TEMPLATES[zabbix_agent]}" ;;
        22) cmd="${CMD_TEMPLATES[network_listen]}" ;;
        23) cmd="${CMD_TEMPLATES[process_top]}" ;;
        24)
            cmd=$(dialog --inputbox "Enter custom command:" 10 60 3>&1 1>&2 2>&3)
            [[ -z "$cmd" ]] && return 1
            ;;
    esac

    echo "$cmd"
}

cmd_execute_on_session() {
    if [[ -z "${CURRENT_TMUX_SESSION:-}" ]]; then
        dialog --msgbox "No active tmux session.\nConnect to hosts first." 7 45
        return 1
    fi

    local cmd
    cmd="$(cmd_show_menu)" || return 1

    case "$cmd" in
        *restart*|*stop*|*kill*|*reboot*|*shutdown*)
            dialog --yesno "⚠ Destructive command detected:\n\n$cmd\n\nProceed?" 10 60 || return 1
            ;;
    esac

    tmux_send_command "$cmd"
    dialog --msgbox "Command sent to all panes:\n\n$cmd" 8 60
    log_info "Executed quick command: $cmd"
}
