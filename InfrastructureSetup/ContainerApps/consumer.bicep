/*
  This Bicep file takes several string paramter inputs, including - 
  containerAppImage - Full docker image name, e.g. cwcaks.azurecr.io/daprexample/consumer:cbb
  containerRegistry - Full ACR URL, e.g. cwcaks.azurecr.io
  containerRegistryUsername - ACR Username, e.g. cwcaks
  serviceBusQueueName - Name of the queue that we want to consume from, e.g. testqueue
  containerRegistryPassword - A secure string, 
*/
param containerAppImage string
param containerRegistry string
param containerRegistryUsername string
param serviceBusQueueName string

/*
  This Bicep file takes a couple of securestring paramter inputs, including - 
  containerRegistryPassword - Password used to login to the Azure Container Registry (Note the ACR Admin access must be enabled).
  serviceBusConnectionString - Connection string to access the Service Bus. Depending on whether this is an input/output binding, you'll need to make sure that you have send/listen permissions configured respectively on the appropriate queue. I believe manage permission is required at present, but need further testing to confirm.
*/
@secure()
param containerRegistryPassword string

@secure()
param serviceBusConnectionString string

// Also take an object as an input for the tags parameter. This is used to cascade resource tags to all resources.
param tags object

// Set location as a parameter with a default of the Resource Group Location. This allows for overrides if needed, and is a templating best practice.
param location string = resourceGroup().location

/*
  This Bicep file uses several varaibles to aid in readability - 
  environmentName - The name of the Container App Environment
  minReplicas - Minimum number of container instances to run
  maxReplicas - Maximum number of container instances to run
  containerAppServiceAppName - The name of the Container App App
  workspaceName - Name of the Log Analytics Workspace to be created
  appInsightsName - Name of the App Insights resource to be created
  containerRegistryPasswordRef - An identifier/reference for the container registry password. This is the same concept as refs directly within DAPR/KEDA.
  serviceBusConnectionStringRef - An identifier/reference for the Service Bus Connection String. This is the same concept as refs directly within DAPR/KEDA.
*/
var environmentName = 'env-${uniqueString(resourceGroup().id)}'
var minReplicas = 0
var maxReplicas = 1
var containerAppServiceAppName = 'cwc-consumer'
var workspaceName = '${containerAppServiceAppName}-log-analytics'
var appInsightsName = '${containerAppServiceAppName}-app-insights'
var containerRegistryPasswordRef = 'container-registry-password'
var serviceBusConnectionStringRef = 'servicebus-connection-string'

// Definition for the Log Analytics Workspace
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

// Definition for the App Insights Resource
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: workspace.id
  }
}

// Definition for the Azure Container Apps Environment
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

/* 
Definition for the Azure Container Apps Container App.

This contains the bulk of the template, including container image details, authorization details for the Azure Container Registry, scaling thresholds, secret references, DAPR configuration and KEDA configuration.
*/
resource containerApp 'Microsoft.Web/containerapps@2021-03-01' = {
  name: containerAppServiceAppName
  kind: 'containerapps'
  tags: tags
  location: location
  properties: {
    kubeEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'single'
      ingress: {
        external: false
        targetPort: 5000
      }
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
        appPort: 5000
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
