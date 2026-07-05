// ============================================================================
// Microsoft Sentinel - Workspace, Onboarding & Defender XDR Data Connectors
// ============================================================================
// Deploys the Azure resources required to run Microsoft Sentinel as the SIEM
// layer over Microsoft Defender XDR:
//   - Log Analytics Workspace (Sentinel's underlying data store)
//   - Microsoft Sentinel onboarding (SecurityInsights solution)
//   - Data connector: Microsoft Defender XDR (unified incidents & alerts from
//     Defender for Endpoint, Defender for Identity, Defender for Office 365,
//     Defender for Cloud Apps and Defender Vulnerability Management)
//   - Data connector: Microsoft Entra ID (sign-in & audit logs)
//   - Fusion analytics rule (built-in ML correlation across connected sources)
//
// Usage:
//   az deployment group create \
//     --resource-group rg-sentinel \
//     --template-file main.bicep \
//     --parameters main.parameters.json
// ============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used in resource naming (e.g., prod, dev, test).')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Base name prefix for resources.')
param namePrefix string = 'sentinel'

@description('Log Analytics workspace retention in days. Sentinel requires the workspace the SecurityInsights solution is attached to.')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 90

@description('Microsoft Entra (Azure AD) tenant ID that Defender XDR and Sentinel both trust. Required by the Defender XDR data connector.')
param tenantId string = tenant().tenantId

@description('Enable the unified Microsoft Defender XDR incidents & alerts connector (kind: MicrosoftThreatProtection).')
param enableDefenderXdrConnector bool = true

@description('Enable the Microsoft Entra ID sign-in and audit log connector.')
param enableEntraIdConnector bool = true

@description('Enable the built-in Fusion ML rule for multi-stage attack detection correlating signals across connected Defender products.')
param enableFusionRule bool = true

@description('Tags applied to all resources.')
param tags object = {
  project: 'Microsoft Sentinel'
  managedBy: 'Bicep'
}

// ---------------------------------------------------------------
// Variables
// ---------------------------------------------------------------

var uniqueSuffix = uniqueString(resourceGroup().id)
var workspaceName = '${namePrefix}-law-${environment}-${uniqueSuffix}'

// ---------------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------------

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ---------------------------------------------------------------
// Microsoft Sentinel onboarding (SecurityInsights solution)
// ---------------------------------------------------------------

resource sentinelSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  plan: {
    name: 'SecurityInsights(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource sentinelOnboarding 'Microsoft.SecurityInsights/onboardingStates@2024-03-01' = {
  scope: logAnalyticsWorkspace
  name: 'default'
  properties: {}
  dependsOn: [
    sentinelSolution
  ]
}

// ---------------------------------------------------------------
// Data Connector: Microsoft Defender XDR (unified connector)
// ---------------------------------------------------------------
// This single connector streams SecurityIncident and SecurityAlert tables
// covering Defender for Endpoint, Defender for Identity, Defender for
// Office 365, Defender for Cloud Apps and Defender Vulnerability Management.
// It is the primary bridge between the Defender XDR portal's incident queue
// and Sentinel's incident queue - once enabled, incidents are bi-directionally
// synced (status, severity, owner, comments) between both experiences.

resource defenderXdrConnector 'Microsoft.SecurityInsights/dataConnectors@2024-03-01' = if (enableDefenderXdrConnector) {
  scope: logAnalyticsWorkspace
  name: guid(logAnalyticsWorkspace.id, 'MicrosoftThreatProtection')
  kind: 'MicrosoftThreatProtection'
  properties: {
    tenantId: tenantId
    dataTypes: {
      incidents: {
        state: 'Enabled'
      }
    }
  }
  dependsOn: [
    sentinelOnboarding
  ]
}

// ---------------------------------------------------------------
// Data Connector: Microsoft Entra ID (sign-in & audit logs)
// ---------------------------------------------------------------
// Feeds SigninLogs / AuditLogs, correlating identity signal-ins with Defender
// for Identity's IdentityLogonEvents for end-to-end identity investigations.

resource entraIdConnector 'Microsoft.SecurityInsights/dataConnectors@2024-03-01' = if (enableEntraIdConnector) {
  scope: logAnalyticsWorkspace
  name: guid(logAnalyticsWorkspace.id, 'AzureActiveDirectory')
  kind: 'AzureActiveDirectory'
  properties: {
    tenantId: tenantId
    dataTypes: {
      alerts: {
        state: 'Enabled'
      }
    }
  }
  dependsOn: [
    sentinelOnboarding
  ]
}

// ---------------------------------------------------------------
// Analytics Rule: Fusion (built-in multi-stage attack correlation)
// ---------------------------------------------------------------
// Fusion correlates low-fidelity signals across every connected data source
// (Defender XDR products + Entra ID) into a single high-confidence incident,
// which is what allows Sentinel to detect attack chains that span endpoint,
// identity, email and cloud-app stages that no single Defender product would
// flag as critical on its own.

resource fusionRule 'Microsoft.SecurityInsights/alertRules@2024-03-01' = if (enableFusionRule) {
  scope: logAnalyticsWorkspace
  name: guid(logAnalyticsWorkspace.id, 'Fusion')
  kind: 'Fusion'
  properties: {
    enabled: true
    alertRuleTemplateName: 'f71aba3d-28fb-450b-b192-4e76a83015c8'
  }
  dependsOn: [
    defenderXdrConnector
    entraIdConnector
  ]
}

// ---------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------

@description('Log Analytics Workspace resource ID (attach this in the Defender XDR portal under Settings > Microsoft Sentinel).')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics Workspace name.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('Microsoft Defender XDR data connector resource ID (if deployed).')
output defenderXdrConnectorId string = enableDefenderXdrConnector ? defenderXdrConnector.id : 'Not deployed'

@description('Microsoft Entra ID data connector resource ID (if deployed).')
output entraIdConnectorId string = enableEntraIdConnector ? entraIdConnector.id : 'Not deployed'
