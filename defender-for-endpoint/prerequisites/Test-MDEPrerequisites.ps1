[CmdletBinding()]
param(
    [switch]$SkipDefenderServiceCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$results = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name,[bool]$Passed,[string]$Detail)
    $status = if ($Passed) { '[PASS]' } else { '[FAIL]' }
    $color = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host "$status $Name" -ForegroundColor $color
    if ($Detail) { Write-Host "       $Detail" -ForegroundColor Gray }
    $results.Add([PSCustomObject]@{ Check = $Name; Passed = $Passed; Detail = $Detail }) | Out-Null
}

Write-Host 'Microsoft Defender for Endpoint - Prerequisites' -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem
Add-Check -Name 'Windows 10/11 or Server 2019+' -Passed (([Version]$os.Version) -ge [Version]'10.0.17763') -Detail "$($os.Caption) ($($os.Version))"

$psVersionOk = $PSVersionTable.PSVersion.Major -ge 5
Add-Check -Name 'PowerShell 5+' -Passed $psVersionOk -Detail $PSVersionTable.PSVersion.ToString()

if (-not $SkipDefenderServiceCheck) {
    $svc = Get-Service -Name Sense -ErrorAction SilentlyContinue
    Add-Check -Name 'Microsoft Defender for Endpoint service (Sense)' -Passed ($null -ne $svc) -Detail (if ($svc) { $svc.Status } else { 'Service not installed' })
}

$overall = ($results | Where-Object { -not $_.Passed }).Count -eq 0
Write-Host ''
Write-Host (if ($overall) { 'All prerequisite checks passed.' } else { 'One or more checks failed.' }) -ForegroundColor (if ($overall) { 'Green' } else { 'Red' })
if (-not $overall) { exit 1 }
