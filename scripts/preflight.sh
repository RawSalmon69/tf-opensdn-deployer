#!/usr/bin/env bash
# Run on the deployer node before any Ansible playbook.
# Installs pinned versions of ansible-core, kolla-ansible, and all required
# Galaxy collections. Generates an SSH keypair if one does not already exist.
set -euo pipefail

echo "[1/5] Installing system packages"
apt-get update -y
apt-get install -y python3 python3-pip python3-venv sshpass software-properties-common
add-apt-repository universe -y

echo "[2/5] Creating Python virtual environment"
python3 -m venv /opt/kolla-deploy-env
source /opt/kolla-deploy-env/bin/activate

echo "[3/5] Installing Python packages"
pip3 install \
  'ansible-core>=2.15,<2.17' \
  'kolla-ansible==20.3.0' \
  'requests<2.32'

echo "[4/5] Installing Ansible Galaxy collections"
ansible-galaxy collection install \
  ansible.posix \
  ansible.utils \
  ansible.netcommon \
  community.general \
  community.docker \
  containers.podman \
  openstack.cloud

echo "[5/5] Checking SSH keypair"
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
  echo "Keypair generated at ~/.ssh/id_ed25519"
else
  echo "Keypair already exists at ~/.ssh/id_ed25519"
fi

echo ""
echo "=== Installed versions ==="
ansible --version | head -1
kolla-ansible --version
python3 --version
echo ""
echo "Activate the environment with:"
echo "  source /opt/kolla-deploy-env/bin/activate"
