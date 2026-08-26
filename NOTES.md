# Development Notes

## Day 1 – Project Initialization

- Initialized Git repository.
- Added `auditor.sh` skeleton with shebang and `main()` placeholder.
- Set executable permission on script.

### Lessons Learned
- Importance of starting with a minimal, working skeleton.

## Day 2 – Uptime and Load Average Collection

- Added `get_uptime()` function using `uptime -p` command.
- Added `get_load_average()` function parsing `/proc/loadavg`.
- Created `display_system_info()` to format the output.
- Tested script successfully.

### Lessons Learned
- `/proc/loadavg` contains three load average values (1, 5, 15 minutes).
- `uptime -p` gives a human-readable uptime format.
- Breaking code into functions makes it more maintainable.
