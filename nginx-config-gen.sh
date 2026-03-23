#!/usr/bin/env bash
# ==============================================================================
#  nginx-config-gen.sh  |  Nginx Configuration Generator
#  Version 1.0
#  Interactive TUI for generating production-ready nginx configurations
#  Supports: Debian/Ubuntu, RHEL/CentOS/Fedora, Arch, openSUSE
# ==============================================================================

set -euo pipefail

# ── ANSI Color Scheme ─────────────────────────────────────────────────────────
R=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
CLR_HEADER=$'\e[38;2;56;189;248m'
CLR_ACCENT=$'\e[38;2;34;211;238m'
CLR_LABEL=$'\e[38;2;148;163;184m'
CLR_VALUE=$'\e[38;2;241;245;249m'
CLR_GOOD=$'\e[38;2;74;222;128m'
CLR_WARN=$'\e[38;2;251;191;36m'
CLR_ERR=$'\e[38;2;248;113;113m'
CLR_SEL=$'\e[38;2;56;189;248m\e[1m'
CLR_BOX=$'\e[38;2;71;85;105m'
CLR_TITLE=$'\e[38;2;99;102;241m'
CLR_DIM=$'\e[38;2;71;85;105m'

# ── Language mode ──────────────────────────────────────────────────────────────
LANG_MODE="en"

# ── i18n ──────────────────────────────────────────────────────────────────────
declare -A T
_load_strings() {
  if [[ "$LANG_MODE" == "ru" ]]; then
    T[title]="Генератор конфигурации Nginx"
    T[subtitle]="Интерактивный мастер настройки"
    T[press_enter]="Нажмите Enter для продолжения"
    T[select_lang]="Выберите язык / Select language"
    T[main_menu]="ГЛАВНОЕ МЕНЮ"
    T[menu_basic]="Основные параметры"
    T[menu_ssl]="Настройки SSL / TLS"
    T[menu_security]="Заголовки безопасности"
    T[menu_proxy]="Расширенные настройки прокси"
    T[menu_cache]="Кэширование"
    T[menu_limits]="Ограничения и тайм-ауты"
    T[menu_logging]="Логирование"
    T[menu_gzip]="Сжатие (gzip)"
    T[menu_advanced]="Дополнительные параметры"
    T[menu_preview]="Предпросмотр конфигурации"
    T[menu_save]="Сохранить конфигурацию"
    T[menu_apply]="Применить (reload nginx)"
    T[menu_exit]="Выход"
    T[basic_params]="ОСНОВНЫЕ ПАРАМЕТРЫ"
    T[listen_port]="Порт прослушивания"
    T[server_name]="Домен или IP-адрес"
    T[proxy_ip]="Внутренний IP для проксирования"
    T[proxy_port]="Порт для проксирования"
    T[proxy_proto]="Протокол бэкенда"
    T[input_prompt]="Введите значение"
    T[current]="Текущее"
    T[error_empty]="Значение не может быть пустым"
    T[error_port]="Некорректный порт (1-65535)"
    T[error_ip]="Некорректный IP-адрес"
    T[ssl_settings]="НАСТРОЙКИ SSL / TLS"
    T[ssl_enable]="Включить SSL"
    T[ssl_cert]="Путь к сертификату (.crt/.pem)"
    T[ssl_key]="Путь к приватному ключу (.key)"
    T[ssl_chain]="Цепочка сертификатов (необязательно)"
    T[ssl_protocols]="Протоколы TLS"
    T[ssl_ciphers]="Набор шифров"
    T[ssl_hsts]="Включить HSTS"
    T[ssl_hsts_age]="HSTS max-age (секунды)"
    T[ssl_stapling]="OCSP Stapling"
    T[ssl_session_timeout]="SSL session timeout"
    T[ssl_dhparam]="Путь к dhparam (необязательно)"
    T[ssl_redirect]="HTTP -> HTTPS редирект"
    T[security_headers]="ЗАГОЛОВКИ БЕЗОПАСНОСТИ"
    T[sec_xframe]="X-Frame-Options"
    T[sec_xcontent]="X-Content-Type-Options: nosniff"
    T[sec_xss]="X-XSS-Protection"
    T[sec_referrer]="Referrer-Policy"
    T[sec_csp]="Content-Security-Policy"
    T[sec_csp_value]="Значение CSP"
    T[sec_permissions]="Permissions-Policy"
    T[sec_server_tokens]="Скрыть версию nginx"
    T[proxy_settings]="НАСТРОЙКИ ПРОКСИ"
    T[proxy_buffering]="proxy_buffering"
    T[proxy_buf_size]="proxy_buffer_size"
    T[proxy_buffers]="proxy_buffers"
    T[proxy_timeout]="proxy_read_timeout (сек)"
    T[proxy_connect]="proxy_connect_timeout (сек)"
    T[proxy_send]="proxy_send_timeout (сек)"
    T[proxy_headers]="Передавать заголовки хоста"
    T[proxy_real_ip]="Передавать реальный IP клиента"
    T[proxy_websocket]="Поддержка WebSocket"
    T[proxy_intercept]="proxy_intercept_errors"
    T[cache_settings]="НАСТРОЙКИ КЭШИРОВАНИЯ"
    T[cache_enable]="Включить кэширование прокси"
    T[cache_zone]="Имя зоны кэша"
    T[cache_path]="Путь к кэшу"
    T[cache_time]="proxy_cache_valid"
    T[cache_bypass]="Cache-bypass условие"
    T[limits_settings]="ОГРАНИЧЕНИЯ И ТАЙМ-АУТЫ"
    T[client_max_body]="client_max_body_size (МБ)"
    T[client_timeout]="client_body_timeout (сек)"
    T[keepalive_timeout]="keepalive_timeout (сек)"
    T[send_timeout]="send_timeout (сек)"
    T[limit_req_enable]="Включить rate limiting"
    T[limit_req_zone]="Зона rate limiting"
    T[limit_req_rate]="Лимит запросов (r/s)"
    T[limit_req_burst]="burst"
    T[logging_settings]="НАСТРОЙКИ ЛОГИРОВАНИЯ"
    T[access_log]="access_log (путь или off)"
    T[error_log]="error_log (путь)"
    T[log_level]="Уровень лога"
    T[log_format]="Формат логов"
    T[gzip_settings]="НАСТРОЙКИ GZIP"
    T[gzip_enable]="Включить gzip"
    T[gzip_level]="gzip_comp_level (1-9)"
    T[gzip_types]="gzip_types"
    T[gzip_min_len]="gzip_min_length (байт)"
    T[gzip_vary]="gzip_vary on"
    T[gzip_proxied]="gzip_proxied"
    T[advanced_settings]="ДОПОЛНИТЕЛЬНЫЕ ПАРАМЕТРЫ"
    T[adv_root]="root директория (статика)"
    T[adv_index]="index файлы"
    T[adv_try_files]="try_files директива"
    T[adv_upstream_name]="Имя upstream группы"
    T[adv_upstream_keepalive]="upstream keepalive"
    T[adv_custom_headers]="Кастомные заголовки (через ;)"
    T[adv_return_404]="Возвращать 404 для неизвестных хостов"
    T[custom_error_pages]="Кастомные страницы ошибок"
    T[maintenance_mode]="Режим обслуживания (503)"
    T[adv_worker_proc]="worker_processes (nginx.conf)"
    T[adv_worker_conn]="worker_connections (nginx.conf)"
    T[preview_title]="ПРЕДПРОСМОТР КОНФИГУРАЦИИ"
    T[save_title]="СОХРАНЕНИЕ КОНФИГУРАЦИИ"
    T[save_path]="Путь для сохранения .conf файла"
    T[save_nginx_conf]="Обновить nginx.conf?"
    T[save_ok]="Конфигурация сохранена"
    T[save_err]="Ошибка сохранения"
    T[apply_ok]="nginx перезагружен успешно"
    T[apply_err]="Ошибка nginx"
    T[apply_test]="Проверка синтаксиса..."
    T[nginx_not_found]="nginx не найден"
    T[nginx_found]="nginx найден"
    T[confd_found]="conf.d найдена"
    T[confd_not_found]="conf.d не найдена"
    T[ssl_dir_found]="ssl/ найдена"
    T[ssl_dir_not_found]="ssl/ не найдена"
    T[distro_detected]="Дистрибутив"
    T[root_required]="Требуются права root"
    T[toggle_on]="[ВКЛ]"
    T[toggle_off]="[ВЫКЛ]"
    T[nav_hint]="стрелки — навигация  |  Enter — выбор  |  q — выход"
    T[back]="<- Назад"
    T[done]="Готово"
    T[confirm_apply]="Применить конфигурацию? (y/n)"
    T[no_basic]="Сначала заполните основные параметры"
    T[ssl_pick_cert]="Выберите сертификат"
    T[ssl_pick_key]="Выберите приватный ключ"
    T[manual_input]="Ввести путь вручную"
  else
    T[title]="Nginx Configuration Generator"
    T[subtitle]="Interactive Configuration Wizard"
    T[press_enter]="Press Enter to continue"
    T[select_lang]="Select language / Выберите язык"
    T[main_menu]="MAIN MENU"
    T[menu_basic]="Basic Parameters"
    T[menu_ssl]="SSL / TLS Settings"
    T[menu_security]="Security Headers"
    T[menu_proxy]="Advanced Proxy Settings"
    T[menu_cache]="Caching"
    T[menu_limits]="Limits and Timeouts"
    T[menu_logging]="Logging"
    T[menu_gzip]="Compression (gzip)"
    T[menu_advanced]="Advanced Options"
    T[menu_preview]="Preview Configuration"
    T[menu_save]="Save Configuration"
    T[menu_apply]="Apply (reload nginx)"
    T[menu_exit]="Exit"
    T[basic_params]="BASIC PARAMETERS"
    T[listen_port]="Listen port"
    T[server_name]="Domain or IP address"
    T[proxy_ip]="Internal IP to proxy"
    T[proxy_port]="Port to proxy"
    T[proxy_proto]="Backend protocol"
    T[input_prompt]="Enter value"
    T[current]="Current"
    T[error_empty]="Value cannot be empty"
    T[error_port]="Invalid port (1-65535)"
    T[error_ip]="Invalid IP address"
    T[ssl_settings]="SSL / TLS SETTINGS"
    T[ssl_enable]="Enable SSL"
    T[ssl_cert]="Certificate path (.crt/.pem)"
    T[ssl_key]="Private key path (.key)"
    T[ssl_chain]="Certificate chain path (optional)"
    T[ssl_protocols]="TLS Protocols"
    T[ssl_ciphers]="Cipher suite"
    T[ssl_hsts]="Enable HSTS"
    T[ssl_hsts_age]="HSTS max-age (seconds)"
    T[ssl_stapling]="OCSP Stapling"
    T[ssl_session_timeout]="SSL session timeout"
    T[ssl_dhparam]="dhparam path (optional)"
    T[ssl_redirect]="HTTP -> HTTPS redirect"
    T[security_headers]="SECURITY HEADERS"
    T[sec_xframe]="X-Frame-Options"
    T[sec_xcontent]="X-Content-Type-Options: nosniff"
    T[sec_xss]="X-XSS-Protection"
    T[sec_referrer]="Referrer-Policy"
    T[sec_csp]="Content-Security-Policy"
    T[sec_csp_value]="CSP value"
    T[sec_permissions]="Permissions-Policy"
    T[sec_server_tokens]="Hide nginx version (server_tokens off)"
    T[proxy_settings]="PROXY SETTINGS"
    T[proxy_buffering]="proxy_buffering"
    T[proxy_buf_size]="proxy_buffer_size"
    T[proxy_buffers]="proxy_buffers"
    T[proxy_timeout]="proxy_read_timeout (sec)"
    T[proxy_connect]="proxy_connect_timeout (sec)"
    T[proxy_send]="proxy_send_timeout (sec)"
    T[proxy_headers]="Pass host headers"
    T[proxy_real_ip]="Pass real client IP"
    T[proxy_websocket]="WebSocket support"
    T[proxy_intercept]="proxy_intercept_errors"
    T[cache_settings]="CACHE SETTINGS"
    T[cache_enable]="Enable proxy cache"
    T[cache_zone]="Cache zone name"
    T[cache_path]="Cache path"
    T[cache_time]="proxy_cache_valid"
    T[cache_bypass]="Cache-bypass condition"
    T[limits_settings]="LIMITS AND TIMEOUTS"
    T[client_max_body]="client_max_body_size (MB)"
    T[client_timeout]="client_body_timeout (sec)"
    T[keepalive_timeout]="keepalive_timeout (sec)"
    T[send_timeout]="send_timeout (sec)"
    T[limit_req_enable]="Enable rate limiting"
    T[limit_req_zone]="Rate limit zone"
    T[limit_req_rate]="Request rate (r/s)"
    T[limit_req_burst]="burst"
    T[logging_settings]="LOGGING SETTINGS"
    T[access_log]="access_log (path or off)"
    T[error_log]="error_log (path)"
    T[log_level]="error_log level"
    T[log_format]="Log format"
    T[gzip_settings]="GZIP COMPRESSION"
    T[gzip_enable]="Enable gzip"
    T[gzip_level]="gzip_comp_level (1-9)"
    T[gzip_types]="gzip_types"
    T[gzip_min_len]="gzip_min_length (bytes)"
    T[gzip_vary]="gzip_vary on"
    T[gzip_proxied]="gzip_proxied"
    T[advanced_settings]="ADVANCED OPTIONS"
    T[adv_root]="root directory (static files)"
    T[adv_index]="index files"
    T[adv_try_files]="try_files directive"
    T[adv_upstream_name]="Upstream group name"
    T[adv_upstream_keepalive]="upstream keepalive connections"
    T[adv_custom_headers]="Custom response headers (semicolon separated)"
    T[adv_return_404]="Return 404 for unknown hosts"
    T[custom_error_pages]="Custom error pages"
    T[maintenance_mode]="Maintenance mode (503)"
    T[adv_worker_proc]="worker_processes (nginx.conf)"
    T[adv_worker_conn]="worker_connections (nginx.conf)"
    T[preview_title]="CONFIGURATION PREVIEW"
    T[save_title]="SAVE CONFIGURATION"
    T[save_path]="Output path for .conf file"
    T[save_nginx_conf]="Also update nginx.conf? (y/n)"
    T[save_ok]="Configuration saved"
    T[save_err]="Save error"
    T[apply_ok]="nginx reloaded successfully"
    T[apply_err]="nginx error"
    T[apply_test]="Testing nginx syntax..."
    T[nginx_not_found]="nginx not found"
    T[nginx_found]="nginx found"
    T[confd_found]="conf.d found"
    T[confd_not_found]="conf.d not found"
    T[ssl_dir_found]="ssl/ found"
    T[ssl_dir_not_found]="ssl/ not found"
    T[distro_detected]="Distro"
    T[root_required]="Root privileges required"
    T[toggle_on]="[ON]"
    T[toggle_off]="[OFF]"
    T[nav_hint]="arrows navigate  |  Enter select  |  q quit"
    T[back]="<- Back"
    T[done]="Done"
    T[confirm_apply]="Apply configuration? (y/n)"
    T[no_basic]="Fill in basic parameters first"
    T[ssl_pick_cert]="Select certificate"
    T[ssl_pick_key]="Select private key"
    T[manual_input]="Enter path manually"
  fi
}

# ── Default configuration values ──────────────────────────────────────────────
CFG_LISTEN_PORT="80"
CFG_SERVER_NAME=""
CFG_PROXY_IP=""
CFG_PROXY_PORT="3000"
CFG_PROXY_PROTO="http"

CFG_SSL_ENABLE=false
CFG_SSL_CERT=""
CFG_SSL_KEY=""
CFG_SSL_CHAIN=""
CFG_SSL_PROTOCOLS="TLSv1.2 TLSv1.3"
CFG_SSL_CIPHERS="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305"
CFG_SSL_HSTS=false
CFG_SSL_HSTS_AGE="31536000"
CFG_SSL_STAPLING=false
CFG_SSL_SESSION_TIMEOUT="1d"
CFG_SSL_DHPARAM=""
CFG_SSL_REDIRECT=false

CFG_SEC_XFRAME="SAMEORIGIN"
CFG_SEC_XCONTENT=true
CFG_SEC_XSS=true
CFG_SEC_REFERRER="strict-origin-when-cross-origin"
CFG_SEC_CSP=false
CFG_SEC_CSP_VALUE="default-src 'self'"
CFG_SEC_PERMISSIONS=false
CFG_SEC_SERVER_TOKENS=true

CFG_PROXY_BUFFERING=true
CFG_PROXY_BUF_SIZE="4k"
CFG_PROXY_BUFFERS="8 4k"
CFG_PROXY_TIMEOUT="60"
CFG_PROXY_CONNECT="10"
CFG_PROXY_SEND="60"
CFG_PROXY_HEADERS=true
CFG_PROXY_REAL_IP=true
CFG_PROXY_WEBSOCKET=false
CFG_PROXY_INTERCEPT=false

CFG_CACHE_ENABLE=false
CFG_CACHE_ZONE="my_cache"
CFG_CACHE_PATH="/var/cache/nginx/my_cache"
CFG_CACHE_TIME="200 1d"
CFG_CACHE_BYPASS=""

CFG_CLIENT_MAX_BODY="10"
CFG_CLIENT_TIMEOUT="60"
CFG_KEEPALIVE_TIMEOUT="75"
CFG_SEND_TIMEOUT="60"
CFG_LIMIT_REQ_ENABLE=false
CFG_LIMIT_REQ_ZONE="one"
CFG_LIMIT_REQ_RATE="10"
CFG_LIMIT_REQ_BURST="20"

CFG_ACCESS_LOG="/var/log/nginx/access.log"
CFG_ERROR_LOG="/var/log/nginx/error.log"
CFG_LOG_LEVEL="warn"
CFG_LOG_FORMAT="combined"

CFG_GZIP_ENABLE=true
CFG_GZIP_LEVEL="6"
CFG_GZIP_TYPES="text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/atom+xml image/svg+xml"
CFG_GZIP_MIN_LEN="1024"
CFG_GZIP_VARY=true
CFG_GZIP_PROXIED="any"

CFG_ROOT=""
CFG_INDEX="index.html index.htm"
CFG_TRY_FILES=""
CFG_UPSTREAM_NAME="backend"
CFG_UPSTREAM_KEEPALIVE="32"
CFG_CUSTOM_HEADERS=""
CFG_RETURN_404=false
CFG_CUSTOM_ERROR_PAGES=false
CFG_MAINTENANCE=false
CFG_NGINX_CONF_WORKER_PROC=""
CFG_NGINX_CONF_WORKER_CONN=""
CFG_OUTPUT_PATH="/etc/nginx/conf.d/site.conf"

# ── System detection ──────────────────────────────────────────────────────────
NGINX_BIN=""
NGINX_CONF="/etc/nginx/nginx.conf"
NGINX_CONFD="/etc/nginx/conf.d"
NGINX_SSL="/etc/nginx/ssl"
DISTRO="Unknown"
DISTRO_FAMILY="unknown"
NGINX_FOUND=false
CONFD_FOUND=false
SSL_DIR_FOUND=false

detect_system() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO="${NAME:-Unknown}"
    case "${ID:-}" in
      ubuntu|debian|linuxmint|pop|kali|raspbian) DISTRO_FAMILY="debian" ;;
      rhel|centos|fedora|rocky|almalinux|ol|amzn) DISTRO_FAMILY="rhel" ;;
      arch|manjaro|endeavouros) DISTRO_FAMILY="arch" ;;
      opensuse*|sles) DISTRO_FAMILY="suse" ;;
      *) DISTRO_FAMILY="unknown" ;;
    esac
  elif [[ -f /etc/debian_version ]]; then
    DISTRO="Debian"; DISTRO_FAMILY="debian"
  elif [[ -f /etc/redhat-release ]]; then
    DISTRO=$(cat /etc/redhat-release); DISTRO_FAMILY="rhel"
  fi

  for _b in nginx /usr/sbin/nginx /usr/local/sbin/nginx /usr/bin/nginx; do
    if command -v "$_b" &>/dev/null; then
      NGINX_BIN=$(command -v "$_b")
      NGINX_FOUND=true
      break
    elif [[ -x "$_b" ]]; then
      NGINX_BIN="$_b"
      NGINX_FOUND=true
      break
    fi
  done

  [[ -d "$NGINX_CONFD" ]] && CONFD_FOUND=true
  [[ -d "$NGINX_SSL"   ]] && SSL_DIR_FOUND=true
}

# ── Terminal ──────────────────────────────────────────────────────────────────
TERM_W=80
TERM_H=24

upd_size() {
  TERM_W=$(tput cols  2>/dev/null || echo 80)
  TERM_H=$(tput lines 2>/dev/null || echo 24)
}

hide_cur() { printf '\e[?25l'; }
show_cur() { printf '\e[?25h'; }
mov()      { printf '\e[%d;%dH' "$1" "$2"; }

center() {
  local txt="$1" w="${2:-$TERM_W}"
  local clean; clean=$(printf '%s' "$txt" | sed 's/\x1b\[[0-9;]*m//g')
  local pad=$(( (w - ${#clean}) / 2 ))
  [[ $pad -lt 0 ]] && pad=0
  printf '%*s%s' "$pad" '' "$txt"
}

hline() {
  local c="${1:--}" w="${2:-$TERM_W}"
  printf '%s' "${CLR_BOX}"
  printf '%*s' "$w" '' | tr ' ' "$c"
  printf '%s\n' "${R}"
}

draw_header() {
  upd_size
  printf '\e[2J\e[H'
  local w=$TERM_W
  printf '%s' "${CLR_HEADER}${BOLD}"
  printf '%s\n' "$(center "$(printf '╔%*s╗' $((w-2)) '' | tr ' ' '═')" "$w")"
  printf '%s\n' "$(center "$(printf '║%*s║' $((w-2)) '')" "$w")"

  local t1=" ⚡  ${T[title]}  ⚡ "
  local inner_t1; inner_t1=$(printf '%b' "${CLR_ACCENT}${BOLD}${t1}${CLR_HEADER}")
  printf '║'
  center "$inner_t1" $((w-2))
  printf '║\n'

  local t2="  ${T[subtitle]}  "
  local inner_t2; inner_t2=$(printf '%b' "${CLR_DIM}${t2}${CLR_HEADER}")
  printf '║'
  center "$inner_t2" $((w-2))
  printf '║\n'

  printf '%s\n' "$(center "$(printf '║%*s║' $((w-2)) '')" "$w")"
  printf '%s\n' "$(center "$(printf '╚%*s╝' $((w-2)) '' | tr ' ' '═')" "$w")"
  printf '%s\n' "${R}"
}

draw_sysinfo() {
  local nv="" nstr cstr sstr dstr
  if $NGINX_FOUND; then
    nv=$("$NGINX_BIN" -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || true)
    nstr="${CLR_GOOD}${T[nginx_found]}${R}${CLR_DIM} (${nv:-?})${R}"
  else
    nstr="${CLR_ERR}${T[nginx_not_found]}${R}"
  fi
  $CONFD_FOUND && cstr="${CLR_GOOD}${T[confd_found]}${R}" || cstr="${CLR_WARN}${T[confd_not_found]}${R}"
  $SSL_DIR_FOUND && sstr="${CLR_GOOD}${T[ssl_dir_found]}${R}" || sstr="${CLR_WARN}${T[ssl_dir_not_found]}${R}"
  dstr="${CLR_LABEL}${T[distro_detected]}:${R} ${CLR_VALUE}${DISTRO}${R} ${CLR_DIM}[${DISTRO_FAMILY}]${R}"

  printf '  %b  |  nginx: %b  |  conf.d: %b  |  ssl: %b\n' \
    "$dstr" "$nstr" "$cstr" "$sstr"
  hline '-' "$TERM_W"
  echo
}

draw_footer() {
  echo
  printf '%s' "${CLR_DIM}"
  center "-- ${T[nav_hint]} --" "$TERM_W"
  printf '%s\n' "${R}"
}

# ── Menu engine ────────────────────────────────────────────────────────────────
MENU_RESULT=0

menu_select() {
  local title="$1"
  local -n _mi="$2"
  local cur=0
  local cnt=${#_mi[@]}
  hide_cur
  while true; do
    draw_header
    draw_sysinfo
    printf '  %s%s%s\n\n' "${CLR_ACCENT}${BOLD}" "$title" "${R}"
    for ((i=0; i<cnt; i++)); do
      if [[ $i -eq $cur ]]; then
        printf '  %s>  %b%s\n' "${CLR_SEL}" "${_mi[$i]}" "${R}"
      else
        printf '     %b%s\n' "${_mi[$i]}" "${R}"
      fi
    done
    draw_footer
    IFS= read -rsn1 k
    if [[ "$k" == $'\x1b' ]]; then
      IFS= read -rsn2 -t 0.1 sq || true
      [[ "$sq" == '[A' ]] && (( cur > 0 )) && (( cur-- ))
      [[ "$sq" == '[B' ]] && (( cur < cnt-1 )) && (( cur++ ))
    elif [[ "$k" == '' ]]; then
      MENU_RESULT=$cur; show_cur; return 0
    elif [[ "$k" == 'q' || "$k" == 'Q' ]]; then
      show_cur; return 1
    fi
  done
}

# ── Input helpers ──────────────────────────────────────────────────────────────
prompt_input() {
  local label="$1" varname="$2" validator="${3:-}"
  local cur; cur=$(eval "echo \"\${$varname}\"")
  show_cur
  while true; do
    printf '\n  %s%s%s' "${CLR_ACCENT}" "$label" "${R}"
    [[ -n "$cur" ]] && printf '  %s(%s: %s)%s' "${CLR_DIM}" "${T[current]}" "$cur" "${R}"
    printf '\n  %s> %s ' "${CLR_SEL}" "${R}"
    IFS= read -re inp
    [[ -z "$inp" && -n "$cur" ]] && inp="$cur"
    local ok=true
    case "$validator" in
      port)
        if ! [[ "$inp" =~ ^[0-9]+$ ]] || (( inp < 1 || inp > 65535 )); then
          printf '  %s  %s%s\n' "${CLR_ERR}" "${T[error_port]}" "${R}"; ok=false
        fi ;;
      ip)
        if ! [[ "$inp" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
          printf '  %s  %s%s\n' "${CLR_ERR}" "${T[error_ip]}" "${R}"; ok=false
        fi ;;
      nonempty)
        if [[ -z "$inp" ]]; then
          printf '  %s  %s%s\n' "${CLR_ERR}" "${T[error_empty]}" "${R}"; ok=false
        fi ;;
    esac
    if $ok; then eval "$varname=\"\$inp\""; hide_cur; return 0; fi
  done
}

toggle_bool() {
  local vn="$1"
  local cv; cv=$(eval "echo \"\${$vn}\"")
  if $cv; then eval "$vn=false"; else eval "$vn=true"; fi
}

bool_badge() {
  local v="$1"
  if $v; then printf '%s%s%s' "${CLR_GOOD}" "${T[toggle_on]}"  "${R}"
  else        printf '%s%s%s' "${CLR_DIM}"  "${T[toggle_off]}" "${R}"
  fi
}

prompt_choose() {
  local label="$1" varname="$2"; shift 2
  local opts=("$@")
  printf '\n  %s%s%s\n' "${CLR_ACCENT}" "$label" "${R}"
  for ((i=0; i<${#opts[@]}; i++)); do
    printf '  %s[%d]%s %s\n' "${CLR_LABEL}" "$((i+1))" "${R}" "${opts[$i]}"
  done
  printf '  %s> %s ' "${CLR_SEL}" "${R}"
  show_cur
  IFS= read -re ch
  hide_cur
  if [[ "$ch" =~ ^[0-9]+$ ]] && (( ch >= 1 && ch <= ${#opts[@]} )); then
    eval "$varname=\"${opts[$((ch-1))]}\""
  fi
}

# ── SSL file picker ────────────────────────────────────────────────────────────
pick_ssl_file() {
  local varname="$1" hint="$2"
  local files=()
  if [[ -d "$NGINX_SSL" ]]; then
    while IFS= read -r -d '' f; do
      files+=("$(basename "$f")")
    done < <(find "$NGINX_SSL" -maxdepth 2 -type f \
      \( -name "*.crt" -o -name "*.pem" -o -name "*.key" -o -name "*.cer" \) \
      -print0 2>/dev/null || true)
  fi
  files+=("${T[manual_input]}")
  local cur=0
  hide_cur
  while true; do
    draw_header
    printf '  %s%s%s\n\n' "${CLR_ACCENT}${BOLD}" "$hint" "${R}"
    for ((i=0; i<${#files[@]}; i++)); do
      if [[ $i -eq $cur ]]; then
        printf '  %s>  %s%s\n' "${CLR_SEL}" "${files[$i]}" "${R}"
      else
        printf '     %s\n' "${files[$i]}"
      fi
    done
    draw_footer
    IFS= read -rsn1 k
    if [[ "$k" == $'\x1b' ]]; then
      IFS= read -rsn2 -t 0.1 sq || true
      [[ "$sq" == '[A' ]] && (( cur > 0 )) && (( cur-- ))
      [[ "$sq" == '[B' ]] && (( cur < ${#files[@]}-1 )) && (( cur++ ))
    elif [[ "$k" == '' ]]; then
      local chosen="${files[$cur]}"
      if [[ "$chosen" == "${T[manual_input]}" ]]; then
        prompt_input "$hint" "$varname"
      else
        eval "$varname=\"${NGINX_SSL}/${chosen}\""
      fi
      show_cur; return 0
    elif [[ "$k" == 'q' || "$k" == 'Q' ]]; then
      show_cur; return 1
    fi
  done
}

# ── Sections ──────────────────────────────────────────────────────────────────
section_basic() {
  draw_header
  printf '  %s%s%s\n\n' "${CLR_ACCENT}${BOLD}" "${T[basic_params]}" "${R}"
  prompt_input "${T[listen_port]}"  CFG_LISTEN_PORT  port
  prompt_input "${T[server_name]}"  CFG_SERVER_NAME  nonempty
  prompt_input "${T[proxy_ip]}"     CFG_PROXY_IP     ip
  prompt_input "${T[proxy_port]}"   CFG_PROXY_PORT   port
  prompt_choose "${T[proxy_proto]}" CFG_PROXY_PROTO  http https
  printf '\n  %s%s %s%s\n' "${CLR_GOOD}" "+" "${T[done]}" "${R}"
  sleep 0.6
}

section_ssl() {
  while true; do
    local items=(
      "$(bool_badge $CFG_SSL_ENABLE)  ${T[ssl_enable]}"
      "${CLR_LABEL}${T[ssl_cert]}:${R} ${CLR_VALUE}${CFG_SSL_CERT:-—}${R}"
      "${CLR_LABEL}${T[ssl_key]}:${R} ${CLR_VALUE}${CFG_SSL_KEY:-—}${R}"
      "${CLR_LABEL}${T[ssl_chain]}:${R} ${CLR_VALUE}${CFG_SSL_CHAIN:-—}${R}"
      "${CLR_LABEL}${T[ssl_protocols]}:${R} ${CLR_VALUE}${CFG_SSL_PROTOCOLS}${R}"
      "${CLR_LABEL}${T[ssl_ciphers]}:${R} ${CLR_DIM}(ECDHE...)${R}"
      "$(bool_badge $CFG_SSL_HSTS)  ${T[ssl_hsts]}"
      "${CLR_LABEL}${T[ssl_hsts_age]}:${R} ${CLR_VALUE}${CFG_SSL_HSTS_AGE}${R}"
      "$(bool_badge $CFG_SSL_STAPLING)  ${T[ssl_stapling]}"
      "${CLR_LABEL}${T[ssl_session_timeout]}:${R} ${CLR_VALUE}${CFG_SSL_SESSION_TIMEOUT}${R}"
      "${CLR_LABEL}${T[ssl_dhparam]}:${R} ${CLR_VALUE}${CFG_SSL_DHPARAM:-—}${R}"
      "$(bool_badge $CFG_SSL_REDIRECT)  ${T[ssl_redirect]}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[ssl_settings]}" items || return
    case $MENU_RESULT in
      0)  toggle_bool CFG_SSL_ENABLE
          $CFG_SSL_ENABLE && CFG_LISTEN_PORT="443" ;;
      1)  pick_ssl_file CFG_SSL_CERT "${T[ssl_pick_cert]}" ;;
      2)  pick_ssl_file CFG_SSL_KEY  "${T[ssl_pick_key]}"  ;;
      3)  prompt_input "${T[ssl_chain]}"            CFG_SSL_CHAIN ;;
      4)  prompt_choose "${T[ssl_protocols]}" CFG_SSL_PROTOCOLS \
            "TLSv1.2 TLSv1.3" "TLSv1.3" "TLSv1.1 TLSv1.2 TLSv1.3" ;;
      5)  prompt_input "${T[ssl_ciphers]}"          CFG_SSL_CIPHERS ;;
      6)  toggle_bool CFG_SSL_HSTS ;;
      7)  prompt_input "${T[ssl_hsts_age]}"         CFG_SSL_HSTS_AGE ;;
      8)  toggle_bool CFG_SSL_STAPLING ;;
      9)  prompt_input "${T[ssl_session_timeout]}"  CFG_SSL_SESSION_TIMEOUT ;;
      10) prompt_input "${T[ssl_dhparam]}"          CFG_SSL_DHPARAM ;;
      11) toggle_bool CFG_SSL_REDIRECT ;;
      12) return ;;
    esac
  done
}

section_security() {
  while true; do
    local items=(
      "${CLR_LABEL}${T[sec_xframe]}:${R} ${CLR_VALUE}${CFG_SEC_XFRAME}${R}"
      "$(bool_badge $CFG_SEC_XCONTENT)  ${T[sec_xcontent]}"
      "$(bool_badge $CFG_SEC_XSS)  ${T[sec_xss]}"
      "${CLR_LABEL}${T[sec_referrer]}:${R} ${CLR_VALUE}${CFG_SEC_REFERRER}${R}"
      "$(bool_badge $CFG_SEC_CSP)  ${T[sec_csp]}"
      "${CLR_LABEL}${T[sec_csp_value]}:${R} ${CLR_DIM}${CFG_SEC_CSP_VALUE:0:35}...${R}"
      "$(bool_badge $CFG_SEC_PERMISSIONS)  ${T[sec_permissions]}"
      "$(bool_badge $CFG_SEC_SERVER_TOKENS)  ${T[sec_server_tokens]}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[security_headers]}" items || return
    case $MENU_RESULT in
      0) prompt_choose "${T[sec_xframe]}" CFG_SEC_XFRAME \
           SAMEORIGIN DENY "ALLOW-FROM https://example.com" ;;
      1) toggle_bool CFG_SEC_XCONTENT ;;
      2) toggle_bool CFG_SEC_XSS ;;
      3) prompt_choose "${T[sec_referrer]}" CFG_SEC_REFERRER \
           "strict-origin-when-cross-origin" "no-referrer" \
           "same-origin" "origin" "unsafe-url" ;;
      4) toggle_bool CFG_SEC_CSP ;;
      5) prompt_input "${T[sec_csp_value]}" CFG_SEC_CSP_VALUE ;;
      6) toggle_bool CFG_SEC_PERMISSIONS ;;
      7) toggle_bool CFG_SEC_SERVER_TOKENS ;;
      8) return ;;
    esac
  done
}

section_proxy() {
  while true; do
    local items=(
      "$(bool_badge $CFG_PROXY_BUFFERING)  ${T[proxy_buffering]}"
      "${CLR_LABEL}${T[proxy_buf_size]}:${R} ${CLR_VALUE}${CFG_PROXY_BUF_SIZE}${R}"
      "${CLR_LABEL}${T[proxy_buffers]}:${R} ${CLR_VALUE}${CFG_PROXY_BUFFERS}${R}"
      "${CLR_LABEL}${T[proxy_timeout]}:${R} ${CLR_VALUE}${CFG_PROXY_TIMEOUT}${R}"
      "${CLR_LABEL}${T[proxy_connect]}:${R} ${CLR_VALUE}${CFG_PROXY_CONNECT}${R}"
      "${CLR_LABEL}${T[proxy_send]}:${R} ${CLR_VALUE}${CFG_PROXY_SEND}${R}"
      "$(bool_badge $CFG_PROXY_HEADERS)  ${T[proxy_headers]}"
      "$(bool_badge $CFG_PROXY_REAL_IP)  ${T[proxy_real_ip]}"
      "$(bool_badge $CFG_PROXY_WEBSOCKET)  ${T[proxy_websocket]}"
      "$(bool_badge $CFG_PROXY_INTERCEPT)  ${T[proxy_intercept]}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[proxy_settings]}" items || return
    case $MENU_RESULT in
      0)  toggle_bool CFG_PROXY_BUFFERING ;;
      1)  prompt_input "${T[proxy_buf_size]}"  CFG_PROXY_BUF_SIZE ;;
      2)  prompt_input "${T[proxy_buffers]}"   CFG_PROXY_BUFFERS ;;
      3)  prompt_input "${T[proxy_timeout]}"   CFG_PROXY_TIMEOUT ;;
      4)  prompt_input "${T[proxy_connect]}"   CFG_PROXY_CONNECT ;;
      5)  prompt_input "${T[proxy_send]}"      CFG_PROXY_SEND ;;
      6)  toggle_bool CFG_PROXY_HEADERS ;;
      7)  toggle_bool CFG_PROXY_REAL_IP ;;
      8)  toggle_bool CFG_PROXY_WEBSOCKET ;;
      9)  toggle_bool CFG_PROXY_INTERCEPT ;;
      10) return ;;
    esac
  done
}

section_cache() {
  while true; do
    local items=(
      "$(bool_badge $CFG_CACHE_ENABLE)  ${T[cache_enable]}"
      "${CLR_LABEL}${T[cache_zone]}:${R} ${CLR_VALUE}${CFG_CACHE_ZONE}${R}"
      "${CLR_LABEL}${T[cache_path]}:${R} ${CLR_VALUE}${CFG_CACHE_PATH}${R}"
      "${CLR_LABEL}${T[cache_time]}:${R} ${CLR_VALUE}${CFG_CACHE_TIME}${R}"
      "${CLR_LABEL}${T[cache_bypass]}:${R} ${CLR_VALUE}${CFG_CACHE_BYPASS:-—}${R}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[cache_settings]}" items || return
    case $MENU_RESULT in
      0) toggle_bool CFG_CACHE_ENABLE ;;
      1) prompt_input "${T[cache_zone]}"   CFG_CACHE_ZONE ;;
      2) prompt_input "${T[cache_path]}"   CFG_CACHE_PATH ;;
      3) prompt_input "${T[cache_time]}"   CFG_CACHE_TIME ;;
      4) prompt_input "${T[cache_bypass]}" CFG_CACHE_BYPASS ;;
      5) return ;;
    esac
  done
}

section_limits() {
  while true; do
    local items=(
      "${CLR_LABEL}${T[client_max_body]}:${R} ${CLR_VALUE}${CFG_CLIENT_MAX_BODY}m${R}"
      "${CLR_LABEL}${T[client_timeout]}:${R} ${CLR_VALUE}${CFG_CLIENT_TIMEOUT}s${R}"
      "${CLR_LABEL}${T[keepalive_timeout]}:${R} ${CLR_VALUE}${CFG_KEEPALIVE_TIMEOUT}s${R}"
      "${CLR_LABEL}${T[send_timeout]}:${R} ${CLR_VALUE}${CFG_SEND_TIMEOUT}s${R}"
      "$(bool_badge $CFG_LIMIT_REQ_ENABLE)  ${T[limit_req_enable]}"
      "${CLR_LABEL}${T[limit_req_zone]}:${R} ${CLR_VALUE}${CFG_LIMIT_REQ_ZONE}${R}"
      "${CLR_LABEL}${T[limit_req_rate]}:${R} ${CLR_VALUE}${CFG_LIMIT_REQ_RATE}r/s${R}"
      "${CLR_LABEL}${T[limit_req_burst]}:${R} ${CLR_VALUE}${CFG_LIMIT_REQ_BURST}${R}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[limits_settings]}" items || return
    case $MENU_RESULT in
      0) prompt_input "${T[client_max_body]}"   CFG_CLIENT_MAX_BODY ;;
      1) prompt_input "${T[client_timeout]}"    CFG_CLIENT_TIMEOUT ;;
      2) prompt_input "${T[keepalive_timeout]}" CFG_KEEPALIVE_TIMEOUT ;;
      3) prompt_input "${T[send_timeout]}"      CFG_SEND_TIMEOUT ;;
      4) toggle_bool CFG_LIMIT_REQ_ENABLE ;;
      5) prompt_input "${T[limit_req_zone]}"    CFG_LIMIT_REQ_ZONE ;;
      6) prompt_input "${T[limit_req_rate]}"    CFG_LIMIT_REQ_RATE ;;
      7) prompt_input "${T[limit_req_burst]}"   CFG_LIMIT_REQ_BURST ;;
      8) return ;;
    esac
  done
}

section_logging() {
  while true; do
    local items=(
      "${CLR_LABEL}${T[access_log]}:${R} ${CLR_VALUE}${CFG_ACCESS_LOG}${R}"
      "${CLR_LABEL}${T[error_log]}:${R} ${CLR_VALUE}${CFG_ERROR_LOG}${R}"
      "${CLR_LABEL}${T[log_level]}:${R} ${CLR_VALUE}${CFG_LOG_LEVEL}${R}"
      "${CLR_LABEL}${T[log_format]}:${R} ${CLR_VALUE}${CFG_LOG_FORMAT}${R}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[logging_settings]}" items || return
    case $MENU_RESULT in
      0) prompt_input "${T[access_log]}" CFG_ACCESS_LOG ;;
      1) prompt_input "${T[error_log]}"  CFG_ERROR_LOG ;;
      2) prompt_choose "${T[log_level]}" CFG_LOG_LEVEL \
           debug info notice warn error crit alert emerg ;;
      3) prompt_choose "${T[log_format]}" CFG_LOG_FORMAT \
           combined common json ;;
      4) return ;;
    esac
  done
}

section_gzip() {
  while true; do
    local items=(
      "$(bool_badge $CFG_GZIP_ENABLE)  ${T[gzip_enable]}"
      "${CLR_LABEL}${T[gzip_level]}:${R} ${CLR_VALUE}${CFG_GZIP_LEVEL}${R}"
      "${CLR_LABEL}${T[gzip_min_len]}:${R} ${CLR_VALUE}${CFG_GZIP_MIN_LEN}${R}"
      "$(bool_badge $CFG_GZIP_VARY)  ${T[gzip_vary]}"
      "${CLR_LABEL}${T[gzip_proxied]}:${R} ${CLR_VALUE}${CFG_GZIP_PROXIED}${R}"
      "${CLR_LABEL}${T[gzip_types]}:${R} ${CLR_DIM}(text/plain text/css ...)${R}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[gzip_settings]}" items || return
    case $MENU_RESULT in
      0) toggle_bool CFG_GZIP_ENABLE ;;
      1) prompt_choose "${T[gzip_level]}" CFG_GZIP_LEVEL 1 2 3 4 5 6 7 8 9 ;;
      2) prompt_input "${T[gzip_min_len]}" CFG_GZIP_MIN_LEN ;;
      3) toggle_bool CFG_GZIP_VARY ;;
      4) prompt_choose "${T[gzip_proxied]}" CFG_GZIP_PROXIED \
           off expired no-cache no-store private no_last_modified no_etag auth any ;;
      5) prompt_input "${T[gzip_types]}" CFG_GZIP_TYPES ;;
      6) return ;;
    esac
  done
}

section_advanced() {
  while true; do
    local items=(
      "${CLR_LABEL}${T[adv_root]}:${R} ${CLR_VALUE}${CFG_ROOT:-—}${R}"
      "${CLR_LABEL}${T[adv_index]}:${R} ${CLR_VALUE}${CFG_INDEX}${R}"
      "${CLR_LABEL}${T[adv_try_files]}:${R} ${CLR_VALUE}${CFG_TRY_FILES:-—}${R}"
      "${CLR_LABEL}${T[adv_upstream_name]}:${R} ${CLR_VALUE}${CFG_UPSTREAM_NAME}${R}"
      "${CLR_LABEL}${T[adv_upstream_keepalive]}:${R} ${CLR_VALUE}${CFG_UPSTREAM_KEEPALIVE}${R}"
      "${CLR_LABEL}${T[adv_custom_headers]}:${R} ${CLR_VALUE}${CFG_CUSTOM_HEADERS:-—}${R}"
      "$(bool_badge $CFG_RETURN_404)  ${T[adv_return_404]}"
      "$(bool_badge $CFG_CUSTOM_ERROR_PAGES)  ${T[custom_error_pages]}"
      "$(bool_badge $CFG_MAINTENANCE)  ${T[maintenance_mode]}"
      "${CLR_LABEL}${T[adv_worker_proc]}:${R} ${CLR_VALUE}${CFG_NGINX_CONF_WORKER_PROC:-auto}${R}"
      "${CLR_LABEL}${T[adv_worker_conn]}:${R} ${CLR_VALUE}${CFG_NGINX_CONF_WORKER_CONN:-1024}${R}"
      "${CLR_DIM}${T[back]}${R}"
    )
    menu_select "${T[advanced_settings]}" items || return
    case $MENU_RESULT in
      0)  prompt_input "${T[adv_root]}"               CFG_ROOT ;;
      1)  prompt_input "${T[adv_index]}"              CFG_INDEX ;;
      2)  prompt_input "${T[adv_try_files]}"          CFG_TRY_FILES ;;
      3)  prompt_input "${T[adv_upstream_name]}"      CFG_UPSTREAM_NAME ;;
      4)  prompt_input "${T[adv_upstream_keepalive]}" CFG_UPSTREAM_KEEPALIVE ;;
      5)  prompt_input "${T[adv_custom_headers]}"     CFG_CUSTOM_HEADERS ;;
      6)  toggle_bool CFG_RETURN_404 ;;
      7)  toggle_bool CFG_CUSTOM_ERROR_PAGES ;;
      8)  toggle_bool CFG_MAINTENANCE ;;
      9)  prompt_choose "${T[adv_worker_proc]}" CFG_NGINX_CONF_WORKER_PROC \
            auto 1 2 4 8 ;;
      10) prompt_choose "${T[adv_worker_conn]}" CFG_NGINX_CONF_WORKER_CONN \
            512 1024 2048 4096 ;;
      11) return ;;
    esac
  done
}

# ── Config generator ──────────────────────────────────────────────────────────
generate_config() {
  local o=""

  # upstream
  o+="upstream ${CFG_UPSTREAM_NAME} {\n"
  o+="    server ${CFG_PROXY_IP}:${CFG_PROXY_PORT};\n"
  o+="    keepalive ${CFG_UPSTREAM_KEEPALIVE};\n"
  o+="}\n\n"

  # HTTP -> HTTPS redirect server block
  if $CFG_SSL_ENABLE && $CFG_SSL_REDIRECT; then
    o+="server {\n"
    o+="    listen      80;\n"
    o+="    listen      [::]:80;\n"
    o+="    server_name ${CFG_SERVER_NAME};\n"
    o+="    return      301 https://\$host\$request_uri;\n"
    o+="}\n\n"
  fi

  # main server block
  o+="server {\n"
  if $CFG_SSL_ENABLE; then
    o+="    listen      ${CFG_LISTEN_PORT} ssl;\n"
    o+="    listen      [::]:${CFG_LISTEN_PORT} ssl;\n"
  else
    o+="    listen      ${CFG_LISTEN_PORT};\n"
    o+="    listen      [::]:${CFG_LISTEN_PORT};\n"
  fi
  o+="\n    server_name ${CFG_SERVER_NAME};\n"
  $CFG_SEC_SERVER_TOKENS && o+="\n    server_tokens off;\n"

  # SSL block
  if $CFG_SSL_ENABLE; then
    o+="\n    # ── SSL ─────────────────────────────────────────────────────\n"
    [[ -n "$CFG_SSL_CERT" ]]  && o+="    ssl_certificate         ${CFG_SSL_CERT};\n"
    [[ -n "$CFG_SSL_KEY" ]]   && o+="    ssl_certificate_key     ${CFG_SSL_KEY};\n"
    [[ -n "$CFG_SSL_CHAIN" ]] && o+="    ssl_trusted_certificate ${CFG_SSL_CHAIN};\n"
    o+="    ssl_protocols               ${CFG_SSL_PROTOCOLS};\n"
    o+="    ssl_ciphers                 ${CFG_SSL_CIPHERS};\n"
    o+="    ssl_prefer_server_ciphers   on;\n"
    o+="    ssl_session_cache           shared:SSL:10m;\n"
    o+="    ssl_session_timeout         ${CFG_SSL_SESSION_TIMEOUT};\n"
    o+="    ssl_session_tickets         off;\n"
    [[ -n "$CFG_SSL_DHPARAM" ]] && o+="    ssl_dhparam             ${CFG_SSL_DHPARAM};\n"
    if $CFG_SSL_STAPLING; then
      o+="    ssl_stapling        on;\n"
      o+="    ssl_stapling_verify on;\n"
      o+="    resolver            8.8.8.8 8.8.4.4 valid=300s;\n"
      o+="    resolver_timeout    5s;\n"
    fi
  fi

  # HSTS
  if $CFG_SSL_ENABLE && $CFG_SSL_HSTS; then
    o+="\n    # ── HSTS ────────────────────────────────────────────────────\n"
    o+="    add_header Strict-Transport-Security \"max-age=${CFG_SSL_HSTS_AGE}; includeSubDomains; preload\" always;\n"
  fi

  # Security headers
  o+="\n    # ── Security Headers ────────────────────────────────────────\n"
  o+="    add_header X-Frame-Options         \"${CFG_SEC_XFRAME}\" always;\n"
  $CFG_SEC_XCONTENT && o+="    add_header X-Content-Type-Options  \"nosniff\" always;\n"
  $CFG_SEC_XSS      && o+="    add_header X-XSS-Protection        \"1; mode=block\" always;\n"
  o+="    add_header Referrer-Policy         \"${CFG_SEC_REFERRER}\" always;\n"
  $CFG_SEC_CSP      && o+="    add_header Content-Security-Policy \"${CFG_SEC_CSP_VALUE}\" always;\n"
  $CFG_SEC_PERMISSIONS && o+="    add_header Permissions-Policy \"camera=(), microphone=(), geolocation=()\" always;\n"

  # Logging
  o+="\n    # ── Logging ─────────────────────────────────────────────────\n"
  o+="    access_log  ${CFG_ACCESS_LOG};\n"
  o+="    error_log   ${CFG_ERROR_LOG} ${CFG_LOG_LEVEL};\n"

  # Client limits
  o+="\n    # ── Client Limits ───────────────────────────────────────────\n"
  o+="    client_max_body_size  ${CFG_CLIENT_MAX_BODY}m;\n"
  o+="    client_body_timeout   ${CFG_CLIENT_TIMEOUT}s;\n"
  o+="    keepalive_timeout     ${CFG_KEEPALIVE_TIMEOUT}s;\n"
  o+="    send_timeout          ${CFG_SEND_TIMEOUT}s;\n"

  # Gzip
  if $CFG_GZIP_ENABLE; then
    o+="\n    # ── Gzip ────────────────────────────────────────────────────\n"
    o+="    gzip            on;\n"
    o+="    gzip_comp_level ${CFG_GZIP_LEVEL};\n"
    o+="    gzip_min_length ${CFG_GZIP_MIN_LEN};\n"
    $CFG_GZIP_VARY && o+="    gzip_vary       on;\n"
    o+="    gzip_proxied    ${CFG_GZIP_PROXIED};\n"
    o+="    gzip_types      ${CFG_GZIP_TYPES};\n"
  fi

  # Rate limiting
  if $CFG_LIMIT_REQ_ENABLE; then
    o+="\n    # ── Rate Limiting ───────────────────────────────────────────\n"
    o+="    limit_req zone=${CFG_LIMIT_REQ_ZONE} burst=${CFG_LIMIT_REQ_BURST} nodelay;\n"
  fi

  # Custom headers
  if [[ -n "$CFG_CUSTOM_HEADERS" ]]; then
    o+="\n    # ── Custom Headers ──────────────────────────────────────────\n"
    IFS=';' read -ra _ch <<< "$CFG_CUSTOM_HEADERS"
    for _h in "${_ch[@]}"; do
      local _ht="${_h#"${_h%%[![:space:]]*}"}"
      [[ -n "$_ht" ]] && o+="    add_header ${_ht};\n"
    done
  fi

  # Custom error pages
  if $CFG_CUSTOM_ERROR_PAGES; then
    o+="\n    # ── Custom Error Pages ──────────────────────────────────────\n"
    o+="    error_page 404              /404.html;\n"
    o+="    error_page 500 502 503 504  /50x.html;\n"
    o+="    location = /50x.html { root /usr/share/nginx/html; }\n"
  fi

  # Static root
  if [[ -n "$CFG_ROOT" ]]; then
    o+="\n    # ── Static Root ─────────────────────────────────────────────\n"
    o+="    root  ${CFG_ROOT};\n"
    o+="    index ${CFG_INDEX};\n"
    [[ -n "$CFG_TRY_FILES" ]] && o+="    try_files ${CFG_TRY_FILES};\n"
  fi

  # Proxy location
  o+="\n    # ── Proxy ───────────────────────────────────────────────────\n"
  o+="    location / {\n"
  if $CFG_MAINTENANCE; then
    o+="        return 503;\n"
  else
    o+="        proxy_pass              ${CFG_PROXY_PROTO}://${CFG_UPSTREAM_NAME};\n"
    if $CFG_PROXY_BUFFERING; then
      o+="        proxy_buffering         on;\n"
      o+="        proxy_buffer_size       ${CFG_PROXY_BUF_SIZE};\n"
      o+="        proxy_buffers           ${CFG_PROXY_BUFFERS};\n"
    else
      o+="        proxy_buffering         off;\n"
    fi
    o+="        proxy_read_timeout      ${CFG_PROXY_TIMEOUT}s;\n"
    o+="        proxy_connect_timeout   ${CFG_PROXY_CONNECT}s;\n"
    o+="        proxy_send_timeout      ${CFG_PROXY_SEND}s;\n"
    if $CFG_PROXY_HEADERS; then
      o+="        proxy_set_header        Host              \$host;\n"
      o+="        proxy_set_header        X-Forwarded-Host  \$host;\n"
      o+="        proxy_set_header        X-Forwarded-Port  \$server_port;\n"
    fi
    if $CFG_PROXY_REAL_IP; then
      o+="        proxy_set_header        X-Real-IP         \$remote_addr;\n"
      o+="        proxy_set_header        X-Forwarded-For   \$proxy_add_x_forwarded_for;\n"
      o+="        proxy_set_header        X-Forwarded-Proto \$scheme;\n"
    fi
    if $CFG_PROXY_WEBSOCKET; then
      o+="        proxy_http_version      1.1;\n"
      o+="        proxy_set_header        Upgrade           \$http_upgrade;\n"
      o+="        proxy_set_header        Connection        \"upgrade\";\n"
    else
      o+="        proxy_http_version      1.1;\n"
      o+="        proxy_set_header        Connection        \"\";\n"
    fi
    $CFG_PROXY_INTERCEPT && o+="        proxy_intercept_errors  on;\n"
    if $CFG_CACHE_ENABLE; then
      o+="        proxy_cache             ${CFG_CACHE_ZONE};\n"
      o+="        proxy_cache_valid       ${CFG_CACHE_TIME};\n"
      o+="        proxy_cache_use_stale   error timeout updating http_500 http_502 http_503 http_504;\n"
      [[ -n "$CFG_CACHE_BYPASS" ]] && o+="        proxy_cache_bypass      \$${CFG_CACHE_BYPASS};\n"
    fi
  fi
  o+="    }\n"

  # Return 404 for unknown hosts
  if $CFG_RETURN_404; then
    o+="\n    # ── Default deny ─────────────────────────────────────────────\n"
    o+="    location @fallback {\n"
    o+="        return 404;\n"
    o+="    }\n"
  fi

  o+="}\n"
  printf '%b' "$o"
}

# ── nginx.conf updater ────────────────────────────────────────────────────────
update_nginx_conf() {
  if [[ ! -f "$NGINX_CONF" ]]; then
    printf '  %s%s not found%s\n' "${CLR_WARN}" "$NGINX_CONF" "${R}"
    return 0
  fi
  local bak="${NGINX_CONF}.bak.$(date +%s)"
  cp "$NGINX_CONF" "$bak"
  printf '  %sBackup: %s%s\n' "${CLR_DIM}" "$bak" "${R}"

  if [[ -n "$CFG_NGINX_CONF_WORKER_PROC" ]]; then
    sed -i "s/^\s*worker_processes\s.*/worker_processes ${CFG_NGINX_CONF_WORKER_PROC};/" "$NGINX_CONF"
  fi
  if [[ -n "$CFG_NGINX_CONF_WORKER_CONN" ]]; then
    sed -i "s/^\s*worker_connections\s.*/    worker_connections ${CFG_NGINX_CONF_WORKER_CONN};/" "$NGINX_CONF"
  fi

  local inject=""
  if $CFG_CACHE_ENABLE; then
    if ! grep -q "keys_zone=${CFG_CACHE_ZONE}" "$NGINX_CONF" 2>/dev/null; then
      inject+="    proxy_cache_path ${CFG_CACHE_PATH} levels=1:2 keys_zone=${CFG_CACHE_ZONE}:10m max_size=1g inactive=60m use_temp_path=off;\n"
    fi
  fi
  if $CFG_LIMIT_REQ_ENABLE; then
    if ! grep -q "zone=${CFG_LIMIT_REQ_ZONE}:" "$NGINX_CONF" 2>/dev/null; then
      inject+="    limit_req_zone \$binary_remote_addr zone=${CFG_LIMIT_REQ_ZONE}:10m rate=${CFG_LIMIT_REQ_RATE}r/s;\n"
    fi
  fi
  if [[ -n "$inject" ]]; then
    sed -i "/^\s*http\s*{/a\\$(printf '%b' "$inject")" "$NGINX_CONF"
  fi
  printf '  %snginx.conf updated%s\n' "${CLR_GOOD}" "${R}"
}

# ── Preview ───────────────────────────────────────────────────────────────────
section_preview() {
  draw_header
  printf '  %s%s%s\n\n' "${CLR_ACCENT}${BOLD}" "${T[preview_title]}" "${R}"
  hline '-' "$TERM_W"
  echo
  generate_config | head -150 | while IFS= read -r ln; do
    if [[ "$ln" =~ ^# ]]; then
      printf '%s%s%s\n' "${CLR_DIM}" "$ln" "${R}"
    elif [[ "$ln" =~ ^(server|upstream|location) ]]; then
      printf '%s%s%s\n' "${CLR_ACCENT}${BOLD}" "$ln" "${R}"
    elif [[ "$ln" =~ ssl_ ]]; then
      printf '%s%s%s\n' "${CLR_GOOD}" "$ln" "${R}"
    elif [[ "$ln" =~ add_header ]]; then
      printf '%s%s%s\n' "${CLR_WARN}" "$ln" "${R}"
    else
      printf '%s\n' "$ln"
    fi
  done
  echo
  hline '-' "$TERM_W"
  printf '\n  '
  show_cur; read -rp "${T[press_enter]}..." _; hide_cur
}

# ── Save ──────────────────────────────────────────────────────────────────────
section_save() {
  draw_header
  printf '  %s%s%s\n\n' "${CLR_ACCENT}${BOLD}" "${T[save_title]}" "${R}"
  [[ -z "$CFG_OUTPUT_PATH" || "$CFG_OUTPUT_PATH" == "/etc/nginx/conf.d/site.conf" ]] && \
    CFG_OUTPUT_PATH="/etc/nginx/conf.d/${CFG_SERVER_NAME:-site}.conf"
  prompt_input "${T[save_path]}" CFG_OUTPUT_PATH nonempty

  local dir; dir=$(dirname "$CFG_OUTPUT_PATH")
  if [[ ! -d "$dir" ]]; then
    printf '  %sCreating %s...%s\n' "${CLR_WARN}" "$dir" "${R}"
    mkdir -p "$dir" 2>/dev/null || {
      printf '  %sCannot create directory (root required?)%s\n' "${CLR_ERR}" "${R}"
      show_cur; read -rp "  ${T[press_enter]}..." _; hide_cur; return
    }
  fi

  generate_config > "$CFG_OUTPUT_PATH" \
    && printf '\n  %s%s: %s%s\n' "${CLR_GOOD}" "${T[save_ok]}" "$CFG_OUTPUT_PATH" "${R}" \
    || printf '\n  %s%s%s\n'     "${CLR_ERR}"  "${T[save_err]}"                    "${R}"

  if $CFG_SSL_ENABLE && [[ ! -d "$NGINX_SSL" ]]; then
    printf '  %sCreating %s...%s\n' "${CLR_WARN}" "$NGINX_SSL" "${R}"
    mkdir -p "$NGINX_SSL" && chmod 700 "$NGINX_SSL" || true
  fi

  printf '\n  %s%s%s ' "${CLR_LABEL}" "${T[save_nginx_conf]}" "${R}"
  show_cur; IFS= read -re _ans; hide_cur
  if [[ "$_ans" =~ ^[yYдД] ]]; then
    update_nginx_conf
  fi
  show_cur; read -rp "  ${T[press_enter]}..." _; hide_cur
}

# ── Apply ─────────────────────────────────────────────────────────────────────
section_apply() {
  if [[ -z "$CFG_SERVER_NAME" || -z "$CFG_PROXY_IP" ]]; then
    draw_header
    printf '\n  %s%s%s\n' "${CLR_ERR}" "${T[no_basic]}" "${R}"
    show_cur; read -rp "  ${T[press_enter]}..." _; hide_cur; return
  fi
  if [[ $EUID -ne 0 ]]; then
    draw_header
    printf '\n  %s%s%s\n' "${CLR_WARN}" "${T[root_required]}" "${R}"
    show_cur; read -rp "  ${T[press_enter]}..." _; hide_cur; return
  fi
  draw_header
  printf '  %s%s%s\n' "${CLR_LABEL}" "${T[apply_test]}" "${R}"
  if "$NGINX_BIN" -t 2>&1; then
    printf '  %s%s%s\n' "${CLR_GOOD}" "OK" "${R}"
    printf '\n  %s ' "${T[confirm_apply]}"
    show_cur; IFS= read -re _ans; hide_cur
    if [[ "$_ans" =~ ^[yYдД] ]]; then
      "$NGINX_BIN" -s reload \
        && printf '  %s%s%s\n' "${CLR_GOOD}" "${T[apply_ok]}" "${R}" \
        || printf '  %s%s%s\n' "${CLR_ERR}"  "${T[apply_err]}" "${R}"
    fi
  else
    printf '  %s%s%s\n' "${CLR_ERR}" "${T[apply_err]}" "${R}"
  fi
  show_cur; read -rp "  ${T[press_enter]}..." _; hide_cur
}

# ── Language selector ─────────────────────────────────────────────────────────
select_language() {
  printf '\e[2J\e[H'
  printf '\n\n'
  printf '%s' "${CLR_HEADER}${BOLD}"
  center "  Nginx Configuration Generator  " "$TERM_W"; echo
  printf '%s\n\n\n' "${R}"
  local opts=("English" "Russian / Русский")
  local cur=0
  hide_cur
  while true; do
    mov 7 1
    for ((i=0; i<2; i++)); do
      if [[ $i -eq $cur ]]; then
        printf '  %s>  %s%s\n' "${CLR_SEL}" "${opts[$i]}" "${R}"
      else
        printf '     %s\n' "${opts[$i]}"
      fi
    done
    IFS= read -rsn1 k
    if [[ "$k" == $'\x1b' ]]; then
      IFS= read -rsn2 -t 0.1 sq || true
      [[ "$sq" == '[A' ]] && cur=0
      [[ "$sq" == '[B' ]] && cur=1
    elif [[ "$k" == '' ]]; then
      [[ $cur -eq 0 ]] && LANG_MODE="en" || LANG_MODE="ru"
      show_cur; return
    fi
  done
}

# ── Main menu ─────────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    local ok=""
    [[ -n "$CFG_SERVER_NAME" && -n "$CFG_PROXY_IP" ]] && ok=" ${CLR_GOOD}+${R}"
    local items=(
      "${T[menu_basic]}${ok}"
      "${T[menu_ssl]}  $(bool_badge $CFG_SSL_ENABLE)"
      "${T[menu_security]}"
      "${T[menu_proxy]}"
      "${T[menu_cache]}  $(bool_badge $CFG_CACHE_ENABLE)"
      "${T[menu_limits]}"
      "${T[menu_logging]}"
      "${T[menu_gzip]}  $(bool_badge $CFG_GZIP_ENABLE)"
      "${T[menu_advanced]}"
      "${CLR_DIM}------------------------------------${R}"
      "${T[menu_preview]}"
      "${T[menu_save]}"
      "$( $NGINX_FOUND && echo "${T[menu_apply]}" || echo "${CLR_DIM}${T[menu_apply]} (nginx not found)${R}" )"
      "${CLR_DIM}------------------------------------${R}"
      "${T[menu_exit]}"
    )
    menu_select "${T[main_menu]}" items || break
    case $MENU_RESULT in
      0)  section_basic ;;
      1)  section_ssl ;;
      2)  section_security ;;
      3)  section_proxy ;;
      4)  section_cache ;;
      5)  section_limits ;;
      6)  section_logging ;;
      7)  section_gzip ;;
      8)  section_advanced ;;
      9)  : ;;
      10) section_preview ;;
      11) section_save ;;
      12) $NGINX_FOUND && section_apply ;;
      13) : ;;
      14) break ;;
    esac
  done
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
_cleanup() {
  show_cur
  printf '\e[2J\e[H'
  printf '\n  %sGoodbye.%s\n\n' "${CLR_DIM}" "${R}"
}
trap _cleanup EXIT INT TERM

# ── Entry point ────────────────────────────────────────────────────────────────
upd_size
detect_system
select_language
_load_strings
main_menu
