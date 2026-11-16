# Development Notes

## Day 1

- Initialized Git repository.
- Added `auditor.sh` skeleton with shebang and `main()` placeholder.
- Set executable permission on script.

### Lessons Learned

- Importance of starting with a minimal, working skeleton.

## Day 2

- Added `get_uptime()` function using `uptime -p` command.
- Added `get_load_average()` function parsing `/proc/loadavg`.
- Created `display_system_info()` to format the output.
- Tested script successfully.

### Lessons Learned

- `/proc/loadavg` contains three load average values (1, 5, 15 minutes).
- `uptime -p` gives a human-readable uptime format.
- Breaking code into functions makes it more maintainable.

## Day 3

- Added `get_cpu_usage()` function.
- Used `top -bn1` to get CPU idle percentage; computed usage as 100 - idle.
- Tested script successfully.

### Lessons Learned

- `top -bn1` runs `top` once in batch mode (non-interactive).
- The CPU line format may vary by distribution; always test.
- Integer arithmetic in bash: `${idle%.*}` removes decimal part.

## Day 4

- Added functions to get total, used memory, and usage percentage.
- Used `free -m` for memory info in MB.
- Added functions for disk total, used, free, and usage percentage.
- Used `df -h /` to get root partition info.

### Lessons Learned

- `free -m` shows memory in MB; `-h` would be human-readable but harder to parse.
- `/^Mem:/` in awk matches the line starting with "Mem:".
- `df -h /` shows human-readable disk usage for root partition.
- `NR==2` in awk selects the second line (first is header).
- `sed 's/%//'` removes the percent sign for numeric comparison.

## Day 5

- Added `get_open_ports()` function using `ss -tuln`.
- Sorted unique entries for cleaner output.
- Added `get_failed_logins()` function.
- Checked for auth log location (/var/log/auth.log or /var/log/secure).
- Used `grep "Failed password"` and `wc -l` to count attempts.

### Lessons Learned

- `ss -tuln` shows TCP/UDP listening ports without name resolution.
- `sort -u` removes duplicate lines.
- Different distros store auth logs in different locations.
- `wc -l` counts lines from grep output.

## Day 6

- Added built-in CPU, memory and disk warning and critical thresholds.
- Added `get_status()` with inclusive WARN and CRIT boundaries.
- Display functions store each measured value once and show `[OK]`, `[WARN]`, `[CRIT]`, or `[N/A]`.

### Lessons Learned

- Strip a trailing percent sign before numeric threshold comparisons.
- Treat unavailable or empty values as `N/A` instead of assigning a misleading status.

## Day 7

- Added overall status aggregation and exit codes: 0 for OK, 1 for WARN, and 2 for CRIT.
- CRIT takes precedence over WARN, and display functions update the parent shell directly.
- Added an overall status summary to the end of each report.

### Lessons Learned

- Avoid short-circuit arithmetic assignments when `set -e` may be enabled; use an explicit `if` statement.
- Functions called inside command substitution run in a subshell, so status updates must happen outside `$(...)`.

## Day 8

- Added `--help` and `--version` flags with usage text and exit 64 on unknown options.
- Added a non-root privilege warning and a clear sudo message for unreadable authentication logs.
- Fixed ShellCheck warnings for system-file sourcing, login counting, and network output.
- Tagged v0.2.0.

### Lessons Learned

- Use a `for` loop over `"$@"` for simple flag parsing to avoid unreachable `shift` code.
- `# shellcheck source=/dev/null` silences SC1091 for system files ShellCheck cannot follow.
- Check `EUID` early and tell the user exactly which checks may be incomplete.

## Day 9

- Added `config/auditor.conf` with the default CPU, memory, and disk thresholds.
- Added optional config loading with built-in defaults when the file is absent.
- Added `CONFIG_FILE` support for selecting an alternate configuration path.
- Added fail-fast validation for all threshold values and WARN/CRIT ordering.
- Invalid configuration reports all detected errors and exits with code 65 (`EX_DATAERR`).
- Valid leading-zero values are parsed as decimal numbers rather than octal.

### Lessons Learned

- Resolve the config path from the script directory so the command works from any current directory.
- Source configuration only after assigning built-in defaults so file values override them.
- Validate each value before performing arithmetic comparisons.
- Collect independent configuration errors so one run gives the user a complete repair list.
