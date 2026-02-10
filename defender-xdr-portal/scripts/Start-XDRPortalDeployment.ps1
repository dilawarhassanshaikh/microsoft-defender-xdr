[CmdletBinding()]
param(
    [string]$QueriesOutputPath = '.\\xdr-hunting-queries.kql'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../deployment/Invoke-XDRPortalDeployment.ps1" -QueriesOutputPath $QueriesOutputPath
