# Microsoft Defender for Identity - Deployment Toolkit

Automation scripts and Infrastructure-as-Code templates for deploying Microsoft Defender for Identity (MDI) sensors on Domain Controllers.

## What is Defender for Identity?

Microsoft Defender for Identity (formerly Azure ATP) monitors Active Directory signals to detect advanced threats, compromised identities, and malicious insider actions. It runs as a **sensor** installed directly on Domain Controllers (or AD FS servers).

## Repository Structure

```
defender-for-identity/
├── prerequisites/
│   ├── Test-MDIPrerequisites.ps1    # Validate DC readiness before installation
│   └── Set-MDIAuditPolicy.ps1      # Configure required Windows audit policies
├── scripts/
│   └── New-MDIgMSAAccount.ps1      # Create gMSA account for the sensor
├── sensor-deployment/
│   └── Install-MDISensor.ps1        # Download & silently install the sensor
├── bicep/
│   ├── main.bicep                   # Azure supporting infrastructure (Log Analytics, NSG, alerts)
│   └── main.parameters.json         # Parameter file for Bicep deployment
└── docs/
    └── (future detailed guides)
```

## Prerequisites

Before installing the MDI sensor, the following must be in place:

### Environment Requirements

| Requirement | Detail |
|-------------|--------|
| **Operating System** | Windows Server 2016 or later |
| **Role** | Machine must be a Domain Controller or AD FS server |
| **RAM** | Minimum 6 GB |
| **CPU** | Minimum 2 cores |
| **Disk** | Minimum 6 GB free on the system drive |
| **.NET Framework** | 4.7 or later |
| **Power Plan** | High Performance recommended |

### Network Requirements

| Direction | Port | Protocol | Destination | Purpose |
|-----------|------|----------|-------------|---------|
| Outbound | 443 | TCP | `*.atp.azure.com` | Sensor-to-cloud communication |
| Outbound | 443 | TCP | `*.blob.core.windows.net` | Package download |
| Outbound | 53 | TCP/UDP | DNS servers | Name resolution |
| Outbound | 123 | UDP | NTP servers | Time synchronization |
| Internal | 444 | TCP | Between DCs | Sensor internal communication |

### Required Windows Services

- Active Directory Domain Services (NTDS)
- Netlogon
- Windows Time (W32Time)
- DNS Server (if role is installed)

### Required Audit Policies

MDI depends on specific Windows Security Event logs. The `Set-MDIAuditPolicy.ps1` script configures:

- **Account Logon**: Credential Validation
- **Account Management**: Computer, Distribution Group, Security Group, User Account Management
- **DS Access**: Directory Service Access & Changes
- **Logon/Logoff**: Logon, Logoff, Special Logon, Other Events
- **Object Access**: SAM
- **System**: Security System Extension
- **NTLM Auditing**: Incoming and outgoing NTLM traffic

### MDI Workspace & Access Key

1. Ensure you have a Defender for Identity workspace in the Microsoft 365 Defender portal
2. Navigate to **Settings > Identities > Sensors** to obtain the **Access Key**

## Quick Start

### Step 1: Validate Prerequisites

```powershell
.\prerequisites\Test-MDIPrerequisites.ps1
```

This checks OS version, hardware, .NET, services, network connectivity, and gMSA readiness. Fix any `[FAIL]` items before proceeding.

### Step 2: Configure Audit Policies

```powershell
# Apply locally on each DC
.\prerequisites\Set-MDIAuditPolicy.ps1

# Or create a GPO for domain-wide deployment
.\prerequisites\Set-MDIAuditPolicy.ps1 -GPOName 'MDI Audit Policy'
```

### Step 3: Create gMSA Account (Recommended)

```powershell
# Grant all DCs permission to use the gMSA
.\scripts\New-MDIgMSAAccount.ps1 -AccountName 'MDISensor' -AllDomainControllers

# Or limit to specific DCs
.\scripts\New-MDIgMSAAccount.ps1 -AccountName 'MDISensor' -DomainControllers 'DC01','DC02'
```

### Step 4: Deploy Azure Supporting Infrastructure (Optional)

```powershell
# Deploy Log Analytics, NSG, Event Hub, and alert action group
az deployment group create \
  --resource-group rg-mdi \
  --template-file bicep/main.bicep \
  --parameters bicep/main.parameters.json
```

### Step 5: Install the Sensor

```powershell
# Download and install (provide your workspace name and access key)
.\sensor-deployment\Install-MDISensor.ps1 \
  -AccessKey 'YOUR_BASE64_ACCESS_KEY' \
  -WorkspaceName 'contoso'

# Or install from a pre-downloaded package
.\sensor-deployment\Install-MDISensor.ps1 \
  -AccessKey 'YOUR_BASE64_ACCESS_KEY' \
  -InstallerPath 'C:\temp\sensor.zip'
```

### Step 6: Verify in Portal

After installation, the sensor appears in the MDI portal under **Settings > Identities > Sensors** within a few minutes. Verify the health status shows as **Running**.

## Bicep Infrastructure

The `bicep/main.bicep` template deploys Azure resources that complement an MDI deployment:

| Resource | Purpose |
|----------|---------|
| **Log Analytics Workspace** | Central log storage, Microsoft Sentinel integration |
| **Sentinel Solution** | Enables SecurityInsights on the workspace |
| **Event Hub** (optional) | SIEM forwarding for third-party integration |
| **NSG** | Pre-configured outbound rules for Azure-hosted DCs |
| **Action Group** | Email alerts for sensor health monitoring |

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| Sensor service not starting | Check `.NET 4.7+` is installed, verify access key, review logs in `%ProgramFiles%\Azure Advanced Threat Protection Sensor\Logs` |
| No data in portal | Verify audit policies with `auditpol /get /category:*`, ensure outbound 443 to `*.atp.azure.com` is open |
| gMSA validation fails | Run `Test-ADServiceAccount -Identity MDISensor` on the DC, verify KDS Root Key is replicated |
| High memory usage | Normal for DCs with high authentication volume; ensure DC meets minimum RAM requirements |

## References

- [Microsoft Defender for Identity documentation](https://learn.microsoft.com/en-us/defender-for-identity/)
- [MDI prerequisites](https://learn.microsoft.com/en-us/defender-for-identity/prerequisites)
- [Configure Windows Event collection](https://learn.microsoft.com/en-us/defender-for-identity/configure-windows-event-collection)
- [gMSA accounts for MDI](https://learn.microsoft.com/en-us/defender-for-identity/directory-service-accounts)
