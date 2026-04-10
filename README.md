# SSH UI Manager v1.0.0

A terminal-based SSH management tool built with **dialog** and **tmux** for managing multi-host SSH connections, encrypted credential storage, and quick DevOps command execution — all from a single interactive TUI.
**Author:** Karthick-Dkk  
**Stack:** Bash, dialog, tmux, SQLite, OpenSSL

## SSH UI:
<img width="1221" height="597" alt="image" src="https://github.com/user-attachments/assets/9cffb56b-5135-4ab8-b4cd-72bac624f17c" />

## SSH Login:
<img width="1196" height="733" alt="image" src="https://github.com/user-attachments/assets/c4e2a84d-4797-4991-9358-6d5c24021408" />

## Muli-Select mode - Tmux mode
<img width="1329" height="685" alt="image" src="https://github.com/user-attachments/assets/088580eb-29ef-4502-8db6-eb57f9f794f9" />

---

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Usage](#usage)
- [Keyboard Controls](#keyboard-controls)
- [Architecture](#architecture)
- [Inventory Management](#inventory-management)
- [Salt Roster Import](#salt-roster-import)
- [Credential Vault](#credential-vault)
- [Quick Commands](#quick-commands)
- [tmux Session Management](#tmux-session-management)
- [Configuration](#configuration)
- [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)
- [Dependencies](#dependencies)
- [Project Structure](#project-structure)
- [Security](#security)
- [License](#license)

---

## Features

- **Single-Host SSH** — Highlight a host, press Enter, connect directly (no tmux overhead)
- **Multi-Host SSH via tmux** — Select MULTI mode, mark hosts with spacebar, connect to all simultaneously in tiled tmux panes
- **Synchronized Panes** — Type once, command executes on all connected hosts
- **Credential Vault** — Store usernames, passwords, and key passphrases encrypted with AES-256-CBC in SQLite
- **Auto-Fill Credentials** — Saved usernames automatically populate the login prompt
- **CSV Inventory** — Structured host inventory with group and environment fields
- **Salt Roster Import** — Parse `/etc/salt/roster` directly into the inventory with auto-group detection
- **Host Filtering** — Filter hosts by group, environment, or keyword search
- **Quick Commands** — One-click execution of common DevOps commands (Logstash, Elasticsearch, disk, CPU, memory)
- **Custom Commands** — Run any ad-hoc command across all connected hosts
- **Session Management** — Reattach to existing tmux sessions, kill all sessions
- **CLI Mode** — List hosts, direct connect, and import roster without launching the UI

---

## Screenshots

### Main Menu
```
┌──────────────────────────────────────────────────────┐
│              SSH UI Manager v1.0.0                    │
│          Hosts: 371  |  Active tmux sessions: 2      │
│──────────────────────────────────────────────────────│
│  1. Connect to Hosts           [SSH + tmux]          │
│  2. Quick Commands             [on active session]   │
│  3. Reattach tmux Session      [existing]            │
│  4. Manage Inventory           [add/edit/delete]     │
│  5. Import from Salt Roster    [/etc/salt/roster]    │
│  6. Manage Credentials         [encrypted vault]    │
│  7. Kill All SSH Sessions      [cleanup]             │
│  0. Exit                                             │
└──────────────────────────────────────────────────────┘
```

### Host Selection (Single Connect)
```
┌─────────────────────────────────────────────────────────────────┐
│  Select Host  |  Hosts: 371  |  Filter: all                    │
│─────────────────────────────────────────────────────────────────│
│  Enter = Connect to highlighted host                            │
│  MULTI = Select multiple hosts with * for tmux                  │
│─────────────────────────────────────────────────────────────────│
│  MULTI    >>> Multi-Select Mode (tmux) <<<                      │
│  0        elk-node-01       10.0.1.10  [elasticsearch/prod]     │
│  1        elk-node-02       10.0.1.11  [elasticsearch/prod]     │
│  2        logstash-01       10.0.1.20  [logstash/prod]          │
│  3        app-srv-01        10.0.2.10  [application/staging]    │
│  ...                                                             │
└─────────────────────────────────────────────────────────────────┘
```

### Multi-Select Checklist
```
┌─────────────────────────────────────────────────────────────────┐
│  Multi-Select (SPACE=mark *, ENTER=confirm)                     │
│─────────────────────────────────────────────────────────────────│
│  [ ] elk-node-01       10.0.1.10     [elasticsearch/prod]       │
│  [ ] elk-node-02       10.0.1.11     [elasticsearch/prod]       │
│  [*] logstash-01       10.0.1.20     [logstash/prod]            │
│  [*] logstash-02       10.0.1.21     [logstash/prod]            │
│  [*] logstash-03       10.0.1.22     [logstash/prod]            │
│  [ ] app-srv-01        10.0.2.10     [application/staging]      │
│─────────────────────────────────────────────────────────────────│
│  <OK>                                           <Cancel>        │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
    tmux session with 3 tiled panes
    ┌──────────────┬──────────────┐
    │ logstash-01  │ logstash-02  │
    │              ├──────────────┤
    │              │ logstash-03  │
    └──────────────┴──────────────┘
```

### Quick Commands Submenu
```
┌─────────────────────────────────────────┐
│  Quick Commands                         │
│─────────────────────────────────────────│
│  1.  Logstash — Status                  │
│  2.  Logstash — Restart                 │
│  3.  Logstash — Recent Logs             │
│  4.  Elasticsearch — Status             │
│  5.  Elasticsearch — Restart            │
│  6.  Elasticsearch — Cluster Health     │
│  7.  Elasticsearch — List Indices       │
│  ...                                    │
│  24. Custom Command...                  │
└─────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

- Linux (Ubuntu/Debian/RHEL/CentOS)
- Root or sudo access
- Bash 4.0+

### Install

```bash
# Extract the package
tar xzf ssh-ui-manager-v1.0.0-final.tar.gz
cd ssh-ui

# Run installer (as root)
sudo bash install.sh
```

The installer will:
1. Check and install missing dependencies (dialog, tmux, sqlite3)
2. Copy files to `/opt/ssh-ui/`
3. Create symlink `/usr/local/bin/ssh-ui`
4. Preserve existing data on reinstall
5. Optionally import from `/etc/salt/roster`

### Verify Installation

```bash
ssh-ui --version
ssh-ui --help
```

### Uninstall

```bash
sudo rm -f /usr/local/bin/ssh-ui
sudo rm -rf /opt/ssh-ui
```

---

## Usage

### Interactive Mode (TUI)

```bash
ssh-ui
```

### CLI Mode

```bash
# List all hosts
ssh-ui -l

# Direct connect to a host by name
ssh-ui -c elk-node-01

# Refresh inventory from salt roster
ssh-ui -r

# Import from a custom roster file
ssh-ui -i /path/to/custom/roster

# Show help
ssh-ui -h
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_UI_ROSTER` | `/etc/salt/roster` | Override roster file path |
| `SSH_UI_DATA` | `./data` | Override data directory |

```bash
# Example: use a different roster file
SSH_UI_ROSTER=/etc/salt/roster.prod ssh-ui -r
```

---

## Keyboard Controls

### dialog Menus

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate list |
| `Enter` | Confirm selection / Connect to highlighted host |
| `Space` | Toggle selection (checklist mode) |
| `Tab` | Switch between OK / Cancel buttons |
| `Esc` | Cancel / Go back |
| `Home` | Jump to first item (if supported by dialog version) |
| `End` | Jump to last item (if supported by dialog version) |
| `PgUp` / `PgDn` | Scroll page |

### tmux (after connecting)

| Key | Action |
|-----|--------|
| `Ctrl+B` then `D` | Detach from session (keeps connections alive) |
| `Ctrl+B` then `Arrow` | Switch between panes |
| `Ctrl+B` then `Z` | Zoom/unzoom current pane |
| `Ctrl+B` then `[` | Scroll mode (q to exit) |
| `Ctrl+B` then `X` | Kill current pane |
| `Ctrl+D` | Close current SSH session + pane |

---

## Architecture

### Data Flow

```
/etc/salt/roster ──► import-roster.sh ──► inventory.csv
                                              │
                                              ▼
                         ssh-ui.sh ──► dialog menu ──► tmux session(s)
                             │              │                │
                             ▼              ▼                ▼
                      credentials.db   Filter/Search    SSH to host(s)
                      (SQLite + AES)   by group/env     parallel panes
```

### Connection Flow

```
User selects host(s)
        │
        ├── Single host ──► inventory_ssh_cmd() ──► eval "ssh ..." (direct)
        │
        └── Multi host ──► tmux new-session
                               ├── Pane 1: ssh host1
                               ├── Pane 2: ssh host2
                               ├── Pane 3: ssh host3
                               └── select-layout tiled
```

### Credential Flow

```
Host selected → Check credentials.db for saved entry
  ├─ Found → Auto-fill username in dialog prompt
  │          └─ Password stored? → Use sshpass for auto-login
  └─ Not found → Prompt username or use inventory default
                  └─ SSH key auth (from inventory priv_key field)
```

---

## Inventory Management

### CSV Schema

The inventory is stored in `data/inventory.csv` with the following columns:

```csv
hostname,host_ip,port,user,priv_key,proxy_jump,group,environment,notes
```

| Column | Required | Default | Description |
|--------|----------|---------|-------------|
| `hostname` | Yes | — | Unique identifier for the host |
| `host_ip` | Yes | — | IP address or hostname to connect to |
| `port` | No | `22` | SSH port |
| `user` | No | `root` | Default SSH username |
| `priv_key` | No | `/root/.ssh/id_ecdsa` | Path to SSH private key |
| `proxy_jump` | No | — | ProxyJump host (e.g., `admin@bastion:2222`) |
| `group` | No | `ungrouped` | Logical group for filtering |
| `environment` | No | `production` | Environment tag |
| `notes` | No | — | Free-text notes |

### Example Inventory

```csv
hostname,host_ip,port,user,priv_key,proxy_jump,group,environment,notes
prod-app1-frontend,10.1.1.10,22,admin,/root/.ssh/id_ecdsa,,app1,production,
dev-app1-frontend,10.1.1.20,22,dev_user,/root/.ssh/id_ecdsa,,app1,dev,
dev-app2-frontend,10.1.1.21,22,dev_admin,/root/.ssh/id_ecdsa,,app2,dev,
prod-app2-frontend,10.1.1.11,22,sysadmin,/root/.ssh/id_ecdsa,,app2,production,
prod-db1,10.1.1.15,22,karthick,/root/.ssh/id_ecdsa,,app1,production,
test-db1,10.1.1.25,22,test_admin,/root/.ssh/id_ecdsa,,db1,test,
```

### Managing Hosts

**Via the UI:**
- Main Menu → Option 4 → Add / Edit / Delete / View / Sort

**Via CLI:**
- Edit the CSV directly: `nano /opt/ssh-ui/data/inventory.csv`
- Import from roster: `ssh-ui -r`

### Filtering

When connecting, you can filter the host list by:
- **All** — Show every host
- **Group** — Show only hosts matching a group (e.g., `elasticsearch`)
- **Environment** — Show only hosts matching an environment (e.g., `production`)
- **Search** — Free-text keyword search across hostname, IP, group, environment, and notes

---

## Salt Roster Import

The tool can parse `/etc/salt/roster` files (YAML-like format) into the CSV inventory.

### Supported Roster Format

```yaml
prod-app1-frontend:
  host: 10.1.1.10
  port: 1656
  user: admin
  priv: /root/.ssh/id_ecdsa
  ssh_options:
     - ProxyJump=karthick@172.18.1.2

dev-app1-frontend:
  host: 172.18.7.2
  user: warder
  priv: /root/.ssh/id_ecdsa

test-db1:
  host: 10.1.1.25
  user: warder
  priv: /root/.ssh/id_ecdsa
```

### Import Methods

```bash
# CLI — wipe and reimport all hosts
ssh-ui -r

# CLI — import from custom file
ssh-ui -i /path/to/roster

# Standalone with debug output
bash /opt/ssh-ui/scripts/import-roster.sh --debug --force

# UI — Main Menu → Option 5 (choose Merge / Force / Debug mode)
```

### Import Modes

| Mode | Behavior |
|------|----------|
| **Merge** | Keep existing hosts, add only new ones (skip duplicates) |
| **Force** | Wipe entire CSV and reimport everything from roster |
| **Debug** | Show line-by-line parsing details without modifying inventory |

### Auto-Group Detection

The importer auto-assigns groups based on hostname patterns:

| Hostname Pattern | Assigned Group |
|-----------------|----------------|
| `*elk*`, `*elastic*`, `*es-*` | `elasticsearch` |
| `*logstash*`, `*ls-*` | `logstash` |
| `*kibana*`, `*kb-*` | `kibana` |
| `*wazuh*`, `*wz-*` | `wazuh` |
| `*zabbix*`, `*zbx-*` | `zabbix` |
| `*salt*`, `*master*` | `saltstack` |
| `*jump*`, `*bastion*`, `*gw-*` | `bastion` |
| `*forwarder*`, `*fwd*` | `forwarder` |
| `*app*`, `*web*`, `*api*` | `application` |
| `*db*`, `*mysql*`, `*mongo*` | `database` |
| `*docker*`, `*kube*`, `*k8s*` | `containers` |

---

## Credential Vault

Passwords and key passphrases are stored encrypted in a SQLite database.

### Encryption Details

```
Master Password (prompted once per session)
        │
        ▼
PBKDF2 (100,000 iterations) + random salt → AES-256 key
        │
        ▼
openssl enc -aes-256-cbc -pbkdf2 → base64 encoded → SQLite
```

| Property | Detail |
|----------|--------|
| Cipher | AES-256-CBC |
| Key derivation | PBKDF2 with 100,000 iterations |
| Master password | SHA-256 hash + random salt stored for verification |
| Storage | SQLite database (`data/credentials.db`) |
| File permissions | `chmod 600` |
| Session key | Held in `$SSH_UI_MASTER_KEY` env var, cleared on exit |

### Managing Credentials

**Via the UI:**
- Main Menu → Option 6 → Store / View / Delete / Change Master Password

**Stored fields per host:**
- Username
- Password (encrypted)
- SSH key path
- Key passphrase (encrypted)

### How Credentials Are Used

1. When you connect to a host, the tool checks `credentials.db` for a saved entry
2. If found, the stored **username** auto-fills in the login prompt
3. If a **password** is stored, `sshpass` is used for automatic authentication
4. If no password, SSH key authentication is used (from inventory `priv_key` field)

---

## Quick Commands

Pre-configured DevOps commands that can be executed on all connected tmux panes simultaneously.

| # | Command | What It Runs |
|---|---------|-------------|
| 1 | Logstash — Status | `systemctl status logstash --no-pager -l` |
| 2 | Logstash — Restart | `sudo systemctl restart logstash` |
| 3 | Logstash — Recent Logs | `journalctl -u logstash --no-pager -n 50` |
| 4 | Elasticsearch — Status | `systemctl status elasticsearch --no-pager -l` |
| 5 | Elasticsearch — Restart | `sudo systemctl restart elasticsearch` |
| 6 | Elasticsearch — Cluster Health | `curl localhost:9200/_cluster/health?pretty` |
| 7 | Elasticsearch — List Indices | `curl localhost:9200/_cat/indices?v` |
| 8 | Elasticsearch — Node Info | `curl localhost:9200/_cat/nodes?v` |
| 9 | Elasticsearch — Shard Status | `curl localhost:9200/_cat/shards?v` |
| 10 | Storage — Disk Usage | `df -hT` (filtered) |
| 11 | Storage — Inode Usage | `df -i` (filtered) |
| 12 | System — CPU Load | `top -bn1 \| head -20` |
| 13 | System — Memory Usage | `free -h` |
| 14 | System — Uptime | `uptime` |
| 15 | System — Logged-in Users | `w` |
| 16 | Logs — dmesg Errors | `dmesg -T --level=err,warn \| tail -30` |
| 17 | Logs — Journal Errors | `journalctl -p err -n 30 --since '1 hour ago'` |
| 18 | Agent — Wazuh Status | `systemctl status wazuh-agent` |
| 19 | Agent — Filebeat Status | `systemctl status filebeat` |
| 20 | Agent — Salt Minion | `systemctl status salt-minion` |
| 21 | Agent — Zabbix Agent | `systemctl status zabbix-agent2` |
| 22 | Network — Listening Ports | `ss -tlnp` |
| 23 | System — Top Processes | `ps aux --sort=-%mem \| head -15` |
| 24 | Custom Command | Enter any command |

Destructive commands (restart, stop, kill, reboot) trigger a confirmation dialog.

---

## tmux Session Management

### Session Naming

Sessions are named with the pattern: `ssh-mgr-<first5chars>-<PID>`

Example: `ssh-mgr-logst-12345` for a session started on `logstash-01`

### Managing Sessions

| Action | How |
|--------|-----|
| Detach from session | `Ctrl+B` then `D` |
| Reattach via UI | Main Menu → Option 3 |
| Reattach via CLI | `tmux attach -t ssh-mgr-logst-12345` |
| List sessions | `tmux list-sessions` |
| Kill all sessions | Main Menu → Option 7 |

### Sync Panes

When connecting to multiple hosts, you're prompted to choose:
- **Independent panes** — Each pane operates separately
- **Synchronized panes** — Keystrokes are sent to all panes simultaneously

Toggle sync inside tmux: `Ctrl+B` then `:setw synchronize-panes`

---

## Configuration

### Default Settings (lib/config.sh)

| Setting | Default | Description |
|---------|---------|-------------|
| `DEFAULT_PORT` | `22` | SSH port when not specified |
| `DEFAULT_USER` | `root` | SSH user when not specified |
| `DEFAULT_KEY` | `/root/.ssh/id_ecdsa` | SSH key when not specified |
| `ROSTER_FILE` | `/etc/salt/roster` | Default roster file path |
| `CIPHER` | `aes-256-cbc` | Encryption cipher |
| `PBKDF2_ITER` | `100000` | Key derivation iterations |

### Customizing Defaults

Edit `/opt/ssh-ui/lib/config.sh` to change defaults:

```bash
sudo nano /opt/ssh-ui/lib/config.sh
```

---

## Backup and Restore

### Backup

```bash
# Full backup (scripts + data + credentials)
sudo tar czf ~/ssh-ui-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C / opt/ssh-ui/

# Data only
sudo cp /opt/ssh-ui/data/inventory.csv ~/inventory.csv.bak
sudo cp /opt/ssh-ui/data/credentials.db ~/credentials.db.bak
```

### Restore

```bash
# Full restore — extracts to /opt/ssh-ui/
sudo tar xzf ~/ssh-ui-backup-YYYYMMDD-HHMMSS.tar.gz -C /

# Data only
sudo cp ~/inventory.csv.bak /opt/ssh-ui/data/inventory.csv
sudo cp ~/credentials.db.bak /opt/ssh-ui/data/credentials.db
```

### Reinstall Without Data Loss

The `install.sh` script automatically backs up and restores `inventory.csv` and `credentials.db` during reinstall.

---

## Troubleshooting

### ssh-ui command not found

```bash
# Check if symlink exists
ls -la /usr/local/bin/ssh-ui

# Recreate if missing
sudo ln -sf /opt/ssh-ui/ssh-ui.sh /usr/local/bin/ssh-ui
```

### Empty host list after reinstall

```bash
# Reimport from roster
ssh-ui -r

# Or check if CSV has data
cat /opt/ssh-ui/data/inventory.csv
```

### SSH connection fails via UI but works manually

```bash
# Check generated SSH command
bash -c '
cd /opt/ssh-ui
source lib/config.sh
source lib/inventory.sh
ensure_dirs
inventory_load
echo "CMD: $(inventory_ssh_cmd 0)"
'

# Test the command manually
ssh -i /root/.ssh/id_ecdsa -p 22 -o StrictHostKeyChecking=no user@host
```

### Credential vault errors

```bash
# Reinitialize the database
rm /opt/ssh-ui/data/credentials.db
ssh-ui  # Will recreate on first access
```

### Debug import issues

```bash
# Run import with debug output
IMPORT_DEBUG=true bash /opt/ssh-ui/scripts/import-roster.sh --debug --force
```

### View logs

```bash
tail -50 /opt/ssh-ui/logs/ssh-ui.log
```

---

## Dependencies

| Package | Required | Purpose | Install |
|---------|----------|---------|---------|
| `dialog` | Yes | Terminal UI menus, checklists, forms | `apt install dialog` |
| `tmux` | Yes | Terminal multiplexer for multi-host | `apt install tmux` |
| `sqlite3` | Yes | Credential database storage | `apt install sqlite3` |
| `openssl` | Yes | AES-256 encryption | Pre-installed |
| `ssh` | Yes | SSH client | Pre-installed |
| `sshpass` | Optional | Password-based SSH automation | `apt install sshpass` |
| `jq` | Optional | JSON formatting for ES health | `apt install jq` |

---

## Project Structure

```
/opt/ssh-ui/
├── ssh-ui.sh                 # Main entry point (200 lines)
├── install.sh                # Installation script (142 lines)
├── README.md                 # This file
├── lib/
│   ├── config.sh             # Global config, paths, logging (98 lines)
│   ├── inventory.sh          # CSV CRUD, filtering, SSH cmd builder (154 lines)
│   ├── dialog_ui.sh          # All dialog menus and forms (586 lines)
│   ├── tmux_session.sh       # tmux create/split/tile/sync/attach (191 lines)
│   ├── credentials.sh        # SQLite + AES-256 credential vault (162 lines)
│   └── commands.sh           # Quick command templates + menu (117 lines)
├── scripts/
│   └── import-roster.sh      # Salt roster parser (223 lines)
├── data/
│   ├── inventory.csv         # Host inventory (persistent)
│   └── credentials.db        # Encrypted credentials (persistent)
└── logs/
    └── ssh-ui.log            # Activity log
```

**Total: ~1,918 lines of Bash**

### Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| `ssh-ui.sh` | Entry point, CLI argument parsing, main menu loop |
| `config.sh` | Paths, defaults, logging functions, cleanup trap |
| `inventory.sh` | Load/add/edit/delete hosts, build SSH commands, filtering |
| `dialog_ui.sh` | All user-facing dialog menus, forms, and input boxes |
| `tmux_session.sh` | Create sessions, split panes, tile layout, sync, attach |
| `credentials.sh` | Master password, AES encrypt/decrypt, CRUD operations |
| `commands.sh` | Command templates, quick command menu, send to panes |
| `import-roster.sh` | Parse salt roster YAML, validate, dedup, write CSV |

---

## Security

| Area | Implementation |
|------|---------------|
| Master password | SHA-256 hash + random salt stored in DB — never plaintext |
| Session key | Derived via PBKDF2 (100K iterations), held in env var, cleared on exit via `trap` |
| Passwords at rest | AES-256-CBC encrypted, base64 encoded in SQLite |
| Passwords in transit | Passed via `sshpass -e` (env var) — never visible in CLI args or `/proc` |
| Database permissions | `chmod 600` on `credentials.db` |
| SSH command safety | Built from validated CSV fields, no raw user input in `eval` |
| Temp files | Created with `mktemp`, cleaned up via `trap EXIT` |
| ProxyJump | Supported natively via `-o ProxyJump=` in SSH command |

---

## License
Open Source
