/*
  This Bicep file takes several string paramter inputs, including - 
  containerAppImage - Full docker image name, e.g. cwcaks.azurecr.io/daprexample/consumer:cb9
  prefix - Used in front of several resources in the deployment
  tags - Used as metadata for the deployed resources (e.g. cost center, owner, etc.)
  location - Used as the Azure Region for deployment. This defaults to current resource group location
  serviceBusInputQueueName - Name of the queue used in Service Bus to input the messages
  serviceBusOutputQueueName - Name of the queue used in Service Bus to output the messages
  storageQueueInputName - Name of the queue used in Azure Storage Queues to input the messages
  storageQueueOutputName - Name of the queue used in Azure Storage Queues to output the messages
*/

param containerAppImage string = 'consumer:v1.0'
param prefix string = 'cappatv'

// Also take an object as an input for the tags parameter. This is used to cascade resource tags to all resources.
param tags object = {}

// Set location as a parameter with a default of the Resource Group Location. This allows for overrides if needed, and is a templating best practice.
param location string = resourceGroup().location

param serviceBusInputQueueName string = 'ca-sb-queue-input'

/*
  This Bicep file uses several varaibles to aid in readability - 
  acrName - Name of the Azure Container Registry
  acrLoginServerName - URL of the Azure Container Registry for Auth purposes and image path
  appInsightsName - Name of the App Insights resource to be created
  containerAppServiceAppName - The name of the Container App App
  containerRegistryPasswordRef - An identifier/reference for the container registry password. This is the same concept as refs directly within DAPR/KEDA.
  environmentName - The name of the Container App Environment
  serviceBusAuthRule - Auth rule used by the Service Bus to authenticate
  serviceBusConnectionStringRef - An identifier/reference for the Service Bus Connection String. This is the same concept as refs directly within DAPR/KEDA.
  serviceBusName - Name of the Service Bus which holds the input/output queue
  storageAccountName - Name of the Storage Account which holds the input/output queue
  storageAccountNameRef - tbc
  storageAccountKeyRef - tbc
  workspaceName - Name of the Log Analytics Workspace to be created
*/

var acrName = '${prefix}acr'
var acrLoginServerName = '${prefix}acr.azurecr.io'
var appInsightsName = '${prefix}-app-insights'
var containerAppServiceAppName = '${prefix}-container-app'
var containerRegistryPasswordRef = 'container-registry-password'
var environmentName = '${prefix}-kube-env'
var serviceBusAuthRule = '${prefix}-service-bus-auth-rule'
var serviceBusConnectionStringRef = 'service-bus-connection-string'
var serviceBusName = '${prefix}-service-bus'
var storageAccountName = '${prefix}stg'
var workspaceName = '${prefix}-log-analytics'

// Definition for the existing Log Analytics Workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' existing = {
  name: workspaceName
}

// Definition for the existing App Insights Resource
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: appInsightsName
}

// Definition for the existing Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: acrName
}

// Definition for the existing storage account
resource sa 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
}

resource servicebusnamespace 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' existing = {
  name: serviceBusName
}

resource servicebusauthrule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-06-01-preview' existing = {
  name: serviceBusAuthRule
  parent: servicebusnamespace
}

// Definition for the Azure Container Apps Environment
resource environment 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: listKeys(workspace.id, workspace.apiVersion).primarySharedKey
      }
    }
    daprAIInstrumentationKey: appInsights.properties.InstrumentationKey
  }
}

resource queuebinding 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
  name: 'decouple-with-queue'
  parent: environment
  properties: {
    componentType: 'bindings.azure.servicebusqueues'
    version: 'v1'
    metadata: [
      {
        name: 'connectionString'
        secretRef: serviceBusConnectionStringRef
      }
      {
        name: 'queueName'
        value: serviceBusInputQueueName
      }
    ]
    scopes: [
      'consumer-app'
    ]
    secrets: [
      {
        name: serviceBusConnectionStringRef
        value: listKeys(servicebusauthrule.id, servicebusauthrule.apiVersion).primaryConnectionString
      }
    ]
  }
}


/* 
Definition for the Azure Container Apps Container App.

This contains the bulk of the template, including container image details, authorization details for the Azure Container Registry, scaling thresholds, secret references, DAPR configuration and KEDA configuration.
*/

resource containerApp 'Microsoft.App/containerapps@2022-01-01-preview' = {
  name: containerAppServiceAppName
  tags: tags
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'single'
      ingress:{
        external:true
        targetPort:5000
      } 
      registries: [
        {
          server: acrLoginServerName
          username: acr.name
          passwordSecretRef: containerRegistryPasswordRef
        }
      ]
      dapr: {
        enabled: true
        appPort: 5000
        appId: 'consumer-app'
      }
      secrets: [
        {
          name: containerRegistryPasswordRef
          value: listCredentials(acr.id, acr.apiVersion).passwords[0].value
        }
        {
          name: serviceBusConnectionStringRef
          value: listKeys(servicebusauthrule.id, servicebusauthrule.apiVersion).primaryConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${acrLoginServerName}/${containerAppImage}'
          name: containerAppServiceAppName
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}
