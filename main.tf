terraform {
  required_providers {
    azurerm = {
      # Specify what version of the provider we are going to utilise.
      source        = "hashicorp/azurerm"
      version       = ">= 3.34.0"
    }
    random = {
      source        = "hashicorp/random"
      version       = "3.1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "primary" {
}
data "azurerm_client_config" "current" {}

# Create random string - This will create a random character string to be used for naming of resources
resource "random_string" "rg_random_1" {
  length  = 4
  special = false
}

# Create Resource Group 1
resource "azurerm_resource_group" "rg_1" {
  name     =  "${var.rg_name_1}-${random_string.rg_random_1.result}"
  location = var.region_1
  tags = {
    Environment = var.tag_environment
    CreatedBy   = var.tag_createdby
    CreatedWith = var.tag_createdwith
  }
}

# Create custom role
resource "azurerm_role_definition" "customrole" {
  name               = "Custom Storage Blob Data Contributor"
  scope              = data.azurerm_subscription.primary.id
  description        = "This is a custom role created via Terraform"

  permissions {
    actions     =   [
                    "Microsoft.Storage/storageAccounts/blobServices/containers/delete",
                    "Microsoft.Storage/storageAccounts/blobServices/containers/read",
                    "Microsoft.Storage/storageAccounts/blobServices/containers/write",
                    "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action"
                     ]
    not_actions   = []
    data_actions   = [
                    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
                    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
                    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
                    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/move/action",
                    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action"
                     ]
    not_data_actions = []

  }

  assignable_scopes = [
    data.azurerm_subscription.primary.id,
  ]
}


# Create storage account
resource "azurerm_storage_account" "storage" {
  name                     = var.storageAccountName
  resource_group_name      = azurerm_resource_group.rg_1.name
  location                 = azurerm_resource_group.rg_1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
  
 
}

# Create blob container
resource "azurerm_storage_container" "example" {
  name                  = var.blobContainer
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "container"
}

# Create blob container
resource "azurerm_storage_container" "exampleq" {
  name                  = "silver"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "container"
}

# Create role assignment with conditions on resource group 
resource "azurerm_role_assignment" "roleAssignment" {
  scope                = azurerm_resource_group.rg_1.id
  role_definition_name = "Custom Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  condition            = "((!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'})) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals 'copper'))" // Role assignment condition
  condition_version     = "2.0"
}