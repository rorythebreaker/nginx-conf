#!/usr/bin/env bash
# ==============================================================================
#  install.sh — pngxconf automated installer
#  Installs pngxconf and ssl-wizard.sh to standard system locations
#  Run as root: sudo bash install.sh
# ==============================================================================
set -euo pipefail

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
die()   { err "$*"; exit 1; }
hr()    { echo -e "${DIM}  $(printf '%.0s─' {1..62})${R}"; }

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
    clear
    echo ""
    echo -e "  ${BOLD}${BLUE}╔══════════════════════════════════════════════════════════╗${R}"
    echo -e "  ${BOLD}${BLUE}║${R}  ${BOLD}${WHITE}pngxconf installer${R}                                    ${BOLD}${BLUE}║${R}"
    echo -e "  ${BOLD}${BLUE}║${R}  ${DIM}Nginx Management System — automated setup${R}             ${BOLD}${BLUE}║${R}"
    echo -e "  ${BOLD}${BLUE}╚══════════════════════════════════════════════════════════╝${R}"
    echo ""
}

# ── Root check ────────────────────────────────────────────────────────────────
require_root() {
    [[ $EUID -eq 0 ]] || die "Installer must be run as root.  Try: sudo bash install.sh"
}

# ── Distro detection ──────────────────────────────────────────────────────────
DISTRO="unknown"
DISTRO_FAMILY="unknown"

detect_distro() {
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
    fi
}

# ── Check prerequisites ───────────────────────────────────────────────────────
check_prereqs() {
    echo -e "  ${BOLD}Checking prerequisites…${R}"
    hr; echo ""

    local missing=()

    # bash version
    local bash_ver="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
    if (( BASH_VERSINFO[0] >= 4 )); then
        ok "bash           ${bash_ver}"
    else
        err "bash           ${bash_ver}  (need 4.0+)"
        missing+=("bash")
    fi

    # openssl
    if command -v openssl &>/dev/null; then
        ok "openssl        $(openssl version | awk '{print $2}')"
    else
        warn "openssl        not found — will attempt install"
        missing+=("openssl")
    fi

    # nginx
    if command -v nginx &>/dev/null; then
        local nver; nver=$(nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        ok "nginx          ${nver}"
    else
        warn "nginx          not found — required for pngxconf to operate"
        missing+=("nginx")
    fi

    # curl (required by ssl-wizard for acme.sh)
    if command -v curl &>/dev/null; then
        ok "curl           $(curl --version | head -1 | awk '{print $2}')"
    else
        warn "curl           not found — will attempt install"
        missing+=("curl")
    fi

    # socat (optional, for ssl-wizard standalone mode)
    if command -v socat &>/dev/null; then
        ok "socat          found"
    else
        warn "socat          not found  ${DIM}(optional — for acme.sh standalone)${R}"
    fi

    echo ""
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing packages: ${missing[*]}"
        echo ""
        if prompt_yn "Attempt to install missing packages now?"; then
            install_missing "${missing[@]}"
        else
            warn "Continuing without installing. pngxconf may not function correctly."
        fi
    fi
    echo ""
}

install_missing() {
    local pkgs=("$@")
    case "$DISTRO_FAMILY" in
        debian)
            info "Running: apt-get update && apt-get install -y ${pkgs[*]}"
            apt-get update && apt-get install -y "${pkgs[@]}"
            ;;
        rhel)
            if command -v dnf &>/dev/null; then
                info "Running: dnf install -y ${pkgs[*]}"
                dnf install -y "${pkgs[@]}"
            else
                info "Running: yum install -y ${pkgs[*]}"
                yum install -y "${pkgs[@]}"
            fi
            ;;
        arch)
            info "Running: pacman -Sy --noconfirm ${pkgs[*]}"
            pacman -Sy --noconfirm "${pkgs[@]}"
            ;;
        suse)
            info "Running: zypper install -y ${pkgs[*]}"
            zypper install -y "${pkgs[@]}"
            ;;
        *)
            err "Unknown distribution — cannot auto-install. Please install manually: ${pkgs[*]}"
            return 1
            ;;
    esac
}

prompt_yn() {
    local prompt="${1:-Proceed?}"
    local ans
    printf "  %s [Y/n]: " "$prompt"
    IFS= read -r ans
    [[ -z "$ans" ]] && return 0
    [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

# ── Find source files ─────────────────────────────────────────────────────────
SRC_PNGXCONF=""
SRC_WIZARD=""

find_sources() {
    # pngxconf
    if [[ -f "${SCRIPT_DIR}/pngxconf" ]]; then
        SRC_PNGXCONF="${SCRIPT_DIR}/pngxconf"
    elif [[ -f "${SCRIPT_DIR}/pngxconf.sh" ]]; then
        SRC_PNGXCONF="${SCRIPT_DIR}/pngxconf.sh"
    else
        die "pngxconf source not found in ${SCRIPT_DIR}. Place pngxconf next to install.sh."
    fi

    # ssl-wizard.sh
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

# ── Install ───────────────────────────────────────────────────────────────────
do_install() {
    echo -e "  ${BOLD}Installing pngxconf…${R}"
    hr; echo ""

    # 1. Create directories
    info "Creating directories…"
    mkdir -p "$BIN_DIR" "$LIB_DIR" "$STATE_DIR" "$NGINX_BAK_DIR"
    chmod 755 "$BIN_DIR" "$LIB_DIR"
    chmod 700 "$STATE_DIR"
    ok "  ${BIN_DIR}"
    ok "  ${LIB_DIR}"
    ok "  ${STATE_DIR}  ${DIM}(chmod 700)${R}"
    ok "  ${NGINX_BAK_DIR}"

    # nginx dirs — create only if /etc/nginx exists (nginx installed)
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

    # 2. Install pngxconf binary
    info "Installing pngxconf binary…"
    if [[ -f "$PNGX_BIN" ]]; then
        local bak="${PNGX_BIN}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$PNGX_BIN" "$bak"
        warn "  Existing ${PNGX_BIN} backed up to ${bak}"
    fi
    install -m 755 "$SRC_PNGXCONF" "$PNGX_BIN"
    ok "  ${PNGX_BIN}  ${DIM}(chmod 755)${R}"
    echo ""

    # 3. Install ssl-wizard.sh
    if [[ -n "$SRC_WIZARD" ]]; then
        info "Installing ssl-wizard.sh…"
        install -m 755 "$SRC_WIZARD" "$WIZARD_TARGET"
        ok "  ${WIZARD_TARGET}  ${DIM}(chmod 755)${R}"
        echo ""
    fi

    # 4. State files — create empty with correct permissions
    info "Initialising state files…"
    touch "${STATE_DIR}/state.conf" "${STATE_DIR}/sites.db" "${STATE_DIR}/certs.db" "${STATE_DIR}/pngxconf.log"
    chmod 600 "${STATE_DIR}/state.conf" "${STATE_DIR}/sites.db" "${STATE_DIR}/certs.db"
    chmod 644 "${STATE_DIR}/pngxconf.log"
    ok "  ${STATE_DIR}/state.conf"
    ok "  ${STATE_DIR}/sites.db"
    ok "  ${STATE_DIR}/certs.db"
    ok "  ${STATE_DIR}/pngxconf.log"
    echo ""

    # 5. Verify binary is in PATH
    info "Verifying installation…"
    if command -v pngxconf &>/dev/null; then
        ok "  pngxconf is in PATH"
    else
        warn "  ${BIN_DIR} not in PATH — you may need to restart your shell"
        warn "  Or add to your shell rc: export PATH=\"${BIN_DIR}:\$PATH\""
    fi
    if bash -n "$PNGX_BIN"; then
        ok "  pngxconf syntax OK"
    else
        die "  pngxconf syntax check failed — installation corrupt"
    fi
    echo ""
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
do_uninstall() {
    echo -e "  ${BOLD}Uninstalling pngxconf…${R}"
    hr; echo ""

    warn "This will remove pngxconf binary and ssl-wizard.sh."
    warn "State files in ${STATE_DIR} and nginx configs will NOT be removed."
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
  sudo bash install.sh              Install pngxconf and ssl-wizard.sh
  sudo bash install.sh --uninstall  Remove pngxconf
  sudo bash install.sh --help       Show this help

${BOLD}What it installs:${R}
  ${PNGX_BIN}            main binary (pngxconf command)
  ${WIZARD_TARGET}      SSL wizard
  ${STATE_DIR}                   state dir (sites, certs, log)

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
        do_uninstall
        exit 0 ;;
    "")
        require_root
        banner
        detect_distro
        info "Detected: ${WHITE}${DISTRO}${R} ${DIM}[${DISTRO_FAMILY}]${R}"
        echo ""
        find_sources
        check_prereqs
        do_install
        print_summary
        ;;
    *)
        err "Unknown argument: $1"
        echo "Run 'bash install.sh --help' for usage"
        exit 1
        ;;
esac
