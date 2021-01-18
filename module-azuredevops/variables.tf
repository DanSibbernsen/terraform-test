variable "name" {
  default = "azure"
  type = string
  description = "Name of the azure devops project"
}

variable "base_tags" {
  type = map
  default = {
    ManagedBy = "terraform"
    Platform  = "azuredevops"
  }
  description = "Base Tags to place on all assets created by module"
}
