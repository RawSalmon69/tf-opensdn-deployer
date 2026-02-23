# Architecture

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

---

## NIPA Cloud Reference

- NIPA Cloud documentation: https://docs-epc.gitbook.io/ncs-documents/
- OpenRC credentials: NIPA Cloud dashboard → Project Overview → Manage Project → Download **Public API RC file**
  Source this file before running any `openstack` CLI command: `source <projectname>-openrc.sh`

---

## Prerequisites (on the OpenStack controller node)

These are installed automatically by `scripts/preflight.sh` in the `tf-ansible-deployer` repo, run in Step 4 of the Deployment Order below.

**Python packages**:
- `ansible-core>=2.17,<2.19`
- `kolla-ansible==20.3.0`
- `requests<2.32`

**Ansible Galaxy collections**:
- `ansible.posix`
- `ansible.utils`
- `ansible.netcommon`
- `community.general`
- `community.docker`
- `containers.podman`
- `openstack.cloud`

---

## Phase 1 — Run from Your Local Machine

> The steps in this section run on your local machine. Terraform provisions the cloud infrastructure on NIPA Cloud. Once `terraform apply` completes, all further steps move to the OpenStack controller, which serves as the deployer host for all Ansible playbooks.

### NIPA Cloud Setup

Terraform provisions compute instances, ports, and floating IPs but does not create networks, the router, or security groups. The following resources must exist in the NIPA Cloud portal before running `terraform apply`.

1. Create Network1 (e.g. `10.10.1.0/24`) — control plane and management traffic (eth0 on all nodes). Disable RPF (Reverse Path Filtering) on this network.
2. Create Network2 (e.g. `10.20.1.0/24`) — data plane and vRouter (eth1 / vhost0 on compute nodes). Disable RPF (Reverse Path Filtering) on this network.
3. Create a Router and attach both networks to it
4. Add a static route on Network2: Destination `10.10.1.0/24`, Next hop `10.20.1.1`
5. Ensure the following security groups exist (create them if they do not):

   | Group | Purpose |
   |---|---|
   | `SSH` | SSH ingress |
   | `In-Cluster` | Unrestricted traffic between cluster nodes |
   | `TF_ENDPOINT_SG` | Ingress on ports 8082, 8085, 8143, 8180 |
   | `ALL` | Unrestricted ingress (used during initial setup) |

6. Create an Application Credential for Terraform. The credential ID and secret can be obtained from the NIPA Cloud dashboard under Project Overview → Manage Project → Public API.
7. Verify that the project has sufficient quota for the required number of instances, volumes, and floating IPs.

### Install Terraform

#### macOS

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Linux (Ubuntu/Debian)

```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform
```

#### Windows

Using winget (Windows 10/11):
```powershell
winget install HashiCorp.Terraform
```

Using Chocolatey:
```powershell
choco install terraform
```

Or download the binary directly from https://developer.hashicorp.com/terraform/downloads and add it to your `PATH`.

---

### Configure `terraform.tfvars`

The repository includes a `terraform.tfvars` file with NIPA Cloud defaults pre-filled. Open it in any text editor and fill in the fields that are left empty:

| Variable | Where to find it |
|---|---|
| `project_id` | NIPA Cloud dashboard → Project Overview → Manage Project |
| `openstack_application_credential_id` / `_secret` | NIPA Cloud dashboard → Project Overview → Manage Project → Public API |
| `image_id` | Ubuntu 22.04 — use image `ubuntu-22-v260122` (NIPA Cloud portal → Compute → Images) |
| `network1_id` | NIPA Cloud portal → Network → Networks |
| `network2_id` | NIPA Cloud portal → Network → Networks |
| `resource_prefix` | Short prefix applied to all resource names (default: `tf`); must match the instance keys used in `instances.yaml` |

All other values (region, availability zone, flavor names, etc.) are set to NIPA Cloud defaults and can be left as-is unless your environment differs.

---

### Instance Password

After `terraform apply`, reset the `root` password for each instance via the NIPA Cloud dashboard: Compute → Instances → select instance → Reset Password.

Once you can log in via the VNC console, set a password for the `root` user:

```bash
passwd root
```

Use `root` and the password you set when SSHing into the instances for all subsequent steps.

---

### Initialize and Apply

The following commands are the same on all platforms:

```bash
terraform init
terraform plan
terraform apply
```

After `terraform apply` completes, note the output — it includes the floating IPs and internal IPs you will need throughout Phase 2.

> **Action required before Phase 2.** Associate all floating IPs to their instances and attach the eth1 ports to the compute nodes via the NIPA Cloud dashboard before proceeding.

---

## Phase 2 — Run from the OpenStack Controller

> All steps in this section run on the OpenStack controller node, which serves as the Ansible deployer host. It has network access to all other nodes and is where `preflight.sh`, `setup_host.yaml`, and every `ansible-playbook` command is executed.

---

## Reference: Network Interface Setup

After `terraform apply`, two steps must be completed in the NIPA Cloud portal before proceeding to Phase 2.

**1. Associate floating IPs**

Run `terraform show` to see which floating IP belongs to which instance. Then for each instance (openstack-controller, opensdn-controller, compute-1, compute-2):

- Go to Network → Floating IPs in the NIPA Cloud dashboard.
- Associate each floating IP to the corresponding instance's eth0 port.
- Confirm the FIP appears on the instance under Compute → Instances.

**2. Attach eth1 (Network2) to compute nodes**

For each compute node:

- The eth1 port names follow the pattern `<prefix>-compute-1-eth1`, `<prefix>-compute-2-eth1` and are visible in Network → Ports. Port IDs are also available via `terraform show`.
- Go to Compute → Instances → select the compute instance → Attach Interface.
- Select the pre-created eth1 port. Verify the `In-Cluster` security group is applied.

---

## Deployment Order

### Step 1 — Provision infrastructure (local machine)

```bash
terraform apply
```

Note the output — you will need the floating IPs and internal IPs in subsequent steps.

---

### Step 1.5 — Manual portal steps (NIPA Cloud dashboard)

Before SSH-ing into any node, complete the following in the NIPA Cloud dashboard:

1. **Associate all 4 floating IPs** to their respective instances (openstack-controller, opensdn-controller, compute-1, compute-2) via Network → Floating IPs → Associate. Run `terraform show` to see which floating IP belongs to which instance.
2. **Attach the eth1 port** to each compute instance via Compute → Instances → Attach Interface. Port names are `<prefix>-compute-1-eth1` and `<prefix>-compute-2-eth1`. Port IDs are available via `terraform show`.

---

### Step 2 — SSH into the OpenStack controller

```bash
ssh root@<OPENSTACK_CONTROLLER_FIP>
```

> From this point on, every command runs on the OpenStack controller. It acts as the Ansible deployer for all nodes.

---

### Step 3 — Clone the Ansible deployer

```bash
git clone https://github.com/RawSalmon69/tf-ansible-deployer /root/tf-ansible-deployer
cd /root/tf-ansible-deployer
```

---

### Step 4 — Run preflight and activate the environment

```bash
bash scripts/preflight.sh
source /opt/kolla-deploy-env/bin/activate
```

This installs `ansible-core`, `kolla-ansible`, all required Galaxy collections, and generates an SSH keypair if one does not exist.

Verify the installation:

```bash
ansible --version
kolla-ansible --version
```

---

### Step 5 — Edit `config/instances.yaml`

`config/instances.yaml` defines the role of each node and the OpenSDN configuration. Open it for editing:

```bash
vi config/instances.yaml
```

Update the following fields:

- Instance keys (e.g. `tf-openstack-controller`, `tf-compute-1`) must exactly match the OS hostname of each node. Terraform sets the instance name, which cloud-init uses as the hostname.
- `ip:` fields — set to the internal IPs from `terraform output` (noted in Step 1).
- `VROUTER_GATEWAY:` — gateway IP of network2 (eth1 subnet). Find this under Network → Subnets in the NIPA Cloud portal.
- `KEYSTONE_AUTH_ADMIN_PASSWORD` / `keystone_admin_password` — change from the default to a secure value.
- `CONTAINER_REGISTRY` — registry hosting the OpenSDN images for your deployment.

Network IDs, subnet details, and application credentials can be found in the NIPA Cloud dashboard under Project Overview → Manage Project.

Reference configuration:

```yaml
provider_config:
  bms:
instances:
  tf-openstack-controller:
    provider: bms
    ip: 10.10.1.15
    roles:
      openstack_control:
      openstack_network:
      openstack_storage:

  tf-opensdn-controller:
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

  tf-compute-1:
    provider: bms
    ip: 10.10.1.16
    roles:
      openstack_compute:
      vrouter:
        PHYSICAL_INTERFACE: eth1
        VROUTER_GATEWAY: 10.20.1.1

  tf-compute-2:
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
    #docker_registry: "xxxxxxxxx"         # Default Image From quay.io
    #docker_namespace: "xxxxxxxxx"        # Default Image From quay.io
    #docker_registry_username: "xxxxxxx"

  kolla_passwords:
    keystone_admin_password: contrail123Nipa
    metadata_secret: contrail123Nipa
    #docker_registry_password: xxxxxxx
```

---

### Step 6 — Create the Ansible inventory

`my_inventory.ini` is a static inventory used for connectivity checks and `setup_host.yaml`. It is separate from the `inventory/` directory used by the deployer playbooks.

Run the following on your local machine and paste the output into the controller:

```bash
# On local machine
terraform output ansible_inventory_internal
```

Then on the controller, create the file:

```bash
cat > ~/tf-ansible-deployer/my_inventory.ini << 'EOF'
# Paste terraform output here, for example:
tf-openstack-controller     ansible_host=10.10.1.15  ansible_ssh_user=root   #fip=103.29.190.213
tf-opensdn-controller       ansible_host=10.10.1.18  ansible_ssh_user=root   #fip=103.29.190.227
tf-compute-1                ansible_host=10.10.1.16  ansible_ssh_user=root   #fip=103.29.190.224
tf-compute-2                ansible_host=10.10.1.17  ansible_ssh_user=root   #fip=103.29.190.225
EOF
```

---

### Step 7 — Verify connectivity

Create an `ansible.cfg` to disable host key checking for freshly provisioned instances, then run a ping check to confirm Ansible can reach all nodes:

```bash
cat > ansible.cfg << EOF
[defaults]
host_key_checking = False
EOF

ansible -m ping all -i my_inventory.ini -k
```

All nodes must return `pong` before continuing.

---

### Step 8 — Prepare all host nodes

Run `setup_host.yaml` to distribute the SSH key and create the `/opt/kollaenv` Python venv on all nodes:

```bash
ansible-playbook -i my_inventory.ini setup_host.yaml -k
```

---

### Step 9 — Verify hostnames and /etc/hosts

Every node's OS hostname must exactly match its key in `instances.yaml`. A mismatch causes RabbitMQ to form an incorrect cluster node name, resulting in a crash-loop that requires a full redeploy.

Check all hostnames:

```bash
ansible -m setup all -a 'filter=ansible_hostname' -i my_inventory.ini
```

If any node's hostname is wrong, fix it on that node and reboot:

```bash
hostnamectl set-hostname <correct-name>
reboot
```

The `resource_prefix` in `terraform.tfvars` determines instance names — ensure `instances.yaml` keys use the same prefix (e.g., if prefix is `tf`: `tf-compute-1`, `tf-openstack-controller`).

Additionally, `/etc/hosts` on every node must contain entries for all cluster nodes. Cluster services such as RabbitMQ and Cassandra rely on hostname resolution and will fail if these entries are missing.

Using the internal IPs from `terraform output`, add the entries to all nodes in one step:

```bash
ansible all -i my_inventory.ini --become -m ansible.builtin.blockinfile -a \
  "path=/etc/hosts marker='# {mark} OPENSDN CLUSTER HOSTS' block='10.10.1.15 tf-openstack-controller
10.10.1.18 tf-opensdn-controller
10.10.1.16 tf-compute-1
10.10.1.17 tf-compute-2'"
```

Replace the IPs and hostnames with the values from `terraform output`. Add or remove lines to match your `compute_instance_count`.

---

### Step 10 — Configure instances (~5 minutes)

The deployer playbooks use the `inventory/` directory, which is populated dynamically from `config/instances.yaml`. This is separate from `my_inventory.ini` used in the previous steps.

```bash
ansible-playbook \
  -e orchestrator=openstack \
  -e virtualenv=/opt/kollaenv \
  -e ansible_python_interpreter=/opt/kollaenv/bin/python3 \
  -i inventory/ playbooks/configure_instances.yml
```

Hostname validation runs as play 2 — resolve any failures before continuing.

---

### Step 11 — Attach eth1 ports (NIPA Cloud portal)

Before installing OpenStack, attach each compute node's eth1 data port via the NIPA Cloud portal:

- Run `terraform show` (locally) to identify the eth1 port IDs for each compute node.
- Attach each port via the NIPA Cloud portal: Compute → Instances → Attach Interface.
- Verify the `In-Cluster` security group is applied to all eth1 ports.

---

### Step 12 — Install OpenStack (~45 minutes)

Replace `<OPENSTACK_CONTROLLER_FIP>` with the floating IP of the OpenStack controller from Step 1. This configures the noVNC proxy URL so that browser console sessions are accessible from outside the cluster.

```bash
ansible-playbook \
  -e orchestrator=openstack \
  -e virtualenv=/opt/kollaenv \
  -e ansible_python_interpreter=/opt/kollaenv/bin/python3 \
  -e novnc_public_ip=<OPENSTACK_CONTROLLER_FIP> \
  -i inventory/ playbooks/install_openstack.yml
```

---

### Step 13 — Install OpenSDN (~20 minutes)

```bash
ansible-playbook \
  -e orchestrator=openstack \
  -e virtualenv=/opt/kollaenv \
  -e ansible_python_interpreter=/opt/kollaenv/bin/python3 \
  -i inventory/ playbooks/install_opensdn.yml
```

vRouter initialization runs automatically at the end of this playbook.

---

## After Installation

Run `kolla-ansible post-deploy` from the controller:

```bash
cd /root/contrail-kolla-ansible
kolla-ansible post-deploy -i ansible/inventory/my_inventory --configdir=/root/contrail-kolla-ansible/etc/kolla/
```

---

## OpenStack CLI Setup

Kolla generates OpenRC and clouds.yaml files after `post-deploy`. Set up a separate venv for the OpenStack CLI on the controller:

```bash
deactivate

python3 -m venv /opt/osenv
source /opt/osenv/bin/activate

pip3 install openstackclient
```

The generated credential files are in `/root/contrail-kolla-ansible/etc/kolla/`:

```
-rw------- 1 root root   551 admin-openrc.sh
-rw------- 1 root root   477 admin-openrc-system.sh
-rw------- 1 root root   926 clouds.yaml
-rw-r--r-- 1 root root  1429 globals.yml
-rw-r----- 1 root root 35522 passwords.yml
-rw------- 1 root root   462 public-openrc.sh
-rw------- 1 root root   394 public-openrc-system.sh
```

The Keystone URL in these files is generated with an empty host — fix it before use:

```bash
cd /root/contrail-kolla-ansible/etc/kolla
sed -i 's#http://:5000#http://10.10.1.15:5000#g' clouds.yaml
sed -i 's#http://:5000#http://10.10.1.15:5000#g' *.sh
```

Then source the credentials:

```bash
source /root/contrail-kolla-ansible/etc/kolla/admin-openrc.sh
```

---

## Verification & Testing

### Access OpenStack Horizon

```
http://<openstack-controller-ip>
user: admin
password: contrail123Nipa
```

### Access OpenSDN Web UI

```
http://<opensdn-controller-ip>:8143
user: admin
password: contrail123Nipa
```

If the UI is not reachable over HTTP, try HTTPS on the same port.

### Check contrail-status on the OpenSDN Controller

```bash
root@tf-opensdn-controller:/etc/contrail/control# contrail-status
Pod              Service         Original Name                         Original Version  State    Id            Status
                 redis           opensdn-external-redis                nightly           running  0d868dce3147  Up 2 hours
analytics        api             opensdn-analytics-api                 nightly           running  4718e59da113  Up 2 hours
analytics        collector       opensdn-analytics-collector           nightly           running  f1c7ecf9b91e  Up 2 hours
...
config-database  rabbitmq        opensdn-external-rabbitmq             nightly           running  3af11257a395  Up 2 hours
config-database  zookeeper       opensdn-external-zookeeper            nightly           running  e06aa9685a7f  Up 2 hours
control          control         opensdn-controller-control-control    nightly           running  18aef0e7af06  Up 15 seconds
...

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

== Contrail analytics ==
nodemgr: active
api: active
collector: active

== Contrail config-database ==
nodemgr: active
cassandra: active
zookeeper: active
rabbitmq: active
```

---

## Create Basic Resources

After sourcing the OpenRC file on the controller, create standard flavors and upload a test image:

```bash
openstack flavor create --id 1 --ram 512   --disk 1   --vcpus 1 m1.tiny
openstack flavor create --id 2 --ram 2048  --disk 20  --vcpus 1 m1.small
openstack flavor create --id 3 --ram 4096  --disk 40  --vcpus 2 m1.medium
openstack flavor create --id 4 --ram 8192  --disk 80  --vcpus 4 m1.large
openstack flavor create --id 5 --ram 16384 --disk 160 --vcpus 8 m1.xlarge
openstack flavor create --id 6 --ram 512   --disk 1   --vcpus 2 m2.tiny

wget https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create --file cirros-0.6.2-x86_64-disk.img --disk-format qcow2 --public cirros-0.6.2
```

---

## Logging

```bash
# Neutron server log
tail -f /var/log/kolla/neutron/neutron-server.log

# Nova compute log
tail -f /var/log/kolla/nova/nova-compute.log

# vRouter agent log (on compute nodes)
tail -f /var/log/contrail/contrail-vrouter-agent.log
```

Example neutron log output:
```
2025-11-14 01:52:47.829 32 ERROR neutron_plugin_contrail.plugins.opencontrail.quota.driver [...] Resource type subnetpool not found
2025-11-14 01:52:49.226 32 INFO neutron.wsgi [-] 10.10.1.15 "GET / HTTP/1.1" status: 200  len: 228 time: 0.0019927
2025-11-14 01:52:49.273 31 INFO neutron.wsgi [...] 10.10.1.15 "GET /v2.0/subnets HTTP/1.1" status: 200  len: 668 time: 0.0347683
```

---

## Advanced Terraform Usage

### Applying Specific Resources

You can use the `-target` flag to apply changes to a specific resource or a single instance of a resource created with `count`. This is useful for development or for recovering a single failed resource.

Note: Using `-target` can be risky as it ignores dependencies. Use with caution.

```bash
# Apply changes only to the OpenStack controller instance and all of its related resources
terraform apply -target=openstack_compute_instance_v2.tf-openstack-controller \
  -target=openstack_networking_port_v2.tf-openstack-controller-eth0 \
  -target=openstack_networking_floatingip_v2.tf-openstack-controller-external-ip

# Apply changes to the first compute node (index 0) and all of its related resources
terraform apply \
  -target=openstack_networking_port_v2.tf-compute-eth0-ports[0] \
  -target=openstack_networking_port_v2.tf-compute-eth1-ports[0] \
  -target=openstack_networking_floatingip_v2.tf-compute-external-ips[0] \
  -target=openstack_compute_instance_v2.tf-computes[0]
```

### Destroying Resources

```bash
# Tear down all infrastructure
terraform destroy

# Destroy only the second compute node (index 1)
terraform destroy -target=openstack_compute_instance_v2.tf-computes[1]
```

---

## Known Issues

- **RabbitMQ crash-loop** on a fresh install almost always indicates a hostname mismatch — verify hostnames (Step 10) before any other troubleshooting.
- **OpenSDN Web UI** is accessible at port **8143** on the OpenSDN controller. If the UI is not reachable over HTTP, try HTTPS on the same port.
- **Compute node vRouter not coming up** — the `install_opensdn.yml` playbook runs a vRouter initialization sequence at the end (DHCP on eth1, kernel module reload, compose restart). If the agent still fails to establish an XMPP session, see the vhost0 connectivity note below.

---

## Potential Issues

### vhost0 XMPP Connectivity on NIPA Cloud

After vRouter initializes, XMPP sessions sourced from vhost0 may be dropped by port security on the control-plane network. If the vRouter agent fails to connect to the control plane, setting an allowed-address-pair on the compute node's eth0 port has been observed to help in some deployments:

```bash
# Run from the controller with OpenRC sourced
# Port names follow the resource_prefix set in terraform.tfvars (default: tf)
PORT_NAME="<resource_prefix>-compute-<N>-eth0"   # e.g. tf-compute-1-eth0
VHOST0_CIDR="<network2_subnet>.0/24"   # /24 of the vhost0 IP

PORT_ID=$(openstack port show "${PORT_NAME}" -f value -c id)
openstack port set --allowed-address "ip-address=${VHOST0_CIDR}" "${PORT_ID}"
```

