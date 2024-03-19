# Resource Group and Network
resource "azurerm_resource_group" "tc-rg" {
	name = "TC-Checkpoint1"
	location = "eastus"
}

resource "azurerm_network_security_group" "tc-sg" {
	name = "TC-SecurityGroup"
	location = azurerm_resource_group.tc-rg.location
	resource_group_name = azurerm_resource_group.tc-rg.name

	security_rule {
		name = "TC-SecurityGroupRule"
		priority = 100
		direction = "Inbound"
		access = "Allow"
		protocol = "Tcp"
		source_port_range = "*"
		destination_port_range = "*"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}
}

resource "azurerm_virtual_network" "tc-vnet" {
	name = "TC-Network"
	resource_group_name = azurerm_resource_group.tc-rg.name
	location = azurerm_resource_group.tc-rg.location
	address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "tc-subnet-web" {
	name = "TC-Network-Web"
	resource_group_name = azurerm_resource_group.tc-rg.name
	virtual_network_name = azurerm_virtual_network.tc-vnet.name
	address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "tc-subnet-data" {
	name = "TC-Network-Data"
	resource_group_name = azurerm_resource_group.tc-rg.name
	virtual_network_name = azurerm_virtual_network.tc-vnet.name
	address_prefixes = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "tc-subnet-jumpbox" {
	name = "TC-Network-Jumpbox"
	resource_group_name = azurerm_resource_group.tc-rg.name
	virtual_network_name = azurerm_virtual_network.tc-vnet.name
	address_prefixes = ["10.0.3.0/24"]
}

resource "azurerm_public_ip" "tc-pip" {
	name = "TC-PublicIP"
	resource_group_name = azurerm_resource_group.tc-rg.name
	location = azurerm_resource_group.tc-rg.location
	allocation_method = "Dynamic"
}

