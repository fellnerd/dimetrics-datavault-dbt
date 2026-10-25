// Provisions the SQL Server, up to three databases (prod/dev/test, individually toggleable),
// a storage account for staged source files (new or existing), and the RBAC role assignment
// needed for managed-identity-based external data sources.
//
// Deploy with: az deployment group create --resource-group <rg> --template-file main.bicep
// (see ../.github/workflows/infra-deploy.yml for the automated version, and
// ../scripts/setup_external_source.sql for the T-SQL that must run after this deployment).

targetScope = 'resourceGroup'

// ---- General ----
param location string = 'westeurope'
param sqlServerName string

// ---- AAD Admin (group-based) ----
param aadAdminGroupName string
param aadAdminGroupObjectId string
param aadTenantId string = subscription().tenantId

// ---- Secondary SQL admin login (SQL auth, in addition to the AAD-only admin) ----
param sqlAdminLogin string = 'sqladmin'

@secure()
param sqlAdminPassword string

// ---- Firewall ----
param allowAzureServices bool = true
param allowAllIps bool = false

// ---- Database toggles ----
param deploySqlDatavault bool = true
param deploySqlDatavaultDev bool = true
param deploySqlDatavaultTest bool = true

param databaseBaseName string = 'datavault'

// ---- Database SKUs (serverless General Purpose, per-environment defaults) ----
param prodSkuName string = 'GP_S_Gen5_6'
param prodMinCapacity string = '1.5'

param devSkuName string = 'GP_S_Gen5_2'
param devMinCapacity string = '0.5'

param testSkuName string = 'GP_S_Gen5_4'
param testMinCapacity string = '1'

param autoPauseDelay int = 60
param backupStorageRedundancy string = 'Geo'

// ---- Storage account (new vs existing) ----
param createStorageAccount bool = true
param storageAccountName string
param storageContainerName string = 'stage-fs'
param existingStorageAccountResourceGroup string = resourceGroup().name

// ---- Storage role assigned to the SQL Server's managed identity ----
@allowed([
  'StorageBlobDataContributor'
  'StorageBlobDataReader'
])
param storageRole string = 'StorageBlobDataContributor'

// Must be computable at the start of deployment (not a module output) since it's used
// for a module's `scope:` — see the rbac module call below.
var storageResourceGroupName = createStorageAccount ? resourceGroup().name : existingStorageAccountResourceGroup

module sqlServer 'modules/sql-server.bicep' = {
  name: 'deploy-sql-server'
  params: {
    location: location
    sqlServerName: sqlServerName
    aadAdminGroupName: aadAdminGroupName
    aadAdminGroupObjectId: aadAdminGroupObjectId
    aadTenantId: aadTenantId
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    allowAzureServices: allowAzureServices
    allowAllIps: allowAllIps
  }
}

module dbProd 'modules/sql-database.bicep' = if (deploySqlDatavault) {
  name: 'deploy-db-prod'
  params: {
    serverName: sqlServerName
    databaseName: databaseBaseName
    location: location
    skuName: prodSkuName
    minCapacity: prodMinCapacity
    autoPauseDelay: autoPauseDelay
    backupStorageRedundancy: backupStorageRedundancy
  }
  dependsOn: [
    sqlServer
  ]
}

module dbDev 'modules/sql-database.bicep' = if (deploySqlDatavaultDev) {
  name: 'deploy-db-dev'
  params: {
    serverName: sqlServerName
    databaseName: '${databaseBaseName}-dev'
    location: location
    skuName: devSkuName
    minCapacity: devMinCapacity
    autoPauseDelay: autoPauseDelay
    backupStorageRedundancy: backupStorageRedundancy
  }
  dependsOn: [
    sqlServer
  ]
}

module dbTest 'modules/sql-database.bicep' = if (deploySqlDatavaultTest) {
  name: 'deploy-db-test'
  params: {
    serverName: sqlServerName
    databaseName: '${databaseBaseName}-test'
    location: location
    skuName: testSkuName
    minCapacity: testMinCapacity
    autoPauseDelay: autoPauseDelay
    backupStorageRedundancy: backupStorageRedundancy
  }
  dependsOn: [
    sqlServer
  ]
}

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    createStorageAccount: createStorageAccount
    storageAccountName: storageAccountName
    storageContainerName: storageContainerName
    location: location
    existingStorageAccountResourceGroup: existingStorageAccountResourceGroup
  }
}

// Scoped to the storage account's own resource group (may differ from this deployment's
// RG when referencing an existing, cross-RG storage account) — a resource can only be
// deployed at the scope of its containing module, so this scope must be set here rather
// than via a `scope:` property on an `existing` resource inside rbac.bicep itself.
module rbac 'modules/rbac.bicep' = {
  name: 'deploy-rbac'
  scope: resourceGroup(storageResourceGroupName)
  params: {
    storageAccountName: storage.outputs.storageAccountName
    principalId: sqlServer.outputs.sqlServerPrincipalId
    storageRole: storageRole
  }
}

output sqlServerFqdn string = sqlServer.outputs.sqlServerFqdn
output deployedDatabases array = [
  deploySqlDatavault ? databaseBaseName : ''
  deploySqlDatavaultDev ? '${databaseBaseName}-dev' : ''
  deploySqlDatavaultTest ? '${databaseBaseName}-test' : ''
]
