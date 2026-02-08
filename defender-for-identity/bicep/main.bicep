// ============================================================================
// Microsoft Defender for Identity - Supporting Azure Infrastructure
// ============================================================================
// Deploys Azure resources that support an MDI sensor deployment:
//   - Log Analytics Workspace (for MDI signal forwarding / Sentinel integration)
//   - Event Hub Namespace (optional SIEM forwarding)
//   - Network Security Group with MDI-required outbound rules
//   - Action Group for sensor health alerts
//
// Usage:
//   az deployment group create \
//     --resource-group rg-mdi \
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
param namePrefix string = 'mdi'

@description('Log Analytics workspace retention in days.')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 90

@description('Deploy Event Hub for SIEM forwarding.')
param deploySiemForwarding bool = false

@description('Email address for alert notifications.')
param alertEmail string

@description('Tags applied to all resources.')
param tags object = {
  project: 'Microsoft Defender for Identity'
  managedBy: 'Bicep'
}

// ---------------------------------------------------------------
// Variables
// ---------------------------------------------------------------

var uniqueSuffix = uniqueString(resourceGroup().id)
var workspaceName = '${namePrefix}-law-${environment}-${uniqueSuffix}'
var eventHubNamespaceName = '${namePrefix}-evhns-${environment}-${uniqueSuffix}'
var nsgName = '${namePrefix}-nsg-dc-${environment}'
var actionGroupName = '${namePrefix}-ag-sensor-health'

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
    workspaceCapping: {
      dailyQuotaGb: -1 // unlimited
    }
  }
}

// Microsoft Defender for Identity solution on the workspace
resource mdiSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
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

// ---------------------------------------------------------------
// Event Hub Namespace (optional SIEM forwarding)
// ---------------------------------------------------------------

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = if (deploySiemForwarding) {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 4
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (deploySiemForwarding) {
  parent: eventHubNamespace
  name: 'mdi-alerts'
  properties: {
    messageRetentionInDays: 7
    partitionCount: 2
  }
}

// ---------------------------------------------------------------
// Network Security Group - Outbound rules for MDI sensor
// ---------------------------------------------------------------
// These rules should be applied to the subnet/NIC of Azure-hosted
// Domain Controllers running the MDI sensor.

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-MDI-Sensor-HTTPS-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureCloud'
          description: 'Allow MDI sensor outbound HTTPS to Azure services (*.atp.azure.com)'
        }
      }
      {
        name: 'Allow-DNS-Outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          description: 'Allow DNS resolution for MDI endpoints'
        }
      }
      {
        name: 'Allow-NTP-Outbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '123'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          description: 'Allow NTP for time synchronization'
        }
      }
      {
        name: 'Allow-Internal-SensorPort'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '444'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          description: 'Allow internal MDI sensor communication on port 444'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------
// Action Group for Sensor Health Alerts
// ---------------------------------------------------------------

resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'MDISensor'
    enabled: true
    emailReceivers: [
      {
        name: 'MDI-Admin'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// ---------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------

@description('Log Analytics Workspace resource ID.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics Workspace name.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('NSG resource ID to attach to DC subnets.')
output nsgId string = nsg.id

@description('Event Hub Namespace connection string (if deployed).')
output eventHubNamespaceId string = deploySiemForwarding ? eventHubNamespace.id : 'Not deployed'

@description('Action Group resource ID for alert rules.')
output actionGroupId string = actionGroup.id
