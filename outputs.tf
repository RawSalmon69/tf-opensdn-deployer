output "ansible_inventory_internal" {
  description = "Ansible inventory style output for SSH access using internal IPs."
  value = join("\n", compact([
    format("%s     ansible_host=%s  ansible_ssh_user=nc-user   #fip=%s",
      openstack_compute_instance_v2.tf-openstack-controller.name,
      openstack_compute_instance_v2.tf-openstack-controller.network.0.fixed_ip_v4,
      openstack_networking_floatingip_v2.tf-openstack-controller-external-ip.address
    ),
    format("%s      ansible_host=%s  ansible_ssh_user=nc-user   #fip=%s",
      openstack_compute_instance_v2.tf-opensdn-controller.name,
      openstack_compute_instance_v2.tf-opensdn-controller.network.0.fixed_ip_v4,
      openstack_networking_floatingip_v2.tf-opensdn-controller-external-ip.address
    ),
    format("%s      ansible_host=%s  ansible_ssh_user=nc-user   #fip=%s",
      openstack_compute_instance_v2.tf-computes[0].name,
      openstack_compute_instance_v2.tf-computes[0].network.0.fixed_ip_v4,
      openstack_networking_floatingip_v2.tf-compute-external-ips[0].address

    ),
    format("%s      ansible_host=%s  ansible_ssh_user=nc-user   #fip=%s",
      openstack_compute_instance_v2.tf-computes[1].name,
      openstack_compute_instance_v2.tf-computes[1].network.0.fixed_ip_v4,
      openstack_networking_floatingip_v2.tf-compute-external-ips[1].address
    )
  ]))
}