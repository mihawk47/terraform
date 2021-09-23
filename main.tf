resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "app-dev-network" {
  name  =  "${var.prefix}-network"
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "App_subnet" {
  name = "App_subnet"
  resource_group_name = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.app-dev-network.name
  address_prefixes = ["10.0.1.0/24"]
  
}

resource "azurerm_subnet" "DB_subnet" {
  name = "DB_subnett"
  resource_group_name = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.app-dev-network.name
  address_prefixes = ["10.0.2.0/24"]
  service_endpoints = ["Microsoft.Sql"]
}

resource "azurerm_network_interface" "nic1" {
    name = "${var.prefix}-nic"
    location = azurerm_resource_group.example.location
    resource_group_name = azurerm_resource_group.example.name

    ip_configuration {
      name  = "test configuration"
      subnet_id = azurerm_subnet.internal.id
      private_ip_address = ["10..0.2.4/32"]
    }
  
}

resource "azurerm_virtual_machine" "appdevserver" {
    name = "${var.prefix}-vm"
    location = azurerm_resource_group.example.location
    resource_group_name = azurerm_resource_group.example.name
    network_interface_ids = [azurerm_network_interface.nic1.id]
    vm_size = "Standard_DS1_V2"

    storage_image_reference {
      publisher = "Canonical"
      offer = "UbuntuServer"
      sku = "20.04-LTS"
      version = "latest"
    }

    storage_os_disk {
        name = "myosdisk1"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
      computer_name = "appdevserver"
      admin_password = Cosmos@123
      admin_username = testadmin
      custom_data = file("azure_user_data.sh")
    }

    os_os_profile_linux_config {
        disable_password_authentication = false
    }

    tags {
        environment = "dev"
    }
  
}



//Azure SQl server


resource "azurerm_mysql_server" "mysqldevServer" {
  name                = "mysqlserver"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  administrator_login          = "mysqladminun"
  administrator_login_password = "H@Sh1CoR3!"

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = true
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mysql_database" "example" {
  name                = "exampledb"
  resource_group_name = azurerm_resource_group.example.name
  server_name         = azurerm_mysql_server.mysqldevServer.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurerm_sql_firewall_rule" "allow_all_azure_ips" {
  name                = "AllowAllAzureIps"
  resource_group_name = "${azurerm_resource_group.example.name}"
  server_name         = "${azurerm_mysql_server.mysqldevServer.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}


resource "azurerm_sql_virtual_network_rule" "sql_subnet_rule" {
  name                = "MyDBAppRule"
  resource_group_name = "${azurerm_resource_group.terraform_tips.name}"
  server_name         = "${azurerm_sql_server.terraform_tips.name}"
  subnet_id           = "${azurerm_subnet.App_subnet.id}"
}