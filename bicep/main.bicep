// ==============================================================================
// main.bicep - Azure Landing Zone Foundation Template
// Control 3.4 Automated Deployment Demo
// ==============================================================================

targetScope = 'resourceGroup'

// ==============================================================================
// Parameters
// ==============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, stg, prd)')
@allowed(['dev', 'stg', 'prd'])
param environment string = 'dev'

@description('Project or workload name')
param projectName string = 'lz-demo'

@description('VNet address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet configurations')
param subnets array = [
  {
    name: 'snet-web'
    addressPrefix: '10.0.1.0/24'
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.Sql']
  }
  {
    name: 'snet-app'
    addressPrefix: '10.0.2.0/24'
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.Sql']
  }
  {
    name: 'snet-db'
    addressPrefix: '10.0.3.0/24'
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.Sql']
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '10.0.255.0/26'
    serviceEndpoints: []
  }
]

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  Project: projectName
  ManagedBy: 'Bicep'
  CreatedDate: utcNow('yyyy-MM-dd')
}

// ==============================================================================
// Variables
// ==============================================================================

var namingPrefix = '${projectName}-${environment}'
var vnetName = 'vnet-${namingPrefix}'
var nsgWebName = 'nsg-${namingPrefix}-web'
var nsgAppName = 'nsg-${namingPrefix}-app'
var nsgDbName = 'nsg-${namingPrefix}-db'

// ==============================================================================
// Network Security Groups
// ==============================================================================

// NSG for Web Tier
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgWebName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// NSG for App Tier
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgAppName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowWebTier'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: '10.0.1.0/24'  // Web subnet
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// NSG for DB Tier
resource nsgDb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgDbName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowAppTier'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '10.0.2.0/24'  // App subnet
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ==============================================================================
// Virtual Network
// ==============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: subnets[0].name  // snet-web
        properties: {
          addressPrefix: subnets[0].addressPrefix
          networkSecurityGroup: {
            id: nsgWeb.id
          }
          serviceEndpoints: [for endpoint in subnets[0].serviceEndpoints: {
            service: endpoint
          }]
        }
      }
      {
        name: subnets[1].name  // snet-app
        properties: {
          addressPrefix: subnets[1].addressPrefix
          networkSecurityGroup: {
            id: nsgApp.id
          }
          serviceEndpoints: [for endpoint in subnets[1].serviceEndpoints: {
            service: endpoint
          }]
        }
      }
      {
        name: subnets[2].name  // snet-db
        properties: {
          addressPrefix: subnets[2].addressPrefix
          networkSecurityGroup: {
            id: nsgDb.id
          }
          serviceEndpoints: [for endpoint in subnets[2].serviceEndpoints: {
            service: endpoint
          }]
        }
      }
      {
        name: subnets[3].name  // AzureBastionSubnet
        properties: {
          addressPrefix: subnets[3].addressPrefix
        }
      }
    ]
  }
}

// ==============================================================================
// Outputs
// ==============================================================================

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds object = {
  web: vnet.properties.subnets[0].id
  app: vnet.properties.subnets[1].id
  db: vnet.properties.subnets[2].id
  bastion: vnet.properties.subnets[3].id
}
output nsgIds object = {
  web: nsgWeb.id
  app: nsgApp.id
  db: nsgDb.id
}
