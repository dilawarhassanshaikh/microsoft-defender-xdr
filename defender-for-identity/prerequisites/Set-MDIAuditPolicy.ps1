<#
.SYNOPSIS
    Configures Windows Advanced Audit Policies required by Microsoft Defender for Identity.

.DESCRIPTION
    MDI relies on specific Windows security events to detect lateral movement,
    credential theft, and domain dominance attacks. This script configures the
    Advanced Audit Policy settings that MDI requires for full signal coverage.

    Policies configured:
    - Account Logon: Audit Credential Validation (Success, Failure)
    - Account Management: Audit Computer/Distribution Group/Security Group/User Account Management
    - DS Access: Audit Directory Service Access & Changes
    - Logon/Logoff: Audit Logon, Logoff, Special Logon, Other Logon/Logoff Events
    - Object Access: Audit SAM
    - System: Audit Security System Extension

.PARAMETER WhatIf
    Show what changes would be made without applying them.

.PARAMETER GPOName
    If specified, creates a new GPO with these audit settings instead of applying locally.
    Requires GroupPolicy PowerShell module.

.EXAMPLE
    .\Set-MDIAuditPolicy.ps1
    Applies MDI audit policies to the local machine.

.EXAMPLE
    .\Set-MDIAuditPolicy.ps1 -GPOName 'MDI Audit Policy'
    Creates a GPO named 'MDI Audit Policy' with the required settings.

.NOTES
    Run as Administrator. For domain-wide deployment, use the -GPOName parameter
    and link the GPO to the Domain Controllers OU.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$GPOName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# MDI required audit subcategories and their settings
# Format: Subcategory GUID, Subcategory Name, Success, Failure
$auditPolicies = @(
    # Account Logon
    @{ SubCategory = 'Credential Validation';                  Success = 'enable'; Failure = 'enable' }

    # Account Management
    @{ SubCategory = 'Computer Account Management';            Success = 'enable'; Failure = 'enable' }
    @{ SubCategory = 'Distribution Group Management';          Success = 'enable'; Failure = 'enable' }
    @{ SubCategory = 'Security Group Management';              Success = 'enable'; Failure = 'enable' }
    @{ SubCategory = 'User Account Management';                Success = 'enable'; Failure = 'enable' }

    # DS Access
    @{ SubCategory = 'Directory Service Access';               Success = 'enable'; Failure = 'enable' }
    @{ SubCategory = 'Directory Service Changes';              Success = 'enable'; Failure = 'enable' }

    # Logon/Logoff
    @{ SubCategory = 'Logon';                                  Success = 'enable'; Failure = 'enable' }
    @{ SubCategory = 'Logoff';                                 Success = 'enable'; Failure = 'disable' }
    @{ SubCategory = 'Special Logon';                          Success = 'enable'; Failure = 'disable' }
    @{ SubCategory = 'Other Logon/Logoff Events';              Success = 'enable'; Failure = 'enable' }

    # Object Access
    @{ SubCategory = 'SAM';                                    Success = 'enable'; Failure = 'disable' }

    # System
    @{ SubCategory = 'Security System Extension';              Success = 'enable'; Failure = 'enable' }
)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' MDI - Advanced Audit Policy Configuration' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

if ($GPOName) {
    # ---------------------------------------------------------------
    # GPO-based deployment
    # ---------------------------------------------------------------
    Write-Host "Creating GPO: '$GPOName'" -ForegroundColor Cyan

    try {
        Import-Module GroupPolicy -ErrorAction Stop
    } catch {
        Write-Error 'GroupPolicy module not available. Install RSAT Group Policy tools.'
        return
    }

    $gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        if ($PSCmdlet.ShouldProcess($GPOName, 'Create GPO')) {
            $gpo = New-GPO -Name $GPOName -Comment 'Advanced Audit Policies required for Microsoft Defender for Identity'
            Write-Host "  GPO created: $($gpo.DisplayName) ($($gpo.Id))" -ForegroundColor Green
        }
    } else {
        Write-Host "  GPO already exists: $($gpo.DisplayName)" -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '  NOTE: GPO-based advanced audit policy configuration requires' -ForegroundColor Yellow
    Write-Host '  editing the GPO with GPMC or importing an audit.csv backup.' -ForegroundColor Yellow
    Write-Host '  The local auditpol commands below show the required settings.' -ForegroundColor Yellow
    Write-Host '  Consider linking this GPO to the Domain Controllers OU.' -ForegroundColor Yellow
    Write-Host ''
}

# ---------------------------------------------------------------
# Local auditpol-based configuration
# ---------------------------------------------------------------
Write-Host 'Configuring Advanced Audit Policies via auditpol...' -ForegroundColor Cyan
Write-Host ''

$successCount = 0
$failCount = 0

foreach ($policy in $auditPolicies) {
    $subCat = $policy.SubCategory
    $successFlag = "/success:$($policy.Success)"
    $failureFlag = "/failure:$($policy.Failure)"

    $cmd = "auditpol /set /subcategory:`"$subCat`" $successFlag $failureFlag"

    if ($PSCmdlet.ShouldProcess($subCat, 'Set audit policy')) {
        try {
            $output = & auditpol /set /subcategory:"$subCat" /success:$($policy.Success) /failure:$($policy.Failure) 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] $subCat (S:$($policy.Success) F:$($policy.Failure))" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  [FAIL] $subCat - $output" -ForegroundColor Red
                $failCount++
            }
        } catch {
            Write-Host "  [FAIL] $subCat - $_" -ForegroundColor Red
            $failCount++
        }
    }
}

# ---------------------------------------------------------------
# Ensure "Force audit policy subcategory settings" is enabled
# ---------------------------------------------------------------
Write-Host ''
Write-Host 'Ensuring Advanced Audit Policy override is enabled...' -ForegroundColor Cyan

$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$regName = 'SCENoApplyLegacyAuditPolicy'
$currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName

if ($currentValue -ne 1) {
    if ($PSCmdlet.ShouldProcess('SCENoApplyLegacyAuditPolicy', 'Set to 1')) {
        Set-ItemProperty -Path $regPath -Name $regName -Value 1 -Type DWord
        Write-Host '  Enabled: Advanced Audit Policy subcategory settings override legacy policy.' -ForegroundColor Green
    }
} else {
    Write-Host '  Already enabled.' -ForegroundColor Green
}

# ---------------------------------------------------------------
# Configure NTLM Auditing (recommended by MDI)
# ---------------------------------------------------------------
Write-Host ''
Write-Host 'Configuring NTLM auditing...' -ForegroundColor Cyan

$ntlmSettings = @(
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'; Name = 'AuditReceivingNTLMTraffic'; Value = 2; Description = 'Audit incoming NTLM traffic' }
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'; Name = 'RestrictSendingNTLMTraffic'; Value = 1; Description = 'Audit outgoing NTLM traffic' }
)

foreach ($setting in $ntlmSettings) {
    if ($PSCmdlet.ShouldProcess($setting.Name, 'Set registry value')) {
        if (-not (Test-Path $setting.Path)) {
            New-Item -Path $setting.Path -Force | Out-Null
        }
        Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type DWord
        Write-Host "  [OK] $($setting.Description)" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' Summary' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host "  Policies configured: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Policies failed:     $failCount" -ForegroundColor Red
}
Write-Host ''
Write-Host '  Verify with: auditpol /get /category:*' -ForegroundColor Gray
Write-Host ''

if ($GPOName) {
    Write-Host "  Next step: Link GPO '$GPOName' to the Domain Controllers OU:" -ForegroundColor Yellow
    Write-Host "    New-GPLink -Name '$GPOName' -Target 'OU=Domain Controllers,$((Get-ADDomain).DistinguishedName)'" -ForegroundColor Yellow
}
