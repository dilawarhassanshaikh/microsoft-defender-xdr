[CmdletBinding()]
param(
    [switch]$SkipAzLoginCheck
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

Write-Host 'Microsoft Sentinel - Prerequisites' -ForegroundColor Cyan

$psVersionOk = $PSVersionTable.PSVersion.Major -ge 7
Add-Check -Name 'PowerShell 7+' -Passed $psVersionOk -Detail $PSVersionTable.PSVersion.ToString()

$azCli = Get-Command az -ErrorAction SilentlyContinue
Add-Check -Name 'Azure CLI installed' -Passed ($null -ne $azCli) -Detail (if ($azCli) { (az version --query "azure-cli" -o tsv 2>$null) } else { 'Install from https://learn.microsoft.com/cli/azure/install-azure-cli' })

$azSentinelModule = Get-Module -ListAvailable -Name Az.SecurityInsights
Add-Check -Name 'Az.SecurityInsights module installed' -Passed ([bool]$azSentinelModule) -Detail 'Install-Module Az.SecurityInsights'

$azMonitorModule = Get-Module -ListAvailable -Name Az.OperationalInsights
Add-Check -Name 'Az.OperationalInsights module installed' -Passed ([bool]$azMonitorModule) -Detail 'Install-Module Az.OperationalInsights'

$graphModule = Get-Module -ListAvailable -Name Microsoft.Graph.Security
Add-Check -Name 'Microsoft.Graph.Security module installed' -Passed ([bool]$graphModule) -Detail 'Install-Module Microsoft.Graph.Security (used to read/sync Defender XDR incidents)'

if (-not $SkipAzLoginCheck -and $azCli) {
    $account = az account show 2>$null | ConvertFrom-Json
    Add-Check -Name 'Azure CLI authenticated' -Passed ($null -ne $account) -Detail (if ($account) { "Subscription: $($account.name)" } else { 'Run: az login' })
}

Write-Host ''
Write-Host 'Required Microsoft Entra ID permissions to connect Sentinel to Microsoft Defender XDR:' -ForegroundColor Cyan
Write-Host '  - Global Administrator or Security Administrator (one-time connector enablement)' -ForegroundColor Gray
Write-Host '  - Azure RBAC: Microsoft Sentinel Contributor on the target workspace/resource group' -ForegroundColor Gray
Write-Host '  - Microsoft Defender XDR: Security Administrator or Security Operator role (unified RBAC)' -ForegroundColor Gray

$overall = ($results | Where-Object { -not $_.Passed }).Count -eq 0
Write-Host ''
Write-Host (if ($overall) { 'All prerequisite checks passed.' } else { 'One or more checks failed.' }) -ForegroundColor (if ($overall) { 'Green' } else { 'Red' })
if (-not $overall) { exit 1 }
