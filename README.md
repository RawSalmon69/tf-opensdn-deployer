# Architechture

```
+-----------+ (network1)
|           +---------------------+--------------------------+---------------------------+--------------------------+
|           |                     |FIP                       |FIP                        |FIP                       |FIP
|           |                     |                          |                           |                          |
|  Logical  |                 eth0|10.10.1.x/24          eth0|10.10.1.x/24           eth0|10.10.1.x/24          eth0|10.10.1.x/24 
|  Router   |         +-----------+-----------+  +-----------+-----------+   +-----------+-----------+  +-----------+-----------+
|           |         |   [   OpenStack   ]   |  |   [   OpenSDN    ]    |   | [ OpenStack Compute ] |  | [ OpenStack Compute ] |
|           |         |    ( Controller  )    |  |    ( Controller  )    |   |                       |  |                       |
+-----+-----+         |                       |  |                       |   |                       |  |                       |
      |               |  MariaDB    RabbitMQ  |  |  rabbitmq,            |   |  Nova Compute         |  |  Nova Compute         |
      |               |  Memcached  Nginx     |  |  Cassandra.           |   |  Nova Libvirt         |  |  Nova Libvirt         |
      |               |  Keystone   httpd     |  |  zookeeper            |   |  Vrouter agent        |  |  Vrouter agent        |
      |               |  Glance     Nova API  |  |  api, schema ,svc     |   |                       |  |                       |
      |               |  Neutron Server       |  |  control, dns named   |   |                       |  |                       |
      |               |  Neutron Metadata     |  |  webui, job, redis    |   |                       |  |                       |
      |               +-----------------------+  +-----------------------+   +-----------+-----------+  +-----------+-----------+
      |                                                                              eth1| (vhost0)             eth1| (vhost0) 
      | (network2)                                                                       |                          |
      +----------------------------------------------------------------------------------+--------------------------+

```
# STEP 

## 1. Prerequiresite
    1.1 Create Network1 (eg. 10.10.1.0/24)
    1.2 Create Network2 (eg. 10.20.1.0/24)
    1.3 Create Router and attach Network1 and Network2 in to it.
    1.4 Add additional route in Network2 eg. Destionation IP 10.10.1.0/24, Nexthop IP 10.20.1.1.
    1.5 Check that the required security groups exist: `SSH`, `In-Cluster`, `TF_ENDPOINT_SG(Ingress 8082,8085,8143,8180)`, `ALL`.
    1.6 Create an OpenStack Application Credential for Terraform to use.
    1.7 Recheck available quota in the project.

## Install Terraform (MAC)
```bash
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
```

## Create Terraform variable 
```
cat > terraform.tfvars << EOF

# OpenStack Keystone URL
openstack_auth_url = "https://cloud-api.nipa.cloud:5000/v3"

# OpenStack User Domain name
openstack_domain_name = "nipacloud"

# OpenStack Project name
project_id = ""

# OpenStack Application Credential ID
openstack_application_credential_id = ""

# OpenStack Application Secret
openstack_application_credential_secret = ""

# OpenStack Region 
openstack_region = "NCP-TH"

# OpenStack Instance AZ
instance_az = "NCP-NON"

# OpenStack Instance Image ID - Using Rocky 9.3
image_id = ""

# OpenStack Instance OS Disk
volume_size = 200

# OpenStack Instance Interface Control (with Gateway)
network1_id = ""

# OpenStack Instance Interface for Vhost0
network2_id = ""

# OpenStack Floating IP for assosiate with Interface Control
floating_ip_pool_name = "Standard_Public_IP_Pool_NON"

# OpenStack Instance Flavor Name (For OpenStack Contoller role and OpenSDN Controller role)
controller_flavor_name = "csa.2xlarge.v2"

# OpenStack Instance Flavor Name (For Compute role)
compute_flavor_name = "csa.2xlarge.v2"

# Number of OpenStack Compute Node 
compute_instance_count = 2

EOF
```

## Customizing the Instance Password 
The instances are created with a default user `nc-user` and a default password `y0V#ew8k4nM+`. To change this password, you need to update two variables in your terraform.tfvars file: 
1. `ssh_user_password`: The plain-text password used by Terraform to run the post-creation SSH connection test. 
2. `ssh_user_password_hash`: The cryptographically-hashed version of the password that cloud-init uses to set the user's password on the instance. To generate a new password hash, use the openssl command. For example, to generate a hash for the password MyNewSecretPassword!: 
```bash 
openssl passwd -6 'MyNewSecretPassword!' 
```
This will output a string that starts with `$6$`. You would then update your terraform.tfvars file like this:  
```
# In terraform.tfvars
ssh_user_password = "MyNewSecretPassword!"
ssh_user_password_hash = "$6$your_generated_hash_string..."
```

## Before you can run a plan or apply, you must initialize the Terraform working directory.
```
terraform init
```

## Run a plan to see what resources will be created.
```
terraform plan
```


## If the plan is acceptable, apply the configuration to create the infrastructure.
```
terraform apply
```

## Advanced Usage

### Applying Specific Resources

You can use the `-target` flag to apply changes to a specific resource or a single instance of a resource created with `count`. This is useful for development or for recovering a single failed resource.

**Note:** Using `-target` can be risky as it ignores dependencies. Use with caution.

```bash
# Apply changes only to the OpenStack controller instance and all of its related
# resources (network ports, floating IP, and SSH test), you must target
# every resource individually.
terraform apply -target=openstack_compute_instance_v2.tf-openstack-controller \
  -target=openstack_networking_port_v2.tf-openstack-controller-eth0 \
  -target=openstack_networking_floatingip_v2.tf-openstack-controller-external-ip \
  -target=openstack_networking_floatingip_associate_v2.tf-openstack-controller-fip-associate \
  -target=ssh_resource.test-ssh-openstack-controller

# To apply changes to the first compute node (index 0) and all of its related resources.
terraform apply \
  -target=openstack_networking_port_v2.tf-compute-eth0-ports[0] \
  -target=openstack_networking_port_v2.tf-compute-eth1-ports[0] \
  -target=openstack_networking_floatingip_v2.tf-compute-external-ips[0] \
  -target=openstack_compute_instance_v2.tf-computes[0] \
  -target=openstack_networking_floatingip_associate_v2.tf-compute-fip-associates[0] \
  -target=ssh_resource.test-ssh-computes[0]

```

### Destroying Resources

To tear down all infrastructure created by this project, use the `destroy` command.
```bash
terraform destroy
```

You can also use the `-target` flag to destroy a specific resource.
```bash
# Destroy only the second compute node (index 1)
terraform destroy -target=openstack_compute_instance_v2.tf-computes[1]
```

# ติดตั้ง OpenSDN

prerequisite ต้องสร้าง vm มาก่อน

- terraform apply (https://gitlab.nipa.cloud/tungsten-fabric/terrafrom-opensdn-lab-deployer)

ผลลัพธ์จาก terraform
```
moo-openstack-controller     ansible_host=10.10.1.15  ansible_ssh_user=nc-user   #fip=103.29.190.213
moo-opensdn-controller      ansible_host=10.10.1.18  ansible_ssh_user=nc-user   #fip=103.29.190.227
moo-compute-1      ansible_host=10.10.1.16  ansible_ssh_user=nc-user   #fip=103.29.190.224
moo-compute-2      ansible_host=10.10.1.17  ansible_ssh_user=nc-user   #fip=103.29.190.225
```





Prepare Deployer Host



ใช้ terminal ssh ไปที่  openstack-controller เราจะใช้เป็นเครื่องรัน ansible 


สร้าง venv ชื่อ kolla-deploy-env ไว้ลง pip kolla-ansible 

```
apt-get install python3 python3-pip python3-venv sshpass -y

python3 -m venv /opt/kolla-deploy-env
source /opt/kolla-deploy-env/bin/activate

pip3 install kolla-ansible
#pip3 install 'ansible>=6,<8'
ansible-galaxy collection install community.docker

ssh-keygen
```


check ansible version (เผื่อมีปัญหา)

```
root@moo-openstack-controller:~/tf-ansible-deployer~$ ansible --version
ansible [core 2.18.11]
  config file = /root/tf-ansible-deployer/ansible.cfg
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /opt/kolla-deploy-env/lib/python3.12/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /opt/kolla-deploy-env/bin/ansible
  python version = 3.12.3 (main, Aug 14 2025, 17:47:21) [GCC 13.3.0] (/opt/kolla-deploy-env/bin/python3)
  jinja version = 3.1.6
  libyaml = True

(kolla-deploy-env) root@moo-openstack-controller:~/tf-ansible-deployer~$ kolla-ansible --version
kolla-ansible 20.3.0
```

Create Inventory From Terraform Output


Terraform จะให้มา จาก output ตอนรันเสร็จ สามารถ copy มาใช้ได้

```
cat > ./my_inventory.ini << EOT

moo-openstack-controller     ansible_host=10.10.1.15  ansible_ssh_user=nc-user   #fip=103.29.190.213
moo-opensdn-controller      ansible_host=10.10.1.18  ansible_ssh_user=nc-user   #fip=103.29.190.227
moo-compute-1      ansible_host=10.10.1.16  ansible_ssh_user=nc-user   #fip=103.29.190.224
moo-compute-2      ansible_host=10.10.1.17  ansible_ssh_user=nc-user   #fip=103.29.190.225

EOT
```


ทดสอบ inventory ที่ได้มาโดยการ  ping pong check

```
cat > ansible.cfg << EOF
[defaults]
host_key_checking = False

EOF 

ansible -m ping all -i my_inventory.ini -k
```







เนื่องจากเครื่องที่สร้างมายังไม่พร้อมรัน ansible เราจำเป็นต้อง prepare host เพื่อให้รัน ansible ได้

- copy ssh pub key to root user  ทำให้ ssh ไป remote ได้โดยไม่มี password
- install package and create venv (/opt/kollaenv) ไว้ลง pip package เวลา deployer ต้องใช้ตอน run ansible

```
cat > ./setup_host.yaml <<EOF
---
- name: Prepare Host for tf-ansible-deployer
  hosts: all
  become: true

  tasks:
    - name: Ensure .ssh directory exists and has correct permissions
      ansible.builtin.file:
        path: "/root/.ssh"
        state: directory
        mode: '0700'

    - name: Add public key to authorized_keys
      ansible.posix.authorized_key:
        user: root
        state: present
        key: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"

    - name: Install required packages
      ansible.builtin.apt:
        name:
          - python3
          - python3-pip
          - python3-venv
        state: present
        update_cache: yes

    - name: Create a virtual environment for docker-py
      ansible.builtin.command: >
        python3 -m venv --system-site-packages /opt/kollaenv
      args:
        creates: /opt/kollaenv/bin/activate

    - name: Create Python virtual environment at /opt/kollaenv
      ansible.builtin.pip:
        name: 
          - docker<7
        virtualenv: /opt/kollaenv

EOF
```


Run setup_host.yaml Playbook


```
ansible-playbook -i my_inventory.ini setup_host.yaml -k
```




หลังจากนี้จะเป็น step จาก upsteam repo tf-ansible-deployer แต่เราจะต้องปรับเปลี่ยนบางอย่างเพื่อให้ติดตั้งได้ไว และใช้ได้ทันที








Setup OpenSDN Deployer

```
cd /root/
git clone https://github.com/OpenSDN-io/tf-ansible-deployer 
cd ./tf-ansible-deployer/config/
cat > ./instances.yaml << EOF
provider_config:
  bms:
instances:
  moo-openstack-controller:
    provider: bms
    ip: 10.10.1.15
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:

  moo-opensdn-controller:
    provider: bms
    ip: 10.10.1.18
    roles:
      analytics:
      analytics_snmp:
      analytics_alarm:
      analytics_database:
      config:
      config_database:
      control:
      webui:

  moo-compute-1:
    provider: bms
    ip: 10.10.1.16
    roles:
      openstack_compute:
      vrouter:
        PHYSICAL_INTERFACE: eth1
        VROUTER_GATEWAY: 10.20.1.1

  moo-compute-2:
    provider: bms
    ip: 10.10.1.17
    roles:
      openstack_compute:
      vrouter:
        PHYSICAL_INTERFACE: eth1
        VROUTER_GATEWAY: 10.20.1.1

global_configuration:
  CONTAINER_REGISTRY: registry.nipa.cloud/nipa-opensdn
  ENABLE_DESTROY: false

contrail_configuration:
  KEYSTONE_AUTH_ADMIN_PORT: 5000
  KEYSTONE_AUTH_PUBLIC_PORT: 5000
  KEYSTONE_AUTH_INTERFACE: internal
  KEYSTONE_AUTH_URL_VERSION: /v3
  KEYSTONE_AUTH_ADMIN_PASSWORD: contrail123Nipa
  CONTRAIL_VERSION: "2025-11-03"
  OPENSTACK_VERSION: "2024.1"
  CONFIG_DATABASE_NODEMGR__DEFAULTS__minimum_diskGB: "1"
  DATABASE_NODEMGR__DEFAULTS__minimum_diskGB: "1"
  JVM_EXTRA_OPTS: "-Xms2g -Xmx4g"
  VROUTER_ENCRYPTION: FALSE
  LOG_LEVEL: SYS_DEBUG
  CLOUD_ORCHESTRATOR: openstack
  SSL_ENABLE: "false"
  RABBITMQ_USE_SSL: "false"
  CASSANDRA_SSL_ENABLE: "false"
  ANALYTICSDB_ENABLE: "true"
  ANALYTICS_ALARM_ENABLE: "true"
  ANALYTICS_SNMP_ENABLE: "true"
  AUTH_MODE: keystone
  AAA_MODE: rbac
  STDIN_OPEN: true
  RABBITMQ_NODE_PORT: 5673
  KOLLA_MODE: patched

kolla_config:
  kolla_globals:
    network_interface: eth0
    enable_haproxy: no
    enable_proxysql: no
    enable_swift: no
    openstack_service_workers: 2
    kolla_base_distro: "ubuntu"
    kolla_install_type: "source"
    nova_compute_virt_type: "qemu"
    heat_opencontrail_init_image_full: opensdn/opensdn-openstack-heat-init:latest
    neutron_opencontrail_init_image_full: opensdn/opensdn-openstack-neutron-init:latest
    neutron_opencontrail_ml2_init_image_full: opensdn/opensdn-openstack-neutron-init:latest
    nova_compute_opencontrail_init_image_full: opensdn/opensdn-openstack-compute-init:latest
    #docker_registry: "xxxxxxxxx"         # Default Image From quey.io
    #docker_namespace: "xxxxxxxxx"        # Default Image From quey.io
    #docker_registry_username: "xxxxxxx" 

  kolla_passwords:
    keystone_admin_password: contrail123Nipa
    metadata_secret: contrail123Nipa
    #docker_registry_password: xxxxxxx
EOF
```

แก้ไข IP, Hostname ให้เป็นของ Instance ตัวเองก่อน

ขั้นตอนการ prepare host ก่อนจะรัน ติดตั้ง opensdn + openstack  (5 minutes)

```
cd /root/tf-ansible-deployer

ansible-playbook \
-e orchestrator=openstack \
-e virtualenv=/opt/kollaenv \
-e ansible_python_interpreter=/opt/kollaenv/bin/python3 \
-i inventory/ playbooks/configure_instances.yml -v
```

1. ขั้นตอนการติดตั้ง OpenStack (45 minutes)
   

```

### แก้ปัญหา playbook หายและ format เปลี่ยนจาก ansible version

cat > install_openstack.yaml-patch <<  EOF
diff --git a/playbooks/install_openstack.yml b/playbooks/install_openstack.yml
index 0fd0da7..71ceca6 100644
--- a/playbooks/install_openstack.yml
+++ b/playbooks/install_openstack.yml
@@ -29,12 +29,12 @@
   vars_files:
     - "{{ hostvars['localhost'].config_file }}"
   vars:
-    - container_registry: "{{ hostvars['localhost'].container_registry }}"
-    - contrail_version_tag: "{{ hostvars['localhost'].contrail_version_tag }}"
-    - config_nodes_list: "{{ hostvars['localhost'].config_nodes_list }}"
-    - analytics_nodes_list: "{{ hostvars['localhost'].analytics_nodes_list }}"
-    - openstack_nodes_list: "{{ hostvars['localhost'].openstack_nodes_list }}"
-    - webui_nodes_list: "{{ hostvars['localhost'].webui_nodes_list }}"
+    container_registry: "{{ hostvars['localhost'].container_registry }}"
+    contrail_version_tag: "{{ hostvars['localhost'].contrail_version_tag }}"
+    config_nodes_list: "{{ hostvars['localhost'].config_nodes_list }}"
+    analytics_nodes_list: "{{ hostvars['localhost'].analytics_nodes_list }}"
+    openstack_nodes_list: "{{ hostvars['localhost'].openstack_nodes_list }}"
+    webui_nodes_list: "{{ hostvars['localhost'].webui_nodes_list }}"
   tasks:
   - name: Import group variables
     no_log: True
@@ -90,7 +90,7 @@
   connection: local
   gather_facts: no
   vars:
-    - kolla_config: "{{ hostvars['localhost'].get('kolla_config', None) }}"
+    kolla_config: "{{ hostvars['localhost'].get('kolla_config', None) }}"
   vars_files:
     - "{{ config_file }}"
   pre_tasks:
@@ -121,7 +121,7 @@
   connection: local
   gather_facts: no
   vars:
-    - kolla_config: "{{ hostvars['localhost'].get(kolla_config, None) }}"
+    kolla_config: "{{ hostvars['localhost'].get(kolla_config, None) }}"
   vars_files:
     - "{{ config_file }}"
   pre_tasks:
@@ -173,4 +173,4 @@
     action: deploy
     kolla_action: deploy

-- import_playbook: "{{ playbook_dir }}/../../contrail-kolla-ansible/ansible/post-deploy-contrail.yml"
+#- import_playbook: "{{ playbook_dir }}/../../contrail-kolla-ansible/ansible/post-deploy-contrail.yml"
EOF

## รัน apply patch file
git apply install_openstack.yaml-patch


cd /root/tf-ansible-deployer
ansible-playbook \
-e orchestrator=openstack \
-e virtualenv=/opt/kollaenv \
-e ansible_python_interpreter=/opt/kollaenv/bin/python \
-i inventory/ playbooks/install_openstack.yml -v
```
2. ขั้นตอนการติดตั้ง OpenSDN  (20 minutes)
   



โดยจะใช้ image จาก global_configuration  CONTAINER_REGISTRY: registry.nipa.cloud/nipa-opensdn

```
cd /root/tf-ansible-deployer

## แก้ไขปัญหา docker_compose module end of support ใน ansible version ที่เราใช้
grep -rl "docker_compose:" playbooks/roles/ | xargs sed -i "s/docker_compose:/community.docker.docker_compose_v2:/g"
grep -rl "version: '2.4'"  playbooks/roles/ | xargs sed -i "s/version: '2.4'/---/g"

ansible-playbook -e orchestrator=openstack \
-e virtualenv=/opt/kollaenv \
-e ansible_python_interpreter=/opt/kollaenv/bin/python3 \
-i inventory/ playbooks/install_opensdn.yml -v
```




ทดสอบเข้า OpenStack Horizon


http://tf-openstack-controller
user admin
password contrail123Nipa



ทดสอบเข้า OpenSDN webUI


http://tf-openstack-controller:8180
user admin
password contrail123Nipa







After Installation

```
cd /root/contrail-kolla-ansible

kolla-ansible post-deploy -i ansible/inventory/my_inventory --configdir=/root/contrail-kolla-ansible/etc/kolla/

```

การใช้งาน command openstack (จะมี venv แยกสำหรับ command openstack โดยเฉพราะ)


```
deactivate

python3 -m venv /opt/osenv
source /opt/osenv/bin/activate

pip3 install openstackclient

cd /root/contrail-kolla-ansible/etc/kolla
ls -al
drwxr-xr-x 2 root root  4096 Nov 14 01:31 .
drwxr-xr-x 3 root root  4096 Nov 14 00:52 ..
-rw------- 1 root root   551 Nov 14 01:31 admin-openrc.sh
-rw------- 1 root root   477 Nov 14 01:31 admin-openrc-system.sh
-rw------- 1 root root   926 Nov 14 01:31 clouds.yaml
-rw-r--r-- 1 root root  1429 Nov 14 01:00 globals.yml
-rw-r----- 1 root root 35522 Nov 14 01:24 passwords.yml
-rw------- 1 root root   462 Nov 14 01:31 public-openrc.sh
-rw------- 1 root root   394 Nov 14 01:31 public-openrc-system.sh

## Replace IP in openrc file
 sed -i 's#http://:5000#http://10.10.1.15:5000#g' clouds.yaml
 sed -i 's#http://:5000#http://10.10.1.15:5000#g' *.sh


```






Create Basic Resource

```
openstack flavor create --id 1 --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack flavor create --id 2 --ram 2048 --disk 20 --vcpus 1 m1.small
openstack flavor create --id 3 --ram 4096 --disk 40 --vcpus 2 m1.medium
openstack flavor create --id 4 --ram 8192 --disk 80 --vcpus 4 m1.large
openstack flavor create --id 5 --ram 16384 --disk 160 --vcpus 8 m1.xlarge
openstack flavor create --id 6 --ram 512 --disk 1 --vcpus 2 m2.tiny
+----------------------------+---------+
| Field                      | Value   |
+----------------------------+---------+
| OS-FLV-DISABLED:disabled   | False   |
| OS-FLV-EXT-DATA:ephemeral  | 0       |
| description                | None    |
| disk                       | 1       |
| id                         | 1       |
| name                       | m1.tiny |
| os-flavor-access:is_public | True    |
| properties                 |         |
| ram                        | 512     |
| rxtx_factor                | 1.0     |
| swap                       | 0       |
| vcpus                      | 1       |
+----------------------------+---------+
+----------------------------+----------+
| Field                      | Value    |
+----------------------------+----------+
| OS-FLV-DISABLED:disabled   | False    |
| OS-FLV-EXT-DATA:ephemeral  | 0        |
| description                | None     |
| disk                       | 20       |
| id                         | 2        |
| name                       | m1.small |
| os-flavor-access:is_public | True     |
| properties                 |          |
| ram                        | 2048     |
| rxtx_factor                | 1.0      |
| swap                       | 0        |
| vcpus                      | 1        |
+----------------------------+----------+
+----------------------------+-----------+
| Field                      | Value     |
+----------------------------+-----------+
| OS-FLV-DISABLED:disabled   | False     |
| OS-FLV-EXT-DATA:ephemeral  | 0         |
| description                | None      |
| disk                       | 40        |
| id                         | 3         |
| name                       | m1.medium |
| os-flavor-access:is_public | True      |
| properties                 |           |
| ram                        | 4096      |
| rxtx_factor                | 1.0       |
| swap                       | 0         |
| vcpus                      | 2         |
+----------------------------+-----------+
+----------------------------+----------+
| Field                      | Value    |
+----------------------------+----------+
| OS-FLV-DISABLED:disabled   | False    |
| OS-FLV-EXT-DATA:ephemeral  | 0        |
| description                | None     |
| disk                       | 80       |
| id                         | 4        |
| name                       | m1.large |
| os-flavor-access:is_public | True     |
| properties                 |          |
| ram                        | 8192     |
| rxtx_factor                | 1.0      |
| swap                       | 0        |
| vcpus                      | 4        |
+----------------------------+----------+
+----------------------------+-----------+
| Field                      | Value     |
+----------------------------+-----------+
| OS-FLV-DISABLED:disabled   | False     |
| OS-FLV-EXT-DATA:ephemeral  | 0         |
| description                | None      |
| disk                       | 160       |
| id                         | 5         |
| name                       | m1.xlarge |
| os-flavor-access:is_public | True      |
| properties                 |           |
| ram                        | 16384     |
| rxtx_factor                | 1.0       |
| swap                       | 0         |
| vcpus                      | 8         |
+----------------------------+-----------+
+----------------------------+---------+
| Field                      | Value   |
+----------------------------+---------+
| OS-FLV-DISABLED:disabled   | False   |
| OS-FLV-EXT-DATA:ephemeral  | 0       |
| description                | None    |
| disk                       | 1       |
| id                         | 6       |
| name                       | m2.tiny |
| os-flavor-access:is_public | True    |
| properties                 |         |
| ram                        | 512     |
| rxtx_factor                | 1.0     |
| swap                       | 0       |
| vcpus                      | 2       |
+----------------------------+---------+

wget https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create --file cirros-0.6.2-x86_64-disk.img --disk-format qcow2 --public cirros-0.6.2

+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field            | Value                                                                                                                                                                                                                                                                                                                                    |
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| checksum         | c8fc807773e5354afe61636071771906                                                                                                                                                                                                                                                                                                         |
| container_format | bare                                                                                                                                                                                                                                                                                                                                     |
| created_at       | 2025-11-13T18:55:08Z                                                                                                                                                                                                                                                                                                                     |
| disk_format      | qcow2                                                                                                                                                                                                                                                                                                                                    |
| file             | /v2/images/900e2f09-eaf3-4caa-982c-7ca63fc6b4c7/file                                                                                                                                                                                                                                                                                     |
| id               | 900e2f09-eaf3-4caa-982c-7ca63fc6b4c7                                                                                                                                                                                                                                                                                                     |
| min_disk         | 0                                                                                                                                                                                                                                                                                                                                        |
| min_ram          | 0                                                                                                                                                                                                                                                                                                                                        |
| name             | cirros-0.6.2                                                                                                                                                                                                                                                                                                                             |
| owner            | 42ecbcd09f3140af87501a40b03aebb9                                                                                                                                                                                                                                                                                                         |
| properties       | os_hash_algo='sha512', os_hash_value='1103b92ce8ad966e41235a4de260deb791ff571670c0342666c8582fbb9caefe6af07ebb11d34f44f8414b609b29c1bdf1d72ffa6faa39c88e8721d09847952b', os_hidden='False', owner_specified.openstack.md5='', owner_specified.openstack.object='images/cirros-0.6.2', owner_specified.openstack.sha256='', stores='file' |
| protected        | False                                                                                                                                                                                                                                                                                                                                    |
| schema           | /v2/schemas/image                                                                                                                                                                                                                                                                                                                        |
| size             | 21430272                                                                                                                                                                                                                                                                                                                                 |
| status           | active                                                                                                                                                                                                                                                                                                                                   |
| tags             |                                                                                                                                                                                                                                                                                                                                          |
| updated_at       | 2025-11-13T18:55:09Z                                                                                                                                                                                                                                                                                                                     |
| virtual_size     | 117440512                                                                                                                                                                                                                                                                                                                                |
| visibility       | public                                                                                                                                                                                                                                                                                                                                   |
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
```



LOGGING

```
 tail -f /var/log/kolla/neutron/neutron-server.log
2025-11-14 01:52:47.829 32 ERROR neutron_plugin_contrail.plugins.opencontrail.quota.driver [None req-802e869c-9593-4162-b537-e315a7f701ca 1e251927fecf4ef1b4ad74073c94499e 42ecbcd09f3140af87501a40b03aebb9 - - default default] Resource type subnetpool not found
2025-11-14 01:52:49.226 32 INFO neutron.wsgi [-] 10.10.1.15 "GET / HTTP/1.1" status: 200  len: 228 time: 0.0019927
2025-11-14 01:52:49.273 31 INFO neutron.wsgi [None req-7822cfee-24bf-4614-a8a6-e6a34f88e4ce 1e251927fecf4ef1b4ad74073c94499e 42ecbcd09f3140af87501a40b03aebb9 - - default default] 10.10.1.15 "GET /v2.0/subnets HTTP/1.1" status: 200  len: 668 time: 0.0347683
```



ตรวจสอบเครื่อง tf-opensdn-controller
```
root@moo-opensdn-controller:/etc/contrail/control# contrail-status
Unable to find image 'registry.nipa.cloud/nipa-opensdn/opensdn-status:2025-11-03' locally
2025-11-03: Pulling from nipa-opensdn/opensdn-status
4622e890055f: Pull complete
3a950f7ba0c7: Pull complete
700648634947: Pull complete
Digest: sha256:abc0575a25df72214d4dbcf7eed088372b6a1cf3b2ef85aed17f267b3ff23fb7
Status: Downloaded newer image for registry.nipa.cloud/nipa-opensdn/opensdn-status:2025-11-03
Pod              Service         Original Name                         Original Version  State    Id            Status
                 redis           opensdn-external-redis                nightly           running  0d868dce3147  Up 2 hours
analytics        api             opensdn-analytics-api                 nightly           running  4718e59da113  Up 2 hours
analytics        collector       opensdn-analytics-collector           nightly           running  f1c7ecf9b91e  Up 2 hours
analytics        nodemgr         opensdn-nodemgr                       nightly           running  2c69186ee979  Up 2 hours
analytics        provisioner     opensdn-provisioner                   nightly           running  50ee56c11b85  Up 2 hours
analytics-alarm  alarm-gen       opensdn-analytics-alarm-gen           nightly           running  457c2f56f45b  Up 2 hours
analytics-alarm  kafka           opensdn-external-kafka                nightly           running  cbfe11da6f00  Up 2 hours
analytics-alarm  nodemgr         opensdn-nodemgr                       nightly           running  49d884fe388f  Up 2 hours
analytics-alarm  provisioner     opensdn-provisioner                   nightly           running  2402c68aaad5  Up 2 hours
analytics-snmp   nodemgr         opensdn-nodemgr                       nightly           running  d41e32543e04  Up 2 hours
analytics-snmp   provisioner     opensdn-provisioner                   nightly           running  f08a27fc8484  Up 2 hours
analytics-snmp   snmp-collector  opensdn-analytics-snmp-collector      nightly           running  17175110198a  Up 2 hours
analytics-snmp   topology        opensdn-analytics-snmp-topology       nightly           running  84c5f65ee3d2  Up 2 hours
config           api             opensdn-controller-config-api         nightly           running  f368d9494d6d  Up 37 seconds
config           device-manager  opensdn-controller-config-devicemgr   nightly           running  1a40fe7371af  Up 36 seconds
config           dnsmasq         opensdn-controller-config-dnsmasq     nightly           running  21837788e273  Up 2 seconds
config           nodemgr         opensdn-nodemgr                       nightly           running  25f3c85578b7  Up 37 seconds
config           provisioner     opensdn-provisioner                   nightly           running  26b996a49bda  Up 37 seconds
config           schema          opensdn-controller-config-schema      nightly           running  0aa942271705  Up 37 seconds
config           svc-monitor     opensdn-controller-config-svcmonitor  nightly           running  b005ca864496  Up 37 seconds
config-database  cassandra       opensdn-external-cassandra            nightly           running  bc8c8413e9a2  Up 2 hours
config-database  nodemgr         opensdn-nodemgr                       nightly           running  e49aa892e5ae  Up 2 hours
config-database  provisioner     opensdn-provisioner                   nightly           running  1b866cabf330  Up 2 hours
config-database  rabbitmq        opensdn-external-rabbitmq             nightly           running  3af11257a395  Up 2 hours
config-database  zookeeper       opensdn-external-zookeeper            nightly           running  e06aa9685a7f  Up 2 hours
control          control         opensdn-controller-control-control    nightly           running  18aef0e7af06  Up 15 seconds
control          dns             opensdn-controller-control-dns        nightly           running  d89c2edc70a6  Up 15 seconds
control          named           opensdn-controller-control-named      nightly           running  a1836381344d  Up 14 seconds
control          nodemgr         opensdn-nodemgr                       nightly           running  7eb67a0d7402  Up 15 seconds
control          provisioner     opensdn-provisioner                   nightly           running  45ede9be39e0  Up 15 seconds
database         cassandra       opensdn-external-cassandra            nightly           running  5fb07f00ef2b  Up 2 hours
database         nodemgr         opensdn-nodemgr                       nightly           running  f632984b90cd  Up 2 hours
database         provisioner     opensdn-provisioner                   nightly           running  a3288b288e4c  Up 2 hours
database         query-engine    opensdn-analytics-query-engine        nightly           running  df85aae5242a  Up 2 hours
webui            job             opensdn-controller-webui-job          nightly           running  5e135c391b3d  Up 2 hours
webui            web             opensdn-controller-webui-web          nightly           running  da3d376f5865  Up 6 minutes

WARNING: container with original name 'opensdn-external-redis' have Pod or Service empty. Pod: '' / Service: 'redis'. Please pass NODE_TYPE with pod name to container's env

== Contrail control ==
nodemgr: active
control: active
named: active
dns: active

== Contrail config ==
nodemgr: active
api: active
schema: active
svc-monitor: active
device-manager: active

== Contrail analytics-snmp ==
nodemgr: active
snmp-collector: active
topology: active

== Contrail analytics-alarm ==
nodemgr: active
alarm-gen: active
kafka: active

== Contrail analytics ==
nodemgr: active
api: active
collector: active

== Contrail database ==
nodemgr: active
query-engine: active
cassandra: active

== Contrail webui ==
web: active
job: active

== Contrail config-database ==
nodemgr: active
cassandra: active
zookeeper: active
rabbitmq: active
```



## Know Issue

- Compute Node vrouter ยังไม่ Up