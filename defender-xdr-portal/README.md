# Defender XDR Portal

Automation toolkit for baseline Microsoft Defender XDR portal hunting content.

## Contents

- `prerequisites/Test-XDRPortalPrerequisites.ps1` - validates Graph module and shell requirements.
- `deployment/Invoke-XDRPortalDeployment.ps1` - exports baseline KQL hunting queries.
- `scripts/Start-XDRPortalDeployment.ps1` - wrapper script for deployment.

## Quick start

```powershell
.\prerequisites\Test-XDRPortalPrerequisites.ps1
.\scripts\Start-XDRPortalDeployment.ps1 -QueriesOutputPath '.\xdr-hunting-queries.kql'
```
