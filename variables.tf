variable "openstack_auth_url" {
  type = string
  default = ""
}

variable "openstack_domain_name" {
  type = string
  default = "Default"
}

variable "project_id" {
  type = string
  default = ""
}

variable "openstack_application_credential_id" {
  type = string
  default = ""
}
variable "openstack_application_credential_secret" {
  type = string
  default = ""
}
variable "openstack_region" {
  type = string
  default = "RegionOne"
}

variable "instance_az" {
  description = "The availability zone to launch the instance in"
  type        = string
  default     = "nova"
}
variable "image_id" {
  description = "The ID of the image to use for the instance"
  type        = string
}

variable "volume_size" {
  description = "The size of the volume to create in GB"
  type        = number
  default     = 50
}

variable "network1_id" {
  description = "The ID of the first network to attach to the instance"
  type        = string
}

variable "network2_id" {
  description = "The ID of the second network to attach to the instance"
  type        = string
}

data "openstack_networking_secgroup_v2" "secgroup_SSH" {
  name = "SSH"
}

data "openstack_networking_secgroup_v2" "secgroup_In_Cluster" {
  name = "In-Cluster"
}

data "openstack_networking_secgroup_v2" "secgroup_TF_ENDPOINT_SG" {
  name = "TF_ENDPOINT_SG"
}

data "openstack_networking_secgroup_v2" "secgroup_ALL" {
  name = "ALL"
}

variable "floating_ip_pool_name" {
  type = string
  default = "Standard_Public_IP_Pool_BKK"
}

variable "controller_flavor_name" {
  type = string
  default = "csa.2xlarge.v2"
}

variable "compute_flavor_name" {
  type = string
  default = "csa.2xlarge.v2"
}

variable "compute_instance_count" {
  type    = number
  default = 2
}

variable "ssh_user_password_hash" {
  description = "Cryptographically-hashed password for the default user (nc-user). Generate with `openssl passwd -6 'YOUR_PASSWORD'`."
  type        = string
  sensitive   = true
  default     = "$6$YjFbwI/EiomZ3MW7$T1HNX88IK5j4a0vHtISZLBWFJm5O9AzGOoMSL8vx0ITk2CtW9F0pi8f.Z3B1VHRq.86EmGtHxkYSpri/GrYXS0" # Default is 'y0V#ew8k4nM+'
}

variable "ssh_user_password" {
  description = "Plain-text password for the default user (nc-user). Used for the post-creation SSH test."
  type        = string
  sensitive   = true
  default     = "y0V#ew8k4nM+"
}

variable "resource_prefix" {
  description = "A prefix to be added to the name of all created resources."
  type        = string
  default     = "tf"
}
