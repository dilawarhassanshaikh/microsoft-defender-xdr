# Microsoft Defender XDR - Deployment Toolkit

Infrastructure-as-Code and automation scripts for deploying and configuring the Microsoft Defender XDR suite.

## Repository Structure

| Folder | Defender Product | Status |
|--------|-----------------|--------|
| `defender-for-identity/` | Microsoft Defender for Identity | Implemented |
| `defender-for-endpoint/` | Microsoft Defender for Endpoint | Implemented |
| `defender-for-office365/` | Microsoft Defender for Office 365 | Implemented |
| `defender-for-cloud-apps/` | Microsoft Defender for Cloud Apps | Implemented |
| `defender-vulnerability-management/` | Microsoft Defender Vulnerability Management | Implemented |
| `defender-xdr-portal/` | Unified XDR Portal (Hunting, Automation) | Implemented |
| `security-framework-dashboard/` | Compliance dashboard mapping Defender to ISO 27001, CIS, NIST | Implemented |
| `common/` | Shared modules and helper functions | Planned |

## Getting Started

Each product folder contains deployment accelerators:

- **prerequisites/** - Scripts to validate environment readiness
- **deployment/** - Product deployment orchestration scripts
- **scripts/** - Wrapper scripts for standard execution flow
- **README.md** - Product-specific usage notes

Start with the prerequisites checker for any product before running deployments.

## Requirements

- PowerShell 7.x or Windows PowerShell 5.1
- Azure CLI or Az PowerShell module (for Bicep deployments)
- Appropriate Azure AD / Entra ID permissions
- Domain Admin or equivalent for on-premises sensor deployments

## License

MIT License - see [LICENSE](LICENSE) for details.
