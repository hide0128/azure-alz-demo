// ==============================================================================
// main.bicep - Azure VM Deployment Template
// Control 3.4 Automated Deployment Demo
// ==============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('VM name')
param vmName string = 'vm-demo'

@description('VM size')
param vmSize string = 'Standard_B2s'

@description('Admin username for the VM')
@secure()
param vmAdminUsername string

@description('Admin password for the VM')
@secure()
param vmAdminPassword string

// Variables
var vnetName = 'vnet-${vmName}'
var subnetName = 'snet-default'
var nicName = 'nic-${vmName}'
var nsgName = 'nsg-${vmName}'
var pipName = 'pip-${vmName}'

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Public IP
resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Outputs
output vmId string = vm.id
output publicIpAddress string = pip.properties.ipAddress

// === 意図的なエラー（デモ用） ===
resource invalid 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'test'
}
