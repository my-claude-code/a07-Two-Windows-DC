terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  dc1_encoded = textencodebase64(
    templatefile("${path.module}/scripts/dc-setup.ps1", {
      domain_name    = "firstad.local"
      netbios_name   = "FIRSTAD"
      admin_password = var.admin_password
      admin_username = var.admin_username
    }),
    "UTF-16LE"
  )
  dc2_encoded = textencodebase64(
    templatefile("${path.module}/scripts/dc-setup.ps1", {
      domain_name    = "secondad.local"
      netbios_name   = "SECONDAD"
      admin_password = var.admin_password
      admin_username = var.admin_username
    }),
    "UTF-16LE"
  )
}

# ─── DC1 — Canada East — firstad.local ─────────────────────────────────────

resource "azurerm_resource_group" "dc1" {
  name     = "rg-dc1-firstad"
  location = "Canada East"
}

resource "time_sleep" "dc1_rg_ready" {
  create_duration = "30s"
  depends_on      = [azurerm_resource_group.dc1]
}

resource "azurerm_virtual_network" "dc1" {
  name                = "vnet-dc1"
  location            = azurerm_resource_group.dc1.location
  resource_group_name = azurerm_resource_group.dc1.name
  address_space       = ["10.0.0.0/16"]
  depends_on          = [time_sleep.dc1_rg_ready]
}

resource "time_sleep" "dc1_vnet_ready" {
  create_duration = "30s"
  depends_on      = [azurerm_virtual_network.dc1]
}

resource "azurerm_subnet" "dc1" {
  name                 = "subnet-dc1"
  resource_group_name  = azurerm_resource_group.dc1.name
  virtual_network_name = azurerm_virtual_network.dc1.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [time_sleep.dc1_vnet_ready]
}

resource "azurerm_network_security_group" "dc1" {
  name                = "nsg-dc1"
  location            = azurerm_resource_group.dc1.location
  resource_group_name = azurerm_resource_group.dc1.name
  depends_on          = [time_sleep.dc1_rg_ready]

  security_rule {
    name                       = "allow-all-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dc1" {
  subnet_id                 = azurerm_subnet.dc1.id
  network_security_group_id = azurerm_network_security_group.dc1.id
}

resource "azurerm_public_ip" "dc1" {
  name                = "pip-dc1"
  location            = azurerm_resource_group.dc1.location
  resource_group_name = azurerm_resource_group.dc1.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [time_sleep.dc1_rg_ready]
}

resource "azurerm_network_interface" "dc1" {
  name                = "nic-dc1"
  location            = azurerm_resource_group.dc1.location
  resource_group_name = azurerm_resource_group.dc1.name

  ip_configuration {
    name                          = "dc1-ip-config"
    subnet_id                     = azurerm_subnet.dc1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dc1.id
  }
}

resource "azurerm_windows_virtual_machine" "dc1" {
  name                = "vm-dc1"
  resource_group_name = azurerm_resource_group.dc1.name
  location            = azurerm_resource_group.dc1.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [azurerm_network_interface.dc1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "dc1_setup" {
  name                 = "dc1-ad-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -EncodedCommand ${local.dc1_encoded}"
  })

  timeouts {
    create = "60m"
  }
}

# ─── DC2 — West US 2 — secondad.local ──────────────────────────────────────

resource "azurerm_resource_group" "dc2" {
  name     = "rg-dc2-secondad"
  location = "West US 2"
}

resource "time_sleep" "dc2_rg_ready" {
  create_duration = "30s"
  depends_on      = [azurerm_resource_group.dc2]
}

resource "azurerm_virtual_network" "dc2" {
  name                = "vnet-dc2"
  location            = azurerm_resource_group.dc2.location
  resource_group_name = azurerm_resource_group.dc2.name
  address_space       = ["10.1.0.0/16"]
  depends_on          = [time_sleep.dc2_rg_ready]
}

resource "time_sleep" "dc2_vnet_ready" {
  create_duration = "30s"
  depends_on      = [azurerm_virtual_network.dc2]
}

resource "azurerm_subnet" "dc2" {
  name                 = "subnet-dc2"
  resource_group_name  = azurerm_resource_group.dc2.name
  virtual_network_name = azurerm_virtual_network.dc2.name
  address_prefixes     = ["10.1.1.0/24"]
  depends_on           = [time_sleep.dc2_vnet_ready]
}

resource "azurerm_network_security_group" "dc2" {
  name                = "nsg-dc2"
  location            = azurerm_resource_group.dc2.location
  resource_group_name = azurerm_resource_group.dc2.name
  depends_on          = [time_sleep.dc2_rg_ready]

  security_rule {
    name                       = "allow-all-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dc2" {
  subnet_id                 = azurerm_subnet.dc2.id
  network_security_group_id = azurerm_network_security_group.dc2.id
}

resource "azurerm_public_ip" "dc2" {
  name                = "pip-dc2"
  location            = azurerm_resource_group.dc2.location
  resource_group_name = azurerm_resource_group.dc2.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [time_sleep.dc2_rg_ready]
}

resource "azurerm_network_interface" "dc2" {
  name                = "nic-dc2"
  location            = azurerm_resource_group.dc2.location
  resource_group_name = azurerm_resource_group.dc2.name

  ip_configuration {
    name                          = "dc2-ip-config"
    subnet_id                     = azurerm_subnet.dc2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dc2.id
  }
}

resource "azurerm_windows_virtual_machine" "dc2" {
  name                = "vm-dc2"
  resource_group_name = azurerm_resource_group.dc2.name
  location            = azurerm_resource_group.dc2.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [azurerm_network_interface.dc2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "dc2_setup" {
  name                 = "dc2-ad-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -EncodedCommand ${local.dc2_encoded}"
  })

  timeouts {
    create = "60m"
  }
}
