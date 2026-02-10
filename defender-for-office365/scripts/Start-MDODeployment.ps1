[CmdletBinding()]
param(
    [string]$PolicyPrefix = 'MDO-Standard'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../deployment/Invoke-MDODeployment.ps1" -PolicyPrefix $PolicyPrefix
