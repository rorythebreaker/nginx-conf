# pngxconf — Nginx Management System

Interactive TUI system for managing nginx: virtual hosts, SSL certificates, and `nginx.conf` editing with change history. Invoked by the `pngxconf` command from any directory.

**Version:** 1.1
**Components:** `install.sh` · `pngxconf` · `ssl-wizard.sh`

---

## Requirements

| Component | Minimum | Notes |
|---|---|---|
| OS | Linux | Debian/Ubuntu, RHEL/Rocky/Fedora, Arch, openSUSE |
| bash | 4.0+ | `bash --version` |
| nginx | any recent version | installer checks and offers to install |
| openssl | any | required for certificates |
| curl | any | required by `ssl-wizard.sh` for acme.sh |
| socat | optional | only needed for acme.sh standalone mode |
| root | required | all operations require root privileges |

---

## Installation

In the directory containing all three files (`install.sh`, `pngxconf`, `ssl-wizard.sh`):

```bash
sudo bash install.sh
```

The installer will:
1. Detect the Linux distribution
2. Check for bash 4+, nginx, openssl, curl, socat
3. Offer to install missing packages via `apt` / `dnf` / `pacman` / `zypper`
4. Create all required directories with correct permissions
5. Copy `pngxconf` to `/usr/local/bin/pngxconf`
6. Copy `ssl-wizard.sh` to `/usr/local/lib/pngxconf/ssl-wizard.sh`
7. Initialise state files in `/var/lib/pngxconf/`
8. Verify that `pngxconf` is available in `PATH`

After installation, the tool runs from any directory:

```bash
sudo pngxconf
sudo pngxconf -h
```

---

## Uninstallation

```bash
sudo bash install.sh --uninstall
```

Removes the binary and the SSL wizard. Separately asks whether to remove `/var/lib/pngxconf/` (state files).
Nginx configs and certificates under `/etc/nginx/` are **not** removed.

---

## First Run

On the first launch, `pngxconf` automatically performs an environment check:

- nginx binary (searches `/usr/sbin/`, `/usr/local/sbin/`, `/usr/bin/`)
- `/etc/nginx/nginx.conf`
- `/etc/nginx/conf.d/` — created if missing
- `/etc/nginx/ssl/` — created with permissions `700` if missing
- `openssl`
- `ssl-wizard.sh`

The completion flag is saved to `/var/lib/pngxconf/state.conf`. The check does not run again on subsequent launches.

**On every subsequent launch** the tool silently verifies:
- Existence of all registered site `.conf` files
- Existence of certificates and keys referenced in the database
- Any discrepancies are written to `/var/lib/pngxconf/pngxconf.log`

---

## File Layout

Strictly follows the nginx standard:

```
/usr/local/bin/
└── pngxconf                           main binary

/usr/local/lib/pngxconf/
└── ssl-wizard.sh                      SSL wizard

/etc/nginx/
├── nginx.conf                         main nginx config
├── conf.d/
│   ├── site1.conf                     virtual hosts
│   └── site2.conf
├── ssl/
│   ├── example.com/
│   │   ├── example.com.crt            certificate
│   │   ├── example.com.key            private key
│   │   └── example.com.chain.pem     chain (optional)
│   └── api.example.com/
│       ├── api.example.com.crt
│       └── api.example.com.key
└── pngxconf-backups/
    ├── nginx.conf.20240115_143022.worker_processes
    └── nginx.conf.20240115_150311.gzip_recommended

/var/lib/pngxconf/
├── state.conf                          system state variables
├── sites.db                            virtual hosts database
├── certs.db                            certificates database
└── pngxconf.log                        operation log
```

---

## TUI Navigation

| Input | Action |
|---|---|
| `1`–`9` | select menu item |
| `0` | back (from any submenu to the parent) |
| `b` | back (inside input prompts and lists) |
| `Enter` | confirm / accept default |
| `y` / `n` | confirmation |

The `b` key works on **every level** — from the main menu down to nested input forms. In the main menu, `0` exits the program.

---

## Main Menu

```
pngxconf v1.1  │  Nginx Management System

nginx 1.24.0  │  status: running  │  sites: 3  │  certs: 2

  1)  nginx.conf Management      — workers, http, gzip, log formats
  2)  Virtual Hosts              — create, enable, disable, delete
  3)  SSL Certificates           — create, upload, inspect, expiry
  4)  nginx Control              — test, reload, restart, stop, start
  5)  System Status
  0)  Exit
```

---

## Section 1 — nginx.conf Management

Structured editing of `/etc/nginx/nginx.conf` via submenus. **A timestamped backup is created automatically before every change** in `/etc/nginx/pngxconf-backups/` with the name `nginx.conf.YYYYMMDD_HHMMSS.<reason>`.

### Submenus

| Item | Context | Directives |
|---|---|---|
| View current nginx.conf | — | view first 120 lines |
| Edit core worker settings | `main` | `worker_processes`, `worker_rlimit_nofile`, `user` |
| Edit events block settings | `events {}` | `worker_connections`, `multi_accept`, `use` |
| Edit http block global | `http {}` | `server_tokens`, `keepalive_timeout`, `client_max_body_size`, `sendfile`, `tcp_nopush`, `types_hash_max_size` |
| Edit log formats | `http {}` | `log_format combined_plus`, `log_format json` |
| Edit gzip settings | `http {}` | `gzip`, `gzip_comp_level`, `gzip_min_length`, `gzip_vary`, `gzip_proxied`, `gzip_types` |
| Apply / reload nginx | — | `nginx -t` then `nginx -s reload` |
| Test nginx configuration | — | `nginx -t` |
| View change history | — | list of backups, restore |

### Edit Logic

If a directive already exists in the file, its value is replaced via `sed`. If missing, it is inserted after the opening brace of the relevant context. Every change:
1. Creates a backup
2. Updates `state.conf` with a timestamp
3. Writes an entry to `pngxconf.log`

### Restoring from History

The "View change history" submenu lists up to 20 most recent backups sorted by date. When restoring, a backup of the current version is created first with the `pre_restore` tag, then the chosen backup is copied over `nginx.conf`.

---

## Section 2 — Virtual Hosts

Management of files in `/etc/nginx/conf.d/`. Each virtual host is registered in `sites.db`.

### Creating a Virtual Host

The tool prompts for:
1. **Name** (identifier, letters/digits/`-`/`_`) → file `/etc/nginx/conf.d/<name>.conf`
2. **Site type:**

| Type | Description | Content |
|---|---|---|
| Reverse proxy | HTTP proxy to an internal IP:port | `upstream` plus `proxy_pass` |
| Static site | serves static files | `root` plus `try_files` |
| Reverse proxy plus SSL | HTTPS proxy | above plus SSL block |
| HTTP redirect | 301 redirect | `return 301 ...` |

3. **server_name** — domain or IP
4. **Listen port** — default 80, or 443 for SSL
5. For proxy: **Upstream IP** and **Upstream port**
6. For SSL: interactive picker for certificate and key from `/etc/nginx/ssl/` (or manual path entry)

After creation, `nginx -t` runs and a reload is offered.

### Generated Config (Reverse proxy plus SSL)

```nginx
upstream mysite_upstream {
    server 10.0.0.5:3000;
    keepalive 32;
}

server {
    listen      443 ssl;
    listen      [::]:443 ssl;
    server_name example.com;

    server_tokens off;

    ssl_certificate         /etc/nginx/ssl/example.com/example.com.crt;
    ssl_certificate_key     /etc/nginx/ssl/example.com/example.com.key;
    ssl_protocols           TLSv1.2 TLSv1.3;
    ssl_ciphers             ECDHE-ECDSA-AES128-GCM-SHA256:...;
    ssl_prefer_server_ciphers on;
    ssl_session_cache       shared:SSL:10m;
    ssl_session_timeout     1d;
    ssl_session_tickets     off;

    add_header X-Frame-Options        "SAMEORIGIN"                      always;
    add_header X-Content-Type-Options "nosniff"                         always;
    add_header X-XSS-Protection       "1; mode=block"                   always;
    add_header Referrer-Policy        "strict-origin-when-cross-origin" always;

    access_log  /var/log/nginx/example.com_access.log;
    error_log   /var/log/nginx/example.com_error.log warn;

    location / {
        proxy_pass              http://mysite_upstream;
        proxy_http_version      1.1;
        proxy_set_header        Host              $host;
        proxy_set_header        X-Real-IP         $remote_addr;
        proxy_set_header        X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto $scheme;
        proxy_set_header        Connection        "";
        proxy_read_timeout      60s;
        proxy_connect_timeout   10s;
        proxy_send_timeout      60s;
        proxy_buffering         on;
        proxy_buffer_size       4k;
        proxy_buffers           8 4k;
    }
}
```

### Enable / Disable

- **Disable** renames `site.conf` to `site.conf.disabled` (nginx stops reading it)
- **Enable** renames it back
- In both cases a reload is offered
- Status is synced to `sites.db`

### Delete

Removes `.conf` and `.conf.disabled` from disk, plus the record from `sites.db`. Certificates in `/etc/nginx/ssl/` are **not** deleted.

### Check all site configs

For each site the tool verifies:
- existence of `.conf` or `.conf.disabled`
- existence of `cert` and `key` (if bound)
- finally runs `nginx -t`

---

## Section 3 — SSL Certificates

Certificate management. Database at `/var/lib/pngxconf/certs.db`.

### Create Certificate — via ssl-wizard.sh

Runs `ssl-wizard.sh` as a subprocess. After the wizard exits, `pngxconf` compares the contents of `/etc/nginx/ssl/` before and after — any new files are offered for registration in the database.

`ssl-wizard.sh` supports:
- **Let's Encrypt**: standalone, webroot, nginx mode, wildcard manual DNS, wildcard Cloudflare
- **Self-signed**: simple (RSA no passphrase), RSA 2048/3072/4096, ECDSA P-256/P-384/P-521, Ed25519, Local CA plus signed cert
- **Utilities**: RSA / ECDSA / Ed25519 key generation, random bytes (base64 / hex)

Search order for `ssl-wizard.sh`:
1. Path from `state.conf` (`SSL_WIZARD_PATH`)
2. `/usr/local/lib/pngxconf/ssl-wizard.sh` ← recommended location
3. Directory next to the `pngxconf` binary
4. `/var/lib/pngxconf/ssl-wizard.sh`
5. Manual path entry if not found

### Upload / Register

Loading existing certificates:
1. Enter record name and domain
2. `/etc/nginx/ssl/<domain>/` is created with permissions `700`
3. `.crt` copied to `/etc/nginx/ssl/<domain>/<domain>.crt` (permissions `644`)
4. `.key` copied to `/etc/nginx/ssl/<domain>/<domain>.key` (permissions `600`)
5. Chain (optional) → `<domain>.chain.pem`
6. Record added to `certs.db`

Source files are **not** modified — always copied.

### Inspect

For the selected certificate shows:
- Subject
- Issuer
- Validity (notBefore / notAfter)
- Subject Alternative Names
- Serial

### Check Expiry

Table of all registered certificates with colour highlighting:

| Colour | State |
|---|---|
| green | valid for more than 30 days |
| yellow | fewer than 30 days to expiry |
| red | expired |

### Remove Certificate Record

Removes the record from `certs.db` only. Files are **not** deleted.

---

## Section 4 — nginx Control

| Action | Command |
|---|---|
| Test | `nginx -t` |
| Reload | `systemctl reload nginx` or `nginx -s reload` |
| Restart | `systemctl restart nginx` |
| Stop | `systemctl stop nginx` |
| Start | `systemctl start nginx` |

Before Reload, `nginx -t` is always executed — if the test fails, the reload is not performed.

---

## Section 5 — System Status

Summary information: nginx version, process status, paths to key directories, number of sites and certificates in the DB, time of last `nginx.conf` edit, first run date. Ends with `nginx -t` output.

---

## State Database

### `/var/lib/pngxconf/state.conf`

Format `KEY=VALUE`:

| Key | Content |
|---|---|
| `FIRST_RUN_DONE` | `1` after the first check |
| `FIRST_RUN_DATE` | first run date |
| `NGINX_BIN` | path to the nginx binary |
| `NGINX_VERSION` | nginx version |
| `NGINX_CONF_LAST_EDIT` | last nginx.conf edit time |
| `NGINX_CONF_LAST_BAK` | path to the last backup |
| `SSL_WIZARD_PATH` | path to ssl-wizard.sh |
| `NGINX_WORKER_PROCESSES` | current value |
| `NGINX_WORKER_CONNECTIONS` | current value |
| `NGINX_GZIP` | `on` / `off` |
| `NGINX_GZIP_LEVEL` | 1-9 |
| `NGINX_SERVER_TOKENS` | `on` / `off` |
| `NGINX_KEEPALIVE_TIMEOUT` | value |
| `NGINX_CLIENT_MAX_BODY` | value |

### `/var/lib/pngxconf/sites.db`

Pipe-separated format, one line per site:

```
name|conf_path|server_name|listen_port|ssl_cert|ssl_key|status|created
```

Example:
```
myapp|/etc/nginx/conf.d/myapp.conf|app.example.com|443|/etc/nginx/ssl/app.example.com/app.example.com.crt|/etc/nginx/ssl/app.example.com/app.example.com.key|enabled|2024-01-15 14:30:22
```

Field `status`: `enabled` or `disabled`.

### `/var/lib/pngxconf/certs.db`

```
name|domain|cert_path|key_path|chain_path|type|created
```

Example:
```
myapp_cert|app.example.com|/etc/nginx/ssl/app.example.com/app.example.com.crt|/etc/nginx/ssl/app.example.com/app.example.com.key||manual|2024-01-15 14:28:10
```

Field `type`: `manual` (uploaded by hand) or `ssl-wizard` (created via the wizard).

### `/var/lib/pngxconf/pngxconf.log`

Plain-text log of all operations:

```
[2024-01-15 14:28:10] first_run_check completed issues=0
[2024-01-15 14:30:22] nginx.conf backup: /etc/nginx/pngxconf-backups/nginx.conf.20240115_143022.worker_processes reason=worker_processes
[2024-01-15 14:30:22] nginx.conf set worker_processes=4 in main
[2024-01-15 14:31:05] site_add name=myapp conf=/etc/nginx/conf.d/myapp.conf
[2024-01-15 14:31:15] nginx reloaded
```

---

## nginx.conf Backups

Stored in `/etc/nginx/pngxconf-backups/`. Naming:

```
nginx.conf.YYYYMMDD_HHMMSS.<reason>
```

Example reasons: `worker_processes`, `gzip_recommended`, `logformat_json`, `pre_restore`, `server_tokens`, `keepalive_timeout`, `multi_accept`, `io_method`, `client_max_body_size`.

A backup is created **automatically before every change**. Restoration happens through "View change history".

---

## File Permissions

| Path | Permissions |
|---|---|
| `/var/lib/pngxconf/` | `700` (root) |
| `/var/lib/pngxconf/state.conf` | `600` |
| `/var/lib/pngxconf/sites.db` | `600` |
| `/var/lib/pngxconf/certs.db` | `600` |
| `/var/lib/pngxconf/pngxconf.log` | `644` |
| `/usr/local/bin/pngxconf` | `755` |
| `/usr/local/lib/pngxconf/ssl-wizard.sh` | `755` |
| `/etc/nginx/ssl/` | `700` |
| `/etc/nginx/ssl/<domain>/` | `700` |
| `*.key` | `600` |
| `*.crt` / `*.pem` | `644` |

---

## Typical Workflows

### First install and create HTTPS reverse proxy

```bash
# 1. Install
sudo bash install.sh

# 2. Launch (first run — environment check)
sudo pngxconf

# 3. Create a certificate:
#    Main menu → 3 (SSL Certificates) → 2 (Create certificate)
#    ssl-wizard.sh launches — pick the method
#    (Let's Encrypt / self-signed / etc.)

# 4. Create a virtual host:
#    Main menu → 2 (Virtual Hosts) → 2 (Create)
#    Type: Reverse proxy plus SSL
#    Pick the certificate from the list

# 5. Verify and apply:
#    Automatic after creation: nginx -t → reload
```

### Server-wide gzip setup

```
Main menu → 1 (nginx.conf) → 6 (gzip) → 6 (Apply recommended)
Main menu → 4 (nginx Control) → 2 (Reload)
```

### Check expiry of all certificates

```
Main menu → 3 (SSL Certificates) → 5 (Check expiry)
```

### Temporarily disable a site

```
Main menu → 2 (Virtual Hosts) → 4 (Enable/disable)
→ pick site → file renamed to .conf.disabled
→ confirm reload
```

### Upload an existing certificate (manually, without the wizard)

```
Main menu → 3 (SSL Certificates) → 3 (Upload / register existing)
→ enter record name, domain
→ provide paths for .crt, .key (and optionally chain)
→ files copied to /etc/nginx/ssl/<domain>/
→ record added to certs.db
```

### Roll back a change in nginx.conf

```
Main menu → 1 (nginx.conf) → 9 (View change history)
→ pick backup by date → confirm restore
Main menu → 4 (nginx Control) → 2 (Reload)
```

---

## Help

```bash
sudo pngxconf -h                   # pngxconf help
sudo bash install.sh --help        # installer help
sudo bash install.sh --uninstall   # uninstall
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `pngxconf: command not found` | Restart the shell or add `/usr/local/bin` to `PATH` |
| `must be run as root` | Run via `sudo pngxconf` |
| `nginx not found` | Install nginx via the package manager — `install.sh` will offer to |
| `ssl-wizard.sh not found` | Place the file in `/usr/local/lib/pngxconf/` or specify the path manually |
| Site created but nginx -t fails | Run `nginx -t` in the terminal, fix `/etc/nginx/conf.d/<name>.conf` |
| Certificate expired, need to renew | Main menu → 3 → 2 (create a new one via ssl-wizard) |
| View the log | `cat /var/lib/pngxconf/pngxconf.log` |

---

## Architecture

- **install.sh** (~370 lines) — auto-installer with distro detection
- **pngxconf** (~1850 lines) — main binary with TUI, DB logic, nginx.conf editor
- **ssl-wizard.sh** (~1025 lines) — certificate creation wizard

All three components share a common ANSI 24-bit colour palette standard and a unified formatting style.
