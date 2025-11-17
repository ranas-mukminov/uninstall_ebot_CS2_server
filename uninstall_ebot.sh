#!/bin/bash

set -o nounset
set -o pipefail

# Script version
SCRIPT_VERSION="2.0.0"

# Log file location
LOG_FILE="/var/log/uninstall_ebot_cs2.log"

usage() {
  cat <<USAGE
eBot CS2 Uninstaller Script v${SCRIPT_VERSION}

Usage: $0 [options]

Options:
  --dry-run               Show what would be done without making any changes.
  --force-all             Run without any interactive confirmations (DANGEROUS).
  --force                 Run without interactive confirmations for destructive steps (alias for --force-all).
  --include-common-tools  Also remove common utility packages (nano, wget, curl, git, unzip, screen).
  --preserve-home         Keep /home/ebot instead of deleting it.
  --purge-mysql-data      Remove /var/lib/mysql directory after package removal.
  -h, --help              Show this help message.

Environment Variables:
  DRY_RUN=1              Alternative way to enable dry-run mode.

Examples:
  $0 --dry-run                      # Preview what would be removed
  $0                                # Interactive uninstall (safest)
  $0 --force-all --purge-mysql-data # Automated full uninstall (DANGEROUS)

USAGE
}

# Global flags
DRY_RUN=${DRY_RUN:-0}
FORCE_ALL=0
INCLUDE_COMMON_TOOLS=0
PRESERVE_HOME=0
PURGE_MYSQL_DATA=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --force-all|--force)
      FORCE_ALL=1
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

# Logging functions
init_logging() {
  if [[ ${DRY_RUN} -eq 0 ]]; then
    # Create log file with proper permissions
    touch "${LOG_FILE}" 2>/dev/null || {
      LOG_FILE="/tmp/uninstall_ebot_cs2.log"
      echo "Warning: Cannot write to /var/log, using ${LOG_FILE}" >&2
    }
    exec > >(tee -a "${LOG_FILE}")
    exec 2>&1
    log_info "=========================================="
    log_info "eBot CS2 Uninstaller v${SCRIPT_VERSION}"
    log_info "Started at: $(date)"
    log_info "=========================================="
  else
    log_info "=========================================="
    log_info "DRY RUN MODE - No changes will be made"
    log_info "=========================================="
  fi
}

log_to_file() {
  if [[ ${DRY_RUN} -eq 0 && -f "${LOG_FILE}" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}" 2>/dev/null || true
  fi
}

log_info() {
  printf '\e[1;33m%s\e[0m\n' "$1"
  log_to_file "INFO: $1"
}

log_success() {
  printf '\e[1;32m%s\e[0m\n' "$1"
  log_to_file "SUCCESS: $1"
}

log_warn() {
  printf '\e[1;31m%s\e[0m\n' "$1"
  log_to_file "WARNING: $1"
}

log_error() {
  printf '\e[1;31mERROR: %s\e[0m\n' "$1" >&2
  log_to_file "ERROR: $1"
}

log_dry_run() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    printf '\e[1;36m[DRY RUN] %s\e[0m\n' "$1"
  fi
}

prompt_confirm() {
  local prompt_message="$1"
  
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_dry_run "${prompt_message} -- would prompt for confirmation"
    return 0
  fi
  
  if [[ ${FORCE_ALL} -eq 1 ]]; then
    log_info "${prompt_message} -- auto-confirmed due to --force-all flag."
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

# Execute command with dry-run support
execute_cmd() {
  local description="$1"
  shift
  
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_dry_run "${description}: $*"
    return 0
  fi
  
  log_info "${description}..."
  if "$@"; then
    log_success "${description} - completed"
    return 0
  else
    log_error "${description} - failed"
    return 1
  fi
}

# System validation functions
require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "This script must be run as root. Please use sudo."
    exit 1
  fi
}

check_supported_os() {
  if [[ ! -f /etc/os-release ]]; then
    log_error "Cannot detect operating system (/etc/os-release not found)."
    log_error "This script is designed for Ubuntu 20.04 or 22.04."
    exit 1
  fi
  
  source /etc/os-release
  
  if [[ "${ID}" != "ubuntu" ]]; then
    log_error "Unsupported operating system: ${ID}"
    log_error "This script is designed for Ubuntu 20.04 or 22.04."
    exit 1
  fi
  
  case "${VERSION_ID}" in
    20.04|22.04)
      log_info "Detected supported OS: Ubuntu ${VERSION_ID}"
      ;;
    *)
      log_warn "Warning: Detected Ubuntu ${VERSION_ID}"
      log_warn "This script is tested on Ubuntu 20.04 and 22.04."
      log_warn "Proceed at your own risk."
      if [[ ${DRY_RUN} -eq 0 && ${FORCE_ALL} -eq 0 ]]; then
        if ! prompt_confirm "Continue anyway?"; then
          log_info "Aborted by user."
          exit 0
        fi
      fi
      ;;
  esac
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
  if systemctl list-unit-files "$unit" 2>/dev/null | grep -q "$unit"; then
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
        log_info "Package '$pkg' is not installed; skipping."
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

# Main execution functions
stop_ebot_services() {
  log_info "=========================================="
  log_info "Stopping and disabling eBot services..."
  log_info "=========================================="
  
  local SERVICES=(ebot-cs2-app.service ebot-cs2-logs.service)
  local found_any=0
  
  for service in "${SERVICES[@]}"; do
    if service_exists "$service"; then
      found_any=1
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would stop $service"
        log_dry_run "Would disable $service"
      else
        if systemctl stop "$service" 2>/dev/null; then
          log_info "Stopped $service"
        else
          log_warn "Failed to stop $service (may already be stopped)"
        fi
        if systemctl disable "$service" 2>/dev/null; then
          log_info "Disabled $service"
        else
          log_warn "Failed to disable $service (may already be disabled)"
        fi
      fi
    else
      log_info "Service $service not found or already removed; skipping."
    fi
    
    unit_file="/etc/systemd/system/${service}"
    if [[ -f "$unit_file" ]]; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would remove unit file $unit_file"
      else
        rm -f "$unit_file"
        log_info "Removed unit file $unit_file"
      fi
    fi
  done
  
  if [[ ${found_any} -eq 0 ]]; then
    log_info "No eBot services found on this system."
  fi
  
  if command_exists systemctl; then
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_dry_run "Would reload systemd daemon"
    else
      systemctl daemon-reload 2>/dev/null || true
      systemctl reset-failed 2>/dev/null || true
    fi
  fi
  
  log_success "eBot services processed."
}

remove_ebot_cronjobs() {
  log_info "=========================================="
  log_info "Removing eBot cronjobs..."
  log_info "=========================================="
  
  if command_exists crontab; then
    local current_cron
    current_cron=$(crontab -l 2>/dev/null || echo "")
    
    if echo "$current_cron" | grep -q -e "/home/ebot/check-ebot-cs2-app.sh" -e "/home/ebot/check-ebot-cs2-logs.sh"; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would remove eBot cronjobs"
      else
        (crontab -l 2>/dev/null | grep -v "/home/ebot/check-ebot-cs2-app.sh" | grep -v "/home/ebot/check-ebot-cs2-logs.sh" || true) | crontab -
        log_success "eBot cronjobs removed."
      fi
    else
      log_info "No eBot cronjobs found."
    fi
  else
    log_info "crontab command not available; skipping cron cleanup."
  fi
}

remove_ebot_files() {
  log_info "=========================================="
  log_info "Handling eBot application files..."
  log_info "=========================================="
  
  if [[ -d /home/ebot ]]; then
    if [[ ${PRESERVE_HOME} -eq 1 ]]; then
      log_info "/home/ebot preserved due to --preserve-home flag."
    elif prompt_confirm "Remove /home/ebot directory and all of its contents?"; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would remove /home/ebot directory"
      else
        rm -rf /home/ebot
        log_success "/home/ebot removed."
      fi
    else
      log_warn "Removal of /home/ebot skipped by user."
    fi
  else
    log_info "/home/ebot not found; skipping."
  fi
}

remove_apache_config() {
  log_info "=========================================="
  log_info "Removing Apache configuration for eBot..."
  log_info "=========================================="
  
  local changed=0
  
  if command_exists a2dissite; then
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_dry_run "Would disable Apache site ebotcs2.conf"
    else
      a2dissite ebotcs2.conf &>/dev/null || log_info "Site ebotcs2.conf not enabled."
    fi
  fi
  
  if [[ -L /etc/apache2/sites-enabled/ebotcs2.conf ]]; then
    changed=1
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_dry_run "Would remove Apache sites-enabled symlink"
    else
      rm -f /etc/apache2/sites-enabled/ebotcs2.conf
      log_info "Removed Apache sites-enabled symlink."
    fi
  fi
  
  if [[ -f /etc/apache2/sites-available/ebotcs2.conf ]]; then
    changed=1
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_dry_run "Would remove Apache site definition"
    else
      rm -f /etc/apache2/sites-available/ebotcs2.conf
      log_info "Removed Apache site definition."
    fi
  fi
  
  if [[ ${changed} -eq 0 ]]; then
    log_info "No eBot Apache configuration found."
  fi
  
  if service_exists apache2.service && systemctl is-active --quiet apache2 2>/dev/null; then
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_dry_run "Would restart Apache"
    else
      if systemctl restart apache2; then
        log_success "Apache restarted."
      else
        log_warn "Failed to restart Apache."
      fi
    fi
  else
    log_info "Apache service inactive or unavailable; restart skipped."
  fi
  
  log_success "Apache configuration for eBot processed."
}

remove_phpmyadmin() {
  log_info "=========================================="
  log_info "Removing phpMyAdmin..."
  log_info "=========================================="
  
  if [[ -d /usr/share/phpmyadmin ]]; then
    if prompt_confirm "Remove phpMyAdmin directory /usr/share/phpmyadmin?"; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would remove /usr/share/phpmyadmin"
      else
        rm -rf /usr/share/phpmyadmin
        log_success "phpMyAdmin removed."
      fi
    else
      log_warn "phpMyAdmin removal skipped by user."
    fi
  else
    log_info "phpMyAdmin directory not found; skipping."
  fi
}

remove_composer() {
  log_info "=========================================="
  log_info "Removing Composer..."
  log_info "=========================================="
  
  if [[ -f /usr/bin/composer ]]; then
    if prompt_confirm "Remove Composer binary /usr/bin/composer?"; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would remove /usr/bin/composer"
      else
        rm -f /usr/bin/composer
        log_success "Composer removed."
      fi
    else
      log_warn "Composer removal skipped by user."
    fi
  else
    log_info "Composer binary not found; skipping."
  fi
}

remove_npm_packages() {
  log_info "=========================================="
  log_info "Uninstalling global NPM packages..."
  log_info "=========================================="
  
  local GLOBAL_NPM_PACKAGES=(socket.io archiver formidable ts-node n yarn)
  
  if command_exists npm; then
    for pkg in "${GLOBAL_NPM_PACKAGES[@]}"; do
      if npm list -g "$pkg" --depth=0 >/dev/null 2>&1; then
        if [[ ${DRY_RUN} -eq 1 ]]; then
          log_dry_run "Would uninstall global npm package '$pkg'"
        else
          if npm -g uninstall "$pkg"; then
            log_info "Uninstalled global npm package '$pkg'."
          else
            log_warn "Failed to uninstall global npm package '$pkg'."
          fi
        fi
      else
        log_info "Global npm package '$pkg' not found; skipping."
      fi
    done
    
    if [[ -d /usr/local/n ]]; then
      if prompt_confirm "Remove Node versions installed by 'n' under /usr/local/n?"; then
        if [[ ${DRY_RUN} -eq 1 ]]; then
          log_dry_run "Would remove /usr/local/n"
        else
          rm -rf /usr/local/n
          log_success "Directory /usr/local/n removed."
        fi
      else
        log_warn "Removal of /usr/local/n skipped by user."
      fi
    fi
  else
    log_info "npm not available; skipping global package removal."
  fi
  
  if [[ ${DRY_RUN} -eq 0 ]]; then
    hash -r 2>/dev/null || true
  fi
  
  log_success "Global NPM packages processed."
}

remove_snap_packages() {
  log_info "=========================================="
  log_info "Checking for Snap packages (certbot)..."
  log_info "=========================================="
  
  if command_exists snap; then
    if snap list certbot >/dev/null 2>&1; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would remove certbot snap"
      else
        if snap remove certbot; then
          if [[ -L /usr/bin/certbot ]]; then
            rm -f /usr/bin/certbot
            log_info "Removed /usr/bin/certbot symlink."
          fi
          log_success "Certbot snap removed."
        else
          log_warn "Failed to remove certbot snap."
        fi
      fi
    else
      log_info "Certbot snap not found; skipping."
    fi
  else
    log_info "snap command not available; skipping snap cleanup."
  fi
}

remove_ondrej_ppa() {
  log_info "=========================================="
  log_info "Checking for ondrej/php PPA..."
  log_info "=========================================="
  
  if command_exists add-apt-repository; then
    if ls /etc/apt/sources.list.d/ondrej-ubuntu-php*.list >/dev/null 2>&1; then
      if prompt_confirm "Remove ondrej/php PPA from APT sources?"; then
        if [[ ${DRY_RUN} -eq 1 ]]; then
          log_dry_run "Would remove ondrej/php PPA"
        else
          if add-apt-repository --remove ppa:ondrej/php -y; then
            log_success "ondrej/php PPA removed."
          else
            log_warn "Failed to remove ondrej/php PPA."
          fi
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
}

remove_apt_packages() {
  log_info "=========================================="
  log_info "Evaluating APT packages to uninstall..."
  log_info "=========================================="
  
  local BASE_PACKAGES=(
    apache2
    redis-server
    mysql-server
    nodejs
    npm
    language-pack-en-base
    libapache2-mod-php7.4
  )
  
  local PHP_PACKAGES=()
  while IFS= read -r php_pkg; do
    PHP_PACKAGES+=("${php_pkg}")
  done < <(collect_php74_packages || true)
  
  local PACKAGES_TO_UNINSTALL=("${BASE_PACKAGES[@]}" "${PHP_PACKAGES[@]}")
  local COMMON_TOOLS=(nano wget curl git unzip screen)
  
  mapfile -t INSTALLED_PACKAGES < <(filter_installed_packages PACKAGES_TO_UNINSTALL)
  if [[ ${INCLUDE_COMMON_TOOLS} -eq 1 ]]; then
    log_info "Including common tools for removal."
    mapfile -t INSTALLED_COMMON < <(filter_installed_packages COMMON_TOOLS)
    INSTALLED_PACKAGES+=("${INSTALLED_COMMON[@]}")
  fi
  
  if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
    log_warn "The following packages will be purged: ${INSTALLED_PACKAGES[*]}"
    log_warn "This may affect other applications using these packages!"
    
    if prompt_confirm "Proceed with apt-get purge of listed packages?"; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would purge packages: ${INSTALLED_PACKAGES[*]}"
      else
        if ! apt-get purge --auto-remove -y "${INSTALLED_PACKAGES[@]}"; then
          log_warn "apt-get purge encountered issues. Review the output above."
        else
          log_success "Packages purged successfully."
        fi
      fi
    else
      log_warn "APT package purge skipped by user."
    fi
  else
    log_info "No target packages found for removal."
  fi
  
  log_info "Attempting to remove software-properties-common and snapd if installed..."
  local MISC_PACKAGES=(software-properties-common snapd)
  mapfile -t INSTALLED_MISC < <(filter_installed_packages MISC_PACKAGES)
  
  if [[ ${#INSTALLED_MISC[@]} -gt 0 ]]; then
    if prompt_confirm "Proceed with apt-get purge of ${INSTALLED_MISC[*]}?"; then
      if [[ ${DRY_RUN} -eq 1 ]]; then
        log_dry_run "Would purge packages: ${INSTALLED_MISC[*]}"
      else
        if ! apt-get purge --auto-remove -y "${INSTALLED_MISC[@]}"; then
          log_warn "apt-get purge of misc packages encountered issues."
        else
          log_success "Misc packages purged successfully."
        fi
      fi
    else
      log_warn "Purge of misc packages skipped by user."
    fi
  else
    log_info "software-properties-common and snapd not installed or already removed."
  fi
}

cleanup_apt() {
  log_info "=========================================="
  log_info "APT system cleanup..."
  log_info "=========================================="
  
  if prompt_confirm "Run apt-get autoremove/autoclean/clean to tidy up package cache?"; then
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_dry_run "Would run apt-get autoremove"
      log_dry_run "Would run apt-get autoclean"
      log_dry_run "Would run apt-get clean"
    else
      apt-get autoremove -y
      apt-get autoclean -y
      apt-get clean -y
      log_success "APT cleanup complete."
    fi
  else
    log_warn "APT cleanup skipped by user."
  fi
}

remove_mysql_data() {
  log_info "=========================================="
  log_info "MySQL data directory handling..."
  log_info "=========================================="
  
  if [[ ${PURGE_MYSQL_DATA} -eq 1 ]]; then
    if [[ -d /var/lib/mysql ]]; then
      log_warn "WARNING: This will permanently delete ALL MySQL databases!"
      if prompt_confirm "Remove /var/lib/mysql directory? This will delete all MySQL data."; then
        if [[ ${DRY_RUN} -eq 1 ]]; then
          log_dry_run "Would remove /var/lib/mysql"
        else
          rm -rf /var/lib/mysql
          log_success "/var/lib/mysql removed."
        fi
      else
        log_warn "Removal of /var/lib/mysql skipped by user."
      fi
    else
      log_info "/var/lib/mysql not found; skipping."
    fi
  else
    log_info "MySQL data directory preserved. Use --purge-mysql-data to remove it."
  fi
}

# Main orchestration
main() {
  # Initial checks
  require_root
  check_supported_os
  ensure_noninteractive_apt
  init_logging
  
  # Display warning and get confirmation
  log_warn "=========================================="
  log_warn "eBot CS2 UNINSTALLER - DESTRUCTIVE SCRIPT"
  log_warn "=========================================="
  log_warn ""
  log_warn "This script will remove:"
  log_warn "  - eBot services and application files"
  log_warn "  - Apache, PHP, MySQL, Redis, Node.js"
  log_warn "  - phpMyAdmin, Composer, global npm packages"
  log_warn "  - Snap packages (certbot)"
  log_warn "  - Optional: common utilities and MySQL data"
  log_warn ""
  log_warn "OTHER APPLICATIONS using these components WILL BE AFFECTED!"
  log_warn ""
  
  if [[ ${DRY_RUN} -eq 0 && ${FORCE_ALL} -eq 0 ]]; then
    if ! prompt_confirm "Do you want to proceed with the uninstallation?"; then
      log_info "Aborted by user."
      exit 0
    fi
  fi
  
  # Execute uninstallation steps
  stop_ebot_services
  remove_ebot_cronjobs
  remove_ebot_files
  remove_apache_config
  remove_phpmyadmin
  remove_composer
  remove_npm_packages
  remove_snap_packages
  remove_ondrej_ppa
  remove_apt_packages
  cleanup_apt
  remove_mysql_data
  
  # Final summary
  log_success "=========================================="
  log_success "eBot CS2 uninstallation complete!"
  log_success "=========================================="
  
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info ""
    log_info "DRY RUN completed. No changes were made."
    log_info "Run without --dry-run to perform actual uninstallation."
  else
    log_info ""
    log_info "Log file: ${LOG_FILE}"
    log_info "Please review any errors and manually check for leftover files."
    log_info "A reboot is recommended to ensure all services are stopped:"
    log_info "  sudo reboot"
  fi
}

# Run main function
main "$@"
