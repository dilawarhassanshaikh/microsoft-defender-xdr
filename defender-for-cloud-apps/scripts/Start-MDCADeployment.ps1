[CmdletBinding()]
param(
    [string]$TagName = 'DefenderForCloudApps-Onboarded'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../deployment/Invoke-MDCADeployment.ps1" -TagName $TagName
