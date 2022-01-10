param containerAppImage string

param containerRegistry string
param containerRegistryUsername string
param serviceBusQueueName string
@secure()
param containerRegistryPassword string

@secure()
param serviceBusConnectionString string

param tags object

var location = resourceGroup().location
var environmentName = 'env-${uniqueString(resourceGroup().id)}'
var minReplicas = 0
var maxReplicas = 1

var containerAppServiceAppName = 'consumer-app'
var workspaceName = '${containerAppServiceAppName}-log-analytics'
var appInsightsName = '${containerAppServiceAppName}-app-insights'

var containerRegistryPasswordRef = 'container-registry-password'
var serviceBusConnectionStringRef = 'servicebus-connection-string'

resource workspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {}
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
  }
}

resource environment 'Microsoft.Web/kubeEnvironments@2021-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    type: 'managed'
    internalLoadBalancerEnabled: false
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: listKeys(workspace.id, workspace.apiVersion).primarySharedKey
      }
    }
    containerAppsConfiguration: {
      daprAIInstrumentationKey: appInsights.properties.InstrumentationKey
    }
  }
}

resource containerApp 'Microsoft.Web/containerapps@2021-03-01' = {
  name: containerAppServiceAppName
  kind: 'containerapps'
  tags: tags
  location: location
  properties: {
    kubeEnvironmentId: environment.id
    configuration: {
      secrets: [
        {
          name: containerRegistryPasswordRef
          value: containerRegistryPassword
        }
        {
          name: serviceBusConnectionStringRef
          value: serviceBusConnectionString
        }
      ]
      registries: [
        {
          server: containerRegistry
          username: containerRegistryUsername
          passwordSecretRef: containerRegistryPasswordRef
        }
      ]
    }
    template: {
      containers: [
        {
          image: containerAppImage
          name: containerAppServiceAppName
          transport: 'auto'
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'queue-based-autoscaling'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                queueName: serviceBusQueueName
                messageCount: '5'
              }
              auth: [
                {
                  secretRef: serviceBusConnectionStringRef
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
      dapr: {
        enabled: true
        appId: 'consumer'
        components: [
          {
            name: 'azurebusnosecrets'
            type: 'bindings.azure.servicebusqueues'
            version: 'v1'
            metadata: [
              {
                name: 'connectionString'
                secretRef: serviceBusConnectionStringRef
              }
              {
                name: 'queueName'
                value: serviceBusQueueName
              }
            ]
          }
        ]
      }
    }
  }
}
