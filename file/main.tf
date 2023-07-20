terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.0.1"
    }
  }
}

# 2. Configure the AzureRM Provider
provider "azurerm" {
  features {}
  subscription_id = "11e07d93-b7de-44c1-b006-7218b5fb3180"
  client_id       = "b30bfd9a-8e64-4c5a-ac79-c166d9ae713c"
  client_secret   = "mit8Q~qmWXTwifGCRrGggw0m97aJnXNLHwVdTaaZ"
  tenant_id       = "30bf9f37-d550-4878-9494-1041656caf27"
}

resource "azurerm_resource_group" "rg" {
  name     = "terraform_rg"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "terraform"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  address_space = ["10.10.0.0/16"]
}
resource"azurerm_subnet" "sub1" {
  name                 = "sub1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes = ["10.10.1.0/24"]
}



resource "azurerm_public_ip" "mypub1" {
    name = "mupub1"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method = "Dynamic"
  
}

resource "azurerm_network_security_group" "nsg1" {
    name               = "${var.prefix}-nsg1"
    location            = azurerm_resource_group.rg.location
    resource_group_name = "${azurerm_resource_group.rg.name}"
}
resource "azurerm_network_security_rule" "ssh" {
    name = "ssh"
    resource_group_name = azurerm_resource_group.rg.name
    network_security_group_name = "${azurerm_network_security_group.nsg1.name}"
    priority = 102
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnet_assoc" {
    subnet_id = azurerm_subnet.sub1.id
    network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_network_interface" "nic1" {
    name = "${var.prefix}-nic"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location

    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.sub1.id
      private_ip_address_allocation = "Dynamic"
    }

}

resource "azurerm_linux_virtual_machine" "vm002" {
    name = "${var.prefix}-vm002"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    size = "Standard_B1s"
    admin_username = "vm002"
    admin_password = "Vmlinux@1234"
    disable_password_authentication = false
    network_interface_ids = [ azurerm_network_interface.nic1.id ]
    provisioner "file" {
        source = "./script.sh"
        destination = "/tmp/script.sh"

    connection {
      host = self.public_ip_address
      user = self.admin_username
      password = self.admin_password
    }
    }

    source_image_reference {
      publisher = "Canonical"
      offer = "UbuntuServer"
      sku = "18.04-LTS"
      version = "latest"
    }  
    os_disk {
      storage_account_type = "Standard_LRS"
      caching = "ReadWrite"
    }
}