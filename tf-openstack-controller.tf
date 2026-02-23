resource "openstack_networking_port_v2" "tf-openstack-controller-eth0" {
  name       = "${var.resource_prefix}-openstack-controller-eth0"
  network_id = var.network1_id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.secgroup_ALL.id, 
    data.openstack_networking_secgroup_v2.secgroup_In_Cluster.id, 
    data.openstack_networking_secgroup_v2.secgroup_TF_ENDPOINT_SG.id, 
    data.openstack_networking_secgroup_v2.secgroup_SSH.id
  ]
}

resource "openstack_networking_floatingip_v2" "tf-openstack-controller-external-ip" {
  pool = var.floating_ip_pool_name
}


resource "openstack_compute_instance_v2" "tf-openstack-controller" {
  availability_zone       = var.instance_az
  name                    = "${var.resource_prefix}-openstack-controller"
  flavor_name             = var.controller_flavor_name
  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    volume_size           = var.volume_size
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.tf-openstack-controller-eth0.id
  }
  user_data             = local.user_data_cloud_init

}

resource "ssh_resource" "test-ssh-openstack-controller" {
  host     = openstack_networking_floatingip_v2.tf-openstack-controller-external-ip.address
  user     = "nc-user"
  password = var.ssh_user_password
  when = "create"
  timeout     = "5m"
  retry_delay = "5s"

  commands = [
    "echo 'SSH connection to OpenStack Controller successful'"
  ]

  depends_on = [
    openstack_compute_instance_v2.tf-openstack-controller
  ]
}