# Arch Linux ZFS Installation Script v2.0

A comprehensive, production-ready bash script for automated installation of Arch Linux with ZFS as the root filesystem, featuring multi-disk pool support, kernel validation, and multiple bootloader options.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Installation Modes](#installation-modes)
- [Bootloader Options](#bootloader-options)
- [ZFS Pool Configurations](#zfs-pool-configurations)
- [Dataset Layouts](#dataset-layouts)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

## Features

### Core Capabilities

- ✅ **Multi-Disk Pool Support**: Create ZFS pools with single disk, mirror, RAID-Z, RAID-Z2, or RAID-Z3
- ✅ **Kernel Compatibility Validation**: Automatic detection of ZFS-compatible kernels
- ✅ **Multiple Bootloaders**: Choose between GRUB, systemd-boot, or ZFSBootMenu
- ✅ **Boot Environment Support**: Optional boot environment configuration for system snapshots
- ✅ **Flexible Swap**: Partition-based swap, ZRAM, or no swap
- ✅ **Network Configuration**: Full systemd-networkd setup with DHCP or static IP
- ✅ **Automatic Timezone Detection**: Uses IP geolocation to detect timezone
- ✅ **SSH Pre-configured**: SSH server enabled and secured by default
- ✅ **Essential Tools Included**: git, GitHub CLI, networking utilities
- ✅ **Google Shell Style Guide Compliant**: Clean, maintainable code

### ZFS Features

- Optimal pool properties (ashift=12, autotrim=on)
- LZ4 compression enabled by default
- POSIX ACL support
- Automatic dataset creation
- Boot environment capability (optional)
- Persistent ZFS cache configuration

## Requirements

### Hardware

- **UEFI system** (BIOS/Legacy boot not supported)
- **Minimum 2GB RAM** (4GB+ recommended)
- **One or more disks** depending on pool type:
  - Single: 1 disk
  - Mirror: 2+ disks
  - RAID-Z: 3+ disks
  - RAID-Z2: 4+ disks
  - RAID-Z3: 5+ disks
- **Internet connection** (for package download)

### Software

- Arch Linux live ISO (latest)
- Network connectivity
- Root access

## Quick Start

### Step 1: Boot Arch Linux Live ISO

1. Download the latest Arch Linux ISO from [archlinux.org](https://archlinux.org/download/)
2. Create a bootable USB drive using `dd`, Rufus, or Etcher
3. Boot from the USB drive in UEFI mode
4. Verify UEFI boot:
   ```bash
   ls /sys/firmware/efi/efivars
   ```

### Step 2: Connect to Network

#### Using Wi-Fi:
```bash
iwctl
station wlan0 connect "Your-WiFi-Name"
exit
```

#### Using Ethernet:
Network should work automatically via DHCP.

Verify connectivity:
```bash
ping -c 3 archlinux.org
```

### Step 3: Download and Run Installer

```bash
# Download the script
curl -O https://your-url/arch-zfs-install-v2.sh

# Make it executable
chmod +x arch-zfs-install-v2.sh

# Run as root
./arch-zfs-install-v2.sh
```

### Step 4: Follow Interactive Prompts

The script will guide you through:

1. **Disk Selection**: Choose disks and pool type
2. **System Configuration**: Hostname, passwords, users
3. **Localization**: Timezone, locale, keyboard layout
4. **Kernel Selection**: Choose from compatible kernels
5. **Bootloader**: Select GRUB, systemd-boot, or ZFSBootMenu
6. **Swap Configuration**: Partition, ZRAM, or none
7. **Boot Environments**: Enable/disable BE support
8. **Network**: Configure network interface
9. **Confirmation**: Review and confirm settings
10. **Installation**: Automated installation (20-30 minutes)

### Step 5: Reboot

```bash
reboot
```

Remove installation media when prompted.

## Installation Modes

### Single Disk

Simplest configuration for a single storage device.

**Use case**: Personal workstations, testing, VMs

**Configuration**:
- 1 disk required
- No redundancy
- Maximum capacity utilization

### Mirror (RAID-1)

Two or more disks with identical data.

**Use case**: Desktop workstations, servers requiring redundancy

**Configuration**:
- 2+ disks required
- 50% capacity efficiency (2-disk mirror)
- Can survive loss of all but one disk
- Best read performance

### RAID-Z (RAID-5 equivalent)

Three or more disks with single parity.

**Use case**: NAS, file servers, balanced redundancy

**Configuration**:
- 3+ disks required
- (n-1)/n capacity efficiency
- Can survive loss of 1 disk
- Good balance of capacity and redundancy

### RAID-Z2 (RAID-6 equivalent)

Four or more disks with double parity.

**Use case**: Critical servers, large storage arrays

**Configuration**:
- 4+ disks required
- (n-2)/n capacity efficiency
- Can survive loss of 2 disks
- Enhanced data protection

### RAID-Z3

Five or more disks with triple parity.

**Use case**: Enterprise storage, maximum reliability

**Configuration**:
- 5+ disks required
- (n-3)/n capacity efficiency
- Can survive loss of 3 disks
- Maximum redundancy

## Bootloader Options

### GRUB (Recommended)

**Pros**:
- Most compatible
- Widely supported
- Easy to configure
- Works with all pool types

**Cons**:
- Slightly more complex
- Larger installation

**Best for**: General use, compatibility, beginners

### systemd-boot

**Pros**:
- Simple and clean
- Lightweight
- Native systemd integration
- Fast boot

**Cons**:
- UEFI only
- Less flexible than GRUB
- Manual kernel updates

**Best for**: Modern UEFI systems, minimal installations

### ZFSBootMenu

**Pros**:
- Native ZFS integration
- Boot environment selection
- Snapshot booting
- Advanced ZFS features

**Cons**:
- More complex setup
- Requires AUR package post-install
- Advanced use cases only

**Best for**: Advanced users, boot environments, system experimentation

## ZFS Pool Configurations

### Default Pool Properties

```bash
ashift=12              # 4K sector alignment
autotrim=on           # Automatic TRIM for SSDs
```

### Default Filesystem Properties

```bash
acltype=posixacl      # POSIX ACL support
compression=lz4       # Fast compression
dnodesize=auto        # Automatic dnode sizing
normalization=formD   # Unicode normalization
relatime=on          # Efficient access times
xattr=sa             # System attribute extended attributes
```

## Dataset Layouts

### Simple Layout (Boot Environments Disabled)

```
zroot                      (pool root)
├── ROOT                   (boot environment container)
│   └── default           (root filesystem - /)
├── home                  (user home directories - /home)
├── var                   (variable data - /var/log)
└── cache                 (package cache - /var/cache)
```

### Boot Environment Layout (Boot Environments Enabled)

```
zroot                      (pool root)
├── ROOT                   (boot environment container)
│   └── arch              (current boot environment - /)
├── data                  (shared data container)
│   ├── home              (user home directories - /home)
│   └── root              (root user home - /root)
├── var                   (variable data - /var/log)
└── cache                 (package cache - /var/cache)
```

**Boot Environment Benefits**:
- Multiple system configurations
- Safe system updates
- Easy rollback
- Snapshot-based backups
- Experimental testing

## Post-Installation

### First Boot

1. **Remove installation media**
2. **Login** as root or created user
3. **Verify ZFS**:
   ```bash
   zpool status
   zfs list
   ```

4. **Check services**:
   ```bash
   systemctl status zfs.target
   systemctl status NetworkManager
   systemctl status sshd
   ```

### Essential ZFS Commands

#### Pool Management

```bash
# Check pool health
zpool status

# Pool I/O statistics
zpool iostat

# Scrub pool (verify data integrity)
zpool scrub zroot

# Check scrub status
zpool status -v

# Export pool (before shutdown in some cases)
zpool export zroot

# Import pool
zpool import zroot
```

#### Dataset Management

```bash
# List all datasets
zfs list

# List with more details
zfs list -t all

# Create new dataset
zfs create zroot/data/projects

# Destroy dataset
zfs destroy zroot/data/projects

# Set properties
zfs set compression=zstd zroot/data/projects
```

#### Snapshots

```bash
# Create snapshot
zfs snapshot zroot/ROOT/arch@backup-$(date +%Y%m%d)

# List snapshots
zfs list -t snapshot

# Rollback to snapshot
zfs rollback zroot/ROOT/arch@backup-20251019

# Destroy snapshot
zfs destroy zroot/ROOT/arch@backup-20251019

# Clone snapshot (create boot environment)
zfs clone zroot/ROOT/arch@backup-20251019 zroot/ROOT/arch-test
```

### System Maintenance

#### Update System

```bash
# Standard update
sudo pacman -Syu

# If ZFS kernel module conflict:
# Option 1: Wait for compatible ZFS package
# Option 2: Use DKMS version
sudo pacman -S zfs-dkms
```

#### Kernel Updates

With **linux-lts** (recommended), updates are stable and rarely cause issues.

If using **linux** or **linux-zen**, occasionally ZFS modules may lag behind kernel updates:

```bash
# Check kernel version
uname -r

# Check available ZFS packages
pacman -Ss zfs-linux

# If incompatible, use DKMS
sudo pacman -S zfs-dkms
```

### Network Configuration

#### Using NetworkManager CLI

```bash
# Show connections
nmcli connection show

# Connect to Wi-Fi
nmcli device wifi connect "SSID" password "PASSWORD"

# Show current status
nmcli device status

# Edit connection
nmcli connection edit connection-name
```

#### Manual Configuration

Edit `/etc/NetworkManager/system-connections/<interface>.nmconnection`

### SSH Configuration

#### SSH Server (Incoming Connections)

```bash
# Status
systemctl status sshd

# Start/stop
systemctl start sshd
systemctl stop sshd

# Configuration
sudo vim /etc/ssh/sshd_config
```

#### SSH Client (Outgoing Connections)

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy key to remote server
ssh-copy-id user@remote-server

# Connect
ssh user@remote-server
```

## Troubleshooting

### Installation Issues

#### No Internet Connection

```bash
# Check interface status
ip link

# Restart network
systemctl restart NetworkManager

# Manual IP configuration
ip addr add 192.168.1.100/24 dev eth0
ip route add default via 192.168.1.1
echo "nameserver 1.1.1.1" > /etc/resolv.conf
```

#### UEFI Not Detected

Ensure system is booted in UEFI mode:
```bash
ls /sys/firmware/efi/efivars
```

If not in UEFI mode:
1. Reboot
2. Enter BIOS/UEFI settings
3. Disable Legacy/CSM boot
4. Enable UEFI boot
5. Boot from installation media again

#### ZFS Module Not Loading

```bash
# In live environment, ensure archzfs is installed
pacman -Sy archzfs-archiso-linux

# Load module manually
modprobe zfs

# Check module
lsmod | grep zfs
```

### Boot Issues

#### System Doesn't Boot

**Rescue Steps**:

1. Boot from installation media
2. Import pool:
   ```bash
   zpool import -f zroot
   ```

3. Mount filesystems:
   ```bash
   zfs mount zroot/ROOT/default  # or your BE name
   zfs mount -a
   ```

4. Mount EFI:
   ```bash
   mount /dev/sdX1 /mnt/boot/efi
   ```

5. Chroot:
   ```bash
   arch-chroot /mnt
   ```

6. Reinstall bootloader (GRUB example):
   ```bash
   grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
   grub-mkconfig -o /boot/grub/grub.cfg
   ```

7. Exit and reboot:
   ```bash
   exit
   zpool export zroot
   reboot
   ```

#### Kernel Panic - VFS Unable to Mount Root

**Cause**: Initramfs missing ZFS hooks

**Fix**:
1. Boot from installation media
2. Import pool and chroot (see above)
3. Edit `/etc/mkinitcpio.conf`:
   ```bash
   HOOKS=(base udev autodetect modconf block keyboard keymap zfs filesystems)
   ```
4. Regenerate initramfs:
   ```bash
   mkinitcpio -P
   ```
5. Exit and reboot

#### Pool Import Fails

```bash
# Force import
zpool import -f zroot

# Check pool status
zpool status -v

# If degraded, check disks
lsblk

# Replace failed disk (example)
zpool replace zroot /dev/sdX /dev/sdY
```

### ZFS-Specific Issues

#### Pool Degraded

```bash
# Check status
zpool status -v

# Identify failed disk
zpool status

# Replace disk (if possible)
# 1. Physically replace disk
# 2. Partition new disk same as others
# 3. Replace in pool
zpool replace zroot /dev/old-disk /dev/new-disk

# Monitor resilver
zpool status -v
```

#### Slow Performance

```bash
# Check pool status
zpool status

# Check compression ratio
zfs get compressratio

# Check fragmentation
zpool list -v

# Optimize (if needed)
zfs set compression=zstd zroot
zpool scrub zroot
```

#### Out of Space

```bash
# Check space
zfs list
df -h

# Find large datasets
zfs list -o space

# Delete old snapshots
zfs list -t snapshot
zfs destroy zroot/ROOT/arch@old-snapshot

# Clean package cache
sudo pacman -Sc
```

## Advanced Configuration

### Custom Dataset Properties

```bash
# Set compression algorithm
zfs set compression=zstd zroot/data/projects

# Set compression level (zstd-1 to zstd-19)
zfs set compression=zstd-6 zroot/data/projects

# Disable compression
zfs set compression=off zroot/data/database

# Set quota
zfs set quota=100G zroot/data/projects

# Set reservation
zfs set reservation=50G zroot/data/projects

# Enable deduplication (use carefully)
zfs set dedup=on zroot/data/backups
```

### Automated Snapshots

#### Using Systemd Timer

Create `/etc/systemd/system/zfs-snapshot@.service`:
```ini
[Unit]
Description=ZFS Snapshot of %i
Requires=zfs.target
After=zfs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/zfs snapshot %i@auto-$(date +%%Y%%m%%d-%%H%%M%%S)
```

Create `/etc/systemd/system/zfs-snapshot@.timer`:
```ini
[Unit]
Description=Daily ZFS Snapshot of %i

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:
```bash
sudo systemctl enable --now zfs-snapshot@zroot/ROOT/arch.timer
```

### Performance Tuning

#### ARC (Adaptive Replacement Cache)

```bash
# Check current ARC size
cat /proc/spl/kstat/zfs/arcstats | grep "^size"

# Set maximum ARC size (8GB example)
echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf

# Set minimum ARC size (2GB example)
echo "options zfs zfs_arc_min=2147483648" >> /etc/modprobe.d/zfs.conf
```

#### Record Size Optimization

```bash
# Database workloads (small random I/O)
zfs set recordsize=8K zroot/data/database

# Video/media files (large sequential I/O)
zfs set recordsize=1M zroot/data/media

# Default (mixed workload)
zfs set recordsize=128K zroot/data
```

### Boot Environment Management

#### Create New Boot Environment

```bash
# Snapshot current BE
zfs snapshot zroot/ROOT/arch@before-update

# Clone to new BE
zfs clone zroot/ROOT/arch@before-update zroot/ROOT/arch-new

# Set as bootable (if using ZFSBootMenu)
zpool set bootfs=zroot/ROOT/arch-new zroot

# Reboot and select new BE from bootloader menu
```

#### Rollback Boot Environment

```bash
# List boot environments
zfs list -t filesystem | grep ROOT

# Set old BE as bootable
zpool set bootfs=zroot/ROOT/arch-old zroot

# Reboot
reboot
```

### Backup Strategies

#### Local Snapshots

```bash
# Create snapshot
zfs snapshot -r zroot@backup-$(date +%Y%m%d)

# List snapshots
zfs list -t snapshot

# Send to external drive
zfs send zroot@backup-20251019 > /mnt/external/backup.zfs

# Restore from backup
zfs receive zroot/restore < /mnt/external/backup.zfs
```

#### Remote Replication

```bash
# Initial full send
zfs snapshot zroot@initial
zfs send zroot@initial | ssh user@remote zfs receive backup/zroot

# Incremental send
zfs snapshot zroot@incremental
zfs send -i zroot@initial zroot@incremental | ssh user@remote zfs receive backup/zroot
```

## Security Considerations

### Root SSH Access

By default, root SSH login requires SSH keys (password disabled):

```bash
# Generate SSH key pair (on client)
ssh-keygen -t ed25519

# Copy public key to server
ssh-copy-id root@server-ip

# Alternatively, manually add to /root/.ssh/authorized_keys
```

### Firewall Configuration

```bash
# Install firewall
sudo pacman -S ufw

# Enable firewall
sudo systemctl enable --now ufw

# Allow SSH
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable
```

### Sudo Configuration

Users in `wheel` group can use sudo with password:

```bash
# Edit sudoers (if needed)
sudo visudo

# Allow wheel group
%wheel ALL=(ALL:ALL) ALL
```

## Contributing

This script is open source. Contributions, bug reports, and feature requests are welcome.

### Reporting Issues

When reporting issues, include:
- Hardware configuration
- Installation options chosen
- Error messages
- Output of `zpool status` and `zfs list`

## License

GPL-3.0 License

## Resources

### Documentation

- [Arch Linux Wiki - ZFS](https://wiki.archlinux.org/title/ZFS)
- [Arch Linux Wiki - Install Arch Linux on ZFS](https://wiki.archlinux.org/title/Install_Arch_Linux_on_ZFS)
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [ZFSBootMenu Documentation](https://docs.zfsbootmenu.org/)

### Community

- [Arch Linux Forums](https://bbs.archlinux.org/)
- [r/archlinux](https://www.reddit.com/r/archlinux/)
- [r/zfs](https://www.reddit.com/r/zfs/)
- IRC: #archlinux on Libera Chat
- IRC: #zfsonlinux on Libera Chat

### Related Projects

- [archinstall_zfs](https://github.com/okhsunrog/archinstall_zfs) - Python-based TUI installer
- [archzfs](https://github.com/archzfs/archzfs) - ZFS packages for Arch Linux
- [ZFSBootMenu](https://github.com/zbm-dev/zfsbootmenu) - Advanced ZFS bootloader

---

**Version**: 2.0.0  
**Last Updated**: October 2025  
**Maintainer**: Arch ZFS Installation Project
