<#
.SYNOPSIS
    Validates prerequisites for Microsoft Defender for Identity sensor deployment.

.DESCRIPTION
    Checks all requirements before installing the MDI sensor on a Domain Controller
    or AD FS server. Validates OS version, .NET version, network connectivity,
    required ports, service account readiness, and hardware resources.

.PARAMETER DomainController
    The FQDN of the target Domain Controller. Defaults to the local machine.

.PARAMETER SensorAccessKey
    The MDI workspace access key (used only to validate format, not stored).

.PARAMETER SkipConnectivityTests
    Skip external network connectivity tests (useful for air-gapped pre-checks).

.EXAMPLE
    .\Test-MDIPrerequisites.ps1
    Runs all prerequisite checks on the local Domain Controller.

.EXAMPLE
    .\Test-MDIPrerequisites.ps1 -SkipConnectivityTests
    Runs all checks except external connectivity validation.

.NOTES
    Run as a Domain Admin or Local Administrator on the target DC.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DomainController = $env:COMPUTERNAME,

    [Parameter()]
    [string]$SensorAccessKey,

    [Parameter()]
    [switch]$SkipConnectivityTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

#region Helper Functions

function Write-CheckResult {
    param(
        [string]$CheckName,
        [bool]$Passed,
        [string]$Detail = ''
    )
    $status = if ($Passed) { '[PASS]' } else { '[FAIL]' }
    $color = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host "$status $CheckName" -ForegroundColor $color
    if ($Detail) {
        Write-Host "       $Detail" -ForegroundColor Gray
    }
    return [PSCustomObject]@{
        Check  = $CheckName
        Passed = $Passed
        Detail = $Detail
    }
}

function Write-CheckWarning {
    param(
        [string]$CheckName,
        [string]$Detail = ''
    )
    Write-Host "[WARN] $CheckName" -ForegroundColor Yellow
    if ($Detail) {
        Write-Host "       $Detail" -ForegroundColor Gray
    }
    return [PSCustomObject]@{
        Check  = $CheckName
        Passed = $true  # warnings don't block
        Detail = "WARNING: $Detail"
    }
}

#endregion

#region Main Checks

$results = [System.Collections.ArrayList]::new()

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' Microsoft Defender for Identity - Prerequisites Checker' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host "Target: $DomainController"
Write-Host "Date:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ''

# ---------------------------------------------------------------
# 1. Operating System Version
# ---------------------------------------------------------------
Write-Host '--- Operating System ---' -ForegroundColor Cyan
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$osVersion = [Version]$os.Version
$osName = $os.Caption

# MDI sensor requires Windows Server 2016 or later
$osSupported = $osVersion -ge [Version]'10.0.14393'
$null = $results.Add((Write-CheckResult -CheckName 'OS Version (Server 2016+)' -Passed $osSupported -Detail "$osName ($($os.Version))"))

# Check if this is a Domain Controller
$isDC = $false
try {
    $domainRole = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
    # DomainRole 4 = Backup DC, 5 = Primary DC
    $isDC = $domainRole -ge 4
} catch {
    $isDC = $false
}
$null = $results.Add((Write-CheckResult -CheckName 'Machine is a Domain Controller' -Passed $isDC -Detail "DomainRole: $domainRole"))

# ---------------------------------------------------------------
# 2. Hardware Resources
# ---------------------------------------------------------------
Write-Host ''
Write-Host '--- Hardware Resources ---' -ForegroundColor Cyan

# RAM: minimum 6 GB recommended for sensor
$totalMemoryGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$ramOk = $totalMemoryGB -ge 6
$null = $results.Add((Write-CheckResult -CheckName 'RAM (>= 6 GB)' -Passed $ramOk -Detail "${totalMemoryGB} GB installed"))

# CPU cores: minimum 2 cores
$cpuCores = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
$cpuOk = $cpuCores -ge 2
$null = $results.Add((Write-CheckResult -CheckName 'CPU Cores (>= 2)' -Passed $cpuOk -Detail "$cpuCores core(s) detected"))

# Disk space: at least 6 GB free on the system drive
$systemDrive = $env:SystemDrive
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$systemDrive'"
$freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
$diskOk = $freeGB -ge 6
$null = $results.Add((Write-CheckResult -CheckName 'Disk Space (>= 6 GB free on system drive)' -Passed $diskOk -Detail "${freeGB} GB free on $systemDrive"))

# ---------------------------------------------------------------
# 3. .NET Framework
# ---------------------------------------------------------------
Write-Host ''
Write-Host '--- .NET Framework ---' -ForegroundColor Cyan

# MDI sensor requires .NET Framework 4.7 or later
$dotNetRelease = 0
try {
    $dotNetRelease = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction Stop).Release
} catch {
    $dotNetRelease = 0
}

# Release 460798 = .NET 4.7 on Windows 10 Creators Update / Server 2016
$dotNetOk = $dotNetRelease -ge 460798

$dotNetVersionMap = @{
    528040 = '4.8'
    528372 = '4.8'
    528049 = '4.8'
    461808 = '4.7.2'
    461310 = '4.7.1'
    460798 = '4.7'
}
$dotNetFriendly = ($dotNetVersionMap.GetEnumerator() | Where-Object { $dotNetRelease -ge $_.Key } |
    Sort-Object Key -Descending | Select-Object -First 1).Value
if (-not $dotNetFriendly) { $dotNetFriendly = "Unknown (release $dotNetRelease)" }

$null = $results.Add((Write-CheckResult -CheckName '.NET Framework >= 4.7' -Passed $dotNetOk -Detail ".NET $dotNetFriendly (release $dotNetRelease)"))

# ---------------------------------------------------------------
# 4. Required Windows Services
# ---------------------------------------------------------------
Write-Host ''
Write-Host '--- Required Services ---' -ForegroundColor Cyan

$requiredServices = @(
    @{ Name = 'CertSvc'; DisplayName = 'Active Directory Certificate Services'; Required = $false },
    @{ Name = 'NTDS';    DisplayName = 'Active Directory Domain Services';       Required = $true },
    @{ Name = 'DNS';     DisplayName = 'DNS Server';                             Required = $false },
    @{ Name = 'Netlogon'; DisplayName = 'Netlogon';                              Required = $true },
    @{ Name = 'W32Time';  DisplayName = 'Windows Time';                          Required = $true }
)

foreach ($svc in $requiredServices) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        if ($svc.Required) {
            $null = $results.Add((Write-CheckResult -CheckName "Service: $($svc.DisplayName)" -Passed $false -Detail 'Service not found'))
        } else {
            $null = $results.Add((Write-CheckWarning -CheckName "Service: $($svc.DisplayName)" -Detail 'Service not found (optional)'))
        }
    } else {
        $running = $service.Status -eq 'Running'
        if ($svc.Required) {
            $null = $results.Add((Write-CheckResult -CheckName "Service: $($svc.DisplayName)" -Passed $running -Detail "Status: $($service.Status)"))
        } else {
            if ($running) {
                $null = $results.Add((Write-CheckResult -CheckName "Service: $($svc.DisplayName)" -Passed $true -Detail "Status: $($service.Status)"))
            } else {
                $null = $results.Add((Write-CheckWarning -CheckName "Service: $($svc.DisplayName)" -Detail "Status: $($service.Status) (optional)"))
            }
        }
    }
}

# ---------------------------------------------------------------
# 5. Power Settings (High Performance recommended)
# ---------------------------------------------------------------
Write-Host ''
Write-Host '--- Power Plan ---' -ForegroundColor Cyan

try {
    $activePlan = (powercfg /getactivescheme 2>$null)
    $isHighPerf = $activePlan -match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'  # High Performance GUID
    if ($isHighPerf) {
        $null = $results.Add((Write-CheckResult -CheckName 'Power Plan: High Performance' -Passed $true -Detail 'High Performance plan active'))
    } else {
        $null = $results.Add((Write-CheckWarning -CheckName 'Power Plan: High Performance' -Detail "MDI recommends High Performance. Current: $activePlan"))
    }
} catch {
    $null = $results.Add((Write-CheckWarning -CheckName 'Power Plan: High Performance' -Detail 'Unable to determine power plan'))
}

# ---------------------------------------------------------------
# 6. Network Connectivity (MDI cloud endpoints)
# ---------------------------------------------------------------
Write-Host ''
Write-Host '--- Network Connectivity ---' -ForegroundColor Cyan

if ($SkipConnectivityTests) {
    Write-Host '[SKIP] Network connectivity tests skipped by parameter.' -ForegroundColor Yellow
} else {
    # MDI sensor needs outbound HTTPS to these endpoints
    $mdiEndpoints = @(
        @{ Host = '*.atp.azure.com';        TestHost = 'sensorapi.atp.azure.com'; Port = 443; Description = 'MDI Sensor API' },
        @{ Host = '*.blob.core.windows.net'; TestHost = 'mdicloudstorage.blob.core.windows.net'; Port = 443; Description = 'Azure Blob Storage' }
    )

    foreach ($ep in $mdiEndpoints) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $connectResult = $tcp.BeginConnect($ep.TestHost, $ep.Port, $null, $null)
            $waitSuccess = $connectResult.AsyncWaitHandle.WaitOne(5000, $false)
            if ($waitSuccess -and $tcp.Connected) {
                $null = $results.Add((Write-CheckResult -CheckName "Connectivity: $($ep.Description)" -Passed $true -Detail "$($ep.TestHost):$($ep.Port) reachable"))
            } else {
                $null = $results.Add((Write-CheckResult -CheckName "Connectivity: $($ep.Description)" -Passed $false -Detail "$($ep.TestHost):$($ep.Port) not reachable"))
            }
            $tcp.Close()
        } catch {
            $null = $results.Add((Write-CheckResult -CheckName "Connectivity: $($ep.Description)" -Passed $false -Detail "Error testing $($ep.TestHost):$($ep.Port) - $_"))
        }
    }

    # Local ports the sensor listens on (net.tcp port 444 for internal communication)
    $portInUse = $false
    try {
        $listeners = Get-NetTCPConnection -LocalPort 444 -State Listen -ErrorAction SilentlyContinue
        $portInUse = ($null -ne $listeners -and $listeners.Count -gt 0)
    } catch {
        $portInUse = $false
    }
    $null = $results.Add((Write-CheckResult -CheckName 'Local Port 444 available' -Passed (-not $portInUse) -Detail $(if ($portInUse) { 'Port 444 is already in use' } else { 'Port 444 is free' })))
}

# ---------------------------------------------------------------
# 7. Npcap / WinPcap Check
# ---------------------------------------------------------------
Write-Host ''
Write-Host '--- Packet Capture Driver ---' -ForegroundColor Cyan

$npcapInstalled = Test-Path 'HKLM:\SOFTWARE\Npcap' -ErrorAction SilentlyContinue
$winpcapInstalled = Test-Path 'HKLM:\SOFTWARE\WOW6432Node\WinPcap' -ErrorAction SilentlyContinue

if ($npcapInstalled) {
    $null = $results.Add((Write-CheckResult -CheckName 'Npcap installed' -Passed $true -Detail 'Npcap detected'))
} elseif ($winpcapInstalled) {
    $null = $results.Add((Write-CheckWarning -CheckName 'Packet Capture Driver' -Detail 'WinPcap detected. Npcap is recommended for better performance.'))
} else {
    $null = $results.Add((Write-CheckWarning -CheckName 'Packet Capture Driver' -Detail 'Neither Npcap nor WinPcap detected. The sensor installer bundles Npcap if needed.'))
}

# ---------------------------------------------------------------
# 8. Sensor Access Key Format Validation
# ---------------------------------------------------------------
if ($SensorAccessKey) {
    Write-Host ''
    Write-Host '--- Access Key ---' -ForegroundColor Cyan

    # The access key is a base64-encoded string, typically 80+ characters
    $keyValid = $false
    try {
        $bytes = [Convert]::FromBase64String($SensorAccessKey)
        $keyValid = $bytes.Length -gt 0
    } catch {
        $keyValid = $false
    }
    $null = $results.Add((Write-CheckResult -CheckName 'Sensor Access Key format' -Passed $keyValid -Detail $(if ($keyValid) { 'Valid base64 format' } else { 'Invalid format - must be a base64 string from the MDI portal' })))
}

# ---------------------------------------------------------------
# 9. gMSA / DSA Account Readiness
# ---------------------------------------------------------------
Write-Host ''
Write-Host '--- Directory Service Account ---' -ForegroundColor Cyan

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $adModuleLoaded = $true
} catch {
    $adModuleLoaded = $false
}
$null = $results.Add((Write-CheckResult -CheckName 'ActiveDirectory PowerShell module' -Passed $adModuleLoaded -Detail $(if ($adModuleLoaded) { 'Module loaded' } else { 'Module not available - install RSAT AD tools' })))

if ($adModuleLoaded) {
    # Check if any gMSA accounts exist that could be used for MDI
    $gmsaAccounts = Get-ADServiceAccount -Filter * -ErrorAction SilentlyContinue
    if ($gmsaAccounts) {
        $null = $results.Add((Write-CheckResult -CheckName 'gMSA accounts exist in domain' -Passed $true -Detail "$($gmsaAccounts.Count) gMSA account(s) found"))
    } else {
        $null = $results.Add((Write-CheckWarning -CheckName 'gMSA accounts in domain' -Detail 'No gMSA accounts found. Consider creating one for the MDI sensor.'))
    }

    # Check KDS Root Key (required for gMSA)
    $kdsKey = Get-KdsRootKey -ErrorAction SilentlyContinue
    if ($kdsKey) {
        $null = $results.Add((Write-CheckResult -CheckName 'KDS Root Key exists' -Passed $true -Detail 'KDS Root Key available for gMSA creation'))
    } else {
        $null = $results.Add((Write-CheckWarning -CheckName 'KDS Root Key' -Detail 'No KDS Root Key found. Required before creating gMSA accounts.'))
    }
}

#endregion

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' Summary' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan

$passed = ($results | Where-Object { $_.Passed }).Count
$failed = ($results | Where-Object { -not $_.Passed }).Count
$total = $results.Count

Write-Host "Total checks: $total | Passed: $passed | Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })

if ($failed -gt 0) {
    Write-Host ''
    Write-Host 'Failed checks:' -ForegroundColor Red
    $results | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.Check): $($_.Detail)" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Resolve the above failures before installing the MDI sensor.' -ForegroundColor Yellow
} else {
    Write-Host ''
    Write-Host 'All prerequisites met. You can proceed with sensor installation.' -ForegroundColor Green
}

# Output results object for pipeline use
$results
