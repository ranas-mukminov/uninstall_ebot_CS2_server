# Security Policy

## About This Project

The eBot CS2 Uninstaller Script is a **destructive system administration tool** designed to remove software and data from Ubuntu servers. By its very nature, this script performs actions that result in data deletion and service removal.

**This is intentional and expected behavior, not a security vulnerability.**

## Supported Versions

We provide security updates for the latest version of the script.

| Version | Supported          |
| ------- | ------------------ |
| 2.x     | ✅ Yes             |
| < 2.0   | ❌ No              |

## What Constitutes a Security Issue?

Security issues in this project would include:

### Valid Security Concerns ✅

- **Unintended privilege escalation:** The script gaining more privileges than necessary
- **Code injection vulnerabilities:** Ability to execute arbitrary code through script parameters
- **Path traversal issues:** Ability to delete files outside intended scope through manipulation
- **Credential exposure:** Script logging or displaying sensitive information (passwords, keys)
- **Insecure temporary file handling:** Predictable temp file names that could be exploited
- **Supply chain issues:** Compromised dependencies or malicious code in the repository

### NOT Security Issues ❌

- **Data deletion:** The script is designed to delete data - this is its purpose
- **Service disruption:** Removing Apache, MySQL, etc. is expected behavior
- **Destructive behavior:** The script is explicitly a destructive tool
- **Lack of undo:** This is by design; the script is meant for permanent removal
- **Impact on other applications:** This is documented and expected

## Reporting a Security Vulnerability

If you discover a legitimate security vulnerability (see list above), please report it responsibly:

### Private Reporting (Preferred)

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead:

1. **Email:** Send details to `security@run-as-daemon.ru` (placeholder - replace with actual security contact)
   - Include "SECURITY" in the subject line
   - Provide a detailed description of the vulnerability
   - Include steps to reproduce if possible
   - Suggest a fix if you have one

2. **GitHub Security Advisories:** Use [GitHub's private vulnerability reporting](https://github.com/ranas-mukminov/uninstall_ebot_CS2_server/security/advisories/new)

### What to Include

Please provide:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)
- Your name/handle for credit (optional)

### Response Timeline

- **Initial Response:** Within 72 hours (best effort)
- **Status Update:** Within 7 days
- **Fix Target:** Within 30 days for critical issues

**Note:** This is an open-source project maintained in spare time. We will do our best to respond quickly, but cannot guarantee specific timelines.

## Security Best Practices for Users

To use this script securely:

### 1. Verify Script Integrity

Always download the script from the official repository:
```bash
git clone https://github.com/ranas-mukminov/uninstall_ebot_CS2_server.git
```

### 2. Review the Code

This is a destructive script - you should review it before running:
```bash
less uninstall_ebot.sh
```

### 3. Use Dry-Run Mode First

Test what the script will do without making changes:
```bash
sudo ./uninstall_ebot.sh --dry-run
```

### 4. Run as Root Only When Necessary

The script requires root privileges, but you should:
- Review the code first
- Understand what will be deleted
- Have backups in place
- Never run untrusted versions

### 5. Check Logs

The script logs all actions:
```bash
sudo cat /var/log/uninstall_ebot_cs2.log
```

Review logs for unexpected behavior.

### 6. Backup Before Running

**ALWAYS** backup your data before running this script:
- MySQL databases (`mysqldump`)
- Application files (`/home/ebot`)
- Configuration files
- Any other critical data

## Known Security Considerations

### Root Privileges Required

This script requires root access because it:
- Stops and removes systemd services
- Uninstalls system packages with APT
- Removes system directories
- Modifies system configuration

**This is necessary and intentional.** We minimize the risk by:
- Requiring explicit user confirmation for destructive actions
- Providing dry-run mode
- Logging all operations
- Using safe bash practices (`set -o nounset`, `set -o pipefail`)

### Destructive by Design

The script's purpose is to permanently remove software and data. This is **not a bug** but the core functionality. We mitigate risks through:
- Clear documentation and warnings
- Interactive confirmation prompts
- OS version checking
- Idempotent operation (safe to run multiple times)
- Detailed logging

### No Undo Function

Once executed, changes cannot be automatically undone. Users must:
- Have backups before running
- Test with `--dry-run` first
- Understand what will be removed
- Accept the risk of data loss

## Security Updates

Security patches will be released as new versions on GitHub. To stay updated:

1. **Watch this repository** for security announcements
2. **Check for updates** before running the script
3. **Read release notes** for security-related changes

## Disclosure Policy

When security issues are fixed:

1. We will release a patch immediately
2. We will publish a security advisory on GitHub
3. We will credit the reporter (if they wish)
4. We will document the issue in the CHANGELOG

## Contact

- **Security Issues:** `security@run-as-daemon.ru` (placeholder)
- **General Issues:** [GitHub Issues](https://github.com/ranas-mukminov/uninstall_ebot_CS2_server/issues)
- **Professional Support:** [run-as-daemon.ru](https://run-as-daemon.ru)

---

Thank you for helping keep this project secure! 🔒
