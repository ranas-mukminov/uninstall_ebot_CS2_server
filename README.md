# eBot CS2 Uninstaller Script

**A complete uninstaller for eBot CS2 servers installed via the [Flegma ebot-cs2-install-script](https://github.com/Flegma/ebot-cs2-install-script).**

---

## 🛑 EXTREME CAUTION

**THIS SCRIPT IS HIGHLY DESTRUCTIVE AND WILL PERMANENTLY REMOVE SOFTWARE, CONFIGURATIONS, AND DATA FROM YOUR SYSTEM.**

**⚠️ IRREVERSIBLE DATA LOSS WARNING:**
- **MySQL databases** will be uninstalled and can be completely wiped with `--purge-mysql-data`
- **All eBot application files** at `/home/ebot` will be deleted (unless `--preserve-home` is used)
- **Apache, PHP, MySQL, Redis, Node.js** and related packages will be purged
- **Other applications** using these shared components **WILL STOP WORKING**

**USE THIS SCRIPT AT YOUR OWN RISK. THE AUTHORS ARE NOT RESPONSIBLE FOR ANY DATA LOSS, SYSTEM DAMAGE, OR SERVICE INTERRUPTION.**

**🔒 MANDATORY: BACK UP YOUR DATA BEFORE RUNNING THIS SCRIPT.**

---

## Purpose

This script is designed to **completely reverse** the installation performed by the [ebot-cs2-install-script](https://github.com/Flegma/ebot-cs2-install-script) on Ubuntu 20.04/22.04 servers.

**Primary use cases:**
- Decommissioning a dedicated eBot CS2 server
- Completely repurposing a server that was used exclusively for eBot
- Testing and development environments where clean removal is needed

**This script is NOT recommended for:**
- Shared hosting environments
- Servers running multiple applications
- Production servers with other critical services

The uninstaller includes safety features like dry-run mode, interactive confirmations, OS detection, and detailed logging to help prevent accidental damage.

---

## What Will Be Removed/Affected

### eBot Services and Files
- **Systemd services:** `ebot-cs2-app.service`, `ebot-cs2-logs.service` (stopped, disabled, and removed)
- **Service files:** `/etc/systemd/system/ebot-cs2-*.service`
- **Application directory:** `/home/ebot` (requires confirmation; skip with `--preserve-home`)
- **Cronjobs:** eBot monitoring scripts (`check-ebot-cs2-app.sh`, `check-ebot-cs2-logs.sh`)
- **Apache configuration:** `ebotcs2.conf` (site definition and symlinks)

### Web Stack
- **Apache:** `apache2` package (affects ALL hosted websites)
- **PHP 7.4:** Core package and all extensions (`php7.4*`)
- **phpMyAdmin:** `/usr/share/phpmyadmin` directory (requires confirmation)
- **Composer:** `/usr/bin/composer` binary (requires confirmation)
- **mod_php:** `libapache2-mod-php7.4`

### Databases
- **MySQL Server:** `mysql-server` package (requires confirmation before purge)
- **MySQL data:** `/var/lib/mysql` (only with `--purge-mysql-data` flag + additional confirmation)
- **Redis:** `redis-server` package

### Node.js and npm
- **Packages:** `nodejs`, `npm` (APT versions)
- **Global npm packages:** `socket.io`, `archiver`, `formidable`, `ts-node`, `n`, `yarn`
- **Node versions:** `/usr/local/n` directory (if using the `n` version manager)

### Snap Packages
- **certbot:** Snap package and `/usr/bin/certbot` symlink

### APT Repositories and Cleanup
- **PPA:** `ppa:ondrej/php` (requires confirmation)
- **Misc packages:** `software-properties-common`, `snapd` (requires confirmation)
- **APT cache:** `autoremove`, `autoclean`, `clean` (requires confirmation)

### Optional: Common Utilities
**(Only with `--include-common-tools` flag)**
- `nano`, `wget`, `curl`, `git`, `unzip`, `screen`

⚠️ **Impact Warning:** Removing these utilities may break system administration workflows and other applications.

---

## Prerequisites

Before running this script:

1. **Root privileges:** You must run the script as root or with `sudo`
2. **Correct server:** This script must be run on the same server where `ebot-cs2-install-script` was executed
3. **Supported OS:** Ubuntu 20.04 or Ubuntu 22.04 (script will check and warn for other versions)
4. **Full backups:** Create comprehensive backups of:
   - All MySQL databases (`mysqldump` or similar)
   - Website files and configurations
   - `/home/ebot` directory
   - Any other critical data

---

## How to Use

### 1. Download and Prepare the Script

```bash
# Download the script (if not already present)
# Place it on your server

# Make it executable
chmod +x uninstall_ebot.sh
```

### 2. Preview Changes (Dry Run - Recommended First Step)

**Always run in dry-run mode first** to see what would be removed:

```bash
sudo ./uninstall_ebot.sh --dry-run
```

Or using environment variable:

```bash
sudo DRY_RUN=1 ./uninstall_ebot.sh
```

This shows all actions without making any changes to your system.

### 3. Interactive Uninstallation (Safest Method)

Run without flags for interactive mode with confirmation prompts:

```bash
sudo ./uninstall_ebot.sh
```

The script will:
- Check your OS version
- Display warnings
- Prompt for confirmation at each destructive step
- Log all actions to `/var/log/uninstall_ebot_cs2.log`

### 4. Automated Uninstallation (Advanced)

For automated/unattended runs (use with extreme caution):

```bash
# Full automated uninstall (DANGEROUS)
sudo ./uninstall_ebot.sh --force-all

# Full uninstall including MySQL data (EXTREMELY DANGEROUS)
sudo ./uninstall_ebot.sh --force-all --purge-mysql-data

# Preserve /home/ebot but remove everything else
sudo ./uninstall_ebot.sh --force-all --preserve-home
```

### Available Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview all actions without making changes |
| `--force-all` | Skip ALL confirmation prompts (DANGEROUS) |
| `--force` | Alias for `--force-all` |
| `--include-common-tools` | Also remove common utilities (nano, wget, curl, git, unzip, screen) |
| `--preserve-home` | Keep `/home/ebot` directory intact |
| `--purge-mysql-data` | Remove `/var/lib/mysql` after package removal (requires additional confirmation) |
| `-h`, `--help` | Display help message |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `DRY_RUN=1` | Enable dry-run mode (alternative to `--dry-run` flag) |

---

## Important Considerations & Warnings

### Data Loss
- **MySQL removal:** Uninstalling `mysql-server` stops all databases. With `--purge-mysql-data`, all data in `/var/lib/mysql` is permanently deleted.
- **No recovery:** Deleted files and databases cannot be recovered without backups.
- **Test your backups:** Verify that your backups are complete and can be restored before running this script.

### Impact on Other Applications
- **Shared components:** If other applications use Apache, PHP, MySQL, Redis, or Node.js, they **will break** when these packages are removed.
- **Web hosting:** Any websites hosted on Apache will become unavailable.
- **System tools:** Removing common utilities (`--include-common-tools`) may affect system administration.

### System Stability
- **Service dependencies:** Removing `snapd`, system language packs, or core utilities may affect unrelated services.
- **Partial removal:** Script interruptions (Ctrl+C, network issues) can leave the system in an inconsistent state.
- **Review carefully:** Always review the list of packages before confirming removal.

### Logs and Debugging
- **Log file:** All actions are logged to `/var/log/uninstall_ebot_cs2.log` (or `/tmp/uninstall_ebot_cs2.log` if `/var/log` is not writable)
- **Error handling:** The script continues on non-fatal errors but logs them for your review
- **Idempotent:** Safe to run multiple times; already-removed components are skipped

---

## After Running the Script

### 1. Reboot the System

A reboot is strongly recommended to ensure all services are fully stopped:

```bash
sudo reboot
```

### 2. Verify Removal

After reboot, check that components were removed:

```bash
# Check for eBot services
systemctl status ebot-cs2-app
systemctl status ebot-cs2-logs

# Check for removed packages
dpkg -l | grep -E 'apache2|mysql-server|php7.4|redis-server|nodejs'

# Check for remaining files
ls -la /home/ebot
ls -la /etc/apache2/sites-available/ebotcs2.conf
```

### 3. Review Logs

Check the log file for any errors or warnings:

```bash
sudo less /var/log/uninstall_ebot_cs2.log
```

### 4. Manual Cleanup (if needed)

If the script encountered errors, you may need to manually:
- Remove leftover files
- Clean up package remnants
- Fix broken package dependencies

---

## Professional SRE/DevOps Services

This script and repository are maintained by **run-as-daemon** - a professional SRE/DevOps engineering service.

🌐 **Website:** [https://run-as-daemon.ru](https://run-as-daemon.ru)

### Services Offered

We provide expert-level support for game server infrastructure, including:

- **CS2 / eBot Server Setup**
  - Professional installation and hardening of Counter-Strike 2 servers
  - eBot match management system deployment and configuration
  - Multi-server setups with centralized management

- **Infrastructure Monitoring**
  - Prometheus + Grafana dashboards
  - Zabbix monitoring with custom triggers
  - Alerting and on-call support

- **Backup & Disaster Recovery**
  - Automated backup strategies for game servers and databases
  - Point-in-time recovery solutions
  - Disaster recovery planning and testing

- **Server Migration**
  - Zero-downtime migrations to new servers
  - Cloud provider transitions (AWS, GCP, Azure, dedicated hosting)
  - Performance optimization and scaling strategies

- **Custom Automation**
  - Infrastructure as Code (Terraform, Ansible)
  - CI/CD pipelines for game server deployments
  - Custom scripts and tools for your specific needs

**Need help?** Visit [run-as-daemon.ru](https://run-as-daemon.ru) for contact information and service details.

---

## Support / Thanks

### Found This Useful?

If this script saved you time or helped clean up your server, consider:

- ⭐ **Star this repository** to show your appreciation
- 🔄 **Share with friends** and colleagues who might need it
- 💖 **Sponsor via GitHub** or donate using the links below

Your support helps maintain this project and create more useful tools for the community!

### Reporting Issues

- **Bug reports:** Open an issue on [GitHub Issues](https://github.com/ranas-mukminov/uninstall_ebot_CS2_server/issues)
- **Feature requests:** Same place - we welcome your suggestions
- **Questions:** Check existing issues first, then open a new one

### Priority Support

Need guaranteed response times or custom modifications?

📧 **Paid support available:** Contact us via [run-as-daemon.ru](https://run-as-daemon.ru)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Disclaimer

This script is provided "as is" without warranty of any kind. The authors and contributors are not responsible for any damage, data loss, or other issues that may result from using this script. Always test in a non-production environment first and maintain comprehensive backups.

**This is a destructive tool by design.** Use it only when you fully understand the consequences.
