# Defender for Office 365

Configuration automation for Microsoft Defender for Office 365 baseline policies.

## Contents

- `prerequisites/Test-MDOPrerequisites.ps1` - checks required PowerShell module availability.
- `deployment/Invoke-MDODeployment.ps1` - deploys baseline Safe Links and Safe Attachments policies.
- `scripts/Start-MDODeployment.ps1` - wrapper script for full deployment.

## Quick start

```powershell
.\prerequisites\Test-MDOPrerequisites.ps1
.\scripts\Start-MDODeployment.ps1 -PolicyPrefix 'Contoso-MDO'
```
