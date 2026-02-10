# Defender XDR Portal

Automation toolkit for baseline Microsoft Defender XDR portal hunting content.

## Contents

- `prerequisites/Test-XDRPortalPrerequisites.ps1` - validates Graph module and shell requirements.
- `deployment/Invoke-XDRPortalDeployment.ps1` - exports baseline KQL hunting queries.
- `scripts/Start-XDRPortalDeployment.ps1` - wrapper script for deployment.
- `dashboard/` - interactive, fluid Microsoft Security demo dashboard with product sub-dashboards, how-tos, and best practices.

## Quick start

```powershell
.\prerequisites\Test-XDRPortalPrerequisites.ps1
.\scripts\Start-XDRPortalDeployment.ps1 -QueriesOutputPath '.\xdr-hunting-queries.kql'
```

## Dashboard quick view

Use any static web server from the `dashboard` directory to preview the UI:

```bash
python3 -m http.server 8000
# open http://localhost:8000/index.html
```
