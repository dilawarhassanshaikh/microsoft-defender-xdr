# Microsoft Defender XDR - Deployment Toolkit

Infrastructure-as-Code and automation scripts for deploying and configuring the Microsoft Defender XDR suite.

## Repository Structure

| Folder | Defender Product | Status |
|--------|-----------------|--------|
| `defender-for-identity/` | Microsoft Defender for Identity | In Progress |
| `defender-for-endpoint/` | Microsoft Defender for Endpoint | Planned |
| `defender-for-office365/` | Microsoft Defender for Office 365 | Planned |
| `defender-for-cloud-apps/` | Microsoft Defender for Cloud Apps | Planned |
| `defender-vulnerability-management/` | Microsoft Defender Vulnerability Management | Planned |
| `defender-xdr-portal/` | Unified XDR Portal (Hunting, Automation) | Planned |
| `common/` | Shared modules and helper functions | Planned |

## Getting Started

Each product folder contains:

- **prerequisites/** - Scripts to validate environment readiness
- **bicep/** or **configuration/** - Infrastructure-as-Code templates
- **scripts/** - PowerShell automation for deployment and configuration
- **docs/** - Product-specific documentation

Start with the prerequisites checker for any product before running deployments.

## Requirements

- PowerShell 7.x or Windows PowerShell 5.1
- Azure CLI or Az PowerShell module (for Bicep deployments)
- Appropriate Azure AD / Entra ID permissions
- Domain Admin or equivalent for on-premises sensor deployments

## License

MIT License - see [LICENSE](LICENSE) for details.
