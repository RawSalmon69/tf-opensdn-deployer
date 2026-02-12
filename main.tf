terraform {
  required_version = ">= 1.13.5"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "2.0.0"
    }
    ssh = {
      source = "loafoe/ssh"
      version = "2.7.0"
    }
  }
}

provider "openstack" {
  auth_url                        = var.openstack_auth_url
  project_domain_name             = var.openstack_domain_name
  tenant_id                       = var.project_id
  application_credential_id       = var.openstack_application_credential_id
  application_credential_secret   = var.openstack_application_credential_secret
  region                          = var.openstack_region
  enable_logging                  = true
}

locals {
  user_data_cloud_init = templatefile("${path.module}/cloud-init.tftpl", {
    password_hash = var.ssh_user_password_hash
  })
}
