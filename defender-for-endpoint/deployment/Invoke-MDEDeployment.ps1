[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$OnboardingPackagePath,

    [switch]$RunPrerequisiteCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($RunPrerequisiteCheck) {
    & "$PSScriptRoot/../prerequisites/Test-MDEPrerequisites.ps1"
}

if (-not (Test-Path $OnboardingPackagePath)) {
    throw "Onboarding package path not found: $OnboardingPackagePath"
}

if ($PSCmdlet.ShouldProcess('Endpoint', 'Apply onboarding package')) {
    Write-Host "Executing onboarding package: $OnboardingPackagePath" -ForegroundColor Cyan
    Start-Process -FilePath $OnboardingPackagePath -ArgumentList '/quiet' -Wait -NoNewWindow
    Write-Host 'Defender for Endpoint onboarding package execution completed.' -ForegroundColor Green
}
