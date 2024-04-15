# Locals
locals {
  tags = {
    Environment = "Dev"
    Owner       = "Nick Wolff"
    Project     = "TerraChallenge"
    Team        = "IOC Engineering"
    Department  = "Managed Services"
    Version     = "Checkpoint2"
    Deployment  = "Terraform"
  }

  user_account = {
    username = "adminuser"
  }

  location = "eastus"
  vm_size  = "Standard_B1ms"
}

# Resource Group and Network
module "resource_group" {
  source    = "./modules/resourcegroup"
  base_name = "TerraChallenge"
  location  = local.location
}

# Key Vault
module "key_vault" {
  source         = "./modules/keyvault"
  key_vault_name = "TCKeyVault"
  location       = module.resource_group.rg_location_out
  rg_name        = module.resource_group.rg_name_out
}

resource "azurerm_network_security_group" "tc-sg" {
  name                = "TC-SecurityGroup"
  location            = module.resource_group.rg_location_out
  resource_group_name = module.resource_group.rg_name_out

  security_rule {
    name                       = "TC-SecurityGroupRule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_virtual_network" "tc-vnet" {
  name                = "TC-Network"
  resource_group_name = module.resource_group.rg_name_out
  location            = module.resource_group.rg_location_out
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "tc-subnet-web" {
  name                 = "TC-Network-Web"
  resource_group_name  = module.resource_group.rg_name_out
  virtual_network_name = azurerm_virtual_network.tc-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "tc-subnet-data" {
  name                 = "TC-Network-Data"
  resource_group_name  = module.resource_group.rg_name_out
  virtual_network_name = azurerm_virtual_network.tc-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "tc-subnet-jumpbox" {
  name                 = "TC-Network-Jumpbox"
  resource_group_name  = module.resource_group.rg_name_out
  virtual_network_name = azurerm_virtual_network.tc-vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_public_ip" "tc-pip" {
  name                = "TC-PublicIP"
  resource_group_name = module.resource_group.rg_name_out
  location            = module.resource_group.rg_location_out
  allocation_method   = "Dynamic"
  tags                = local.tags
}

# Password Generator
resource "random_password" "vmpassgen" {
  length = 12
  special = true
  min_lower = 4
  min_upper = 4
  numeric = true
}

# Linux VM
resource "azurerm_key_vault_secret" "admin_password_linux" {
  name = "adminpasslinux"
  value = random_password.vmpassgen.result
  key_vault_id = module.key_vault.kv_id_out
  depends_on = [
    module.key_vault
  ]
}

resource "azurerm_network_interface" "tc-linux-nic" {
  name                = "Linux-NIC"
  location            = module.resource_group.rg_location_out
  resource_group_name = module.resource_group.rg_name_out

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tc-subnet-web.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.tags
}

# - Private Key for SSH
resource "tls_private_key" "linux-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "tc-linux" {
  name                = "TC-Linux"
  location            = module.resource_group.rg_location_out
  resource_group_name = module.resource_group.rg_name_out
  size                = local.vm_size
  admin_username      = "adminuser"
  admin_password      = azurerm_key_vault_secret.admin_password_linux.value


  network_interface_ids = [
    azurerm_network_interface.tc-linux-nic.id
  ]

  admin_ssh_key {
    username   = local.user_account.username
    public_key = tls_private_key.linux-key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = local.tags
}

# Windows VM
resource "azurerm_key_vault_secret" "admin_password_windows" {
  name = "adminpasswindows"
  value = random_password.vmpassgen.result
  key_vault_id = module.key_vault.kv_id_out
  depends_on = [
    module.key_vault
  ]
}

resource "azurerm_network_interface" "tc-windows-nic" {
  name                = "Windows-NIC"
  location            = module.resource_group.rg_location_out
  resource_group_name = module.resource_group.rg_name_out

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tc-subnet-jumpbox.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "tc-windows" {
  name                = "TC-Windows"
  resource_group_name = module.resource_group.rg_name_out
  location            = module.resource_group.rg_location_out
  size                = local.vm_size
  admin_username      = local.user_account.username
  admin_password      = azurerm_key_vault_secret.admin_password_windows.value

  network_interface_ids = [
    azurerm_network_interface.tc-windows-nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  tags = local.tags
}

# Recovery Services Vault & Backup Policy
resource "azurerm_recovery_services_vault" "tc-rsv" {
  name                = "TC-RecoveryVault"
  location            = module.resource_group.rg_location_out
  resource_group_name = module.resource_group.rg_name_out
  sku                 = "Standard"

  soft_delete_enabled = false

  tags = local.tags

}

resource "azurerm_backup_policy_vm" "tc-rsp" {
  name                = "TC-BackupPolicy"
  resource_group_name = module.resource_group.rg_name_out
  recovery_vault_name = azurerm_recovery_services_vault.tc-rsv.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 10
  }
}

resource "azurerm_backup_protected_vm" "tc-linux-backup" {
  resource_group_name = module.resource_group.rg_name_out
  recovery_vault_name = azurerm_recovery_services_vault.tc-rsv.name
  source_vm_id        = azurerm_linux_virtual_machine.tc-linux.id
  backup_policy_id    = azurerm_backup_policy_vm.tc-rsp.id
}

resource "azurerm_backup_protected_vm" "tc-windows-backup" {
  resource_group_name = module.resource_group.rg_name_out
  recovery_vault_name = azurerm_recovery_services_vault.tc-rsv.name
  source_vm_id        = azurerm_windows_virtual_machine.tc-windows.id
  backup_policy_id    = azurerm_backup_policy_vm.tc-rsp.id
}
