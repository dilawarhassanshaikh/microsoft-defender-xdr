# Defender for Endpoint

Deployment and onboarding automation for Microsoft Defender for Endpoint.

## Contents

- `prerequisites/Test-MDEPrerequisites.ps1` - validates endpoint readiness.
- `deployment/Invoke-MDEDeployment.ps1` - runs onboarding package deployment.
- `scripts/Start-MDEDeployment.ps1` - wrapper to run prerequisite + deployment flow.

## Quick start

```powershell
.\prerequisites\Test-MDEPrerequisites.ps1
.\scripts\Start-MDEDeployment.ps1 -OnboardingPackagePath 'C:\temp\WindowsDefenderATPOnboardingScript.cmd'
```
