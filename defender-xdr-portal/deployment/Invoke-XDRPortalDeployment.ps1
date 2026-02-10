[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$QueriesOutputPath = '.\\xdr-hunting-queries.kql'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../prerequisites/Test-XDRPortalPrerequisites.ps1"

$queries = @'
// Suspicious sign-ins with impossible travel
SigninLogs
| where TimeGenerated > ago(1d)
| summarize Countries=dcount(Location) by UserPrincipalName
| where Countries > 1

// High volume failed authentications
IdentityLogonEvents
| where Timestamp > ago(1d)
| where ActionType == "LogonFailed"
| summarize Failures=count() by AccountUpn
| where Failures > 25
'@

if ($PSCmdlet.ShouldProcess($QueriesOutputPath, 'Export baseline XDR hunting queries')) {
    Set-Content -Path $QueriesOutputPath -Value $queries -Encoding UTF8
    Write-Host "Baseline hunting queries exported to $QueriesOutputPath" -ForegroundColor Green
}
