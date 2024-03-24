locals {
	tags = {
		Environment = "Dev"
		Owner = "Nick Wolff"
		Project = "TerraChallenge"
		Team = "IOC Engineering"
		Department = "Managed Services"
		Version = "Checkpoint2"
		Deployment = "Terraform"
	}

	user_account = {
		username = "adminuser"
		password = "P@ssword123!"
	}

	location = "eastus"
	vm_size = "Standard_B1ms"
}
