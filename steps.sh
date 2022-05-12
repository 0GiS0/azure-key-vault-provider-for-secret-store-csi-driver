# Variables
RESOURCE_GROUP="aks-ak-csi-driver"
LOCATION="westeurope"
AKS_CLUSTER_NAME="aks-csi-driver"

# Create resource group
az group create -n $RESOURCE_GROUP -l $LOCATION

# Create AKS cluster with Azure Key Vault Provider for Secrets Store CSI Driver capability
az aks create \
-n $AKS_CLUSTER_NAME \
-g $RESOURCE_GROUP \
-l $LOCATION \
--node-vm-size Standard_B4ms \
--generate-ssh-keys \
--enable-addons azure-keyvault-secrets-provider \
--enable-managed-identity

# Get AKS credentials
az aks get-credentials -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP

# Verify the Azure Key Vault Provider for Secrets Store CSI Driver installation
kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver, secrets-store-provider-azure)'

# Create an Azure Key Vault
KEY_VAULT_NAME="aks-kvault"

az keyvault create \
--name $KEY_VAULT_NAME \
--resource-group $RESOURCE_GROUP \
--location $LOCATION 

# Provide an identity to access the Azure Key Vault
# Ger client id
CLIENT_ID=$(az aks show -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" -o tsv)

# Set policy to access secrets in your key vault
az keyvault set-policy -n $KEY_VAULT_NAME \
--secret-permissions get \
--spn $CLIENT_ID

# Store a plain text called mysecret in the Key Vault
az keyvault secret set \
--vault-name $KEY_VAULT_NAME \
-n mysecret \
--value HelloWorld

# Create a SecretProviderClass with the objects you want to retrieve
kubectl apply -f secret-provider-class.yaml

# Create a pod that uses the SecretProviderClass
kubectl apply -f pod-secret-as-mount.yaml

# Verify the secret is available
kubectl exec busybox-secrets-mounted -- ls /mnt/secrets-store/

# Print the content
kubectl exec busybox-secrets-mounted -- cat /mnt/secrets-store/mysecret

# Create another secret
az keyvault secret set \
--vault-name $KEY_VAULT_NAME \
-n username \
--value gisela

# Apply the secret class provider
kubectl apply -f secret-provider-class-env.yaml

# Check if the secret is available
kubectl get secret

# Assign the secret to a variable
kubectl apply -f pod-secret-as-variable.yaml

kubectl get pods

kubectl get secrets

# Check the content of the secret
kubectl get secret credential -o jsonpath="{.data.user}" | base64 --decode

# Check environment variable in the pod
kubectl exec busybox-secret-as-variable -- env | grep SECRET_USERNAME

# More examples: https://github.com/Azure/secrets-store-csi-driver-provider-azure/tree/master/examples/