// Single reusable serverless General Purpose database. Instantiated once per environment
// (prod/dev/test) from main.bicep, each call gated by its own boolean toggle.

param serverName string
param databaseName string
param location string

param skuName string
@description('vCores, supports fractional values (e.g. 0.5, 1.5) for serverless tiers')
param minCapacity string
param maxSizeBytes int = 34359738368 // 32 GB
param autoPauseDelay int = 60
param backupStorageRedundancy string = 'Geo'

resource db 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  name: '${serverName}/${databaseName}'
  location: location
  sku: {
    name: skuName
    tier: 'GeneralPurpose'
  }
  properties: {
    autoPauseDelay: autoPauseDelay
    minCapacity: json(minCapacity)
    maxSizeBytes: maxSizeBytes
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: backupStorageRedundancy
  }
}

output databaseName string = db.name
