[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$failed = 0
function Check { param([string]$Name,[bool]$Pass,[string]$Detail)
    Write-Host ("{0} {1}" -f ($(if($Pass){'[PASS]'}else{'[FAIL]'}), $Name)) -ForegroundColor (if($Pass){'Green'}else{'Red'})
    if ($Detail) { Write-Host "       $Detail" -ForegroundColor Gray }
    if (-not $Pass) { $script:failed++ }
}

Write-Host 'Microsoft Defender for Cloud Apps - Prerequisites' -ForegroundColor Cyan
Check 'PowerShell 7+ recommended' ($PSVersionTable.PSVersion.Major -ge 5) $PSVersionTable.PSVersion.ToString()
Check 'Microsoft.Graph module installed' ([bool](Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) 'Install-Module Microsoft.Graph'

if ($failed -gt 0) { exit 1 }
