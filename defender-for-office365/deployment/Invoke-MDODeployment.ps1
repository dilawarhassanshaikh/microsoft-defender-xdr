[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PolicyPrefix = 'MDO-Standard'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/../prerequisites/Test-MDOPrerequisites.ps1"

if ($PSCmdlet.ShouldProcess('Exchange Online', 'Deploy baseline MDO policies')) {
    Write-Host 'Connecting to Exchange Online...' -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false

    Write-Host "Creating Safe Links policy: $PolicyPrefix-SafeLinks" -ForegroundColor Cyan
    New-SafeLinksPolicy -Name "$PolicyPrefix-SafeLinks" -EnableSafeLinksForEmail $true -TrackClicks $true -ScanUrls $true -ErrorAction SilentlyContinue | Out-Null

    Write-Host "Creating Safe Attachments policy: $PolicyPrefix-SafeAttachments" -ForegroundColor Cyan
    New-SafeAttachmentPolicy -Name "$PolicyPrefix-SafeAttachments" -Action Block -Enable $true -ErrorAction SilentlyContinue | Out-Null

    Write-Host 'Baseline Defender for Office 365 policies deployed.' -ForegroundColor Green
    Disconnect-ExchangeOnline -Confirm:$false
}
