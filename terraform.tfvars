# =============================================================================
# OpenStack / NIPA Cloud Authentication
# Values can be found in the NIPA Cloud dashboard:
#   Project Overview → Manage Project → Download Public API RC file
# =============================================================================

openstack_auth_url    = "https://cloud-api.nipa.cloud:5000/v3"
openstack_domain_name = "nipacloud"
openstack_region      = "NCP-TH"
instance_az           = "NCP-NON"

# OpenStack Project ID
project_id = ""

# Application Credential (from NIPA Cloud → Project Overview → Manage Project)
openstack_application_credential_id     = ""
openstack_application_credential_secret = ""

# =============================================================================
# Images and Networking
# IDs can be found in the NIPA Cloud portal under Compute → Images / Network → Networks
# =============================================================================

# Ubuntu 22.04 image ID (ubuntu-22-v260122)
image_id = "29b95311-db5e-410f-8d14-09e94f2f2f3e"

# Control/management network (Network1)
network1_id = ""

# Data network for vhost0 (Network2)
network2_id = ""

# =============================================================================
# Instance Configuration
# =============================================================================

floating_ip_pool_name = "Standard_Public_IP_Pool_NON"

# Flavor for the OpenStack controller and OpenSDN controller (4 core, 8GB RAM)
controller_flavor_name = "a8ae5a56.s4c8m.v1"

# Flavor for compute nodes (2 core, 4GB RAM)
compute_flavor_name = "a8ae5a56.s2c4m.v1"

# Number of compute nodes to provision
compute_instance_count = 2

# Volume size in GB for each instance
volume_size = 200

# Prefix applied to all resource names (must match instance keys in instances.yaml)
resource_prefix = "tf"

# =============================================================================
# Instance Credentials
# Default: nc-user / y0V#ew8k4nM+
# To use a different password, generate a hash with: openssl passwd -6 'NewPassword'
# The password can also be reset from the NIPA Cloud dashboard:
#   Compute → Instances → Reset Password
# =============================================================================

ssh_user_password      = "y0V#ew8k4nM+"
ssh_user_password_hash = "$6$YjFbwI/EiomZ3MW7$T1HNX88IK5j4a0vHtISZLBWFJm5O9AzGOoMSL8vx0ITk2CtW9F0pi8f.Z3B1VHRq.86EmGtHxkYSpri/GrYXS0"
