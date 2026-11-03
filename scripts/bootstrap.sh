#!/bin/bash
# Enable strict mode: exit on error (-e), unset vars (-u), pipeline errors (-o pipefail), and print commands (-x)
set -euxo pipefail

# 1. Update OS packages non-interactively
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y

# 2. Configure 2GB Swap Memory (OOM Killer protection for Java/MySQL)
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# 3. Install official Docker Engine & Docker Compose Plugin
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Configure Docker log rotation to prevent disk space exhaustion on EC2
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# 5. Allow 'ubuntu' user to run docker commands without sudo
usermod -aG docker ubuntu

# 6. Enable and restart Docker service to apply daemon.json configuration
systemctl enable docker
systemctl restart docker