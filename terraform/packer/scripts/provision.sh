#!/bin/bash
# Runs as root (via sudo) inside the VM during the Packer build.
# Goal: end up with a generic, cloud-init-driven template — same result
# you'd get doing the "install qemu-guest-agent, swapoff -a" steps by
# hand, plus the cloud-init pieces Terraform will need later.
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y

# qemu-guest-agent: already installed via preseed pkgsel, but make sure
# it's enabled. cloud-init: not in preseed, install it here.
apt-get install -y qemu-guest-agent cloud-init cloud-utils 

systemctl enable qemu-guest-agent

# No swap by design (matches `swapoff -a` from the manual notes) — belt
# and suspenders in case the preseed recipe ever grows a swap partition.
swapoff -a || true
sed -i '/\sswap\s/d' /etc/fstab

# Debian 13 (Trixie) note from your manual run: cgroup memory no longer
# needs to be enabled in the bootloader for k3s. Nothing to do here.

# --- Generalize the image so every clone doesn't inherit build-time identity ---

# Cloud-init will regenerate machine-id and SSH host keys on first boot
# of each clone.
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

rm -f /etc/ssh/ssh_host_*

# Reset cloud-init state so it re-runs fully on the clone's first boot.
cloud-init clean --logs --seed || true

# Datasource: Proxmox presents cloud-init config via a NoCloud CD-ROM
# when Terraform sets ciuser/ciupgrade/etc, so pin the datasource list.
cat >/etc/cloud/cloud.cfg.d/99-proxmox-nocloud.cfg <<'EOF'
datasource_list: [ NoCloud, ConfigDrive ]
EOF

# Drop the temporary packer/preseed password account's password so it
# can't be logged into after the template is cloned — SSH keys only,
# delivered via cloud-init from here on.
passwd -l debian

apt-get autoremove -y
apt-get clean
rm -rf /tmp/* /var/tmp/*
history -c || true
