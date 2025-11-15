# uninstall_ebot_CS2_server
https://github.com/Flegma/ebot-cs2-install-script - installation script
# eBot CS2 Uninstaller Script

**🛑 EXTREME CAUTION: THIS SCRIPT IS DESTRUCTIVE AND WILL REMOVE SOFTWARE, CONFIGURATIONS, AND DATA FROM YOUR SYSTEM. 🛑**

**USE THIS SCRIPT AT YOUR OWN RISK. THE AUTHORS ARE NOT RESPONSIBLE FOR ANY DATA LOSS OR SYSTEM DAMAGE.**

**IT IS STRONGLY RECOMMENDED TO BACK UP ANY IMPORTANT DATA *BEFORE* RUNNING THIS SCRIPT.**

This script is designed to reverse the installation performed by the `ebot_cs2_installer.sh` script (or similarly named installer script for eBot CS2 by Flegma).

## Purpose

This script attempts to uninstall eBot CS2 and all associated components and configurations that were set up by the original installer. Its goal is to return the system to a state closer to how it was before the eBot installation, focusing on the specific packages and files managed by that installer.

## What Will Be Removed/Affected

This script will attempt to:

* **Stop and Disable eBot Services:** `ebot-cs2-app` and `ebot-cs2-logs`.
* **Remove eBot Systemd Service Files.**
* **Remove eBot Cronjobs** (specifically those created by the installer for monitoring eBot services).
* **Delete eBot Application Files:** Typically located in `/home/ebot`.
* **Remove eBot Apache Configuration:** The `ebotcs2.conf` site configuration and related symlinks.
* **Uninstall phpMyAdmin:** (The manually installed version from `/usr/share/phpmyadmin`).
* **Uninstall Composer:** (The manually installed version from `/usr/bin/composer`).
* **Uninstall Global NPM Packages:** `socket.io`, `archiver`, `formidable`, `ts-node`, `n`, `yarn`.
* **Remove Node.js versions installed by `n`:** Typically from `/usr/local/n`.
* **Uninstall Snap Packages:** `certbot` (and its symlink `/usr/bin/certbot`).
* **Remove PPA:** `ppa:ondrej/php`.
* **Purge APT Packages:**
    * Server Software: Apache (`apache2`), MySQL Server (`mysql-server`), Redis Server (`redis-server`).
    * PHP: PHP 7.4 and all its extensions installed by the original script (e.g., `php7.4-fpm`, `php7.4-mysql`, `php7.4-curl`, etc.).
    * Node.js/NPM: `nodejs`, `npm` (installed via apt).
    * Common Utilities: `language-pack-en-base`, `software-properties-common`, `nano`, `wget`, `curl`, `git`, `unzip`, `snapd`, `screen` if they were installed by the script and are no longer needed by other applications. *Note: Some of these are common system tools; their removal might affect other system functionalities if they were not exclusively for eBot.*
* **MySQL Data:** The command `apt-get purge mysql-server` often removes the MySQL data directory (e.g., `/var/lib/mysql`). **This means your eBot database AND ANY OTHER MySQL DATABASES on the server WILL LIKELY BE DELETED.**
* **APT System Cleanup:** The script will run `apt-get autoremove`, `apt-get autoclean`, and `apt-get clean`.

## Prerequisites

* You must have the `uninstall_ebot.sh` script file (or the uninstaller script you are documenting).
* You need **root privileges** (`sudo`) to run the script.
* This script should be run on the same server where the original eBot CS2 installation script was executed.

## How to Use

1.  **Backup Your Data:** Before proceeding, ensure you have complete backups of any data you cannot afford to lose from this server. This includes MySQL databases, website files, and any other critical information.
2.  **Download/Locate the Script:** Make sure the uninstaller script (e.g., `uninstall_ebot.sh`) is present on your server.
3.  **Make the Script Executable:**
    ```bash
    chmod +x uninstall_ebot.sh
    ```
4.  **Run the Script with `sudo`:**
    ```bash
    sudo ./uninstall_ebot.sh
    ```
5.  The script is designed to be largely non-interactive once started. Monitor its output for any errors or important messages.
6.  Once the script finishes, review the output carefully.

## Important Considerations & Warnings

* **IRREVERSIBLE DATA LOSS:** This script is designed to remove data, especially MySQL databases. This action is irreversible without a prior backup.
* **IMPACT ON SHARED COMPONENTS:** If other applications on your server depend on components being removed (e.g., Apache, PHP, MySQL, Node.js, Redis, or common utilities), those applications **will stop working**. This uninstaller is most safely used on a server that was dedicated to the eBot installation or that you intend to completely repurpose.
* **SYSTEM STABILITY:** While the script targets components installed by the eBot installer, removing core packages like `snapd` or essential utilities can have wider implications if other parts of your system rely on them unexpectedly.
* **PARTIAL UNINSTALLATION:** If the script is interrupted or encounters critical errors, the uninstallation process might be incomplete. You may need to manually identify and remove leftover components.
* **NO GUARANTEES:** This script attempts a thorough uninstallation based on the actions of the original installer. However, it does not guarantee to restore your system to an exact pre-installation state, especially if other system changes were made manually outside of the installer.

## After Running the Script

* It is highly recommended to **reboot the server** to ensure all uninstalled services are fully stopped and the system state is refreshed:
    ```bash
    sudo reboot
    ```
* After rebooting, manually verify that the components listed above have been removed.
* Check system logs for any unusual errors that might have arisen from the removal of packages.

## Организация игровых мероприятий

Если вы планируете проводить турниры или другие игровые события, вы можете обратиться в команду [run-as-daemon.ru](https://run-as-daemon.ru/) за профессиональной поддержкой. На сайте перечислены актуальные услуги и доступны формы для связи, поэтому рекомендуем изучить предложения и обсудить конкретные потребности проекта напрямую с их специалистами.

---
