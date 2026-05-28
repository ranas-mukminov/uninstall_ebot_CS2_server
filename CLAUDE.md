# CLAUDE.md

Guidance for AI assistants (and humans) working in this repository.

## What this repository is

A **single-purpose Bash uninstaller** that completely reverses an eBot CS2 server
installation produced by the [Flegma ebot-cs2-install-script](https://github.com/Flegma/ebot-cs2-install-script)
on Ubuntu 20.04 / 22.04.

This is **not** an application codebase. There is no build, no package manager, no
dependency tree, and no test framework. The entire product is one shell script
plus documentation and GitHub repo metadata.

### Layout

```
uninstall_ebot.sh           # The entire program (~750 lines of Bash)
README.md                   # User-facing docs (usage, warnings, options)
SECURITY.md                 # Security policy
SUPPORT.md                  # Support / contact info
LICENSE                     # MIT
.github/
  FUNDING.yml
  ISSUE_TEMPLATE/
    bug_report.yml
    feature_request.yml
```

## The script: how it is organized

`uninstall_ebot.sh` is structured top-to-bottom in clear sections. When editing,
preserve this ordering and section-comment style (`# ... functions`):

1. **Header / config** — `set -o nounset`, `set -o pipefail`, `SCRIPT_VERSION`,
   `LOG_FILE`.
2. **`usage()`** — the `--help` text. Keep it in sync with the option parser and
   the README options table whenever flags change.
3. **Argument parsing** — a `while`/`case` loop setting global flags.
4. **Global flags** — `DRY_RUN`, `FORCE_ALL`, `INCLUDE_COMMON_TOOLS`,
   `PRESERVE_HOME`, `PURGE_MYSQL_DATA`.
5. **Logging helpers** — `init_logging`, `log_info/success/warn/error/dry_run`,
   `log_to_file`.
6. **Confirmation / execution helpers** — `prompt_confirm`, `execute_cmd`.
7. **Validation helpers** — `require_root`, `check_supported_os`,
   `command_exists`, `service_exists`, `filter_installed_packages`,
   `collect_php74_packages`, `ensure_noninteractive_apt`.
8. **Removal step functions** — one function per concern:
   `stop_ebot_services`, `remove_ebot_cronjobs`, `remove_ebot_files`,
   `remove_apache_config`, `remove_phpmyadmin`, `remove_composer`,
   `remove_npm_packages`, `remove_snap_packages`, `remove_ondrej_ppa`,
   `remove_apt_packages`, `cleanup_apt`, `remove_mysql_data`.
9. **`main()`** — runs checks, prints the destructive-action warning, asks for the
   top-level confirmation, then calls the removal steps in order.
10. **`main "$@"`** — entry point.

## Conventions to follow

These patterns are consistent throughout the script. New code must match them.

- **This is a destructive tool.** Every change must respect the safety rails
  below. When in doubt, fail safe (skip, warn, ask) rather than delete.
- **Every destructive action gates on `DRY_RUN` first.** The pattern is:
  ```bash
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_dry_run "Would <do the thing>"
  else
    <do the thing>
  fi
  ```
  Never perform a filesystem/package/service mutation without a dry-run branch.
- **Destructive steps prompt for confirmation** via `prompt_confirm "..."`.
  `prompt_confirm` already honors `DRY_RUN` (returns 0, logs intent) and
  `FORCE_ALL` (auto-confirms). Do not re-implement that logic at call sites.
- **Check before acting.** Guard every step with existence checks
  (`command_exists`, `service_exists`, `dpkg -s`, `[[ -d ... ]]`, `[[ -f ... ]]`).
  Missing components must `log_info "... skipping."` and continue, never error.
- **Idempotent.** Running the script twice must be safe. Already-removed things
  are detected and skipped.
- **Tolerant of failure.** Non-fatal command failures use `|| true` or
  `log_warn`, and the script keeps going. Only the initial validation
  (`require_root`, unsupported OS without confirmation) exits early.
- **All user-visible output goes through the `log_*` helpers**, never bare
  `echo`/`printf` (except `usage()` and the `Unknown option` error). The helpers
  colorize output and tee to the log file.
- **Logging:** real runs `tee` everything to `/var/log/uninstall_ebot_cs2.log`
  (falls back to `/tmp/...` if `/var/log` isn't writable). Dry runs do not write
  the log file.
- **Section banners:** each step prints a `====` banner via `log_info` at entry.
- **Bash style:** `[[ ... ]]` tests, `${var}` braces, `local` for function
  variables, arrays for package lists, `mapfile`/process substitution for
  collecting filtered package lists. `filter_installed_packages` uses a
  `local -n` nameref to its array argument.

## Adding or changing a removal step

1. Write a `remove_*` / step function following the section-banner +
   existence-check + dry-run + confirm pattern above.
2. Wire it into `main()` in the correct order (services → cron → files → web →
   db → cleanup). Order matters: stop services before deleting their files;
   purge packages before optionally wiping their data directories.
3. If it introduces a flag, update **all four** places: the option parser, the
   global flags block, `usage()`, and the README options table.
4. Update the "What Will Be Removed/Affected" section of `README.md`.

## Verifying changes

There is no test suite. Validate manually:

```bash
bash -n uninstall_ebot.sh                 # syntax check (do this for every edit)
shellcheck uninstall_ebot.sh              # lint, if shellcheck is available
./uninstall_ebot.sh --dry-run             # full dry run — makes no changes
./uninstall_ebot.sh --help                # confirm usage text renders
```

`--dry-run` is the primary safe way to exercise logic. It runs without root and
without mutating anything. **Never run the script for real (without `--dry-run`)
in this environment or any machine you don't intend to wipe** — it purges
Apache, MySQL, PHP, Redis, Node.js and can delete `/var/lib/mysql` and
`/home/ebot`.

## Runtime flags (reference)

| Flag | Effect |
|------|--------|
| `--dry-run` (or `DRY_RUN=1`) | Preview only; no changes |
| `--force-all` / `--force` | Skip all confirmation prompts (dangerous) |
| `--include-common-tools` | Also remove nano/wget/curl/git/unzip/screen |
| `--preserve-home` | Keep `/home/ebot` |
| `--purge-mysql-data` | Also delete `/var/lib/mysql` (extra confirm) |
| `-h`, `--help` | Show usage |

## Git / workflow

- Branch naming follows `claude/...`, `codex/...`, `copilot/...` per the
  contributor/tool. Develop on a feature branch, never commit directly to `main`.
- Keep commits focused with descriptive messages.
- Do not open a pull request unless explicitly asked.
- Use the GitHub MCP tools (`mcp__github__*`) for any GitHub interaction; the
  `gh` CLI is not available in this environment.
- This repo is restricted to `ranas-mukminov/uninstall_ebot_cs2_server`.
