# pngxconf — Nginx Management System

Интерактивная TUI-система для управления nginx: виртуальные хосты, SSL-сертификаты, редактирование `nginx.conf` с историей изменений. Вызывается командой `pngxconf` из любой директории.

**Версия:** 1.1
**Компоненты:** `install.sh` · `pngxconf` · `ssl-wizard.sh`

---

## Требования

| Компонент | Минимум | Примечание |
|---|---|---|
| OS | Linux | Debian/Ubuntu, RHEL/Rocky/Fedora, Arch, openSUSE |
| bash | 4.0+ | `bash --version` |
| nginx | любая | автоустановщик проверит и предложит установить |
| openssl | любая | нужен для сертификатов |
| curl | любая | нужен `ssl-wizard.sh` для acme.sh |
| socat | опционально | нужен только для acme.sh standalone |
| root | обязательно | все операции требуют прав root |

---

## Установка

В директории с тремя файлами (`install.sh`, `pngxconf`, `ssl-wizard.sh`):

```bash
sudo bash install.sh
```

Установщик сам:
1. Определит дистрибутив
2. Проверит наличие bash 4+, nginx, openssl, curl, socat
3. Предложит установить отсутствующие пакеты через `apt` / `dnf` / `pacman` / `zypper`
4. Создаст все необходимые директории с правильными правами
5. Скопирует `pngxconf` в `/usr/local/bin/pngxconf`
6. Скопирует `ssl-wizard.sh` в `/usr/local/lib/pngxconf/ssl-wizard.sh`
7. Проинициализирует state-файлы в `/var/lib/pngxconf/`
8. Проверит, что `pngxconf` доступен в `PATH`

После установки — запуск из любой директории:

```bash
sudo pngxconf
sudo pngxconf -h
```

---

## Удаление

```bash
sudo bash install.sh --uninstall
```

Удаляет бинарник и ssl-wizard. Затем отдельно спрашивает про `/var/lib/pngxconf/` (state-файлы).
Конфиги nginx и сертификаты в `/etc/nginx/` **не удаляются**.

---

## Первый запуск

При первом запуске `pngxconf` автоматически выполняет проверку окружения:

- Бинарник nginx (ищет в `/usr/sbin/`, `/usr/local/sbin/`, `/usr/bin/`)
- `/etc/nginx/nginx.conf`
- `/etc/nginx/conf.d/` — создаёт если нет
- `/etc/nginx/ssl/` — создаёт с правами `700` если нет
- `openssl`
- `ssl-wizard.sh`

Флаг выполнения сохраняется в `/var/lib/pngxconf/state.conf`. Повторно не запускается.

**На каждом следующем запуске** тихо проверяет (без визуального вывода):
- Существование всех `conf`-файлов зарегистрированных сайтов
- Существование файлов сертификатов и ключей из базы
- Несоответствия пишутся в `/var/lib/pngxconf/pngxconf.log`

---

## Расположение файлов

Строго по стандарту nginx:

```
/usr/local/bin/
└── pngxconf                           основной бинарник

/usr/local/lib/pngxconf/
└── ssl-wizard.sh                      SSL мастер

/etc/nginx/
├── nginx.conf                         главный конфиг nginx
├── conf.d/
│   ├── site1.conf                     виртуальные хосты
│   └── site2.conf
├── ssl/
│   ├── example.com/
│   │   ├── example.com.crt            сертификат
│   │   ├── example.com.key            приватный ключ
│   │   └── example.com.chain.pem     цепочка (опц.)
│   └── api.example.com/
│       ├── api.example.com.crt
│       └── api.example.com.key
└── pngxconf-backups/
    ├── nginx.conf.20240115_143022.worker_processes
    └── nginx.conf.20240115_150311.gzip_recommended

/var/lib/pngxconf/
├── state.conf                          переменные состояния системы
├── sites.db                            база виртуальных хостов
├── certs.db                            база сертификатов
└── pngxconf.log                        лог всех операций
```

---

## Навигация в TUI

| Ввод | Действие |
|---|---|
| `1`–`9` | выбор пункта меню |
| `0` | назад (из любого подменю к родительскому) |
| `b` | назад (в полях ввода и списках) |
| `Enter` | подтвердить / значение по умолчанию |
| `y` / `n` | подтверждение |

Навигация `b` работает **на всех уровнях** — от главного меню до вложенных форм ввода. В главном меню `0` означает выход из программы.

---

## Главное меню

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

## Раздел 1 — nginx.conf Management

Редактирование `/etc/nginx/nginx.conf` через структурированные подменю. **Перед каждым изменением автоматически создаётся timestamped-бэкап** в `/etc/nginx/pngxconf-backups/` с именем `nginx.conf.YYYYMMDD_HHMMSS.<причина>`.

### Подменю

| Пункт | Контекст | Директивы |
|---|---|---|
| View current nginx.conf | — | просмотр первых 120 строк |
| Edit core worker settings | `main` | `worker_processes`, `worker_rlimit_nofile`, `user` |
| Edit events block settings | `events {}` | `worker_connections`, `multi_accept`, `use` |
| Edit http block global | `http {}` | `server_tokens`, `keepalive_timeout`, `client_max_body_size`, `sendfile`, `tcp_nopush`, `types_hash_max_size` |
| Edit log formats | `http {}` | `log_format combined_plus`, `log_format json` |
| Edit gzip settings | `http {}` | `gzip`, `gzip_comp_level`, `gzip_min_length`, `gzip_vary`, `gzip_proxied`, `gzip_types` |
| Apply / reload nginx | — | `nginx -t` затем `nginx -s reload` |
| Test nginx configuration | — | `nginx -t` |
| View change history | — | список бэкапов, восстановление |

### Логика редактирования

Если директива уже существует в файле — значение заменяется через `sed`. Если отсутствует — вставляется после открывающей скобки нужного контекста. Каждое изменение:
1. Создаёт бэкап
2. Обновляет `state.conf` с временной меткой
3. Пишет запись в `pngxconf.log`

### Восстановление из истории

Подменю "View change history" показывает до 20 последних бэкапов, отсортированных по дате. При восстановлении сначала делается бэкап текущей версии с меткой `pre_restore`, затем выбранный бэкап копируется в `nginx.conf`.

---

## Раздел 2 — Virtual Hosts

Управление файлами в `/etc/nginx/conf.d/`. Каждый виртуальный хост регистрируется в `sites.db`.

### Создание виртуального хоста

Запрашивает:
1. **Имя** (идентификатор, буквы/цифры/`-`/`_`) → файл `/etc/nginx/conf.d/<имя>.conf`
2. **Тип сайта:**

| Тип | Описание | Содержимое |
|---|---|---|
| Reverse proxy | HTTP-прокси на внутренний IP:port | `upstream` плюс `proxy_pass` |
| Static site | раздача статических файлов | `root` плюс `try_files` |
| Reverse proxy плюс SSL | HTTPS-прокси | всё выше плюс SSL-блок |
| HTTP redirect | редирект 301 | `return 301 ...` |

3. **server_name** — домен или IP
4. **Listen port** — по умолчанию 80, для SSL — 443
5. Для прокси: **Upstream IP** и **Upstream port**
6. Для SSL: интерактивный выбор сертификата и ключа из `/etc/nginx/ssl/` (или ручной ввод пути)

После создания выполняется `nginx -t` с предложением `reload`.

### Генерируемый конфиг (Reverse proxy плюс SSL)

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

- **Disable** — `site.conf` переименовывается в `site.conf.disabled` (nginx перестаёт читать)
- **Enable** — обратное переименование
- В обоих случаях предлагается `reload nginx`
- Статус синхронизируется в `sites.db`

### Delete

Удаляет `.conf` и `.conf.disabled` с диска плюс запись из `sites.db`. Сертификаты в `/etc/nginx/ssl/` **не удаляются**.

### Check all site configs

Для каждого сайта проверяет:
- существование `.conf` или `.conf.disabled`
- существование `cert` и `key` (если привязаны)
- в конце запускает `nginx -t`

---

## Раздел 3 — SSL Certificates

Управление сертификатами. База в `/var/lib/pngxconf/certs.db`.

### Create certificate — через ssl-wizard.sh

Запускает `ssl-wizard.sh` как вложенный процесс. После завершения мастера сравнивает содержимое `/etc/nginx/ssl/` до и после — новые файлы предлагает зарегистрировать в базе.

`ssl-wizard.sh` поддерживает:
- **Let's Encrypt**: standalone, webroot, nginx mode, wildcard manual DNS, wildcard Cloudflare
- **Self-signed**: simple (RSA без passphrase), RSA 2048/3072/4096, ECDSA P-256/P-384/P-521, Ed25519, Local CA плюс signed
- **Утилиты**: генерация RSA/ECDSA/Ed25519 ключей, случайных байт (base64/hex)

Поиск `ssl-wizard.sh` в порядке:
1. Путь из `state.conf` (`SSL_WIZARD_PATH`)
2. `/usr/local/lib/pngxconf/ssl-wizard.sh` ← рекомендуемое расположение
3. Директория рядом с бинарником `pngxconf`
4. `/var/lib/pngxconf/ssl-wizard.sh`
5. Ручной ввод пути, если не найден

### Upload / Register

Загрузка имеющихся сертификатов:
1. Вводятся имя записи и домен
2. Создаётся `/etc/nginx/ssl/<domain>/` с правами `700`
3. `.crt` копируется в `/etc/nginx/ssl/<domain>/<domain>.crt` (права `644`)
4. `.key` копируется в `/etc/nginx/ssl/<domain>/<domain>.key` (права `600`)
5. Цепочка — опционально в `<domain>.chain.pem`
6. Запись добавляется в `certs.db`

Оригиналы **не изменяются** — всегда копирование.

### Inspect

Для выбранного сертификата показывает:
- Subject
- Issuer
- Validity (notBefore / notAfter)
- Subject Alternative Names
- Serial

### Check expiry

Таблица всех зарегистрированных сертификатов с подсветкой:

| Цвет | Состояние |
|---|---|
| зелёный | действителен более 30 дней |
| жёлтый | менее 30 дней до истечения |
| красный | истёк |

### Remove certificate record

Удаляет только запись из `certs.db`. Файлы **не удаляются**.

---

## Раздел 4 — nginx Control

| Действие | Команда |
|---|---|
| Test | `nginx -t` |
| Reload | `systemctl reload nginx` или `nginx -s reload` |
| Restart | `systemctl restart nginx` |
| Stop | `systemctl stop nginx` |
| Start | `systemctl start nginx` |

Перед Reload всегда выполняется `nginx -t` — при провале теста перезагрузка не производится.

---

## Раздел 5 — System Status

Сводная информация: версия nginx, статус процесса, пути к ключевым директориям, количество сайтов и сертификатов в БД, время последнего редактирования `nginx.conf`, дата первого запуска. В конце — вывод `nginx -t`.

---

## База состояния

### `/var/lib/pngxconf/state.conf`

Формат `KEY=VALUE`:

| Ключ | Содержимое |
|---|---|
| `FIRST_RUN_DONE` | `1` после первой проверки |
| `FIRST_RUN_DATE` | дата первого запуска |
| `NGINX_BIN` | путь к бинарнику nginx |
| `NGINX_VERSION` | версия nginx |
| `NGINX_CONF_LAST_EDIT` | время последнего редактирования nginx.conf |
| `NGINX_CONF_LAST_BAK` | путь к последнему бэкапу |
| `SSL_WIZARD_PATH` | путь к ssl-wizard.sh |
| `NGINX_WORKER_PROCESSES` | текущее значение |
| `NGINX_WORKER_CONNECTIONS` | текущее значение |
| `NGINX_GZIP` | `on` / `off` |
| `NGINX_GZIP_LEVEL` | 1-9 |
| `NGINX_SERVER_TOKENS` | `on` / `off` |
| `NGINX_KEEPALIVE_TIMEOUT` | значение |
| `NGINX_CLIENT_MAX_BODY` | значение |

### `/var/lib/pngxconf/sites.db`

Pipe-разделённый формат, строка на сайт:

```
name|conf_path|server_name|listen_port|ssl_cert|ssl_key|status|created
```

Пример:
```
myapp|/etc/nginx/conf.d/myapp.conf|app.example.com|443|/etc/nginx/ssl/app.example.com/app.example.com.crt|/etc/nginx/ssl/app.example.com/app.example.com.key|enabled|2024-01-15 14:30:22
```

Поле `status`: `enabled` или `disabled`.

### `/var/lib/pngxconf/certs.db`

```
name|domain|cert_path|key_path|chain_path|type|created
```

Пример:
```
myapp_cert|app.example.com|/etc/nginx/ssl/app.example.com/app.example.com.crt|/etc/nginx/ssl/app.example.com/app.example.com.key||manual|2024-01-15 14:28:10
```

Поле `type`: `manual` (загружен вручную) или `ssl-wizard` (создан через мастер).

### `/var/lib/pngxconf/pngxconf.log`

Текстовый лог всех операций:

```
[2024-01-15 14:28:10] first_run_check completed issues=0
[2024-01-15 14:30:22] nginx.conf backup: /etc/nginx/pngxconf-backups/nginx.conf.20240115_143022.worker_processes reason=worker_processes
[2024-01-15 14:30:22] nginx.conf set worker_processes=4 in main
[2024-01-15 14:31:05] site_add name=myapp conf=/etc/nginx/conf.d/myapp.conf
[2024-01-15 14:31:15] nginx reloaded
```

---

## Бэкапы nginx.conf

Хранятся в `/etc/nginx/pngxconf-backups/`. Именование:

```
nginx.conf.YYYYMMDD_HHMMSS.<причина>
```

Примеры причин: `worker_processes`, `gzip_recommended`, `logformat_json`, `pre_restore`, `server_tokens`, `keepalive_timeout`, `multi_accept`, `io_method`, `client_max_body_size`.

Бэкап создаётся **автоматически перед каждым изменением**. Восстановление через пункт "View change history".

---

## Безопасность файлов

| Путь | Права |
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

## Типичные сценарии

### Первая установка и создание HTTPS reverse proxy

```bash
# 1. Установить
sudo bash install.sh

# 2. Запустить (первый раз — проверит окружение)
sudo pngxconf

# 3. Создать сертификат:
#    Main menu → 3 (SSL Certificates) → 2 (Create certificate)
#    Запустится ssl-wizard.sh — выбрать метод
#    (Let's Encrypt / self-signed / и т.д.)

# 4. Создать виртуальный хост:
#    Main menu → 2 (Virtual Hosts) → 2 (Create)
#    Тип: Reverse proxy плюс SSL
#    Выбрать сертификат из списка

# 5. Проверить и применить:
#    Автоматически после создания: nginx -t → reload
```

### Настройка gzip для всего сервера

```
Main menu → 1 (nginx.conf) → 6 (gzip) → 6 (Apply recommended)
Main menu → 4 (nginx Control) → 2 (Reload)
```

### Проверка срока действия всех сертификатов

```
Main menu → 3 (SSL Certificates) → 5 (Check expiry)
```

### Временное отключение сайта

```
Main menu → 2 (Virtual Hosts) → 4 (Enable/disable)
→ выбрать сайт → автоматически переименуется в .conf.disabled
→ подтвердить reload
```

### Загрузка существующего сертификата (ручная, без мастера)

```
Main menu → 3 (SSL Certificates) → 3 (Upload / register existing)
→ ввести имя записи, домен
→ указать пути к .crt, .key (и опц. к chain)
→ файлы копируются в /etc/nginx/ssl/<domain>/
→ запись добавляется в certs.db
```

### Откат изменения в nginx.conf

```
Main menu → 1 (nginx.conf) → 9 (View change history)
→ выбрать бэкап по дате → подтвердить восстановление
Main menu → 4 (nginx Control) → 2 (Reload)
```

---

## Справка

```bash
sudo pngxconf -h                   # справка по pngxconf
sudo bash install.sh --help        # справка по установщику
sudo bash install.sh --uninstall   # удаление
```

---

## Устранение неполадок

| Проблема | Решение |
|---|---|
| `pngxconf: command not found` | Перезапустите shell или добавьте `/usr/local/bin` в `PATH` |
| `must be run as root` | Запускайте через `sudo pngxconf` |
| `nginx not found` | Установите nginx через пакетный менеджер — `install.sh` предложит |
| `ssl-wizard.sh not found` | Положите файл в `/usr/local/lib/pngxconf/` или укажите путь вручную |
| Сайт создан, но nginx -t падает | Проверьте `nginx -t` в терминале, исправьте `/etc/nginx/conf.d/<имя>.conf` |
| Сертификат истёк, нужно обновить | Main menu → 3 → 2 (создать новый через ssl-wizard) |
| Хочу посмотреть лог | `cat /var/lib/pngxconf/pngxconf.log` |

---

## Архитектура

- **install.sh** (~370 строк) — автоустановщик с определением дистрибутива
- **pngxconf** (~1850 строк) — основной бинарник с TUI, логикой БД, редактором nginx.conf
- **ssl-wizard.sh** (~1025 строк) — мастер создания сертификатов

Все три компонента используют общий стандарт цветовой палитры ANSI 24-bit и единый стиль форматирования.
