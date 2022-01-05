# Register the EnablePodIdentityPreview
az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService

# Install the aks-preview Azure CLI
# Install the aks-preview extension
az extension add --name aks-preview

# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview

# Update the existing cluster
RESOURCE_GROUP_NAME="cwc-aks-rg"
CLUSTER_NAME=cwc-aks
az aks update -g $RESOURCE_GROUP_NAME -n $CLUSTER_NAME --enable-pod-identity