#### 
## Setting up passwordless DAPR Secret Store from KeyVault
## Create an Azure Managed Identity for Dapr to access secrets in a KeyVault
####

# First, set up some variables to make the script easier to execute
CLUSTER_NAME="cwc-aks"
RESOURCE_GROUP_NAME="cwc-aks-rg"
LOCATION="westeurope"
DAPR_IDENTITY_NAME="${CLUSTER_NAME}-dapr-secrets-id"

# Now, create a managed identity for the Pod Identity. We'll create a separate identity to retrieve the secrets from a KeyVault. In reality, this may be done on a per application basis (principal of least privilege).
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
az identity create --resource-group $RESOURCE_GROUP_NAME --name $DAPR_IDENTITY_NAME
DAPR_IDENTITY_CLIENT_ID="$(az identity show -g ${RESOURCE_GROUP_NAME} -n ${DAPR_IDENTITY_NAME} --query clientId -otsv)"
DAPR_IDENTITY_RESOURCE_ID="$(az identity show -g ${RESOURCE_GROUP_NAME} -n ${DAPR_IDENTITY_NAME} --query id -otsv)"

# Next up, we need to assign the managed identity with permissions to the KeyVault.
# Pro-tip: Make sure that your KeyVault has been created with AAD/RBAC configuration, and NOT the access policies. Otherwise, you will see a CrashLoopBackOff as the daprd sidecar container will get a 403 when trying to access the KeyVault.
KEYVAULT_RESOURCE_GROUP_NAME="cwc-aks-rg"
KEYVAULT_NAME="daprkvtest"
KEYVAULT_RESOURCE_ID=$(az keyvault show --name $KEYVAULT_NAME --resource-group $KEYVAULT_RESOURCE_GROUP_NAME -o tsv --query "id")

# As KEDA will only need to read secrets from the vault, we can get away with giving it just Key Vault Secrets User access. If you wanted, you could be granular to a per secret level. But, for the purposes of this - the below is fine.
az role assignment create --role "Key Vault Secrets User" --assignee "$DAPR_IDENTITY_CLIENT_ID" --scope $KEYVAULT_RESOURCE_ID

# Create a pod identity in the AKS cluster using the above managed identity
# Be aware that the current pod identity preview will be replaced, per the docs - https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity
# Note the namespace needs to be the same as the namespace where you plan to run your workload, backed by DAPR. This is also why you may want to consider principal of least privilege.
DAPR_POD_IDENTITY_NAME="dapr-secrets-identity"
DAPR_POD_IDENTITY_NAMESPACE="default"
az aks pod-identity add --resource-group $RESOURCE_GROUP_NAME --cluster-name $CLUSTER_NAME --namespace ${DAPR_POD_IDENTITY_NAMESPACE}  --name ${DAPR_POD_IDENTITY_NAME} --identity-resource-id ${DAPR_IDENTITY_RESOURCE_ID}