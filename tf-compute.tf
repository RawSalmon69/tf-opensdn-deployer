resource "openstack_networking_port_v2" "tf-compute-eth0-ports" {
  count      = var.compute_instance_count
  name       = "${var.resource_prefix}-compute-${count.index+1}-eth0"
  network_id = var.network1_id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.secgroup_ALL.id, 
    data.openstack_networking_secgroup_v2.secgroup_In_Cluster.id, 
    data.openstack_networking_secgroup_v2.secgroup_TF_ENDPOINT_SG.id, 
    data.openstack_networking_secgroup_v2.secgroup_SSH.id
  ]
}

resource "openstack_networking_floatingip_v2" "tf-compute-external-ips" {
  count = var.compute_instance_count
  pool  = var.floating_ip_pool_name
  lifecycle {
    ignore_changes = all
  }
}


resource "openstack_networking_port_v2" "tf-compute-eth1-ports" {
  count      = var.compute_instance_count
  name       = "${var.resource_prefix}-compute-${count.index+1}-eth1"
  network_id = var.network2_id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.secgroup_In_Cluster.id, 
  ]
}

resource "openstack_compute_instance_v2" "tf-computes" {
  count                   = var.compute_instance_count
  name                    = "${var.resource_prefix}-compute-${count.index+1}"
  availability_zone       = var.instance_az
  flavor_name             = var.compute_flavor_name
  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    volume_size           = var.volume_size
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.tf-compute-eth0-ports[count.index].id
  }

  user_data             = local.user_data_cloud_init

}
