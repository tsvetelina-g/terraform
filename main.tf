terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.67.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "6439e495-beaf-499c-84c9-920592573b5e"
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "resourceg" {
  name     = "${var.resource_group_name}-${random_integer.ri.result}"
  location = var.location
}

resource "azurerm_service_plan" "service-plan" {
  name                = "${var.app_service_plan_name}-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.resourceg.name
  location            = azurerm_resource_group.resourceg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "web-app" {
  name                = "${var.app_service_name}-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.resourceg.name
  location            = azurerm_service_plan.service-plan.location
  service_plan_id     = azurerm_service_plan.service-plan.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
    always_on = false
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.sqldatabase.name};User ID=${azurerm_mssql_server.sqlserver.administrator_login};Password=${azurerm_mssql_server.sqlserver.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_app_service_source_control" "source-control" {
  app_id                 = azurerm_linux_web_app.web-app.id
  repo_url               = "https://github.com/tsvetelina-g/Azure-Web-App-with-Database-TaskBoard.git"
  branch                 = "main"
  use_manual_integration = true
}

resource "azurerm_mssql_server" "sqlserver" {
  name                         = "${var.sql_server_name}-${random_integer.ri.result}"
  resource_group_name          = azurerm_resource_group.resourceg.name
  location                     = azurerm_resource_group.resourceg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_name
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "sqldatabase" {
  name                 = var.sql_database_name
  server_id            = azurerm_mssql_server.sqlserver.id
  collation            = "SQL_Latin1_General_CP1_CI_AS"
  license_type         = "LicenseIncluded"
  max_size_gb          = 2
  sku_name             = "S0"
  zone_redundant       = false
  storage_account_type = "Local"

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_firewall_rule" "firewallrule" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}