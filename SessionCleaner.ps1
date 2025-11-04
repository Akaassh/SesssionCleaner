##========================================================================
## Filename:     SessionCleanerv51.ps1"
## Description:  Remote Idle user Session Cleaner"
## Created on:   09/09/2025"
## Created by:   Akash Nadar"
## Version:      1.00"
##========================================================================


[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Local')]
param(
    [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string[]] $ComputerName = @(($env:COMPUTERNAME).ToUpper()),

    [Parameter(Position=1)]
    [string] $ServersCsv,

    [int] $IdleThreshold = 60,

    [string[]] $ExcludeUsers,

    [string] $ExcludeFile,

    [string] $LogFile = "C:\Scripts\LogoffLog.txt",

    [System.Management.Automation.PSCredential] $Credential
)


function Show-Banner {

Write-Host " +---------------------------------+ "
Write-Host " |       S E S S I O N             | "
Write-Host " |             C L E A N E R v1.0  | "
Write-Host " +---------------------------------+ "
Write-Host " # Created by:   Akash Nadar"
Write-Host " # Version:      1.00"


}


Show-Banner

function Convert-IdleToMinutes {
    param([string]$Idle)

    if ([string]::IsNullOrWhiteSpace($Idle)) { return 0 }
    $Idle = $Idle.Trim()

    if ($Idle -eq '.' -or $Idle -eq 'none') { return 0 }

    if ($Idle -match '^(?<days>\d+)\+(?<hours>\d{1,2}):(?<mins>\d{2})$') {
        return ([int]$Matches.days * 1440) + ([int]$Matches.hours * 60) + [int]$Matches.mins
    }
    if ($Idle -match '^(?<hours>\d{1,2}):(?<mins>\d{2})$') {
        return ([int]$Matches.hours * 60) + [int]$Matches.mins
    }
    if ($Idle -match '^\d+$') {
        return [int]$Idle
    }

    Write-Verbose "Unrecognized idle format: '$Idle'"
    return $null
}

# Ensure log directory exists
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

# Build target list
$Targets = @()
if ($ServersCsv) {
    try {
        $csv = Import-Csv -Path $ServersCsv -ErrorAction Stop
        if ($csv.Count -gt 0) {
            if ($csv[0].PSObject.Properties.Match('ComputerName')) {
                $Targets += $csv | ForEach-Object { $_.ComputerName }
            }
            else {
                $firstProp = $csv[0].PSObject.Properties[0].Name
                $Targets += $csv | ForEach-Object { $_.$firstProp }
            }
        }
    } catch {
        Write-Warning "Failed to import CSV '$ServersCsv': $($_.Exception.Message)"
    }
}

if ($ComputerName) {
    $Targets += $ComputerName
}

if ($Targets.Count -eq 0) {
    $Targets = @($env:COMPUTERNAME)
}

# Build exclusion list
# Build exclusion list
$Exclusions = @()

if ($ExcludeFile) {
    if (Test-Path $ExcludeFile) {
        $Exclusions = Get-Content -Path $ExcludeFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
    }
    else {
        Write-Warning "Exclude file '$ExcludeFile' not found"
    }
}

if ($ExcludeUsers) {
    $Exclusions = $Exclusions + $ExcludeUsers
}

$Exclusions = $Exclusions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique


# ScriptBlock that enumerates sessions on target machine and returns a PSCustomObject
$scriptBlock = {
    param($IdleThresholdLocal)

    $rows = quser 2>$null
    if (-not $rows) {
        return @{ Success = $false; Message = 'quser returned no data' }
    }

    $lines = $rows | Select-Object -Skip 1
    $sessions = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $clean    = $line.TrimStart() -replace '^\>', ''
        $columns  = $clean -split '\s{2,}'
        if ($columns.Count -lt 5) { continue }

        if ($columns[1] -as [int]) {
            $userName    = $columns[0].Trim()
            $sessionName = ''
            $sessionID   = $columns[1].Trim()
            $state       = $columns[2].Trim()
            $idleStr     = $columns[3].Trim()
            $logonTime   = $columns[4].Trim()
        }
        else {
            $userName    = $columns[0].Trim()
            $sessionName = $columns[1].Trim()
            $sessionID   = $columns[2].Trim()
            $state       = $columns[3].Trim()
            $idleStr     = $columns[4].Trim()
            $logonTime   = $columns[5].Trim()
        }

        $sessions += [pscustomobject]@{
            UserName    = $userName
            SessionName = $sessionName
            SessionID   = $sessionID
            State       = $state
            Idle        = $idleStr
            LogonTime   = $logonTime
        }
    }

    return @{ Success = $true; Sessions = $sessions }
}

foreach ($target in $Targets) {
    $server = $target.Trim()
    if ([string]::IsNullOrWhiteSpace($server)) { continue }

    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - START - $($server)"

    try {
        if ($Credential) {
            $result = Invoke-Command -ComputerName $server -ScriptBlock $scriptBlock -ArgumentList $IdleThreshold -Credential $Credential -ErrorAction Stop
        }
        else {
            $result = Invoke-Command -ComputerName $server -ScriptBlock $scriptBlock -ArgumentList $IdleThreshold -ErrorAction Stop
        }

        if ($null -eq $result -or ($result -is [System.Array] -and $result.Count -eq 0)) {
            Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($server) - No result from Invoke-Command"
            continue
        }
        $rc = $result
        if ($rc -is [System.Array]) { $rc = $rc[0] }

        if ($rc.Success -ne $true) {
            Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($server) - $($rc.Message)"
            continue
        }

        foreach ($s in $rc.Sessions) {
            $idleMinutes = Convert-IdleToMinutes -Idle $s.Idle
            if ($null -eq $idleMinutes) { continue }

            if ($s.State -notmatch '^Disc') { continue }

            if ($Exclusions -and ($Exclusions -contains $s.UserName)) {
                Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($server) - Skipping excluded user '$($s.UserName)' (SessionID: $($s.SessionID))"
                continue
            }

            if ($idleMinutes -ge $IdleThreshold) {
                $actionDesc = "Log off user '$($s.UserName)' (SessionID: $($s.SessionID), Idle: $idleMinutes mins)"
                # Use ShouldProcess so the built-in -WhatIf works
                if ($PSCmdlet.ShouldProcess($($server), $actionDesc)) {
                    try {
                        $logoffBlock = { param($id) logoff $id /V }
                        if ($Credential) {
                            Invoke-Command -ComputerName $server -ScriptBlock $logoffBlock -ArgumentList $s.SessionID -Credential $Credential -ErrorAction Stop
                        }
                        else {
                            Invoke-Command -ComputerName $server -ScriptBlock $logoffBlock -ArgumentList $s.SessionID -ErrorAction Stop
                        }

                        Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($server) - Disconnected user '$($s.UserName)' (SessionID: $($s.SessionID), Idle: $idleMinutes mins) was logged off"
                        Write-Host $actionDesc
                    } catch {
                        Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($server) - FAILED to log off '$($s.UserName)' (SessionID: $($s.SessionID)). Error: $($_.Exception.Message)"
                        Write-Warning "Failed to log off '$($s.UserName)' on $($server): $($_.Exception.Message)"
                    }
                }
                else {
                    # ShouldProcess returned false (e.g. -WhatIf was supplied), log the planned action
                    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($server) - [WhatIf] $actionDesc"
                    Write-Host "[WhatIf] $actionDesc"
                }
            }
        }
    } catch {
        Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($server) - ERROR: $($_.Exception.Message)"
        Write-Warning "Failed processing $($server): $($_.Exception.Message)"
    }

    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - END - $($server)"
}

Write-Host "Completed processing $($Targets.Count) server(s). Log saved to: $LogFile"
