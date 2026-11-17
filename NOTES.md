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

## Day 10

- Fixed `get_status()` so configured values with leading zeroes are parsed as decimal numbers during runtime comparisons.
- Changed threshold pair validation to check CPU, memory, and disk pairs independently.
- Added `is_valid_int()` so a malformed pair is skipped safely while valid pairs still report ordering errors.

### Lessons Learned

- Every Bash arithmetic comparison reads `08` and `09` as fatal octal. If a value comes from config, user input, or a file, prefix it with `10#`; there is no "safe arithmetic" mode.
- Validation should report every independently fixable configuration error in one run.
- Reset configuration state between manual tests; otherwise a previous test can change the result of a later test.

## Day 11

- Moved shared command, status, logging, fatal-error, and configuration-validation helpers into [`lib/common.sh`](./lib/common.sh).
- Added an early `lib/common.sh` availability check with exit code 70 (`EX_SOFTWARE`).
- Guarded `OVERALL` initialization so re-sourcing the library preserves an existing status.

### Lessons Learned

- A sourced library must contain definitions and initializations only; top-level output, main calls, and unconditional exits create side effects in the caller.
- The entry point must validate that a dependency exists before trying to use helpers defined by that dependency.
- Shared state initialization should be idempotent when a library may be sourced more than once.

## Day 12

- Split the collectors into deterministic modules under [`lib/checks/`](./lib/checks/): system, CPU, memory, disk, network, and security.
- Moved report-header system identity helpers into [`lib/common.sh`](./lib/common.sh).
- Updated [`auditor.sh`](./auditor.sh) to load every check module before running the report and to execute checks in the current shell.
- Added guarded threshold defaults to [`lib/common.sh`](./lib/common.sh) so individual check modules can be sourced and run without configuration errors.

### Lessons Learned

- A module loader should fail fast with a specific missing-module error instead of producing a partial report.
- Check functions that mutate shared state must run in the current shell, not through command substitution or a pipeline.
- Shared defaults should be guarded so the entry point's configured values still take precedence.