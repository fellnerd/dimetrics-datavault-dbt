// Storage account for staged source files (ADLS Gen2). Either creates a new account +
// container, or resolves an existing one (possibly in a different resource group) so the
// RBAC module can target it either way.

param createStorageAccount bool
param storageAccountName string
param storageContainerName string
param location string
param existingStorageAccountResourceGroup string

resource newStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = if (createStorageAccount) {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true // ADLS Gen2 hierarchical namespace
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource newContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = if (createStorageAccount) {
  name: '${storageAccountName}/default/${storageContainerName}'
  dependsOn: [
    newStorage
  ]
}

output storageAccountName string = storageAccountName
output storageAccountResourceGroup string = createStorageAccount ? resourceGroup().name : existingStorageAccountResourceGroup
