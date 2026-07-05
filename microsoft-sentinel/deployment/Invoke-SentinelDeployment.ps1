[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [string]$TemplateFile = "$PSScriptRoot/../bicep/main.bicep",

    [string]$ParametersFile = "$PSScriptRoot/../bicep/main.parameters.json",

    [switch]$RunPrerequisiteCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($RunPrerequisiteCheck) {
    & "$PSScriptRoot/../prerequisites/Test-SentinelPrerequisites.ps1"
}

if (-not (Test-Path $TemplateFile)) {
    throw "Bicep template not found: $TemplateFile"
}

if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'Deploy Microsoft Sentinel workspace and Defender XDR data connectors')) {
    Write-Host "Deploying Microsoft Sentinel to resource group '$ResourceGroupName'..." -ForegroundColor Cyan

    $deployment = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $TemplateFile `
        --parameters $ParametersFile `
        --output json | ConvertFrom-Json

    if (-not $deployment) {
        throw 'Deployment failed - see Azure CLI output above for details.'
    }

    $workspaceName = $deployment.properties.outputs.logAnalyticsWorkspaceName.value
    Write-Host "Deployment complete. Log Analytics workspace: $workspaceName" -ForegroundColor Green
    Write-Host "Next: connect this workspace to Microsoft Defender XDR at https://security.microsoft.com under Settings > Microsoft Sentinel." -ForegroundColor Yellow

    $deployment
}
