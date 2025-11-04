# SesssionCleaner
SesssionCleaner PS script is a robust automation tool designed to manage and maintain Windows Server environments by proactively identifying and logging off disconnected and idle Remote Desktop Protocol (RDP) sessions. This helps in conserving server resources, improving security by preventing stale sessions, and ensuring optimal performance. Script also includes logging capability which will specify script actions, success and failures to a logfile specified in a system directory.

**Key Features
***   **Remote Execution:** Can target multiple servers specified via parameters or a CSV file.
*   **Idle Threshold:** Configurable idle time (in minutes) for session logoff.
*   **User Exclusions:** Ability to exclude specific users from the logoff process via parameters or an exclusion file.
*   **Comprehensive Logging:** Detailed logging of script actions, successes, and failures to a specified log file.
*   **Safety Features:** Incorporates `ShouldProcess` for `-WhatIf` and `-Confirm` support, allowing safe testing and controlled execution.
*   **Credential Support:** Option to use alternative credentials for remote connections.
*   **Dynamic Target & Exclusion Lists:** Builds target server and exclusion user lists dynamically based on provided inputs.



**Script Arguments/ Input Parameters  
**
"ComputerName" : Name of the computer/server the script needs to be run, also can be ran on multiple servers specified via parameters (If runnning remotely the computer should be on same network).
"ServersCsv"   : Path to a CSV file containing a list of server names. The script attempts to read from a column named `ComputerName` or the first column it finds.
"IdleThreshold": Idle time to be configured for session logoff (default 60 mins in script).
"ExcludeUsers" : Exclude specific users whose sessions should never be logged off regardless of idle time or state via username from the logoff process via parameters.
"ExcludeFile"  : Path to a text file where each line contains a username to be excluded from the logoff process.
"LogFile"      : The full path and filename for the log file where script activities, successes, and errors will be recorded.

**
Basic Execution **

To run on the local machine with default settings (log off disconnected sessions idle for 60+ minutes):
```powershell
.\SessionCleanerv6.ps1
```

### Targeting Remote Servers
**Using `ComputerName`:**
```powershell
.\SessionCleanerv6.ps1 -ComputerName "Server01", "Server02" -IdleThreshold 90
```

** Using a CSV File (e.g., `servers.csv` containing a column named `ComputerName`):**
```csv
ComputerName
Server01
Server02
Server03
```
```powershell
.\SessionCleanerv6.ps1 -ServersCsv "C:\Path\to\servers.csv" -IdleThreshold 120 -LogFile "C:\Logs\SessionCleanup.log"
```

### Excluding Users
**Excluding specific users:**
```powershell
.\SessionCleanerv6.ps1 -ComputerName "Server01" -ExcludeUsers "Administrator", "svc_backup"
```

** Excluding users from a file (e.g., `exclude.txt`):**
```
Administrator
svc_backup
testuser
```
```powershell
.\SessionCleanerv6.ps1 -ComputerName "Server01" -ExcludeFile "C:\Path\to\exclude.txt"
```

### Using Alternative Credentials
```powershell
$cred = Get-Credential
.\SessionCleanerv6.ps1 -ComputerName "Server01" -Credential $cred
```

### Safe Testing with `-WhatIf`
To see what actions the script *would* take without actually performing them:
```powershell
.\SessionCleanerv6.ps1 -ComputerName "Server01", "Server02" -IdleThreshold 30 -WhatIf
```

### Interactive Confirmation with `-Confirm`
To be prompted before each logoff action:
```powershell
.\SessionCleanerv6.ps1 -ComputerName "Server01" -Confirm
```

##  Logging
The script maintains a detailed log at the path specified by `-LogFile` (default: `C:\Scripts\LogoffLog.txt`). This log includes:
*   Timestamped start and end markers for each server's processing.
*   Records of skipped excluded users.
*   Messages for successful logoffs.
*   Error messages for failed `Invoke-Command` calls or logoff attempts.
*   `[WhatIf]` entries when the `-WhatIf` parameter is used.

Example Log Entry:
```
2023-10-26 10:30:01 - START - SERVER01
2023-10-26 10:30:02 - SERVER01 - Skipping excluded user 'Administrator' (SessionID: 1)
2023-10-26 10:30:03 - SERVER01 - Disconnected user 'johndoe' (SessionID: 2, Idle: 125 mins) was logged off
2023-10-26 10:30:04 - SERVER01 - FAILED to log off 'janedoe' (SessionID: 3). Error: Access is denied.
2023-10-26 10:30:05 - END - SERVER01
```

## Troubleshooting
*   **"Access is denied" during `Invoke-Command`:** Ensure the account running the script (or `-Credential`) has administrative rights on the target servers.
*   **"The client cannot connect to the destination specified in the request"**: WinRM might not be enabled or configured correctly on the target server.
*   **`quser` returns no data:** The user account executing `quser` (remotely) might not have permission to query sessions, or there are no sessions to report.
*   **Session not being logged off:**
    *   Verify the `IdleThreshold` is met.
    *   Ensure the session `State` is "Disc".
    *   Check if the user is in the `ExcludeUsers` or `ExcludeFile` list.
    *   Review the log file for specific error messages.
