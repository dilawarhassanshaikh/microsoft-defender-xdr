[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OnboardingPackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../deployment/Invoke-MDEDeployment.ps1" -OnboardingPackagePath $OnboardingPackagePath -RunPrerequisiteCheck
