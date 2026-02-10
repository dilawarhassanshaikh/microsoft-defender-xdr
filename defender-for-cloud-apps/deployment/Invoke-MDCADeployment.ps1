[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TagName = 'DefenderForCloudApps-Onboarded'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../prerequisites/Test-MDCAPrerequisites.ps1"

if ($PSCmdlet.ShouldProcess('Microsoft Graph', 'Tag applications for Cloud Apps governance baseline')) {
    Connect-MgGraph -Scopes 'Application.ReadWrite.All'
    $apps = Get-MgApplication -Top 25
    foreach ($app in $apps) {
        $tags = @($app.Tags)
        if ($tags -notcontains $TagName) {
            $tags += $TagName
            Update-MgApplication -ApplicationId $app.Id -Tags $tags
            Write-Host "Tagged application: $($app.DisplayName)" -ForegroundColor Green
        }
    }
    Disconnect-MgGraph
    Write-Host 'Cloud Apps governance baseline tagging completed.' -ForegroundColor Green
}
