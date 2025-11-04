# SesssionCleaner
SesssionCleaner PS script is a robust automation tool designed to manage and maintain Windows Server environments by proactively identifying and logging off disconnected and idle Remote Desktop Protocol (RDP) sessions. This helps in conserving server resources, improving security by preventing stale sessions, and ensuring optimal performance.

Key Features
*   **Remote Execution:** Can target multiple servers specified via parameters or a CSV file.
*   **Idle Threshold:** Configurable idle time (in minutes) for session logoff.
*   **User Exclusions:** Ability to exclude specific users from the logoff process via parameters or an exclusion file.
*   **Comprehensive Logging:** Detailed logging of script actions, successes, and failures to a specified log file.
*   **Safety Features:** Incorporates `ShouldProcess` for `-WhatIf` and `-Confirm` support, allowing safe testing and controlled execution.
*   **Credential Support:** Option to use alternative credentials for remote connections.
*   **Dynamic Target & Exclusion Lists:** Builds target server and exclusion user lists dynamically based on provided inputs.

