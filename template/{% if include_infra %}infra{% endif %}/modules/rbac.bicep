// Grants the SQL Server's system-assigned managed identity the "Storage Blob Data
// Contributor" role on the storage account, so CREATE EXTERNAL DATA SOURCE ... CREDENTIAL =
// [managed_identity] can actually read/write blobs. One assignment covers every database
// hosted on the server (they all share the server's identity).
//
// Deploying this requires Microsoft.Authorization/roleAssignments/write on the storage
// account (e.g. "User Access Administrator" or "Owner") — plain "Contributor" is NOT enough.
//
// NOTE: this module must be called with a `scope:` pointing at the storage account's
// resource group (main.bicep does this) — a resource can only be deployed at the scope
// of the containing module, so cross-RG storage accounts can't just be referenced via
// an `existing` resource with its own `scope:` here.

param storageAccountName string
param principalId string

@description('Which built-in storage role to grant the SQL Server identity')
@allowed([
  'StorageBlobDataContributor'
  'StorageBlobDataReader'
])
param storageRole string = 'StorageBlobDataContributor'

@description('Built-in role definition IDs (stable across all tenants/subscriptions)')
var roleDefinitionIds = {
  StorageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

resource existingStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// name: guid(...) makes this deterministic — re-running the deployment updates the same
// assignment in place instead of failing with a duplicate-assignment conflict.
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingStorage.id, principalId, roleDefinitionIds[storageRole])
  scope: existingStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds[storageRole])
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
