#!/bin/bash

set -o nounset
set -o pipefail

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --force                 Run without interactive confirmations for destructive steps.
  --include-common-tools  Also remove common utility packages (nano, wget, curl, git, unzip, screen).
  --preserve-home         Keep /home/ebot instead of deleting it.
  --purge-mysql-data      Remove /var/lib/mysql directory after package removal.
  -h, --help              Show this help message.
USAGE
}

FORCE=0
INCLUDE_COMMON_TOOLS=0
PRESERVE_HOME=0
PURGE_MYSQL_DATA=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    --include-common-tools)
      INCLUDE_COMMON_TOOLS=1
      ;;
    --preserve-home)
      PRESERVE_HOME=1
      ;;
    --purge-mysql-data)
      PURGE_MYSQL_DATA=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift

done

prompt_confirm() {
  local prompt_message="$1"
  if [[ ${FORCE} -eq 1 ]]; then
    log_info "${prompt_message} -- auto-confirmed due to --force flag."
    return 0
  fi
  local reply=""
  read -r -p "${prompt_message} [y/N]: " reply
  case "${reply}" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

log_info() {
  printf '\e[1;33m%s\e[0m\n' "$1"
}

log_success() {
  printf '\e[1;32m%s\e[0m\n' "$1"
}

log_warn() {
  printf '\e[1;31m%s\e[0m\n' "$1"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo." >&2
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

service_exists() {
  local unit="$1"
  if ! command_exists systemctl; then
    return 1
  fi
  if systemctl status "$unit" >/dev/null 2>&1; then
    return 0
  fi
  if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
    return 0
  fi
  [[ -f "/etc/systemd/system/${unit}" ]] || [[ -f "/lib/systemd/system/${unit}" ]]
}

filter_installed_packages() {
  local -n source_array=$1
  local -a installed=()
  local pkg
  declare -A seen=()
  for pkg in "${source_array[@]}"; do
    if [[ -n "${pkg}" && -z "${seen[$pkg]:-}" ]]; then
      seen[$pkg]=1
      if dpkg -s "$pkg" >/dev/null 2>&1; then
        installed+=("$pkg")
      else
        log_info "Package '$pkg' is not installed; skipping." >&2
      fi
    fi
  done
  printf '%s\n' "${installed[@]}"
}

ensure_noninteractive_apt() {
  export DEBIAN_FRONTEND=noninteractive
}

collect_php74_packages() {
  if command_exists dpkg-query; then
    dpkg-query -f '${binary:Package}\n' -W 'php7.4*' 2>/dev/null | sort -u
  fi
}

require_root
ensure_noninteractive_apt

SERVICES=(ebot-cs2-app.service ebot-cs2-logs.service)

log_info "Stopping and disabling eBot services..."
for service in "${SERVICES[@]}"; do
  if service_exists "$service"; then
    if systemctl stop "$service"; then
      log_info "Stopped $service"
    else
      log_warn "Failed to stop $service"
    fi
    if systemctl disable "$service"; then
      log_info "Disabled $service"
    else
      log_warn "Failed to disable $service"
    fi
  else
    log_info "Service $service not found or already removed; skipping."
  fi
  unit_file="/etc/systemd/system/${service}"
  if [[ -f "$unit_file" ]]; then
    rm -f "$unit_file"
    log_info "Removed unit file $unit_file"
  fi

done
if command_exists systemctl; then
  systemctl daemon-reload
  systemctl reset-failed
fi
log_success "eBot services processed."

log_info "Removing eBot cronjobs..."
if command_exists crontab; then
  (crontab -l 2>/dev/null | grep -v "/home/ebot/check-ebot-cs2-app.sh" | grep -v "/home/ebot/check-ebot-cs2-logs.sh" || true) | crontab -
  log_success "eBot cronjobs removed (if they existed)."
else
  log_info "crontab command not available; skipping cron cleanup."
fi

log_info "Handling eBot application files..."
if [[ -d /home/ebot ]]; then
  if [[ ${PRESERVE_HOME} -eq 1 ]]; then
    log_info "/home/ebot preserved due to --preserve-home flag."
  elif prompt_confirm "Remove /home/ebot directory and all of its contents?"; then
    rm -rf /home/ebot
    log_success "/home/ebot removed."
  else
    log_warn "Removal of /home/ebot skipped by user."
  fi
else
  log_info "/home/ebot not found; skipping."
fi

log_info "Removing Apache configuration for eBot..."
if command_exists a2dissite; then
  a2dissite ebotcs2.conf &>/dev/null || log_info "Site ebotcs2.conf not enabled."
fi
if [[ -L /etc/apache2/sites-enabled/ebotcs2.conf ]]; then
  rm -f /etc/apache2/sites-enabled/ebotcs2.conf
  log_info "Removed Apache sites-enabled symlink."
fi
if [[ -f /etc/apache2/sites-available/ebotcs2.conf ]]; then
  rm -f /etc/apache2/sites-available/ebotcs2.conf
  log_info "Removed Apache site definition."
fi
if service_exists apache2.service && systemctl is-active --quiet apache2; then
  if systemctl restart apache2; then
    log_success "Apache restarted."
  else
    log_warn "Failed to restart Apache."
  fi
else
  log_info "Apache service inactive or unavailable; restart skipped."
fi
log_success "Apache configuration for eBot processed."

log_info "Removing phpMyAdmin..."
if [[ -d /usr/share/phpmyadmin ]]; then
  if prompt_confirm "Remove phpMyAdmin directory /usr/share/phpmyadmin?"; then
    rm -rf /usr/share/phpmyadmin
    log_success "phpMyAdmin removed."
  else
    log_warn "phpMyAdmin removal skipped by user."
  fi
else
  log_info "phpMyAdmin directory not found; skipping."
fi

log_info "Removing Composer..."
if [[ -f /usr/bin/composer ]]; then
  if prompt_confirm "Remove Composer binary /usr/bin/composer?"; then
    rm -f /usr/bin/composer
    log_success "Composer removed."
  else
    log_warn "Composer removal skipped by user."
  fi
else
  log_info "Composer binary not found; skipping."
fi

log_info "Uninstalling global NPM packages (n, yarn, socket.io, etc.)..."
GLOBAL_NPM_PACKAGES=(socket.io archiver formidable ts-node n yarn)
if command_exists npm; then
  for pkg in "${GLOBAL_NPM_PACKAGES[@]}"; do
    if npm list -g "$pkg" --depth=0 >/dev/null 2>&1; then
      if npm -g uninstall "$pkg"; then
        log_info "Uninstalled global npm package '$pkg'."
      else
        log_warn "Failed to uninstall global npm package '$pkg'."
      fi
    else
      log_info "Global npm package '$pkg' not found; skipping."
    fi
  done
  if [[ -d /usr/local/n ]]; then
    if prompt_confirm "Remove Node versions installed by 'n' under /usr/local/n?"; then
      rm -rf /usr/local/n
      log_success "Directory /usr/local/n removed."
    else
      log_warn "Removal of /usr/local/n skipped by user."
    fi
  fi
else
  log_info "npm not available; skipping global package removal."
fi
hash -r
log_success "Global NPM packages processed."

log_info "Checking for Snap packages (certbot)..."
if command_exists snap; then
  if snap list certbot >/dev/null 2>&1; then
    if snap remove certbot; then
      if [[ -L /usr/bin/certbot ]]; then
        rm -f /usr/bin/certbot
        log_info "Removed /usr/bin/certbot symlink."
      fi
      log_success "Certbot snap removed."
    else
      log_warn "Failed to remove certbot snap."
    fi
  else
    log_info "Certbot snap not found; skipping."
  fi
else
  log_info "snap command not available; skipping snap cleanup."
fi

log_info "Checking for ondrej/php PPA..."
if command_exists add-apt-repository; then
  if ls /etc/apt/sources.list.d/ondrej-ubuntu-php*.list >/dev/null 2>&1; then
    if prompt_confirm "Remove ondrej/php PPA from APT sources?"; then
      if add-apt-repository --remove ppa:ondrej/php -y; then
        log_success "ondrej/php PPA removed."
      else
        log_warn "Failed to remove ondrej/php PPA."
      fi
    else
      log_warn "Removal of ondrej/php PPA skipped by user."
    fi
  else
    log_info "ondrej/php PPA not found; skipping."
  fi
else
  log_info "add-apt-repository not available; skipping PPA removal."
fi

log_info "Evaluating APT packages to uninstall..."
BASE_PACKAGES=(
  apache2
  redis-server
  mysql-server
  nodejs
  npm
  language-pack-en-base
  libapache2-mod-php7.4
)

PHP_PACKAGES=()
while IFS= read -r php_pkg; do
  PHP_PACKAGES+=("${php_pkg}")
done < <(collect_php74_packages || true)

PACKAGES_TO_UNINSTALL=("${BASE_PACKAGES[@]}" "${PHP_PACKAGES[@]}")
COMMON_TOOLS=(nano wget curl git unzip screen)

mapfile -t INSTALLED_PACKAGES < <(filter_installed_packages PACKAGES_TO_UNINSTALL)
if [[ ${INCLUDE_COMMON_TOOLS} -eq 1 ]]; then
  log_info "Including common tools for removal."
  mapfile -t INSTALLED_COMMON < <(filter_installed_packages COMMON_TOOLS)
  INSTALLED_PACKAGES+=("${INSTALLED_COMMON[@]}")
fi

if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
  log_info "The following packages will be purged: ${INSTALLED_PACKAGES[*]}"
  if prompt_confirm "Proceed with apt-get purge of listed packages?"; then
    if ! apt-get purge --auto-remove -y "${INSTALLED_PACKAGES[@]}"; then
      log_warn "apt-get purge encountered issues. Review the output above."
    fi
  else
    log_warn "APT package purge skipped by user."
  fi
else
  log_info "No target packages found for removal."
fi

log_info "Attempting to remove software-properties-common and snapd if installed..."
MISC_PACKAGES=(software-properties-common snapd)
mapfile -t INSTALLED_MISC < <(filter_installed_packages MISC_PACKAGES)
if [[ ${#INSTALLED_MISC[@]} -gt 0 ]]; then
  if prompt_confirm "Proceed with apt-get purge of ${INSTALLED_MISC[*]}?"; then
    if ! apt-get purge --auto-remove -y "${INSTALLED_MISC[@]}"; then
      log_warn "apt-get purge of misc packages encountered issues."
    fi
  else
    log_warn "Purge of misc packages skipped by user."
  fi
else
  log_info "software-properties-common and snapd not installed or already removed."
fi

if prompt_confirm "Run apt-get autoremove/autoclean/clean to tidy up package cache?"; then
  apt-get autoremove -y
  apt-get autoclean -y
  apt-get clean -y
  log_success "APT cleanup complete."
else
  log_warn "APT cleanup skipped by user."
fi

if [[ ${PURGE_MYSQL_DATA} -eq 1 ]]; then
  if [[ -d /var/lib/mysql ]]; then
    if prompt_confirm "Remove /var/lib/mysql directory? This will delete all MySQL data."; then
      rm -rf /var/lib/mysql
      log_success "/var/lib/mysql removed."
    else
      log_warn "Removal of /var/lib/mysql skipped by user."
    fi
  else
    log_info "/var/lib/mysql not found; skipping."
  fi
else
  log_info "MySQL data directory preserved. Use --purge-mysql-data to remove it."
fi

log_success "eBot CS2 uninstallation attempt complete."
log_info "Please review any errors and manually check for leftover files or configurations."
log_info "A reboot might be advisable to ensure all services are fully stopped/unloaded."
