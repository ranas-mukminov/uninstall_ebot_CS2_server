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

* **Stop and Disable eBot Services:** `ebot-cs2-app` and `ebot-cs2-logs`, with safety checks to avoid touching already-removed units.
* **Remove eBot Systemd Service Files.**
* **Remove eBot Cronjobs** (specifically those created by the installer for monitoring eBot services).
* **Delete or Preserve eBot Application Files:** `/home/ebot` is deleted only after confirmation or when `--force` is used; the `--preserve-home` flag keeps the directory intact.
* **Remove eBot Apache Configuration:** The `ebotcs2.conf` site configuration and related symlinks. Apache is restarted only if it is currently active.
* **Uninstall phpMyAdmin** and **Composer** if you confirm their removal.
* **Uninstall Global NPM Packages:** `socket.io`, `archiver`, `formidable`, `ts-node`, `n`, `yarn` are evaluated individually so missing packages do not stop the process.
* **Remove Node.js versions installed by `n`:** `/usr/local/n` is deleted only after confirmation.
* **Uninstall Snap Packages:** `certbot` (and its symlink `/usr/bin/certbot` when it is a symlink).
* **Remove PPA:** `ppa:ondrej/php`, with an explicit confirmation prompt.
* **Purge APT Packages:**
  * Server Software: Apache (`apache2`), MySQL Server (`mysql-server`), Redis Server (`redis-server`).
  * PHP: PHP 7.4 core and extensions detected dynamically (`php7.4*`).
  * Node.js/NPM: `nodejs`, `npm` (installed via apt).
  * Optional Common Utilities: `language-pack-en-base`, `nano`, `wget`, `curl`, `git`, `unzip`, `screen` (only when `--include-common-tools` is provided).
* **MySQL Data:** With `--purge-mysql-data`, `/var/lib/mysql` is deleted after an additional confirmation. Without the flag, data is preserved.
* **APT System Cleanup:** `apt-get autoremove`, `apt-get autoclean`, and `apt-get clean` run only if you confirm.

## Command-Line Options

| Option | Description |
| --- | --- |
| `--force` | Automatically answers “yes” to all confirmations (dangerous; read the prompts before using). |
| `--include-common-tools` | Adds common utilities (nano, wget, curl, git, unzip, screen) to the purge list when they are installed. |
| `--preserve-home` | Keeps `/home/ebot` even when the script is otherwise instructed to delete it. |
| `--purge-mysql-data` | Offers to remove `/var/lib/mysql` after packages are purged. |
| `-h`, `--help` | Shows usage information. |

### Confirmation Prompts

* Prompts default to **No**. Respond with `y`, `Y`, `yes`, or `YES` to proceed.
* Using `--force` skips prompts while logging that confirmations were auto-accepted.

## How to Use (English)

1. **Back Up Your Data.** Make comprehensive backups of MySQL databases, website files, and any other critical data.
2. **Obtain the Script.** Place `uninstall_ebot.sh` on the same server where the eBot CS2 installer was executed.
3. **Make the Script Executable.**
   ```bash
   chmod +x uninstall_ebot.sh
   ```
4. **Review Available Flags.** Decide whether you need `--include-common-tools`, `--preserve-home`, or `--purge-mysql-data`. Avoid `--force` until you understand every destructive action.
5. **Run with Root Privileges.**
   ```bash
   sudo ./uninstall_ebot.sh [options]
   ```
6. **Respond to Prompts.** Each destructive step requires confirmation unless `--force` is supplied. Watch the output for warnings or failures.
7. **Audit Results.** After completion, review the log output and manually verify that unwanted components are gone.

## Как использовать (Russian)

1. **Сделайте резервные копии.** Сохраните базы данных MySQL, файлы сайтов и другие важные данные.
2. **Получите скрипт.** Поместите `uninstall_ebot.sh` на тот же сервер, где запускался установщик eBot CS2.
3. **Сделайте файл исполняемым.**
   ```bash
   chmod +x uninstall_ebot.sh
   ```
4. **Оцените флаги.** При необходимости используйте `--include-common-tools`, `--preserve-home` или `--purge-mysql-data`. Не применяйте `--force`, пока не ознакомитесь со всеми разрушительными действиями.
5. **Запустите от имени root.**
   ```bash
   sudo ./uninstall_ebot.sh [опции]
   ```
6. **Отвечайте на запросы.** Каждый опасный шаг требует подтверждения, если не указан `--force`. Следите за предупреждениями и ошибками в выводе.
7. **Проверьте результат.** После завершения изучите журнал и убедитесь, что ненужные компоненты удалены.

## Important Considerations & Warnings

* **IRREVERSIBLE DATA LOSS:** Removing MySQL packages or opting in to `--purge-mysql-data` can permanently delete databases. Confirm only if you have reliable backups.
* **IMPACT ON SHARED COMPONENTS:** If other applications depend on Apache, PHP, MySQL, Redis, Node.js, or the optional utilities, those applications will stop working.
* **SYSTEM STABILITY:** Removing `snapd`, language packs, or other utilities might affect services outside of eBot. Review installed packages before agreeing to purge them.
* **PARTIAL UNINSTALLATION:** Errors or interruptions can leave components behind. The script logs skipped items so you can address them manually.
* **PROMPT BEHAVIOR:** Every confirmation defaults to “No.” Use `--force` only for unattended runs when you fully understand the consequences.

## After Running the Script

* A reboot is recommended to ensure all uninstalled services are stopped and the system is refreshed:
  ```bash
  sudo reboot
  ```
* After rebooting, manually verify that the components listed above have been removed.
* Check system logs for any unusual errors that might have arisen from the removal of packages.

## Организация игровых мероприятий / Event Support

If you plan to run tournaments or other gaming events, consider contacting [run-as-daemon.ru](https://run-as-daemon.ru/) for professional assistance. The site lists current services and provides contact forms; please review their offerings and coordinate with their specialists directly.

> **Note:** Direct access to https://run-as-daemon.ru/ from this sandboxed environment returns HTTP 403, so the README links to the official site for up-to-date information.

---
