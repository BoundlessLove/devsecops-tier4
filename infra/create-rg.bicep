targetScope = 'subscription'

@description('Name of the resource group')
param rgName string

@description('Location of the resource group')
param rgLocation string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: rgLocation
}
