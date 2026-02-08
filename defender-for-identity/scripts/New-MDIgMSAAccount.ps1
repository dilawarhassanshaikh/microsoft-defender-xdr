<#
.SYNOPSIS
    Creates a Group Managed Service Account (gMSA) for Microsoft Defender for Identity.

.DESCRIPTION
    Automates the creation of a gMSA that the MDI sensor uses for Active Directory
    queries. Handles KDS Root Key creation, gMSA account provisioning, and
    permission assignment.

.PARAMETER AccountName
    Name for the gMSA account (without the trailing $). Max 15 characters.

.PARAMETER DomainControllers
    Array of Domain Controller hostnames that will retrieve the gMSA password.
    If omitted, all DCs in the domain are granted access.

.PARAMETER AllDomainControllers
    Grant all Domain Controllers permission to retrieve the gMSA password.

.PARAMETER DNSHostName
    DNS host name for the gMSA. Defaults to <AccountName>.<DomainDNSName>.

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\New-MDIgMSAAccount.ps1 -AccountName 'MDISensor' -AllDomainControllers
    Creates gMSA 'MDISensor$' with password retrieval allowed by all DCs.

.EXAMPLE
    .\New-MDIgMSAAccount.ps1 -AccountName 'MDISensor' -DomainControllers 'DC01','DC02'
    Creates gMSA with password retrieval limited to DC01 and DC02.

.NOTES
    Requires: ActiveDirectory PowerShell module, Domain Admin privileges.
    Must be run from a domain-joined machine.
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Specific')]
param(
    [Parameter(Mandatory)]
    [ValidateLength(1, 15)]
    [string]$AccountName,

    [Parameter(ParameterSetName = 'Specific')]
    [string[]]$DomainControllers,

    [Parameter(ParameterSetName = 'All')]
    [switch]$AllDomainControllers,

    [Parameter()]
    [string]$DNSHostName,

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Module Check
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Error 'The ActiveDirectory PowerShell module is required. Install RSAT AD tools and retry.'
    return
}
#endregion

#region Resolve Domain Info
$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName
$domainDNS = $domain.DNSRoot

if (-not $DNSHostName) {
    $DNSHostName = "$AccountName.$domainDNS"
}

Write-Host "Domain:       $domainDNS" -ForegroundColor Cyan
Write-Host "Domain DN:    $domainDN" -ForegroundColor Cyan
Write-Host "gMSA Name:    $AccountName" -ForegroundColor Cyan
Write-Host "DNS Hostname: $DNSHostName" -ForegroundColor Cyan
Write-Host ''
#endregion

#region Step 1: KDS Root Key
Write-Host '[Step 1/4] Checking KDS Root Key...' -ForegroundColor Cyan

$kdsKeys = Get-KdsRootKey -ErrorAction SilentlyContinue
if ($kdsKeys) {
    # Verify at least one key is effective (EffectiveTime <= now)
    $effectiveKey = $kdsKeys | Where-Object { $_.EffectiveTime -le (Get-Date) }
    if ($effectiveKey) {
        Write-Host '  KDS Root Key already exists and is effective.' -ForegroundColor Green
    } else {
        Write-Host '  KDS Root Key exists but is not yet effective. It may need up to 10 hours to replicate.' -ForegroundColor Yellow
        Write-Host '  For lab/test environments, you can use: Add-KdsRootKey -EffectiveImmediately' -ForegroundColor Yellow
    }
} else {
    Write-Host '  No KDS Root Key found. Creating one...' -ForegroundColor Yellow

    if ($Force -or $PSCmdlet.ShouldProcess('KDS Root Key', 'Create')) {
        # In production, use -EffectiveTime ((Get-Date).AddHours(-10)) is NOT recommended.
        # The proper way is to create and wait for replication.
        Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10)) | Out-Null
        Write-Host '  KDS Root Key created with immediate effectiveness (lab shortcut).' -ForegroundColor Green
        Write-Host '  NOTE: In production, create the key and wait 10+ hours for replication.' -ForegroundColor Yellow
    }
}
#endregion

#region Step 2: Determine principals allowed to retrieve password
Write-Host ''
Write-Host '[Step 2/4] Resolving password retrieval principals...' -ForegroundColor Cyan

$principals = @()

if ($AllDomainControllers) {
    # Use the "Domain Controllers" group
    $dcGroup = Get-ADGroup 'Domain Controllers'
    $principals = @($dcGroup)
    Write-Host "  All Domain Controllers (via 'Domain Controllers' group)" -ForegroundColor Green
} elseif ($DomainControllers -and $DomainControllers.Count -gt 0) {
    foreach ($dcName in $DomainControllers) {
        try {
            $dcObj = Get-ADComputer $dcName -ErrorAction Stop
            $principals += $dcObj
            Write-Host "  Added: $($dcObj.Name)" -ForegroundColor Green
        } catch {
            Write-Warning "  Could not find computer object for '$dcName': $_"
        }
    }
} else {
    Write-Error 'Specify either -AllDomainControllers or -DomainControllers with a list of DC names.'
    return
}

if ($principals.Count -eq 0) {
    Write-Error 'No valid principals resolved. Cannot create gMSA.'
    return
}
#endregion

#region Step 3: Create gMSA
Write-Host ''
Write-Host '[Step 3/4] Creating gMSA account...' -ForegroundColor Cyan

$existingAccount = Get-ADServiceAccount -Filter "Name -eq '$AccountName'" -ErrorAction SilentlyContinue
if ($existingAccount) {
    Write-Host "  gMSA '$AccountName' already exists." -ForegroundColor Yellow

    if ($Force -or $PSCmdlet.ShouldProcess($AccountName, 'Update PrincipalsAllowedToRetrieveManagedPassword')) {
        Set-ADServiceAccount -Identity $AccountName -PrincipalsAllowedToRetrieveManagedPassword $principals
        Write-Host '  Updated PrincipalsAllowedToRetrieveManagedPassword.' -ForegroundColor Green
    }
} else {
    if ($Force -or $PSCmdlet.ShouldProcess($AccountName, 'Create gMSA')) {
        New-ADServiceAccount `
            -Name $AccountName `
            -DNSHostName $DNSHostName `
            -PrincipalsAllowedToRetrieveManagedPassword $principals `
            -Enabled $true `
            -Description 'gMSA for Microsoft Defender for Identity sensor' `
            -KerberosEncryptionType AES128, AES256

        Write-Host "  gMSA '$AccountName' created successfully." -ForegroundColor Green
    }
}
#endregion

#region Step 4: Validate
Write-Host ''
Write-Host '[Step 4/4] Validating gMSA...' -ForegroundColor Cyan

try {
    $testResult = Test-ADServiceAccount -Identity $AccountName -ErrorAction Stop
    if ($testResult) {
        Write-Host "  gMSA '$AccountName' validated successfully on this machine." -ForegroundColor Green
    } else {
        Write-Host "  gMSA '$AccountName' validation returned false. This DC may not have permission to retrieve the password." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Could not validate gMSA: $_" -ForegroundColor Yellow
    Write-Host "  Run 'Test-ADServiceAccount -Identity $AccountName' on a permitted DC to verify." -ForegroundColor Yellow
}
#endregion

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host " gMSA '$AccountName$' is ready for MDI sensor configuration." -ForegroundColor Green
Write-Host ' Use this account in the MDI sensor setup or portal.' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Cyan
