# nginx-config-gen.sh

Interactive TUI wizard for generating production-ready nginx reverse proxy configurations.
Runs entirely in the terminal — no dependencies beyond bash and standard Linux utilities.

---

## Requirements

| Requirement | Details |
|---|---|
| Shell | bash 4.0 or newer |
| OS | Linux (Debian/Ubuntu, RHEL/CentOS/Fedora/Rocky, Arch, openSUSE) |
| Permissions | Regular user for generation and preview; **root required** for saving to `/etc/nginx/` and reloading nginx |
| nginx | Optional — script works without nginx installed; Apply function requires it |

---

## Installation

```bash
# Download and make executable
chmod +x nginx-config-gen.sh

# Run as root to save configs and reload nginx
sudo ./nginx-config-gen.sh

# Run as regular user for preview and file generation to custom path
./nginx-config-gen.sh
```

---

## Usage

The script has no command-line arguments. All interaction is through the TUI.

**Navigation:**
- `↑` / `↓` — move between items
- `Enter` — select item / confirm input
- `q` — go back / exit current menu

On first launch, select the interface language (English or Russian). The choice applies to all menus and messages for the current session.

---

## Menu Structure

```
Language selection
└── Main Menu
    ├── Basic Parameters          ← required before saving
    ├── SSL / TLS Settings
    ├── Security Headers
    ├── Advanced Proxy Settings
    ├── Caching
    ├── Limits and Timeouts
    ├── Logging
    ├── Compression (gzip)
    ├── Advanced Options
    ├── Preview Configuration
    ├── Save Configuration        ← writes .conf file, optionally updates nginx.conf
    └── Apply (reload nginx)      ← runs nginx -t then nginx -s reload
```

---

## Configuration Parameters

### Basic Parameters (required)

| Parameter | nginx directive | Default |
|---|---|---|
| Listen port | `listen` | `80` |
| Domain or IP | `server_name` | — |
| Internal IP | `proxy_pass` target | — |
| Proxy port | `proxy_pass` target | `3000` |
| Backend protocol | `proxy_pass` scheme | `http` |

The internal IP and proxy port together form the upstream server address: `proxy_pass http://backend` where `backend` upstream resolves to `<ip>:<port>`.

---

### SSL / TLS Settings

| Parameter | nginx directive | Default |
|---|---|---|
| Enable SSL | `listen 443 ssl` | off |
| Certificate path | `ssl_certificate` | — |
| Private key path | `ssl_certificate_key` | — |
| Certificate chain | `ssl_trusted_certificate` | — |
| TLS protocols | `ssl_protocols` | `TLSv1.2 TLSv1.3` |
| Cipher suite | `ssl_ciphers` | ECDHE/CHACHA20 set |
| HSTS | `Strict-Transport-Security` header | off |
| HSTS max-age | `max-age=` value | `31536000` (1 year) |
| OCSP Stapling | `ssl_stapling on` | off |
| Session timeout | `ssl_session_timeout` | `1d` |
| dhparam path | `ssl_dhparam` | — |
| HTTP→HTTPS redirect | separate `server {}` block on port 80 | off |

**SSL certificate picker:**
When `/etc/nginx/ssl/` exists, the script lists all `.crt`, `.pem`, `.key`, `.cer` files found in that directory and lets you select one interactively. Selecting "Enter path manually" switches to a text input prompt.

Enabling SSL automatically sets the listen port to `443`.

Additional directives always written when SSL is enabled:
```nginx
ssl_prefer_server_ciphers on;
ssl_session_cache         shared:SSL:10m;
ssl_session_tickets       off;
```
When OCSP Stapling is enabled, the resolver is set to `8.8.8.8 8.8.4.4`.

---

### Security Headers

| Parameter | nginx directive | Default |
|---|---|---|
| X-Frame-Options | `add_header X-Frame-Options` | `SAMEORIGIN` |
| X-Content-Type-Options | `add_header X-Content-Type-Options "nosniff"` | on |
| X-XSS-Protection | `add_header X-XSS-Protection "1; mode=block"` | on |
| Referrer-Policy | `add_header Referrer-Policy` | `strict-origin-when-cross-origin` |
| Content-Security-Policy | `add_header Content-Security-Policy` | off |
| CSP value | value for the CSP header | `default-src 'self'` |
| Permissions-Policy | `add_header Permissions-Policy` | off |
| Hide nginx version | `server_tokens off` | on |

All `add_header` directives are written with the `always` flag so they are included in error responses as well.

---

### Advanced Proxy Settings

| Parameter | nginx directive | Default |
|---|---|---|
| proxy_buffering | `proxy_buffering` | `on` |
| proxy_buffer_size | `proxy_buffer_size` | `4k` |
| proxy_buffers | `proxy_buffers` | `8 4k` |
| proxy_read_timeout | `proxy_read_timeout` | `60s` |
| proxy_connect_timeout | `proxy_connect_timeout` | `10s` |
| proxy_send_timeout | `proxy_send_timeout` | `60s` |
| Pass host headers | `proxy_set_header Host`, `X-Forwarded-Host`, `X-Forwarded-Port` | on |
| Pass real client IP | `proxy_set_header X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` | on |
| WebSocket support | `Upgrade` / `Connection` headers + `proxy_http_version 1.1` | off |
| proxy_intercept_errors | `proxy_intercept_errors on` | off |

When WebSocket is disabled, the config still writes `proxy_http_version 1.1` and `proxy_set_header Connection ""` to enable HTTP/1.1 keepalive to the upstream.

---

### Caching

| Parameter | nginx directive | Default |
|---|---|---|
| Enable proxy cache | `proxy_cache` | off |
| Cache zone name | `keys_zone=<name>` | `my_cache` |
| Cache path | `proxy_cache_path` path | `/var/cache/nginx/my_cache` |
| proxy_cache_valid | `proxy_cache_valid` | `200 1d` |
| Cache bypass condition | `proxy_cache_bypass` | — |

When caching is enabled, the following is always added to the location block:
```nginx
proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
```

> **nginx.conf modification:** Enabling cache and answering `y` to "update nginx.conf" injects the following line into the `http {}` block of `/etc/nginx/nginx.conf`:
> ```nginx
> proxy_cache_path /var/cache/nginx/my_cache levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m use_temp_path=off;
> ```
> The injection is skipped if `keys_zone=<name>` is already present in nginx.conf.

---

### Limits and Timeouts

| Parameter | nginx directive | Default |
|---|---|---|
| client_max_body_size | `client_max_body_size` | `10m` |
| client_body_timeout | `client_body_timeout` | `60s` |
| keepalive_timeout | `keepalive_timeout` | `75s` |
| send_timeout | `send_timeout` | `60s` |
| Enable rate limiting | `limit_req` | off |
| Rate limit zone | `zone=<name>` | `one` |
| Request rate | `rate=<n>r/s` | `10r/s` |
| burst | `burst=<n>` | `20` |

Rate limiting in the location block:
```nginx
limit_req zone=one burst=20 nodelay;
```

> **nginx.conf modification:** Enabling rate limiting and answering `y` to "update nginx.conf" injects the following into the `http {}` block of `/etc/nginx/nginx.conf`:
> ```nginx
> limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;
> ```
> The injection is skipped if `zone=<name>:` is already present in nginx.conf.

---

### Logging

| Parameter | nginx directive | Default |
|---|---|---|
| access_log path | `access_log` | `/var/log/nginx/access.log` |
| error_log path | `error_log` | `/var/log/nginx/error.log` |
| error_log level | second argument of `error_log` | `warn` |
| Log format | format name for `access_log` | `combined` |

Setting `access_log` to `off` disables access logging for this virtual host.

Available log levels: `debug`, `info`, `notice`, `warn`, `error`, `crit`, `alert`, `emerg`.

---

### Compression (gzip)

| Parameter | nginx directive | Default |
|---|---|---|
| Enable gzip | `gzip on` | on |
| gzip_comp_level | `gzip_comp_level` | `6` |
| gzip_min_length | `gzip_min_length` | `1024` |
| gzip_vary | `gzip_vary on` | on |
| gzip_proxied | `gzip_proxied` | `any` |
| gzip_types | `gzip_types` | text, css, xml, js, json, svg |

---

### Advanced Options

| Parameter | nginx directive | Notes |
|---|---|---|
| root directory | `root` | For serving static files alongside proxy |
| index files | `index` | Default: `index.html index.htm` |
| try_files | `try_files` | e.g. `$uri $uri/ @backend` |
| Upstream group name | `upstream <name>` | Default: `backend` |
| upstream keepalive | `keepalive` | Connections kept open to upstream. Default: `32` |
| Custom response headers | `add_header` | Semicolon-separated list, e.g. `X-App-Version 1.0; X-Env prod` |
| Return 404 for unknown hosts | `location @fallback { return 404; }` | off |
| Custom error pages | `error_page 404 500 502 503 504` | off |
| Maintenance mode | `return 503` in location | Replaces proxy_pass with static 503 |
| worker_processes | `worker_processes` in nginx.conf | Choices: auto, 1, 2, 4, 8 |
| worker_connections | `worker_connections` in nginx.conf | Choices: 512, 1024, 2048, 4096 |

> **nginx.conf modification:** Setting `worker_processes` or `worker_connections` and answering `y` to "update nginx.conf" uses `sed -i` to replace the existing values in-place in `/etc/nginx/nginx.conf`. A backup of the original file is created before any modification.

---

## nginx.conf Modifications — Full Reference

The script **only modifies `/etc/nginx/nginx.conf`** when:
1. The user explicitly answers `y` (or `д` in Russian) to the "Also update nginx.conf?" prompt in the Save section.
2. At least one of the following is configured: cache, rate limiting, worker_processes, or worker_connections.

A timestamped backup is always created before any change:
```
/etc/nginx/nginx.conf.bak.1710000000
```

| Trigger | What changes in nginx.conf | Method |
|---|---|---|
| Cache enabled | `proxy_cache_path ...` injected into `http {}` | `sed` insert after `http {` |
| Rate limiting enabled | `limit_req_zone ...` injected into `http {}` | `sed` insert after `http {` |
| worker_processes set | Existing `worker_processes` line replaced | `sed -i` in-place replace |
| worker_connections set | Existing `worker_connections` line replaced | `sed -i` in-place replace |

Injections are idempotent — the script checks whether the directive already exists before inserting.

---

## System Checks

At startup, the script detects and displays in the status bar:

| Check | Method | Result if missing |
|---|---|---|
| Linux distribution | `/etc/os-release` → `$ID` | Shows "unknown" |
| nginx binary | `command -v` in common paths | Apply function disabled |
| `/etc/nginx/conf.d/` | `test -d` | Warning shown |
| `/etc/nginx/ssl/` | `test -d` | Warning shown; directory created when saving with SSL enabled |

Detected distribution families: `debian`, `rhel`, `arch`, `suse`, `unknown`. The family is shown in brackets next to the distribution name.

---

## Generated Config Structure

```nginx
upstream backend {
    server <ip>:<port>;
    keepalive 32;
}

# HTTP → HTTPS redirect block (if SSL + redirect enabled)
server {
    listen      80;
    server_name example.com;
    return      301 https://$host$request_uri;
}

server {
    listen      443 ssl;               # or configured port
    server_name example.com;

    server_tokens off;                 # if enabled

    # SSL block
    ssl_certificate     ...;
    ssl_certificate_key ...;
    # ... other ssl_ directives

    # HSTS (if enabled)
    add_header Strict-Transport-Security "max-age=...";

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    # ...

    # Logging
    access_log  /var/log/nginx/access.log;
    error_log   /var/log/nginx/error.log warn;

    # Client limits
    client_max_body_size  10m;
    # ...

    # Gzip (if enabled)
    gzip on;
    # ...

    # Rate limiting (if enabled)
    limit_req zone=one burst=20 nodelay;

    # Custom headers (if set)
    # ...

    # Custom error pages (if enabled)
    # ...

    # Static root (if set)
    # ...

    # Proxy location
    location / {
        proxy_pass            http://backend;
        proxy_buffering       on;
        proxy_buffer_size     4k;
        proxy_buffers         8 4k;
        proxy_read_timeout    60s;
        proxy_connect_timeout 10s;
        proxy_send_timeout    60s;
        proxy_set_header      Host             $host;
        proxy_set_header      X-Real-IP        $remote_addr;
        proxy_set_header      X-Forwarded-For  $proxy_add_x_forwarded_for;
        # ... WebSocket headers if enabled
        # ... proxy_cache if enabled
    }
}
```

---

## Save and Apply

### Save

1. Prompts for output path (default: `/etc/nginx/conf.d/<server_name>.conf`)
2. Creates the directory if it does not exist
3. Writes the generated config
4. If SSL is enabled and `/etc/nginx/ssl/` does not exist, creates it with `chmod 700`
5. Asks whether to update `nginx.conf` (see nginx.conf Modifications above)

### Apply

Requires root and a working nginx installation.

1. Runs `nginx -t` — syntax test
2. If test passes, asks for confirmation
3. On confirmation, runs `nginx -s reload`

---

## Example: Minimal HTTPS Reverse Proxy

Settings to configure for a typical HTTPS reverse proxy with an app running on port 8080:

| Menu | Parameter | Value |
|---|---|---|
| Basic | Listen port | `443` |
| Basic | Domain | `app.example.com` |
| Basic | Proxy IP | `127.0.0.1` |
| Basic | Proxy port | `8080` |
| SSL | Enable SSL | on |
| SSL | Certificate | `/etc/nginx/ssl/app.crt` |
| SSL | Key | `/etc/nginx/ssl/app.key` |
| SSL | HTTP→HTTPS redirect | on |
| Security | server_tokens off | on |
| Save | Output path | `/etc/nginx/conf.d/app.conf` |

---

## Notes

- The script does not install nginx. Use your distribution's package manager.
- The generated `.conf` file is self-contained and valid for inclusion in `conf.d/`.
- All boolean settings in the TUI show `[ON]` / `[OFF]` (or `[ВКЛ]` / `[ВЫКЛ]` in Russian).
- Settings persist within a session. Re-entering a section shows current values.
- There is no import/export of settings between sessions.
