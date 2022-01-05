# Create an Azure Managed Identity for KEDA
RESOURCE_GROUP_NAME="cwc-aks-rg"
CLUSTER_NAME=cwc-aks
LOCATION="westeurope"
KEDA_IDENTITY_NAME="${CLUSTER_NAME}-keda-scale-id"

az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
az identity create --resource-group $RESOURCE_GROUP_NAME --name $IDENTITY_NAME
KEDA_IDENTITY_CLIENT_ID="$(az identity show -g ${RESOURCE_GROUP_NAME} -n ${KEDA_IDENTITY_NAME} --query clientId -otsv)"
KEDA_IDENTITY_RESOURCE_ID="$(az identity show -g ${RESOURCE_GROUP_NAME} -n ${KEDA_IDENTITY_NAME} --query id -otsv)"

# Assign the identity to a Service Bus Queue
SERVICEBUS_RESOURCE_GROUP_NAME="cwc-aks-rg"
SERVICEBUS_NAMESPACE_NAME="daprsbtest"
SERVICEBUS_QUEUE_NAME="testqueue"
SERVICEBUS_RESOURCE_ID=$(az servicebus queue show --name $SERVICEBUS_QUEUE_NAME --namespace-name $SERVICEBUS_NAMESPACE_NAME --resource-group $SERVICEBUS_RESOURCE_GROUP_NAME -o tsv --query "id")

# As KEDA will only need to read the queue (i.e. to see current state), we can get away with giving it just receiver.
az role assignment create --role "Azure Service Bus Data Receiver" --assignee "$KEDA_IDENTITY_CLIENT_ID" --scope $SERVICEBUS_RESOURCE_ID

# Create a pod identity using the above managed identity
# Note the namespace needs to be the same as the namespace where you plan to store your KEDA operator.
POD_IDENTITY_NAME="keda-servicebus-identity"
POD_IDENTITY_NAMESPACE="keda"
az aks pod-identity add --resource-group $RESOURCE_GROUP_NAME --cluster-name $CLUSTER_NAME --namespace ${POD_IDENTITY_NAMESPACE}  --name ${POD_IDENTITY_NAME} --identity-resource-id ${IDENTITY_RESOURCE_ID}

# Install KEDA using the helm chart. Note that you need to set the chart value as below.
helm install keda kedacore/keda --set podIdentity.activeDirectory.identity="keda-servicebus-identity" --namespace keda

# Deploy the workload
kubectl apply -f DaprExample.Consumer.yaml

# Deploy the KEDA scaling rules (depending on state of the queue you'll likely see the pods begin to scale out/in)
kubectl apply -f keda.yaml