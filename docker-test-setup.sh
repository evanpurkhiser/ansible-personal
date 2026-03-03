#!/bin/bash
# Setup script to prepare the Arch Linux container for Ansible testing
# This mimics the manual setup steps from your server installation notes

set -e

echo "=== Setting up Arch Linux container for testing ==="
echo "This mimics the manual 'First reboot into new system' setup"
echo ""

# Initialize pacman keyring (needed in containers)
echo "Initializing pacman..."
pacman-key --init
pacman-key --populate archlinux

# Update package database
echo "Updating package database..."
pacman -Sy --noconfirm

# Install essential packages (matching your install notes)
echo "Installing essential packages..."
pacman -S --noconfirm \
    neovim \
    bash-completion \
    openssh \
    python \
    sudo \
    systemd \
    iproute2 \
    iputils \
    which

echo ""
echo "=== Configuring Networking (manual setup phase) ==="

# Create temporary network config (like your notes)
echo "Creating temporary network configuration..."
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/01-internal.network <<'EOF'
[Match]
Name=*

[Network]
DHCP=yes
EOF

# Enable systemd-networkd and systemd-resolved
echo "Enabling systemd-networkd and systemd-resolved..."
systemctl enable systemd-networkd
systemctl enable systemd-resolved

# Link resolv.conf (will be done by ansible but needed for initial connectivity)
# May be a mount point from Docker, try to unmount first
umount /etc/resolv.conf 2>/dev/null || true
rm -f /etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo ""
echo "=== Configuring OpenSSH server ==="

# Configure SSH to allow root login (like your notes)
mkdir -p /etc/ssh
cat >> /etc/ssh/sshd_config <<'EOF'

# Testing configuration
PermitRootLogin yes
PasswordAuthentication yes
EOF

# Set root password
echo "root:root" | chpasswd

# Enable and start sshd
systemctl enable sshd
systemctl start sshd

echo ""
echo "=== Installing ZFS (if supported) ==="

# Try to install ZFS support
if pacman -S --noconfirm zfs-linux zfs-utils 2>/dev/null; then
    echo "ZFS packages installed"

    # Create a file-backed ZFS pool to simulate your documents pool
    echo "Creating test ZFS pool..."
    mkdir -p /zpool-backing

    # Create 5 small "drives" to simulate your 5x 3.6TB WD drives
    for i in {1..5}; do
        if [ ! -f /zpool-backing/drive${i}.img ]; then
            truncate -s 2G /zpool-backing/drive${i}.img
            echo "Created drive${i}.img (simulating WD drive $i)"
        fi
    done

    # Load ZFS kernel module (may fail in container, that's ok)
    modprobe zfs 2>/dev/null || echo "Note: ZFS module not available (needs host kernel support)"

    # Try to create ZFS pool in raidz configuration like your actual setup
    if ! zpool list documents 2>/dev/null; then
        echo "Creating 'documents' zpool in raidz configuration..."
        if zpool create -f documents raidz \
            /zpool-backing/drive1.img \
            /zpool-backing/drive2.img \
            /zpool-backing/drive3.img \
            /zpool-backing/drive4.img \
            /zpool-backing/drive5.img 2>/dev/null; then

            echo "Setting ZFS cache file..."
            zpool set cachefile=/etc/zfs/zpool.cache documents
            echo "ZFS pool 'documents' created successfully"
            zpool status documents
        else
            echo "ZFS pool creation failed (needs host kernel with ZFS support)"
        fi
    fi
else
    echo "ZFS packages not available, skipping ZFS setup"
fi

echo ""
echo "=== Container setup complete ==="
echo ""
echo "Container is ready for Ansible playbook execution"
echo "This mimics a fresh Arch Linux install after first reboot"
echo ""
echo "Connection methods:"
echo "  - docker exec -it ansible-test-server bash"
echo "  - ssh -p 2222 root@localhost (password: root)"
echo ""
echo "Next steps:"
echo "  1. Copy your ansible SSH key to root authorized_keys"
echo "  2. Run the ansible-personal playbook"
echo "  3. Handle the network configuration manual intervention"
