#!/bin/bash
# ============================================================================
# SSH UI Manager — Inventory Management
# ============================================================================

declare -a INV_HOSTNAME INV_HOST_IP INV_PORT INV_USER INV_PRIV INV_PROXY INV_GROUP INV_ENV INV_NOTES

inventory_clear_arrays() {
    INV_HOSTNAME=(); INV_HOST_IP=(); INV_PORT=(); INV_USER=()
    INV_PRIV=(); INV_PROXY=(); INV_GROUP=(); INV_ENV=(); INV_NOTES=()
}

inventory_load() {
    inventory_clear_arrays
    [[ ! -f "$INVENTORY_CSV" ]] && return 1
    local line_num=0
    while IFS=',' read -r hostname host_ip port user priv proxy group env notes; do
        line_num=$((line_num + 1))
        [[ $line_num -eq 1 ]] && continue
        [[ -z "$hostname" || -z "$host_ip" ]] && continue
        INV_HOSTNAME+=("$hostname")
        INV_HOST_IP+=("$host_ip")
        INV_PORT+=("${port:-$DEFAULT_PORT}")
        INV_USER+=("${user:-$DEFAULT_USER}")
        INV_PRIV+=("${priv:-$DEFAULT_KEY}")
        INV_PROXY+=("$proxy")
        INV_GROUP+=("${group:-ungrouped}")
        INV_ENV+=("${env:-unknown}")
        INV_NOTES+=("$notes")
    done < "$INVENTORY_CSV"
    log_info "Loaded ${#INV_HOSTNAME[@]} hosts from inventory"
}

inventory_count() {
    echo "${#INV_HOSTNAME[@]}"
}

inventory_ssh_cmd() {
    local idx="$1"
    local override_user="${2:-}"
    local user="${override_user:-${INV_USER[$idx]}}"
    local cmd="ssh"

    [[ -n "${INV_PRIV[$idx]}" ]] && cmd+=" -i ${INV_PRIV[$idx]}"
    cmd+=" -p ${INV_PORT[$idx]}"
    cmd+=" -o StrictHostKeyChecking=no -o ConnectTimeout=10"

    if [[ -n "${INV_PROXY[$idx]}" ]]; then
        cmd+=" -o ProxyJump=${INV_PROXY[$idx]}"
    fi

    cmd+=" ${user}@${INV_HOST_IP[$idx]}"
    echo "$cmd"
}

# ---- Filtering ----
inventory_filter_indices() {
    local filter_type="$1"
    local filter_value="${2:-}"
    local indices=()
    local i

    for i in "${!INV_HOSTNAME[@]}"; do
        case "$filter_type" in
            all)
                indices+=("$i")
                ;;
            group)
                [[ "${INV_GROUP[$i]}" == "$filter_value" ]] && indices+=("$i")
                ;;
            env)
                [[ "${INV_ENV[$i]}" == "$filter_value" ]] && indices+=("$i")
                ;;
            search)
                local haystack="${INV_HOSTNAME[$i]} ${INV_HOST_IP[$i]} ${INV_GROUP[$i]} ${INV_ENV[$i]} ${INV_NOTES[$i]}"
                if [[ "${haystack,,}" == *"${filter_value,,}"* ]]; then
                    indices+=("$i")
                fi
                ;;
        esac
    done
    echo "${indices[@]}"
}

inventory_groups() {
    local -A seen
    local groups=()
    for g in "${INV_GROUP[@]}"; do
        if [[ -z "${seen[$g]+_}" ]]; then
            seen["$g"]=1
            groups+=("$g")
        fi
    done
    printf '%s\n' "${groups[@]}" | sort
}

inventory_envs() {
    local -A seen
    local envs=()
    for e in "${INV_ENV[@]}"; do
        if [[ -z "${seen[$e]+_}" ]]; then
            seen["$e"]=1
            envs+=("$e")
        fi
    done
    printf '%s\n' "${envs[@]}" | sort
}

# ---- CRUD ----
inventory_add() {
    local hostname="$1" host_ip="$2" port="${3:-}" user="${4:-}" priv="${5:-}" proxy="${6:-}" group="${7:-}" env="${8:-}" notes="${9:-}"

    [[ -z "$hostname" || -z "$host_ip" ]] && return 1

    for h in "${INV_HOSTNAME[@]}"; do
        [[ "$h" == "$hostname" ]] && { log_warn "Duplicate hostname: $hostname"; return 2; }
    done

    notes="${notes//,/;}"

    echo "${hostname},${host_ip},${port:-$DEFAULT_PORT},${user:-$DEFAULT_USER},${priv:-$DEFAULT_KEY},${proxy},${group:-ungrouped},${env:-unknown},${notes}" >> "$INVENTORY_CSV"
    log_info "Added host: $hostname ($host_ip)"
    inventory_load
}

inventory_delete() {
    local hostname="$1"
    local tmpfile
    tmpfile="$(mktemp)"
    register_cleanup "$tmpfile"

    head -1 "$INVENTORY_CSV" > "$tmpfile"
    tail -n +2 "$INVENTORY_CSV" | grep -v "^${hostname}," >> "$tmpfile"
    mv "$tmpfile" "$INVENTORY_CSV"
    log_info "Deleted host: $hostname"
    inventory_load
}

inventory_update() {
    local old_hostname="$1"
    shift
    inventory_delete "$old_hostname"
    inventory_add "$@"
}

inventory_sort() {
    local tmpfile
    tmpfile="$(mktemp)"
    register_cleanup "$tmpfile"
    head -1 "$INVENTORY_CSV" > "$tmpfile"
    tail -n +2 "$INVENTORY_CSV" | sort -t',' -k1,1 >> "$tmpfile"
    mv "$tmpfile" "$INVENTORY_CSV"
    log_info "Inventory sorted"
}
