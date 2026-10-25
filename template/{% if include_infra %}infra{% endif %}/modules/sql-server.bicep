// SQL logical server + AAD admin (group-based) + secondary SQL admin login + firewall rules.
// A single system-assigned managed identity is used for external-data-source access to
// storage, uniformly across every database hosted on this server.

param location string
param sqlServerName string

param aadAdminGroupName string
param aadAdminGroupObjectId string
param aadTenantId string

param sqlAdminLogin string

@secure()
param sqlAdminPassword string

param allowAzureServices bool = true
param allowAllIps bool = false

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: aadAdminGroupName
      sid: aadAdminGroupObjectId
      tenantId: aadTenantId
      azureADOnlyAuthentication: false
    }
  }
}

resource firewallAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (allowAzureServices) {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Opt-in only, NOT the default: opens the server to the entire internet, protected only by login credentials.
resource firewallOpenAll 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (allowAllIps) {
  parent: sqlServer
  name: 'AllowAll_OptIn_NotRecommended'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

output sqlServerId string = sqlServer.id
output sqlServerPrincipalId string = sqlServer.identity.principalId
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
