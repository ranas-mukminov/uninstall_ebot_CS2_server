#!/bin/bash

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
red='\e[1;31m%s\e[0m\n'
green='\e[1;32m%s\e[0m\n'
yellow='\e[1;33m%s\e[0m\n'

printf "$yellow" "Stopping and disabling eBot services..."

# 1. Stop and disable systemd services
systemctl stop ebot-cs2-app.service ebot-cs2-logs.service
systemctl disable ebot-cs2-app.service ebot-cs2-logs.service
rm -f /etc/systemd/system/ebot-cs2-app.service
rm -f /etc/systemd/system/ebot-cs2-logs.service
systemctl daemon-reload
systemctl reset-failed

printf "$green" "eBot services stopped and disabled."

# 2. Remove Cronjobs
printf "$yellow" "Removing eBot cronjobs..."
# This is safer than crontab -r if other cronjobs exist for the root user
(crontab -l 2>/dev/null | grep -v "/home/ebot/check-ebot-cs2-app.sh" | grep -v "/home/ebot/check-ebot-cs2-logs.sh" || true) | crontab -
printf "$green" "eBot cronjobs removed (if they existed)."

# 3. Remove eBot files and directories
printf "$yellow" "Removing eBot application files..."
rm -rf /home/ebot
printf "$green" "eBot application files removed."

# 4. Remove Apache configuration for eBot
printf "$yellow" "Removing Apache configuration for eBot..."
a2dissite ebotcs2.conf &>/dev/null
rm -f /etc/apache2/sites-available/ebotcs2.conf
# Consider disabling rewrite if nothing else uses it, but it's often shared
# a2dismod rewrite
systemctl restart apache2
printf "$green" "Apache configuration for eBot removed."

# 5. Uninstall phpMyAdmin (manual installation)
printf "$yellow" "Removing phpMyAdmin..."
rm -rf /usr/share/phpmyadmin
printf "$green" "phpMyAdmin removed."

# 6. Uninstall Composer (manual installation)
printf "$yellow" "Removing Composer..."
rm -f /usr/bin/composer
printf "$green" "Composer removed."

# 7. Uninstall global NPM packages installed by the script
# Note: n might have installed node versions in /usr/local/n or similar.
# Removing 'n' itself here. You might need to manually remove /usr/local/n/*
printf "$yellow" "Uninstalling global NPM packages (n, yarn, socket.io, etc.)..."
npm -g uninstall socket.io archiver formidable ts-node n yarn || printf "$yellow" "Some global npm packages might not have been installed or already removed.\n"
# If 'n' was used, its managed Node versions might be in /usr/local/n
if [ -d "/usr/local/n" ]; then
    printf "$yellow" "Removing Node versions installed by 'n' in /usr/local/n..."
    rm -rf /usr/local/n
    printf "$green" "Directory /usr/local/n removed."
fi
hash -r # Clear cached paths for commands

printf "$green" "Global NPM packages uninstalled."

# 8. Uninstall Snap packages
printf "$yellow" "Uninstalling Snap packages (certbot)..."
if snap list certbot &>/dev/null; then
    snap remove certbot
    rm -f /usr/bin/certbot # remove symlink
else
    printf "$yellow" "Certbot snap not found.\n"
fi
# The script also installs snap core and refreshes it. Removing 'core' can be problematic
# if other snaps depend on it. Usually, you wouldn't remove 'core' unless uninstalling snapd itself.
# For a full cleanup specific to what the script *touched*:
# if snap list core &>/dev/null; then
#   snap remove core
# else
#   printf "$yellow" "Core snap not found.\n"
# fi
printf "$green" "Snap packages uninstalled."

# 9. Remove PPA
printf "$yellow" "Removing ondrej/php PPA..."
add-apt-repository --remove ppa:ondrej/php -y
printf "$green" "ondrej/php PPA removed."

# 10. Uninstall APT packages
# List all packages installed by the script
# Be careful, some of these might be system dependencies if not installed solely for eBot
printf "$yellow" "Uninstalling APT packages..."
PACKAGES_TO_UNINSTALL=(
    libapache2-mod-php7.4 apache2 redis-server mysql-server
    php7.4-fpm php7.4-redis php7.4-cgi php7.4-cli php7.4-dev php7.4-phpdbg
    php7.4-bcmath php7.4-bz2 php7.4-common php7.4-curl php7.4-dba php7.4-enchant
    php7.4-gd php7.4-gmp php7.4-imap php7.4-interbase php7.4-intl php7.4-ldap
    php7.4-mbstring php7.4-mysql php7.4-odbc php7.4-pgsql php7.4-pspell
    php7.4-readline php7.4-snmp php7.4-soap php7.4-sqlite3 php7.4-sybase
    php7.4-tidy php7.4-xml php7.4-xmlrpc php7.4-zip php7.4-opcache php7.4 php7.4-xsl
    nodejs npm
    language-pack-en-base # Generally safe to keep, but script installed it
    # software-properties-common # Was needed for add-apt-repository, keep it for --remove, remove last
    nano wget curl git unzip snapd screen # These are common tools, uninstall if you are sure
)

# Add common tools separately if you really want to uninstall them
COMMON_TOOLS=(
    nano wget curl git unzip screen
)

# Uninstall specific PHP 7.4 packages and related server software
apt-get purge --auto-remove -y "${PACKAGES_TO_UNINSTALL[@]}"

# Uninstall common tools if desired (uncomment next lines)
# printf "$yellow" "Uninstalling common tools (nano, wget, etc.)..."
# apt-get purge --auto-remove -y "${COMMON_TOOLS[@]}"

# Finally, try to remove software-properties-common and snapd
printf "$yellow" "Uninstalling software-properties-common and snapd..."
apt-get purge --auto-remove -y software-properties-common snapd

# Clean up apt cache
apt-get autoremove -y
apt-get autoclean -y
apt-get clean -y

printf "$green" "APT packages uninstalled and system cleaned."

# 11. Remove MySQL data directory (VERY DESTRUCTIVE - DATA LOSS)
# apt purge mysql-server should handle this for default installations.
# If it doesn't, and you are sure, you can uncomment the following:
# printf "$red" "WARNING: The next step will remove MySQL data from /var/lib/mysql."
# read -p "Do you want to proceed with removing /var/lib/mysql? (yes/NO): " confirm_mysql_data
# if [[ "$confirm_mysql_data" == "yes" ]]; then
#     rm -rf /var/lib/mysql
#     printf "$green" "/var/lib/mysql removed."
# else
#     printf "$yellow" "Skipped removal of /var/lib/mysql."
# fi

# 12. Revert timezone (optional - set to UTC or your preferred default)
# The script sets it to Europe/Zagreb
# timedatectl set-timezone UTC
# printf "$yellow" "Timezone reverted to UTC (optional step)."


printf "$green" "eBot CS2 uninstallation attempt complete."
printf "$yellow" "Please review any errors and manually check for leftover files or configurations."
printf "$yellow" "A reboot might be advisable to ensure all services are fully stopped/unloaded."
