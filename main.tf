resource "azurerm_container_registry" "main" {
  name                = "testContainerRegistryUniqueName"
  resource_group_name = "tstate"
  location            = "eastus2"
  sku                 = "Basic"
}

data "azurerm_client_config" "main" {
}

data "azurerm_subscription" "main" {}

data "azuredevops_project" "main" {
  name = "test"
}

resource "azuredevops_serviceendpoint_azurecr" "main" {
    project_id                = data.azuredevops_project.main.id
    service_endpoint_name     = "test-1234"
    resource_group            = "tstate"
    azurecr_spn_tenantid      = data.azurerm_client_config.main.tenant_id
    azurecr_name              = azurerm_container_registry.main.name
    azurecr_subscription_id   = data.azurerm_subscription.main.subscription_id
    azurecr_subscription_name = data.azurerm_subscription.main.display_name
    description               = "test"
}

# This is to work around an issue with azuredevops_resource_authorization
# The service connection resource is not ready when immediately
# so the recommendation is to wait 20 seconds until it's ready
resource "time_sleep" "wait_20_seconds" {
  depends_on = [azuredevops_serviceendpoint_azurecr.main, azuredevops_serviceendpoint_kubernetes.main]
  create_duration = "20s"
}

resource "azuredevops_resource_authorization" "main" {
  depends_on = [time_sleep.wait_20_seconds]
  project_id = data.azuredevops_project.main.id
  resource_id = azuredevops_serviceendpoint_azurecr.main.id
  authorized = true
}



# Kubernetes setup

resource "azurerm_virtual_network" "main" {
  name                = "testKube-network"
  location            = "eastus2"
  resource_group_name = "tstate"
  address_space       = ["10.10.0.0/20"]
}

resource "azurerm_subnet" "main" {
  name                  = "internal-subnet"
  resource_group_name   = "tstate"
  virtual_network_name  = azurerm_virtual_network.main.name
  address_prefixes      = ["10.10.0.0/20"]
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "testKube"
  dns_prefix          = "testKubeSibbernsen"
  location            = "eastus2"
  resource_group_name = "tstate"

  default_node_pool {
    name                  = "default"
    vm_size               = "Standard_D2_v3"
    availability_zones    = [1, 2, 3]
    enable_auto_scaling   = false
    enable_node_public_ip = false
    node_count            = 2
    os_disk_size_gb       = 50
    vnet_subnet_id        = azurerm_subnet.main.id

  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }
}

resource "azuredevops_serviceendpoint_kubernetes" "main" {
  project_id                  = "3TierSample"
  service_endpoint_name       = "three-tier-k8s-${terraform.workspace}"
  apiserver_url               = "https://${azurerm_kubernetes_cluster.main.fqdn}"
  authorization_type          = "Kubeconfig"
  kubeconfig {
    kube_config               = azurerm_kubernetes_cluster.main.kube_config_raw
  }
}

resource "azuredevops_resource_authorization" "kubeAuthorization" {
  depends_on = [time_sleep.wait_20_seconds]
  project_id = data.azuredevops_project.main.id
  resource_id = azuredevops_serviceendpoint_azurecr.main.id
  authorized = true
}
