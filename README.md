# pngxconf — Nginx Management System

Интерактивная TUI-система управления nginx: виртуальные хосты, SSL-сертификаты, редактирование `nginx.conf` с историей изменений. Вызывается командой `pngxconf`.

---

## Требования

| Компонент | Минимум | Примечание |
|---|---|---|
| bash | 4.0+ | `bash --version` |
| nginx | любая актуальная | должен быть установлен в системе |
| openssl | любая | нужен для работы с сертификатами |
| root / sudo | обязательно | все операции требуют прав root |
| ssl-wizard.sh | опционально | нужен только для создания сертификатов через мастер |

---

## Установка

```bash
# 1. Установить pngxconf
cp pngxconf /usr/local/bin/pngxconf
chmod +x /usr/local/bin/pngxconf

# 2. Установить ssl-wizard.sh (для создания сертификатов)
mkdir -p /usr/local/lib/pngxconf
cp ssl-wizard.sh /usr/local/lib/pngxconf/ssl-wizard.sh
chmod +x /usr/local/lib/pngxconf/ssl-wizard.sh
```

После этого система доступна из любого места командой:

```bash
pngxconf
pngxconf -h
```

---

## Первый запуск

При первом запуске система автоматически выполняет проверку окружения:

- Наличие и версия бинарника nginx (ищет в `/usr/sbin/nginx`, `/usr/local/sbin/nginx`, `/usr/bin/nginx`)
- Наличие файла `/etc/nginx/nginx.conf`
- Наличие директории `/etc/nginx/conf.d/` — создаёт автоматически если отсутствует
- Наличие директории `/etc/nginx/ssl/` — создаёт автоматически если отсутствует (права `700`)
- Наличие `openssl`
- Расположение `ssl-wizard.sh`

Результат первой проверки сохраняется в базе состояния — повторно при следующих запусках не выполняется.

**При последующих запусках** система молча проверяет:
- Существование всех conf-файлов из базы сайтов
- Существование всех файлов сертификатов и ключей из базы сертификатов
- Несоответствия пишутся в лог `/var/lib/pngxconf/pngxconf.log`

---

## Расположение файлов

Система строго следует стандартной структуре nginx:

```
/etc/nginx/
├── nginx.conf                        главный конфиг nginx
├── conf.d/
│   ├── site1.conf                    конфиги виртуальных хостов
│   └── site2.conf
├── ssl/
│   ├── example.com/
│   │   ├── example.com.crt           сертификат
│   │   ├── example.com.key           приватный ключ
│   │   └── example.com.chain.pem    цепочка (если есть)
│   └── api.example.com/
│       ├── api.example.com.crt
│       └── api.example.com.key
└── pngxconf-backups/
    ├── nginx.conf.20240115_143022.worker_processes
    └── nginx.conf.20240115_150311.gzip_recommended

/var/lib/pngxconf/
├── state.conf      переменные состояния системы
├── sites.db        база виртуальных хостов
├── certs.db        база сертификатов
└── pngxconf.log    лог всех операций
```

---

## Навигация в TUI

| Ввод | Действие |
|---|---|
| `1` – `9` | выбор пункта меню |
| `0` | назад / выход из раздела |
| `b` | назад (в полях ввода) |
| `Enter` | подтвердить / значение по умолчанию |
| `y` / `n` | подтверждение действий |

---

## Главное меню

```
pngxconf v1.0  │  Nginx Management System

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

Редактирование `/etc/nginx/nginx.conf` через структурированные подменю. **Перед каждым изменением автоматически создаётся резервная копия** в `/etc/nginx/pngxconf-backups/` с именем вида `nginx.conf.YYYYMMDD_HHMMSS.<причина>`.

### Подменю

| Пункт | Что редактирует | Директивы |
|---|---|---|
| View current nginx.conf | просмотр файла (первые 120 строк) | — |
| Edit core worker settings | блок `main` | `worker_processes`, `worker_rlimit_nofile`, `user` |
| Edit events block settings | блок `events {}` | `worker_connections`, `multi_accept`, `use` |
| Edit http block global settings | блок `http {}` | `server_tokens`, `keepalive_timeout`, `client_max_body_size`, `sendfile`, `tcp_nopush`, `types_hash_max_size` |
| Edit log formats | блок `http {}` | `log_format combined_plus`, `log_format json` |
| Edit gzip settings | блок `http {}` | `gzip`, `gzip_comp_level`, `gzip_min_length`, `gzip_vary`, `gzip_proxied`, `gzip_types` |
| Apply / reload nginx | — | `nginx -t` → `nginx -s reload` |
| Test nginx configuration | — | `nginx -t` с выводом |
| View change history | просмотр бэкапов | возможность восстановления |

### Поведение при редактировании

Если директива уже существует в файле — значение заменяется через `sed -i`. Если директива отсутствует — вставляется после открывающей скобки нужного контекста. Каждое изменение фиксируется в `state.conf` и в `pngxconf.log`.

### Восстановление из истории

Пункт "View change history" показывает список бэкапов, отсортированных по дате. Выбор бэкапа заменяет текущий `nginx.conf` — при этом сначала создаётся бэкап текущей версии с меткой `pre_restore`.

---

## Раздел 2 — Virtual Hosts

Управление файлами в `/etc/nginx/conf.d/`. Каждый виртуальный хост регистрируется в `/var/lib/pngxconf/sites.db`.

### Создание виртуального хоста

При выборе "Create new virtual host" система запрашивает:

1. **Имя** — идентификатор (буквы, цифры, `-`, `_`). Создаёт файл `/etc/nginx/conf.d/<имя>.conf`
2. **Тип сайта:**

| Тип | Описание | Что генерируется |
|---|---|---|
| Reverse proxy | проксирование на внутренний IP:port | `upstream` блок + `proxy_pass` |
| Static site | раздача статических файлов | `root` + `try_files` |
| Reverse proxy + SSL | HTTPS прокси | всё выше + SSL-блок |
| HTTP redirect to HTTPS | редирект 301 | `return 301 https://...` |

3. **server_name** — домен или IP
4. **Listen port** — порт (по умолчанию 80, для SSL — 443)
5. Для прокси: **Upstream IP** и **Upstream port**
6. Для SSL: выбор сертификата и ключа из `/etc/nginx/ssl/` или ввод пути вручную

После создания автоматически выполняется `nginx -t` с предложением сделать `reload`.

### Генерируемая конфигурация (reverse proxy + SSL)

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

- **Disable** — переименовывает `site.conf` в `site.conf.disabled` (nginx перестаёт его читать)
- **Enable** — переименовывает обратно в `site.conf`
- После обоих действий предлагается `reload nginx`

### Удаление

Удаляет `.conf` и `.conf.disabled` файлы с диска, а также запись из `sites.db`. Файлы сертификатов **не удаляются**.

### Check all site configs

Проверяет для каждого зарегистрированного сайта:
- существование `.conf` файла
- существование файлов сертификата и ключа (если назначены)
- запускает `nginx -t`

---

## Раздел 3 — SSL Certificates

Управление сертификатами. База хранится в `/var/lib/pngxconf/certs.db`.

### Create certificate — ssl-wizard.sh

Запускает `ssl-wizard.sh` как вложенный процесс. После завершения мастера система сравнивает содержимое `/etc/nginx/ssl/` до и после — новые файлы предлагается зарегистрировать в базе.

`ssl-wizard.sh` поддерживает:
- Let's Encrypt (standalone, webroot, nginx mode, wildcard DNS, wildcard Cloudflare)
- Self-signed: simple, RSA, ECDSA, Ed25519, Local CA
- Генерация ключей и случайных байт

Поиск `ssl-wizard.sh` выполняется в следующем порядке:
1. `/usr/local/lib/pngxconf/ssl-wizard.sh` ← рекомендуемое расположение
2. Директория рядом с бинарником `pngxconf`
3. `/var/lib/pngxconf/ssl-wizard.sh`
4. Ввод пути вручную (если не найден)

### Upload / Register

Загрузка уже имеющихся сертификатов:
1. Вводятся имя записи и домен
2. Создаётся директория `/etc/nginx/ssl/<domain>/`
3. Исходный `.crt` файл копируется в `/etc/nginx/ssl/<domain>/<domain>.crt` (права `644`)
4. Исходный `.key` файл копируется в `/etc/nginx/ssl/<domain>/<domain>.key` (права `600`)
5. Цепочка (`.chain.pem`) — опционально
6. Запись добавляется в `certs.db`

Файлы всегда копируются — оригиналы не изменяются.

### Inspect

Показывает для выбранного сертификата:
- Subject и Issuer
- Период действия (notBefore / notAfter)
- Subject Alternative Names
- Серийный номер

### Check expiry

Показывает таблицу всех зарегистрированных сертификатов с подсветкой:

| Цвет | Состояние |
|---|---|
| зелёный | действителен более 30 дней |
| жёлтый | менее 30 дней до истечения |
| красный | истёк |

### Remove certificate record

Удаляет только запись из `certs.db`. Файлы на диске **не удаляются**.

---

## Раздел 4 — nginx Control

| Действие | Команда |
|---|---|
| Test | `nginx -t` |
| Reload | `systemctl reload nginx` или `nginx -s reload` |
| Restart | `systemctl restart nginx` |
| Stop | `systemctl stop nginx` |
| Start | `systemctl start nginx` |

Перед Reload автоматически выполняется `nginx -t` — если тест провален, перезагрузка не производится.

---

## Раздел 5 — System Status

Сводная информация: версия nginx, статус процесса, пути к ключевым директориям, количество сайтов и сертификатов в базе, дата последнего редактирования `nginx.conf`, дата первого запуска. Завершается выводом `nginx -t`.

---

## База состояния

### `/var/lib/pngxconf/state.conf`

Файл формата `KEY=VALUE`. Хранит:

| Ключ | Содержимое |
|---|---|
| `FIRST_RUN_DONE` | `1` после завершения первой проверки |
| `FIRST_RUN_DATE` | дата первого запуска |
| `NGINX_BIN` | путь к бинарнику nginx |
| `NGINX_VERSION` | версия nginx |
| `NGINX_CONF_LAST_EDIT` | время последнего редактирования nginx.conf |
| `NGINX_CONF_LAST_BAK` | путь к последнему бэкапу |
| `SSL_WIZARD_PATH` | путь к ssl-wizard.sh |
| `NGINX_WORKER_PROCESSES` | текущее значение worker_processes |
| `NGINX_WORKER_CONNECTIONS` | текущее значение worker_connections |
| `NGINX_GZIP` | текущее состояние gzip |
| `NGINX_SERVER_TOKENS` | текущее состояние server_tokens |

### `/var/lib/pngxconf/sites.db`

Pipe-разделённый формат, одна строка на сайт:

```
name|conf_path|server_name|listen_port|ssl_cert|ssl_key|status|created
```

Пример:
```
myapp|/etc/nginx/conf.d/myapp.conf|app.example.com|443|/etc/nginx/ssl/app.example.com/app.example.com.crt|/etc/nginx/ssl/app.example.com/app.example.com.key|enabled|2024-01-15 14:30:22
```

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

Текстовый лог всех операций с временными метками:

```
[2024-01-15 14:28:10] site_add name=myapp conf=/etc/nginx/conf.d/myapp.conf
[2024-01-15 14:30:22] nginx.conf backup created: /etc/nginx/pngxconf-backups/nginx.conf.20240115_143022.worker_processes reason=worker_processes
[2024-01-15 14:30:22] nginx.conf set worker_processes=4 in main
[2024-01-15 14:31:05] nginx reloaded
```

---

## Бэкапы nginx.conf

Хранятся в `/etc/nginx/pngxconf-backups/`. Именование:

```
nginx.conf.YYYYMMDD_HHMMSS.<причина>
```

Примеры причин: `worker_processes`, `gzip_recommended`, `logformat_json`, `pre_restore`, `server_tokens`, `keepalive_timeout`.

Бэкап создаётся **автоматически перед каждым изменением** — отдельный файл на каждое действие. Восстановление через пункт "View change history" в разделе nginx.conf Management.

---

## Безопасность файлов

| Путь | Права |
|---|---|
| `/var/lib/pngxconf/` | `700` (только root) |
| `/var/lib/pngxconf/state.conf` | `600` |
| `/var/lib/pngxconf/sites.db` | `600` |
| `/var/lib/pngxconf/certs.db` | `600` |
| `/etc/nginx/ssl/` | `700` |
| `/etc/nginx/ssl/<domain>/` | `700` |
| `*.key` файлы | `600` |
| `*.crt` / `*.pem` файлы | `644` |

---

## Типичный сценарий работы

```bash
# Первый запуск — проверит систему и создаст все нужные директории
sudo pngxconf

# Создать HTTPS reverse proxy для app.example.com → 127.0.0.1:8080
# Главное меню → 3 (SSL Certificates) → 2 (Create) → запустит ssl-wizard
# Главное меню → 2 (Virtual Hosts) → 2 (Create) → тип: Reverse proxy + SSL

# Проверить статус всех сайтов
# Главное меню → 2 → 6 (Check all site configs)

# Включить gzip в nginx.conf
# Главное меню → 1 (nginx.conf) → 6 (gzip) → 6 (Apply recommended)

# Перезагрузить nginx
# Главное меню → 4 (nginx Control) → 2 (Reload)

# Проверить срок действия сертификатов
# Главное меню → 3 (SSL Certificates) → 5 (Check expiry)
```

---

## Справка

```bash
pngxconf -h
```

Выводит: описание, синтаксис вызова, расположение всех файлов, требования.
