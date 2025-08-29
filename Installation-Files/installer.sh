#!/usr/bin/env bash
set -euo pipefail

###############################
# Fail2Ban-Report Setup v0.5.0
###############################

# ---- Colors ----
RED="$(tput setaf 1 || true)"; GREEN="$(tput setaf 2 || true)"
YELLOW="$(tput setaf 3 || true)"; BLUE="$(tput setaf 4 || true)"
BOLD="$(tput bold || true)"; NORMAL="$(tput sgr0 || true)"

# ---- Requirements ----
require_root() {
  if [[ ${EUID:-0} -ne 0 ]]; then
    echo -e "${RED}Please run as root.${NORMAL}"
    exit 1
  fi
}

require_cmd() {
  command -v "$1" &>/dev/null || {
    echo -e "${RED}Missing dependency:${NORMAL} $1"
    exit 1
  }
}

require_root
require_cmd awk
require_cmd jq || {
  echo -e "${YELLOW}jq missing – please install: apt install jq${NORMAL}"
  exit 1
}
require_cmd curl || {
  echo -e "${YELLOW}curl missing – please install: apt install curl${NORMAL}"
  exit 1
}

# ---- Welcome ----
welcome() {
  cat <<'EOF'
========================================
 Fail2Ban-Report v0.5.0 – Setup Wizard
========================================
This script will install the Web-UI and Backend, harden access, and guide you
through optional .htaccess protection. Recommended for Debian/Ubuntu-like systems.

IMPORTANT: Never expose the Web-UI to the internet without protection!
EOF
  echo
}

welcome

# ---- User Inputs ----
BRANCH_NAME="latest"
SUDO_LOGIN_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
DEFAULT_SRC_DIR="/home/${SUDO_LOGIN_USER}/Fail2Ban-Report-latest"
DEFAULT_WEB_ROOT="/var/www/html"

ask_default() {
  local ans
  read -rp "$(echo -e "${BOLD}$1${NORMAL} [${YELLOW}$2${NORMAL}]: ")" ans || true
  echo "${ans:-$2}"
}

TARGET_DIR="$(ask_default "Local source directory (download/clone to)" "$DEFAULT_SRC_DIR")"
WEB_ROOT="$(ask_default "Web-UI install path" "$DEFAULT_WEB_ROOT")"
echo -e "${YELLOW}Note: The Web-UI will be installed under ${WEB_ROOT}/Fail2Ban-Report/${NORMAL}"

# ---- Download Source ----
echo -e "${BLUE}Using git to fetch sources…${NORMAL}"
if [[ -d "$TARGET_DIR/.git" ]]; then
  git -C "$TARGET_DIR" fetch origin "$BRANCH_NAME"
  git -C "$TARGET_DIR" checkout "$BRANCH_NAME"
  git -C "$TARGET_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$TARGET_DIR")"
  rm -rf "$TARGET_DIR" 2>/dev/null || true
  git clone --branch "$BRANCH_NAME" --depth 1 "https://github.com/SubleXBle/Fail2Ban-Report.git" "$TARGET_DIR"
fi

# ---- Web-UI Installation ----
WEB_UI_PATH="${WEB_ROOT}/Fail2Ban-Report"
echo -e "${BLUE}Installing Web-UI to ${WEB_UI_PATH}${NORMAL}"
mkdir -p "$WEB_UI_PATH"
rsync -a --delete "${TARGET_DIR}/Web-UI/" "$WEB_UI_PATH/"
chown -R "www-data:www-data" "$WEB_UI_PATH"

# ---- Backend Installation ----
BACKEND_ROOT="/opt/Fail2Ban-Report"
F2B_JSON_DIR="${BACKEND_ROOT}/archive/fail2ban"
BLOCKLIST_DIR="${BACKEND_ROOT}/archive/blocklists"

echo -e "${BLUE}Preparing Backend at ${BACKEND_ROOT}${NORMAL}"
mkdir -p "${BACKEND_ROOT}/"{archive/fail2ban,archive/blocklists,Settings,Backend,Helper-Scripts}
rsync -a "${TARGET_DIR}/Helper-Scripts/" "${BACKEND_ROOT}/Helper-Scripts/" || true
rsync -a "${TARGET_DIR}/Backend/fail2ban_log2json.sh" "${BACKEND_ROOT}/Backend/"
rsync -a "${TARGET_DIR}/Backend/firewall-update.sh" "${BACKEND_ROOT}/Backend/"

if [[ -f "${TARGET_DIR}/Conf/fail2ban-report.config" ]]; then
  install -m 0644 "${TARGET_DIR}/Conf/fail2ban-report.config" "${BACKEND_ROOT}/Settings/fail2ban-report.config"
else
  echo -e "${YELLOW}Config template not found. Skipping copy.${NORMAL}"
fi

# Adjust paths in scripts
sed -i -E "s|^OUTPUT_JSON_DIR=.*|OUTPUT_JSON_DIR="${F2B_JSON_DIR}"|g" "${BACKEND_ROOT}/Backend/fail2ban_log2json.sh"
sed -i -E "s|^(BLOCKLIST_DIR|BLOCKLIST_PATH)=.*|="${BLOCKLIST_DIR}"|g" "${BACKEND_ROOT}/Backend/firewall-update.sh"
chmod +x "${BACKEND_ROOT}/Backend/fail2ban_log2json.sh"
chmod +x "${BACKEND_ROOT}/Backend/firewall-update.sh"
find "${BACKEND_ROOT}/Helper-Scripts" -type f -name "*.sh" -exec chmod +x {} \;

# ---- Cronjobs ----
ask_yes_no() {
  local d="${2^^}"
  local ans
  read -rp "$(echo -e "${BOLD}$1${NORMAL} (${GREEN}Y${NORMAL}/n)") " ans || true
  ans="${ans:-$d}"
  [[ "${ans,,}" == "y" ]]
}

menu_choice() {
  local title="$1"; shift
  local opts=("$@")
  echo -e "${BOLD}$title${NORMAL}"
  local i=1
  for o in "${opts[@]}"; do echo "  $i) $o"; ((i++)); done
  local sel
  while true; do
    read -rp "Choose [1-${#opts[@]}]: " sel || true
    [[ "$sel" =~ ^[1-9][0-9]*$ ]] && (( sel>=1 && sel<=${#opts[@]} )) && break
    echo -e "${YELLOW}Invalid choice, try again.${NORMAL}"
  done
  echo "$sel"
}

echo
if ask_yes_no "Install cronjobs for backend scripts?" "Y"; then
  echo -e "${BOLD}Choose interval for cronjobs:${NORMAL}"
  interval_choice=$(menu_choice "Interval" "Every 5 minutes" "Every 10 minutes" "Every 15 minutes" "Every 30 minutes")
  case "$interval_choice" in
    1) CRON_INTERVAL="*/5 * * * *" ;;
    2) CRON_INTERVAL="*/10 * * * *" ;;
    3) CRON_INTERVAL="*/15 * * * *" ;;
    4) CRON_INTERVAL="*/30 * * * *" ;;
  esac

  CRON1="${CRON_INTERVAL} ${BACKEND_ROOT}/Backend/fail2ban_log2json.sh"
  CRON2="${CRON_INTERVAL} ${BACKEND_ROOT}/Backend/firewall-update.sh"

  ( crontab -l 2>/dev/null | grep -v -E "fail2ban_log2json\.sh|firewall-update\.sh" || true
    echo "$CRON1"
    echo "$CRON2"
  ) | crontab -

  echo -e "${GREEN}Cronjobs installed with interval: ${CRON_INTERVAL}${NORMAL}"
else
  echo -e "${YELLOW}Skipped cron setup.${NORMAL}"
fi


echo
echo -e "${GREEN}========================================${NORMAL}"
echo -e "${GREEN}   Fail2Ban-Report v0.5.0 – Setup Done  ${NORMAL}"
echo -e "${GREEN}========================================${NORMAL}"
echo
echo -e "${BOLD}The following steps were completed:${NORMAL}"
echo "  ✔ Sources downloaded from GitHub (${TARGET_DIR})"
echo "  ✔ Web-UI installed to: ${WEB_UI_PATH}"
echo "  ✔ Backend installed to: ${BACKEND_ROOT}"
if crontab -l 2>/dev/null | grep -q "fail2ban_log2json.sh"; then
  echo "  ✔ Cronjobs installed (Interval: ${CRON_INTERVAL})"
else
  echo "  ⚠ Cronjobs were not installed"
fi
echo
echo -e "${BOLD}Next steps:${NORMAL}"
echo "  1. Open the Web-UI: http://<SERVER-IP>/Fail2Ban-Report/"
echo "  2. Edit the configuration file if needed:"
echo "     ${BACKEND_ROOT}/Settings/fail2ban-report.config"
echo "  3. Make sure the Web-UI is NOT publicly accessible!"
echo "     (e.g. protect with .htaccess, firewall, or VPN)"
echo
echo -e "${BLUE}Installation completed. Enjoy Fail2Ban-Report! 🕵️${NORMAL}"
echo
