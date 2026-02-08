<#
.SYNOPSIS
    Downloads and silently installs the Microsoft Defender for Identity sensor.

.DESCRIPTION
    Automates the MDI sensor installation on a Domain Controller:
      1. Downloads the latest sensor installer from the MDI portal (or uses a local copy)
      2. Extracts the package
      3. Runs a silent installation with the provided access key
      4. Optionally configures a proxy
      5. Validates the sensor service is running

.PARAMETER AccessKey
    The MDI workspace sensor access key (from the MDI portal > Settings > Sensors).

.PARAMETER InstallerPath
    Path to a pre-downloaded sensor installer ZIP. If omitted, the script
    downloads the latest version from the MDI portal.

.PARAMETER WorkspaceName
    Your MDI workspace name (the subdomain, e.g., 'contoso' for contoso.atp.azure.com).
    Required only when downloading the installer.

.PARAMETER ProxyUrl
    Optional HTTP proxy URL (e.g., http://proxy.contoso.com:8080).

.PARAMETER InstallPath
    Installation directory. Defaults to 'C:\Program Files\Azure Advanced Threat Protection Sensor'.

.PARAMETER NoRestart
    Suppress automatic restart after installation.

.PARAMETER DownloadOnly
    Download and extract the installer without running setup.

.EXAMPLE
    .\Install-MDISensor.ps1 -AccessKey 'BASE64KEY==' -WorkspaceName 'contoso'
    Downloads the latest sensor and installs it silently.

.EXAMPLE
    .\Install-MDISensor.ps1 -AccessKey 'BASE64KEY==' -InstallerPath 'C:\temp\sensor.zip'
    Installs from a local copy of the sensor package.

.NOTES
    Must be run as Administrator on the target Domain Controller.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AccessKey,

    [Parameter()]
    [string]$InstallerPath,

    [Parameter()]
    [string]$WorkspaceName,

    [Parameter()]
    [string]$ProxyUrl,

    [Parameter()]
    [string]$InstallPath = 'C:\Program Files\Azure Advanced Threat Protection Sensor',

    [Parameter()]
    [switch]$NoRestart,

    [Parameter()]
    [switch]$DownloadOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Elevation Check
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'This script must be run as Administrator.'
    return
}
#endregion

$tempDir = Join-Path $env:TEMP "MDISensor_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # ---------------------------------------------------------------
    # Step 1: Obtain Installer
    # ---------------------------------------------------------------
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ' Microsoft Defender for Identity - Sensor Installer' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    $zipPath = $null

    if ($InstallerPath) {
        if (-not (Test-Path $InstallerPath)) {
            Write-Error "Installer not found at: $InstallerPath"
            return
        }
        $zipPath = $InstallerPath
        Write-Host "[1/4] Using local installer: $zipPath" -ForegroundColor Cyan
    } else {
        if (-not $WorkspaceName) {
            Write-Error 'Provide -WorkspaceName to download the sensor, or -InstallerPath for a local copy.'
            return
        }

        $downloadUrl = "https://${WorkspaceName}sensorapi.atp.azure.com/sensor/download"
        $zipPath = Join-Path $tempDir 'Azure ATP Sensor Setup.zip'

        Write-Host "[1/4] Downloading sensor from $downloadUrl ..." -ForegroundColor Cyan

        # Use TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $webClient = New-Object System.Net.WebClient
        if ($ProxyUrl) {
            $proxy = New-Object System.Net.WebProxy($ProxyUrl)
            $proxy.UseDefaultCredentials = $true
            $webClient.Proxy = $proxy
        }

        try {
            $webClient.DownloadFile($downloadUrl, $zipPath)
            Write-Host "  Downloaded to: $zipPath" -ForegroundColor Green
        } catch {
            Write-Error "Failed to download sensor: $_. Verify WorkspaceName and network connectivity."
            return
        } finally {
            $webClient.Dispose()
        }
    }

    # ---------------------------------------------------------------
    # Step 2: Extract
    # ---------------------------------------------------------------
    Write-Host "[2/4] Extracting sensor package..." -ForegroundColor Cyan
    $extractDir = Join-Path $tempDir 'SensorSetup'
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    Write-Host "  Extracted to: $extractDir" -ForegroundColor Green

    # Locate the setup executable
    $setupExe = Get-ChildItem -Path $extractDir -Filter 'Azure ATP sensor Setup.exe' -Recurse |
        Select-Object -First 1

    if (-not $setupExe) {
        # Fallback: look for any setup executable
        $setupExe = Get-ChildItem -Path $extractDir -Filter '*.exe' -Recurse |
            Where-Object { $_.Name -match 'setup' } |
            Select-Object -First 1
    }

    if (-not $setupExe) {
        Write-Error "Could not find the sensor setup executable in $extractDir"
        return
    }

    Write-Host "  Setup executable: $($setupExe.FullName)" -ForegroundColor Green

    if ($DownloadOnly) {
        Write-Host ''
        Write-Host "Download complete. Installer extracted to: $extractDir" -ForegroundColor Green
        Write-Host "Run the setup manually: $($setupExe.FullName)" -ForegroundColor Green
        return
    }

    # ---------------------------------------------------------------
    # Step 3: Silent Install
    # ---------------------------------------------------------------
    Write-Host "[3/4] Installing sensor silently..." -ForegroundColor Cyan

    $installArgs = @(
        '/quiet'
        'NetFrameworkCommandLineArguments="/q"'
        "AccessKey=""$AccessKey"""
    )

    if ($InstallPath -ne 'C:\Program Files\Azure Advanced Threat Protection Sensor') {
        $installArgs += "InstallationPath=""$InstallPath"""
    }

    if ($NoRestart) {
        $installArgs += '/norestart'
    }

    if ($ProxyUrl) {
        $installArgs += "ProxyUrl=""$ProxyUrl"""
    }

    Write-Host "  Running: $($setupExe.FullName) $($installArgs -join ' ')" -ForegroundColor Gray

    $process = Start-Process -FilePath $setupExe.FullName `
        -ArgumentList $installArgs `
        -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Host '  Sensor installed successfully.' -ForegroundColor Green
    } elseif ($process.ExitCode -eq 3010) {
        Write-Host '  Sensor installed successfully. A reboot is required.' -ForegroundColor Yellow
    } else {
        Write-Error "Sensor installation failed with exit code: $($process.ExitCode). Check logs in '$InstallPath\Logs'."
        return
    }

    # ---------------------------------------------------------------
    # Step 4: Validate
    # ---------------------------------------------------------------
    Write-Host "[4/4] Validating sensor service..." -ForegroundColor Cyan

    # The service may take a moment to register
    Start-Sleep -Seconds 10

    $sensorService = Get-Service -Name 'AATPSensor' -ErrorAction SilentlyContinue
    if ($null -eq $sensorService) {
        $sensorService = Get-Service -Name 'Azure Advanced Threat Protection Sensor' -ErrorAction SilentlyContinue
    }

    if ($sensorService) {
        Write-Host "  Service Name:   $($sensorService.Name)" -ForegroundColor Green
        Write-Host "  Service Status: $($sensorService.Status)" -ForegroundColor $(if ($sensorService.Status -eq 'Running') { 'Green' } else { 'Yellow' })

        if ($sensorService.Status -ne 'Running') {
            Write-Host '  Attempting to start the sensor service...' -ForegroundColor Yellow
            Start-Service -Name $sensorService.Name -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            $sensorService.Refresh()
            Write-Host "  Service Status: $($sensorService.Status)" -ForegroundColor $(if ($sensorService.Status -eq 'Running') { 'Green' } else { 'Red' })
        }
    } else {
        Write-Host '  Sensor service not found. It may still be initializing.' -ForegroundColor Yellow
        Write-Host '  Check services.msc for "Azure Advanced Threat Protection Sensor".' -ForegroundColor Yellow
    }

    # Check the updater service as well
    $updaterService = Get-Service -Name 'AATPSensorUpdater' -ErrorAction SilentlyContinue
    if ($updaterService) {
        Write-Host "  Updater Service: $($updaterService.Status)" -ForegroundColor Green
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ' MDI Sensor deployment complete.' -ForegroundColor Green
    Write-Host ' Monitor sensor health in the MDI portal:' -ForegroundColor Green
    Write-Host " https://$WorkspaceName.atp.azure.com" -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Cyan

} finally {
    # Cleanup temp files (keep if DownloadOnly)
    if (-not $DownloadOnly -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
