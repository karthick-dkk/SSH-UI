#!/bin/bash
# ============================================================================
# SSH UI Manager — Credential Management (SQLite + AES-256-CBC)
# ============================================================================

cred_init_db() {
    if [[ ! -f "$CREDENTIALS_DB" ]]; then
        sqlite3 "$CREDENTIALS_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS credentials (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname    TEXT UNIQUE NOT NULL,
    username    TEXT NOT NULL,
    password    TEXT,
    key_path    TEXT,
    passphrase  TEXT,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS master_key (
    id          INTEGER PRIMARY KEY CHECK (id = 1),
    key_hash    TEXT NOT NULL,
    salt        TEXT NOT NULL
);
SQL
        chmod 600 "$CREDENTIALS_DB"
        log_info "Credentials database initialized"
    fi
}

_master_key_exists() {
    local count
    count=$(sqlite3 "$CREDENTIALS_DB" "SELECT COUNT(*) FROM master_key WHERE id=1;")
    [[ "$count" -gt 0 ]]
}

cred_setup_master() {
    if _master_key_exists; then
        return 0
    fi

    local pass1 pass2 salt key_hash

    pass1=$(dialog --insecure --passwordbox "Set Master Password for Credential Vault:" 10 50 3>&1 1>&2 2>&3) || return 1
    [[ -z "$pass1" ]] && { dialog --msgbox "Password cannot be empty." 6 40; return 1; }

    pass2=$(dialog --insecure --passwordbox "Confirm Master Password:" 10 50 3>&1 1>&2 2>&3) || return 1

    if [[ "$pass1" != "$pass2" ]]; then
        dialog --msgbox "Passwords do not match." 6 40
        return 1
    fi

    salt=$(openssl rand -hex 16)
    key_hash=$(echo -n "${pass1}${salt}" | openssl dgst -sha256 -hex 2>/dev/null | awk '{print $NF}')

    sqlite3 "$CREDENTIALS_DB" "INSERT OR REPLACE INTO master_key (id, key_hash, salt) VALUES (1, '$key_hash', '$salt');"
    export SSH_UI_MASTER_KEY="$pass1"
    log_info "Master password configured"
    return 0
}

cred_unlock() {
    [[ -n "${SSH_UI_MASTER_KEY:-}" ]] && return 0

    cred_init_db

    if ! _master_key_exists; then
        cred_setup_master
        return $?
    fi

    local pass salt stored_hash computed_hash
    pass=$(dialog --insecure --passwordbox "Enter Master Password:" 10 50 3>&1 1>&2 2>&3) || return 1
    [[ -z "$pass" ]] && return 1

    salt=$(sqlite3 "$CREDENTIALS_DB" "SELECT salt FROM master_key WHERE id=1;")
    stored_hash=$(sqlite3 "$CREDENTIALS_DB" "SELECT key_hash FROM master_key WHERE id=1;")
    computed_hash=$(echo -n "${pass}${salt}" | openssl dgst -sha256 -hex 2>/dev/null | awk '{print $NF}')

    if [[ "$computed_hash" != "$stored_hash" ]]; then
        dialog --msgbox "Incorrect master password." 6 40
        log_warn "Failed master password attempt"
        return 1
    fi

    export SSH_UI_MASTER_KEY="$pass"
    log_info "Credential vault unlocked"
    return 0
}

cred_encrypt() {
    local plaintext="$1"
    [[ -z "${SSH_UI_MASTER_KEY:-}" ]] && return 1
    echo -n "$plaintext" | openssl enc -${CIPHER} -pbkdf2 -iter ${PBKDF2_ITER} \
        -pass "pass:${SSH_UI_MASTER_KEY}" -a 2>/dev/null
}

cred_decrypt() {
    local ciphertext="$1"
    [[ -z "${SSH_UI_MASTER_KEY:-}" ]] && return 1
    echo -n "$ciphertext" | openssl enc -${CIPHER} -pbkdf2 -iter ${PBKDF2_ITER} \
        -pass "pass:${SSH_UI_MASTER_KEY}" -a -d 2>/dev/null
}

cred_store() {
    local hostname="$1" username="$2" password="${3:-}" key_path="${4:-}" passphrase="${5:-}"

    cred_unlock || return 1

    local enc_pass="" enc_phrase=""
    [[ -n "$password" ]]   && enc_pass=$(cred_encrypt "$password")
    [[ -n "$passphrase" ]] && enc_phrase=$(cred_encrypt "$passphrase")

    sqlite3 "$CREDENTIALS_DB" <<SQL
INSERT INTO credentials (hostname, username, password, key_path, passphrase, updated_at)
VALUES ('$hostname', '$username', '$enc_pass', '$key_path', '$enc_phrase', datetime('now'))
ON CONFLICT(hostname) DO UPDATE SET
    username='$username',
    password='$enc_pass',
    key_path='$key_path',
    passphrase='$enc_phrase',
    updated_at=datetime('now');
SQL
    log_info "Stored credentials for: $hostname"
}

cred_fetch() {
    local hostname="$1"
    cred_unlock || return 1

    local row
    row=$(sqlite3 -separator '|' "$CREDENTIALS_DB" \
        "SELECT username, password, key_path, passphrase FROM credentials WHERE hostname='$hostname';")
    [[ -z "$row" ]] && return 1

    local username enc_pass key_path enc_phrase
    IFS='|' read -r username enc_pass key_path enc_phrase <<< "$row"

    local password="" passphrase=""
    [[ -n "$enc_pass" ]]   && password=$(cred_decrypt "$enc_pass")
    [[ -n "$enc_phrase" ]] && passphrase=$(cred_decrypt "$enc_phrase")

    echo "${username}|${password}|${key_path}|${passphrase}"
}

cred_delete() {
    local hostname="$1"
    sqlite3 "$CREDENTIALS_DB" "DELETE FROM credentials WHERE hostname='$hostname';"
    log_info "Deleted credentials for: $hostname"
}

cred_list() {
    sqlite3 -separator '|' "$CREDENTIALS_DB" \
        "SELECT hostname, username, key_path, updated_at FROM credentials ORDER BY hostname;"
}

cred_has_entry() {
    local hostname="$1"
    local count
    count=$(sqlite3 "$CREDENTIALS_DB" "SELECT COUNT(*) FROM credentials WHERE hostname='$hostname';")
    [[ "$count" -gt 0 ]]
}
