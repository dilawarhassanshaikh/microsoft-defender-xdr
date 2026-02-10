# Defender for Cloud Apps

Configuration automation starter toolkit for Microsoft Defender for Cloud Apps.

## Contents

- `prerequisites/Test-MDCAPrerequisites.ps1` - validates Graph module and execution environment.
- `deployment/Invoke-MDCADeployment.ps1` - applies a governance baseline tag to app registrations.
- `scripts/Start-MDCADeployment.ps1` - wrapper script for baseline deployment.

## Quick start

```powershell
.\prerequisites\Test-MDCAPrerequisites.ps1
.\scripts\Start-MDCADeployment.ps1 -TagName 'DefenderForCloudApps-Onboarded'
```
