[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../deployment/Invoke-SentinelDeployment.ps1" -ResourceGroupName $ResourceGroupName -RunPrerequisiteCheck
