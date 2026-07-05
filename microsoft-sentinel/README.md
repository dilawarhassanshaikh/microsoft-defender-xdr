# Microsoft Sentinel Integration

Infrastructure-as-Code and automation scripts for deploying Microsoft Sentinel as the cloud-native SIEM/SOAR layer over the Microsoft Defender XDR suite in this repository (Defender for Endpoint, Defender for Identity, Defender for Office 365, Defender for Cloud Apps, and Defender Vulnerability Management).

## What is Microsoft Sentinel?

Microsoft Sentinel is a cloud-native **SIEM** (Security Information and Event Management) and **SOAR** (Security Orchestration, Automation and Response) platform built on Azure Log Analytics. It ingests security telemetry from Microsoft and third-party sources into a single Log Analytics workspace, correlates it with analytics rules, and provides incident management, hunting (KQL), workbooks (dashboards), and automated response (playbooks built on Azure Logic Apps).

Unlike the individual Defender products, which each protect one workload (endpoint, identity, email, cloud apps), Sentinel's role is **horizontal**: it aggregates and correlates signal *across* every workload, plus non-Microsoft sources (firewalls, on-prem servers, other clouds, SaaS apps) that Defender XDR itself does not ingest.

## How Sentinel Connects to the Microsoft Defender XDR Platform

Microsoft Defender XDR (`security.microsoft.com`) and Microsoft Sentinel are two halves of Microsoft's **unified security operations platform**. Since 2023 they can run in the *same portal*, sharing one incident queue, one set of advanced hunting tables, and one automation surface. The integration is not a one-time export/import — it is a live, bi-directional data and control plane. The steps below describe exactly how the connection is established and what flows across it.

### Step 1 — Provision the Log Analytics workspace and onboard Sentinel

Sentinel is not a standalone resource; it is the `SecurityInsights` solution layered on top of a Log Analytics workspace. `bicep/main.bicep` in this folder deploys:

- A **Log Analytics Workspace** (the data store all connectors write into).
- The **SecurityInsights** solution (`Microsoft.OperationsManagement/solutions`) — this is what turns a plain workspace into a Sentinel workspace.
- A `Microsoft.SecurityInsights/onboardingStates` resource, which is the formal Sentinel onboarding record Azure RBAC and the Defender portal both check.

### Step 2 — Attach the workspace inside the Defender XDR portal

Once the workspace exists, an admin with **Global Administrator** or **Security Administrator** rights connects it from inside `security.microsoft.com`:

1. Go to **Settings → Microsoft Sentinel** in the Defender XDR portal.
2. Select **Connect a workspace** and pick the workspace created in Step 1 (or paste its resource ID, output as `logAnalyticsWorkspaceId` by the Bicep template).
3. Confirm the tenant matches the Defender XDR tenant (`tenantId` parameter) — Sentinel and Defender XDR must trust the same Microsoft Entra ID tenant for the unified experience to activate.

After this step, Sentinel's incidents, hunting tables, and workbooks all become navigable **inside the Defender XDR portal itself** — there is no separate sign-in or context switch for analysts.

### Step 3 — Enable the Microsoft Defender XDR data connector

This is the core of the integration, deployed by `bicep/main.bicep` as the `defenderXdrConnector` resource (`kind: MicrosoftThreatProtection`):

- It streams the `SecurityIncident` and `SecurityAlert` tables into the Sentinel workspace.
- These tables are the **unified** representation of every alert/incident already raised by Defender for Endpoint, Defender for Identity, Defender for Office 365, Defender for Cloud Apps, and Defender Vulnerability Management — Defender XDR has already correlated per-product alerts into an incident before Sentinel ever sees it.
- Enabling this connector is what activates **bi-directional incident sync**: an analyst who changes an incident's status, severity, classification, or adds a comment in *either* portal (Sentinel or Defender XDR) sees that change reflected in the other within minutes.

### Step 4 — Connect the underlying raw-signal connectors (optional but recommended)

The unified connector in Step 3 carries correlated incidents/alerts, but not the raw per-event telemetry each Defender product generates. For deep hunting, connect the raw tables directly:

| Connector | Raw tables it feeds | Source Defender product |
|---|---|---|
| Microsoft Entra ID | `SigninLogs`, `AuditLogs`, `AADNonInteractiveUserSignInLogs` | Identity (sign-in plane) |
| Microsoft Defender for Endpoint (via Defender XDR connector's advanced hunting tables) | `DeviceEvents`, `DeviceProcessEvents`, `DeviceNetworkEvents`, `DeviceFileEvents` | `defender-for-endpoint/` |
| Microsoft Defender for Identity (via advanced hunting) | `IdentityLogonEvents`, `IdentityDirectoryEvents`, `IdentityQueryEvents` | `defender-for-identity/` |
| Microsoft Defender for Office 365 (via advanced hunting) | `EmailEvents`, `EmailAttachmentInfo`, `EmailUrlInfo` | `defender-for-office365/` |
| Microsoft Defender for Cloud Apps (via advanced hunting) | `CloudAppEvents` | `defender-for-cloud-apps/` |

These advanced hunting tables are mirrored into the Sentinel workspace automatically once the unified Defender XDR connector (Step 3) is enabled with the corresponding raw-data toggle — no separate connector deployment is required for the M365 Defender-native tables, only for Entra ID sign-in/audit logs, which `bicep/main.bicep` deploys as the `entraIdConnector` resource.

### Step 5 — Correlate across products with Fusion and analytics rules

`bicep/main.bicep` deploys a **Fusion** analytics rule (`kind: Fusion`), Sentinel's built-in ML correlation engine. Fusion is the clearest illustration of *why* the Sentinel/XDR connection matters: it looks for low-fidelity signals spread across multiple connected sources — e.g., an anomalous sign-in from Entra ID, a suspicious PowerShell execution from Defender for Endpoint, and a mailbox rule change from Defender for Office 365 — and fuses them into a single high-confidence incident that no individual Defender product would escalate on its own.

Custom **scheduled analytics rules** can be authored with KQL joining tables across products, for example:

```kql
// Endpoint compromise followed by suspicious mailbox forwarding rule (cross-product correlation)
DeviceProcessEvents
| where Timestamp > ago(1h)
| where FileName =~ "powershell.exe" and ProcessCommandLine has "EncodedCommand"
| join kind=inner (
    EmailEvents
    | where Timestamp > ago(1h)
) on $left.AccountUpn == $right.SenderFromAddress
```

### Step 6 — Automated response across both surfaces

Two automation layers now operate on the same incident:

- **Defender XDR Automated Investigation & Response (AIR)** — native, per-product playbooks (e.g., auto-remediate a malicious file on a device, auto-quarantine a phishing email).
- **Sentinel Automation Rules + Playbooks (Azure Logic Apps)** — triggered off the same unified `SecurityIncident` table, able to call out to ServiceNow, Teams, Jira, or any REST API, and able to write back to the Defender XDR incident (close it, tag it, assign it) via the Microsoft Graph Security API.

Because both automation layers write to the same underlying incident object, a Sentinel playbook closing an incident is reflected as closed in the Defender XDR portal, and vice versa.

### Step 7 — Unified role-based access control (RBAC)

Access is governed by two systems that the unified platform reconciles:

- **Azure RBAC** on the Log Analytics workspace/resource group (e.g., *Microsoft Sentinel Contributor*, *Microsoft Sentinel Reader*) — controls Sentinel-specific actions (analytics rules, playbooks, workbooks).
- **Microsoft Defender XDR unified RBAC** (Security Administrator, Security Operator, custom roles) — controls incident/alert visibility and response actions across all connected Defender products and Sentinel from the single `security.microsoft.com` portal.

### Data flow summary

```
 Defender for Endpoint ─┐
 Defender for Identity ─┤
 Defender for Office365─┼──▶  Microsoft Defender XDR  ──▶  SecurityIncident / SecurityAlert  ──▶  Microsoft Sentinel
 Defender for Cloud Apps┤        (correlation engine)         (unified connector, Step 3)      (Log Analytics workspace)
 Defender Vuln Mgmt ────┘                 ▲                                                              │
                                          │                                                              ▼
                              Entra ID sign-in/audit logs ◀── entraIdConnector            Fusion / custom analytics rules
                                                                                                          │
                                                                                                          ▼
                                                                                        Automation rules, playbooks,
                                                                                        hunting, workbooks (bi-directional
                                                                                        incident sync back to Defender XDR)
```

## Repository Structure

```
microsoft-sentinel/
├── prerequisites/
│   └── Test-SentinelPrerequisites.ps1   # Validates tooling, modules, and Azure CLI auth
├── deployment/
│   └── Invoke-SentinelDeployment.ps1    # Runs the Bicep deployment end-to-end
├── scripts/
│   └── Start-SentinelDeployment.ps1     # Wrapper: prerequisites + deployment
└── bicep/
    ├── main.bicep                        # Workspace, Sentinel onboarding, connectors, Fusion rule
    └── main.parameters.json              # Parameter file for the Bicep deployment
```

## Prerequisites

| Requirement | Detail |
|---|---|
| **Licensing** | Microsoft Defender XDR license (E5 or equivalent add-ons) and an Azure subscription for the Sentinel workspace (pay-as-you-go ingestion/retention) |
| **Tooling** | PowerShell 7+, Azure CLI, `Az.SecurityInsights` and `Az.OperationalInsights` PowerShell modules |
| **Permissions to deploy Azure resources** | *Contributor* (or *Microsoft Sentinel Contributor*) on the target resource group |
| **Permissions to connect Defender XDR** | *Global Administrator* or *Security Administrator* in Microsoft Entra ID |
| **Tenant alignment** | The Log Analytics workspace's Azure subscription must belong to the same Microsoft Entra ID tenant as the Defender XDR deployment |

Run the prerequisites checker before deploying:

```powershell
.\prerequisites\Test-SentinelPrerequisites.ps1
```

## Quick Start

### Step 1: Validate prerequisites

```powershell
.\prerequisites\Test-SentinelPrerequisites.ps1
```

### Step 2: Deploy the Sentinel workspace and connectors

```powershell
.\scripts\Start-SentinelDeployment.ps1 -ResourceGroupName 'rg-sentinel'
```

Or run the deployment directly (e.g., in CI) without the wrapper:

```powershell
.\deployment\Invoke-SentinelDeployment.ps1 -ResourceGroupName 'rg-sentinel'
```

### Step 3: Attach the workspace in the Defender XDR portal

1. Sign in to [security.microsoft.com](https://security.microsoft.com) with a Security Administrator account.
2. Navigate to **Settings → Microsoft Sentinel → Connect a workspace**.
3. Select the workspace deployed in Step 2 (name is emitted as an output of the Bicep deployment).

### Step 4: Verify the connection

- In the Defender XDR portal, go to **Incidents & alerts** and confirm incidents show a **Sentinel** badge/source.
- In Sentinel (either standalone at `portal.azure.com` or embedded in `security.microsoft.com`), go to **Data connectors** and confirm **Microsoft Defender XDR** shows status **Connected**.
- Run a quick advanced hunting query to confirm cross-product tables are populated:

```kql
union SecurityIncident, SecurityAlert, DeviceProcessEvents, IdentityLogonEvents, EmailEvents, CloudAppEvents
| where TimeGenerated > ago(1h)
| summarize count() by Type
```

## Troubleshooting

| Issue | Resolution |
|---|---|
| "Connect a workspace" option is greyed out in Defender XDR portal | Confirm the signed-in account has Global Administrator or Security Administrator rights, and that the workspace's subscription is in the same tenant |
| Defender XDR connector shows "Not connected" after deployment | Re-run `az deployment group create` and check the `defenderXdrConnector` resource's provisioning state; ensure `tenantId` parameter matches the Defender XDR tenant |
| No advanced hunting tables (`DeviceEvents`, `EmailEvents`, etc.) appear in Sentinel | These populate only after the unified Defender XDR connector is enabled *and* the individual Defender products are actively generating telemetry — verify each product's onboarding status in `defender-for-endpoint/`, `defender-for-identity/`, etc. |
| Fusion rule not firing | Fusion requires at least two connected, active data sources with correlatable signal; confirm both `defenderXdrConnector` and `entraIdConnector` show status **Connected** |
| Incident status changes not syncing between portals | Sync typically takes a few minutes; if it never syncs, confirm the connector's `dataTypes.incidents.state` is `Enabled` (not just alerts) |

## References

- [Microsoft Sentinel overview](https://learn.microsoft.com/en-us/azure/sentinel/overview)
- [Connect Microsoft Defender XDR data to Microsoft Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/connect-microsoft-365-defender)
- [The unified security operations platform](https://learn.microsoft.com/en-us/unified-secops-platform/overview)
- [Fusion correlation in Microsoft Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/fusion)
- [Microsoft Defender XDR advanced hunting schema reference](https://learn.microsoft.com/en-us/microsoft-365/security/defender/advanced-hunting-schema-tables)
- [Roles and permissions in Microsoft Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/roles)
