#!/usr/bin/env bash
# ==============================================================================
#  install.sh — pngxconf automated installer
#  Installs pngxconf and ssl-wizard.sh to standard system locations
#  Run as root: sudo bash install.sh
# ==============================================================================
set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[38;2;210;65;65m'
GREEN=$'\033[38;2;80;200;120m'
YELLOW=$'\033[38;2;230;185;55m'
CYAN=$'\033[38;2;75;200;215m'
BLUE=$'\033[38;2;70;145;235m'
WHITE=$'\033[38;2;235;235;235m'

info()  { echo -e "${CYAN}  ●${R} $*"; }
ok()    { echo -e "${GREEN}  ✔${R} $*"; }
warn()  { echo -e "${YELLOW}  ⚠${R} $*"; }
err()   { echo -e "${RED}  ✖${R} $*" >&2; }
die()   { err "$*"; pause_err; exit 1; }
hr()    { echo -e "${DIM}  $(printf '%.0s─' {1..62})${R}"; }

# stop on error — wait for keypress
pause_err() {
    echo ""
    echo -e "  ${YELLOW}── Press any key to continue ──${R}"
    read -rsn1 _
}

# ── Paths ─────────────────────────────────────────────────────────────────────
readonly BIN_DIR="/usr/local/bin"
readonly LIB_DIR="/usr/local/lib/pngxconf"
readonly PNGX_BIN="${BIN_DIR}/pngxconf"
readonly WIZARD_TARGET="${LIB_DIR}/ssl-wizard.sh"
readonly STATE_DIR="/var/lib/pngxconf"

readonly NGINX_CONFD="/etc/nginx/conf.d"
readonly NGINX_SSL_DIR="/etc/nginx/ssl"
readonly NGINX_BAK_DIR="/etc/nginx/pngxconf-backups"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Banner ────────────────────────────────────────────────────────────────────
banner() {
    clear 2>/dev/null || printf '\033[2J\033[H'
    echo ""
    echo -e "  ${BOLD}${BLUE}╔══════════════════════════════════════════════════════════╗${R}"
    echo -e "  ${BOLD}${BLUE}║${R}  ${BOLD}${WHITE}pngxconf installer${R}                                    ${BOLD}${BLUE}║${R}"
    echo -e "  ${BOLD}${BLUE}║${R}  ${DIM}Nginx Management System — automated setup${R}             ${BOLD}${BLUE}║${R}"
    echo -e "  ${BOLD}${BLUE}╚══════════════════════════════════════════════════════════╝${R}"
    echo ""
}

# ── Root check ────────────────────────────────────────────────────────────────
require_root() {
    [[ $EUID -eq 0 ]] || die "Installer must be run as root. Try: sudo bash install.sh"
}

# ── Distro detection ──────────────────────────────────────────────────────────
DISTRO="unknown"
DISTRO_FAMILY="unknown"
PKG_MGR=""
PKG_INSTALL=""
PKG_UPDATE=""
PKG_QUERY=""

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        DISTRO="${NAME:-Unknown}"
        case "${ID:-}" in
            ubuntu|debian|linuxmint|pop|kali|raspbian)
                DISTRO_FAMILY="debian"
                PKG_MGR="apt"
                PKG_INSTALL="apt-get install -y"
                PKG_UPDATE="apt-get update"
                PKG_QUERY="dpkg -s"
                ;;
            rhel|centos|fedora|rocky|almalinux|ol|amzn)
                DISTRO_FAMILY="rhel"
                if command -v dnf &>/dev/null; then
                    PKG_MGR="dnf"
                    PKG_INSTALL="dnf install -y"
                    PKG_UPDATE="dnf check-update || true"
                else
                    PKG_MGR="yum"
                    PKG_INSTALL="yum install -y"
                    PKG_UPDATE="yum check-update || true"
                fi
                PKG_QUERY="rpm -q"
                ;;
            arch|manjaro|endeavouros)
                DISTRO_FAMILY="arch"
                PKG_MGR="pacman"
                PKG_INSTALL="pacman -S --noconfirm"
                PKG_UPDATE="pacman -Sy"
                PKG_QUERY="pacman -Qi"
                ;;
            opensuse*|sles)
                DISTRO_FAMILY="suse"
                PKG_MGR="zypper"
                PKG_INSTALL="zypper install -y"
                PKG_UPDATE="zypper refresh"
                PKG_QUERY="rpm -q"
                ;;
            *) DISTRO_FAMILY="unknown" ;;
        esac
    fi
}

# ── Package map per distro ────────────────────────────────────────────────────
# Map generic name → package name for the current distro
pkg_name() {
    local generic="$1"
    case "$DISTRO_FAMILY" in
        debian)
            case "$generic" in
                nginx)    echo "nginx" ;;
                openssl)  echo "openssl" ;;
                curl)     echo "curl" ;;
                socat)    echo "socat" ;;
                cron)     echo "cron" ;;
                acme.sh)  echo "" ;;   # not in repos for Debian/Ubuntu; we install via official installer
                *)        echo "$generic" ;;
            esac ;;
        rhel)
            case "$generic" in
                nginx)    echo "nginx" ;;
                openssl)  echo "openssl" ;;
                curl)     echo "curl" ;;
                socat)    echo "socat" ;;
                cron)     echo "cronie" ;;
                acme.sh)  echo "" ;;
                *)        echo "$generic" ;;
            esac ;;
        arch)
            case "$generic" in
                nginx)    echo "nginx" ;;
                openssl)  echo "openssl" ;;
                curl)     echo "curl" ;;
                socat)    echo "socat" ;;
                cron)     echo "cronie" ;;
                acme.sh)  echo "acme.sh" ;;  # in AUR — likely fails; fallback to manual
                *)        echo "$generic" ;;
            esac ;;
        suse)
            case "$generic" in
                nginx)    echo "nginx" ;;
                openssl)  echo "openssl" ;;
                curl)     echo "curl" ;;
                socat)    echo "socat" ;;
                cron)     echo "cron" ;;
                acme.sh)  echo "" ;;
                *)        echo "$generic" ;;
            esac ;;
        *) echo "$generic" ;;
    esac
}

# Check if a package is installed using the native package manager
pkg_is_installed() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 1
    case "$DISTRO_FAMILY" in
        debian) dpkg -s "$pkg" &>/dev/null ;;
        rhel|suse) rpm -q "$pkg" &>/dev/null ;;
        arch) pacman -Qi "$pkg" &>/dev/null ;;
        *) return 1 ;;
    esac
}

# Run install via native manager
pkg_install() {
    local pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0
    info "Running: ${PKG_INSTALL} ${pkgs[*]}"
    eval "$PKG_INSTALL ${pkgs[*]}" || {
        err "Package installation failed: ${pkgs[*]}"
        pause_err
        return 1
    }
}

# ── Yes/No prompt ─────────────────────────────────────────────────────────────
prompt_yn() {
    local prompt="${1:-Proceed?}"
    local ans
    printf "  %s [Y/n]: " "$prompt"
    IFS= read -r ans
    [[ -z "$ans" ]] && return 0
    [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

# ══════════════════════════════════════════════════════════════════════════════
#  Prerequisite check via NATIVE package manager (not GitHub)
# ══════════════════════════════════════════════════════════════════════════════
check_prereqs() {
    echo -e "  ${BOLD}Checking prerequisites via ${PKG_MGR}…${R}"
    hr; echo ""

    # bash version is checked at script level, not via pkg
    local bash_ver="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
    if (( BASH_VERSINFO[0] >= 4 )); then
        ok "bash           ${bash_ver}"
    else
        err "bash           ${bash_ver}  (need 4.0+)"
        pause_err
    fi

    # Track packages needed
    local need_install=()
    local optional_missing=()

    # === Required packages ===
    _check_pkg() {
        local generic="$1" required="${2:-yes}"
        local pkg; pkg=$(pkg_name "$generic")

        if [[ -z "$pkg" ]]; then
            # Means handled separately (acme.sh)
            return 0
        fi

        if pkg_is_installed "$pkg"; then
            local ver=""
            case "$DISTRO_FAMILY" in
                debian) ver=$(dpkg -s "$pkg" 2>/dev/null | grep '^Version:' | awk '{print $2}') ;;
                rhel|suse) ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null) ;;
                arch) ver=$(pacman -Qi "$pkg" 2>/dev/null | grep '^Version' | awk '{print $3}') ;;
            esac
            printf "  ${GREEN}  ✔${R} %-15s ${DIM}%s${R}  (pkg: %s)\n" "$generic" "${ver:-installed}" "$pkg"
        else
            if [[ "$required" == "yes" ]]; then
                printf "  ${YELLOW}  ⚠${R} %-15s ${RED}not installed${R}  (pkg: %s)\n" "$generic" "$pkg"
                need_install+=("$pkg")
            else
                printf "  ${YELLOW}  ⚠${R} %-15s ${DIM}not installed (optional)${R}  (pkg: %s)\n" "$generic" "$pkg"
                optional_missing+=("$pkg")
            fi
        fi
    }

    _check_pkg "nginx"   "yes"
    _check_pkg "openssl" "yes"
    _check_pkg "curl"    "yes"
    _check_pkg "cron"    "yes"
    _check_pkg "socat"   "no"

    echo ""

    # === Install required missing ===
    if [[ ${#need_install[@]} -gt 0 ]]; then
        warn "Required packages missing: ${need_install[*]}"
        echo ""
        if prompt_yn "Install required packages now?"; then
            info "Updating package index…"
            eval "$PKG_UPDATE" || warn "Package index update returned non-zero — continuing anyway"
            echo ""
            pkg_install "${need_install[@]}" || die "Required package installation failed"
        else
            warn "Continuing without required packages. pngxconf functionality will be limited."
            pause_err
        fi
        echo ""
    fi

    # === Optional packages ===
    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        info "Optional packages not installed: ${optional_missing[*]}"
        echo "  ${DIM}socat is needed for acme.sh standalone mode${R}"
        if prompt_yn "Install optional packages now?"; then
            pkg_install "${optional_missing[@]}" || warn "Optional install failed — continuing"
        fi
        echo ""
    fi

    # === acme.sh check ===
    check_acme_sh

    # === Firewall check (port 80 for acme.sh) ===
    check_firewall
}

# ── acme.sh check ─────────────────────────────────────────────────────────────
check_acme_sh() {
    echo -e "  ${BOLD}Checking acme.sh…${R}"
    hr; echo ""

    local acme_bin=""
    for p in /root/.acme.sh/acme.sh /usr/local/bin/acme.sh; do
        [[ -f "$p" ]] && { acme_bin="$p"; break; }
    done

    if [[ -n "$acme_bin" ]]; then
        local ver; ver=$("$acme_bin" --version 2>/dev/null | head -1)
        ok "acme.sh        ${ver:-installed}  ${DIM}(${acme_bin})${R}"
    else
        warn "acme.sh        not installed"

        # Try native package first
        local native_pkg; native_pkg=$(pkg_name "acme.sh")
        if [[ -n "$native_pkg" ]]; then
            info "Available in repository as: ${native_pkg}"
            if prompt_yn "Install acme.sh via ${PKG_MGR}?"; then
                pkg_install "$native_pkg" && return 0
            fi
        fi

        # Fallback to official installer (only if user agrees)
        echo ""
        warn "acme.sh is not packaged for ${DISTRO_FAMILY} in standard repos."
        info "The official installer fetches from get.acme.sh and installs to /root/.acme.sh/"
        if prompt_yn "Run the official acme.sh installer?"; then
            install_acme_sh_official
        else
            warn "Skipping acme.sh. Let's Encrypt automation via ssl-wizard will be unavailable."
        fi
    fi
    echo ""
}

install_acme_sh_official() {
    if ! command -v curl &>/dev/null; then
        err "curl is required to install acme.sh"
        pause_err
        return 1
    fi
    info "Downloading and running acme.sh installer…"
    curl -fsSL https://get.acme.sh -o /tmp/acme-install.sh || {
        err "Failed to download acme.sh installer"
        pause_err
        return 1
    }
    bash /tmp/acme-install.sh --install -m "admin@$(hostname -f 2>/dev/null || hostname)" || {
        err "acme.sh installation failed"
        rm -f /tmp/acme-install.sh
        pause_err
        return 1
    }
    rm -f /tmp/acme-install.sh
    ok "acme.sh installed to /root/.acme.sh/"

    # Ensure cron entry exists
    if command -v crontab &>/dev/null; then
        if crontab -l 2>/dev/null | grep -q 'acme.sh'; then
            ok "acme.sh cron entry already present"
        else
            warn "acme.sh installer should have added a cron entry — verifying"
            crontab -l 2>/dev/null || true
        fi
    fi
}

# ── Firewall check for acme.sh port 80 ────────────────────────────────────────
check_firewall() {
    echo -e "  ${BOLD}Checking firewall (port 80 for acme.sh HTTP-01)…${R}"
    hr; echo ""

    local issues=0

    # ufw
    if command -v ufw &>/dev/null; then
        local ufw_status; ufw_status=$(ufw status 2>/dev/null | head -1)
        if echo "$ufw_status" | grep -qi 'active'; then
            info "ufw is active"
            if ufw status 2>/dev/null | grep -qE '^80(/tcp)?\s+ALLOW' ; then
                ok "ufw — port 80 is open"
            else
                warn "ufw — port 80 appears NOT to be allowed"
                if prompt_yn "Open port 80 in ufw?"; then
                    ufw allow 80/tcp && ok "Port 80 opened in ufw" || { err "ufw allow failed"; issues=$((issues+1)); }
                fi
            fi
            # Same for 443 since HTTPS will be needed after cert issuance
            if ufw status 2>/dev/null | grep -qE '^443(/tcp)?\s+ALLOW' ; then
                ok "ufw — port 443 is open"
            else
                warn "ufw — port 443 NOT allowed"
                if prompt_yn "Open port 443 in ufw?"; then
                    ufw allow 443/tcp && ok "Port 443 opened in ufw" || { err "ufw allow failed"; issues=$((issues+1)); }
                fi
            fi
        else
            ok "ufw installed but inactive — ports unrestricted by ufw"
        fi
    fi

    # firewalld
    if command -v firewall-cmd &>/dev/null; then
        if systemctl is-active --quiet firewalld 2>/dev/null; then
            info "firewalld is active"
            local zone; zone=$(firewall-cmd --get-default-zone 2>/dev/null)
            if firewall-cmd --list-ports 2>/dev/null | grep -q '80/tcp' || \
               firewall-cmd --list-services 2>/dev/null | grep -qw 'http'; then
                ok "firewalld — port 80 / http open (zone: ${zone})"
            else
                warn "firewalld — port 80 not open in zone '${zone}'"
                if prompt_yn "Open port 80 (and http service) in firewalld?"; then
                    firewall-cmd --permanent --add-service=http && \
                    firewall-cmd --permanent --add-port=80/tcp && \
                    firewall-cmd --reload && ok "Port 80 opened" || { err "firewall-cmd failed"; issues=$((issues+1)); }
                fi
            fi
            if firewall-cmd --list-ports 2>/dev/null | grep -q '443/tcp' || \
               firewall-cmd --list-services 2>/dev/null | grep -qw 'https'; then
                ok "firewalld — port 443 / https open"
            else
                warn "firewalld — port 443 not open"
                if prompt_yn "Open port 443 in firewalld?"; then
                    firewall-cmd --permanent --add-service=https && \
                    firewall-cmd --permanent --add-port=443/tcp && \
                    firewall-cmd --reload && ok "Port 443 opened" || { err "firewall-cmd failed"; issues=$((issues+1)); }
                fi
            fi
        else
            ok "firewalld installed but inactive"
        fi
    fi

    # iptables fallback
    if ! command -v ufw &>/dev/null && ! command -v firewall-cmd &>/dev/null && command -v iptables &>/dev/null; then
        info "Only iptables detected"
        if iptables -L INPUT -n 2>/dev/null | grep -qE 'dpt:80\s'; then
            local action; action=$(iptables -L INPUT -n | grep -E 'dpt:80\s' | head -1 | awk '{print $1}')
            if [[ "$action" == "ACCEPT" ]]; then
                ok "iptables — port 80 ACCEPT rule found"
            else
                warn "iptables — port 80 has ${action} rule"
                issues=$((issues+1))
            fi
        else
            warn "iptables — no explicit rule for port 80 (default policy applies)"
            echo "  ${DIM}If default policy is DROP, acme.sh HTTP-01 challenge will fail${R}"
        fi
    fi

    # No firewall at all
    if ! command -v ufw &>/dev/null && \
       ! command -v firewall-cmd &>/dev/null && \
       ! command -v iptables &>/dev/null; then
        info "No firewall management tool found — ports unrestricted"
    fi

    echo ""

    # Quick reachability hint
    info "Verify port 80 is reachable from outside before requesting a Let's Encrypt cert."
    echo -e "  ${DIM}Test from external host: curl -sS http://YOUR.SERVER.IP/${R}"
    echo ""
}

# ── Cron service ──────────────────────────────────────────────────────────────
check_cron_service() {
    echo -e "  ${BOLD}Verifying cron service…${R}"
    hr; echo ""

    local cron_service=""
    for svc in cron crond cronie; do
        if systemctl list-unit-files --no-legend 2>/dev/null | grep -qE "^${svc}\.service"; then
            cron_service="$svc"
            break
        fi
    done

    if [[ -z "$cron_service" ]]; then
        warn "No cron service unit found"
    else
        if systemctl is-active --quiet "$cron_service" 2>/dev/null; then
            ok "${cron_service} is active"
        else
            warn "${cron_service} is not active"
            if prompt_yn "Enable and start ${cron_service}?"; then
                systemctl enable --now "$cron_service" 2>/dev/null && \
                    ok "${cron_service} enabled and started" || \
                    { err "Failed to start ${cron_service}"; pause_err; }
            fi
        fi
    fi
    echo ""
}

# ── Find source files ─────────────────────────────────────────────────────────
SRC_PNGXCONF=""
SRC_WIZARD=""

find_sources() {
    if [[ -f "${SCRIPT_DIR}/pngxconf" ]]; then
        SRC_PNGXCONF="${SCRIPT_DIR}/pngxconf"
    elif [[ -f "${SCRIPT_DIR}/pngxconf.sh" ]]; then
        SRC_PNGXCONF="${SCRIPT_DIR}/pngxconf.sh"
    else
        die "pngxconf source not found in ${SCRIPT_DIR}. Place pngxconf next to install.sh."
    fi

    if [[ -f "${SCRIPT_DIR}/ssl-wizard.sh" ]]; then
        SRC_WIZARD="${SCRIPT_DIR}/ssl-wizard.sh"
    else
        warn "ssl-wizard.sh not found in ${SCRIPT_DIR}."
        warn "SSL certificate creation wizard will be unavailable."
        echo ""
        if ! prompt_yn "Continue installing without ssl-wizard.sh?"; then
            die "Aborted."
        fi
        SRC_WIZARD=""
    fi
}

# ── Install pngxconf binary and files ─────────────────────────────────────────
do_install() {
    echo -e "  ${BOLD}Installing pngxconf…${R}"
    hr; echo ""

    info "Creating directories…"
    mkdir -p "$BIN_DIR" "$LIB_DIR" "$STATE_DIR" "$NGINX_BAK_DIR" 2>/dev/null
    chmod 755 "$BIN_DIR" "$LIB_DIR"
    chmod 700 "$STATE_DIR"
    ok "  ${BIN_DIR}"
    ok "  ${LIB_DIR}"
    ok "  ${STATE_DIR}  ${DIM}(chmod 700)${R}"
    ok "  ${NGINX_BAK_DIR}"

    if [[ -d /etc/nginx ]]; then
        mkdir -p "$NGINX_CONFD" "$NGINX_SSL_DIR"
        chmod 755 "$NGINX_CONFD"
        chmod 700 "$NGINX_SSL_DIR"
        ok "  ${NGINX_CONFD}"
        ok "  ${NGINX_SSL_DIR}  ${DIM}(chmod 700)${R}"
    else
        warn "/etc/nginx does not exist — nginx dirs will be created on first pngxconf run"
    fi
    echo ""

    info "Installing pngxconf binary…"
    if [[ -f "$PNGX_BIN" ]]; then
        local bak="${PNGX_BIN}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$PNGX_BIN" "$bak"
        warn "  Existing ${PNGX_BIN} backed up to ${bak}"
    fi
    install -m 755 "$SRC_PNGXCONF" "$PNGX_BIN" || die "Failed to install pngxconf"
    ok "  ${PNGX_BIN}  ${DIM}(chmod 755)${R}"
    echo ""

    if [[ -n "$SRC_WIZARD" ]]; then
        info "Installing ssl-wizard.sh…"
        install -m 755 "$SRC_WIZARD" "$WIZARD_TARGET" || die "Failed to install ssl-wizard.sh"
        ok "  ${WIZARD_TARGET}  ${DIM}(chmod 755)${R}"
        echo ""
    fi

    info "Initialising state files…"
    touch "${STATE_DIR}/state.conf" "${STATE_DIR}/sites.db" "${STATE_DIR}/certs.db" "${STATE_DIR}/pngxconf.log"
    chmod 600 "${STATE_DIR}/state.conf" "${STATE_DIR}/sites.db" "${STATE_DIR}/certs.db"
    chmod 644 "${STATE_DIR}/pngxconf.log"
    ok "  ${STATE_DIR}/state.conf"
    ok "  ${STATE_DIR}/sites.db"
    ok "  ${STATE_DIR}/certs.db"
    ok "  ${STATE_DIR}/pngxconf.log"
    echo ""

    info "Verifying installation…"
    if command -v pngxconf &>/dev/null; then
        ok "  pngxconf is in PATH"
    else
        warn "  ${BIN_DIR} not in PATH — you may need to restart your shell"
    fi
    if bash -n "$PNGX_BIN"; then
        ok "  pngxconf syntax OK"
    else
        die "  pngxconf syntax check failed"
    fi
    echo ""
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
do_uninstall() {
    echo -e "  ${BOLD}Uninstalling pngxconf…${R}"
    hr; echo ""

    warn "This will remove pngxconf binary and ssl-wizard.sh."
    warn "State files in ${STATE_DIR} and nginx configs will NOT be removed by default."
    echo ""
    prompt_yn "Continue with uninstall?" || { info "Cancelled."; exit 0; }
    echo ""

    [[ -f "$PNGX_BIN" ]] && { rm -f "$PNGX_BIN"; ok "Removed ${PNGX_BIN}"; }
    [[ -f "$WIZARD_TARGET" ]] && { rm -f "$WIZARD_TARGET"; ok "Removed ${WIZARD_TARGET}"; }
    [[ -d "$LIB_DIR" ]] && { rmdir "$LIB_DIR" 2>/dev/null && ok "Removed ${LIB_DIR}" || true; }

    echo ""
    if prompt_yn "Also remove state directory ${STATE_DIR}? (sites DB, certs DB, logs will be lost)"; then
        rm -rf "$STATE_DIR"
        ok "Removed ${STATE_DIR}"
    else
        info "Keeping ${STATE_DIR}"
    fi
    echo ""
    ok "Uninstall complete."
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
    hr; echo ""
    echo -e "  ${BOLD}${GREEN}Installation complete.${R}"
    echo ""
    echo -e "  ${DIM}Distribution  :${R}  ${WHITE}${DISTRO}${R}  ${DIM}[${DISTRO_FAMILY}]${R}"
    echo -e "  ${DIM}Package mgr   :${R}  ${WHITE}${PKG_MGR}${R}"
    echo -e "  ${DIM}Binary        :${R}  ${WHITE}${PNGX_BIN}${R}"
    [[ -n "$SRC_WIZARD" ]] && \
        echo -e "  ${DIM}SSL wizard    :${R}  ${WHITE}${WIZARD_TARGET}${R}"
    echo -e "  ${DIM}State         :${R}  ${WHITE}${STATE_DIR}${R}"
    echo -e "  ${DIM}nginx backups :${R}  ${WHITE}${NGINX_BAK_DIR}${R}"
    echo ""
    echo -e "  ${BOLD}Run it:${R}"
    echo -e "    ${CYAN}sudo pngxconf${R}        ${DIM}# launch TUI${R}"
    echo -e "    ${CYAN}sudo pngxconf -h${R}     ${DIM}# show help${R}"
    echo ""
    hr
}

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF

${BOLD}pngxconf installer${R}

${BOLD}Usage:${R}
  sudo bash install.sh              Install pngxconf, ssl-wizard.sh, and verify deps
  sudo bash install.sh --uninstall  Remove pngxconf
  sudo bash install.sh --help       Show this help

${BOLD}What it installs / checks:${R}
  ${PNGX_BIN}            main binary (pngxconf command)
  ${WIZARD_TARGET}      SSL wizard
  ${STATE_DIR}                   state dir

  Required packages (via system package manager):
    nginx, openssl, curl, cron
  Optional:
    socat (for acme.sh standalone)
    acme.sh (installed from native repos if available, else official installer)

  Firewall checks:
    ufw, firewalld, iptables — ensures port 80 and 443 are open for ACME

${BOLD}Source files required in current directory:${R}
  pngxconf         (required)
  ssl-wizard.sh    (optional — skippable)

EOF
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-}" in
    -h|--help)
        show_help; exit 0 ;;
    --uninstall)
        require_root
        banner
        detect_distro
        do_uninstall
        exit 0 ;;
    "")
        require_root
        banner
        detect_distro
        info "Detected: ${WHITE}${DISTRO}${R} ${DIM}[${DISTRO_FAMILY}]${R}  ${DIM}(package manager: ${PKG_MGR})${R}"
        echo ""

        if [[ "$DISTRO_FAMILY" == "unknown" ]]; then
            err "Unsupported distribution. install.sh requires apt/dnf/pacman/zypper."
            pause_err
            exit 1
        fi

        find_sources
        check_prereqs
        check_cron_service
        do_install
        print_summary
        ;;
    *)
        err "Unknown argument: $1"
        echo "Run 'bash install.sh --help' for usage"
        exit 1
        ;;
esac
