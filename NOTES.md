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
