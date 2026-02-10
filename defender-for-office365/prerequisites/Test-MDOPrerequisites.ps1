[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$failures = 0
function Write-Check { param([string]$Name,[bool]$Pass,[string]$Detail)
    $status = if ($Pass) { '[PASS]' } else { '[FAIL]' }
    Write-Host "$status $Name" -ForegroundColor (if ($Pass) { 'Green' } else { 'Red' })
    if ($Detail) { Write-Host "       $Detail" -ForegroundColor Gray }
    if (-not $Pass) { $script:failures++ }
}

Write-Host 'Microsoft Defender for Office 365 - Prerequisites' -ForegroundColor Cyan

Write-Check -Name 'ExchangeOnlineManagement module installed' -Pass ([bool](Get-Module -ListAvailable -Name ExchangeOnlineManagement)) -Detail 'Install-Module ExchangeOnlineManagement'
Write-Check -Name 'PowerShell 5+' -Pass ($PSVersionTable.PSVersion.Major -ge 5) -Detail $PSVersionTable.PSVersion.ToString()

if ($failures -gt 0) { exit 1 }
