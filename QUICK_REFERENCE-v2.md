# Arch Linux ZFS Installer - Quick Reference v2.0

## Pre-Installation Checklist

- [ ] UEFI system (not BIOS/Legacy)
- [ ] Minimum 2GB RAM (4GB+ recommended)
- [ ] Internet connection active
- [ ] Backed up existing data
- [ ] Identified target disk(s)

## Boot Preparation

```bash
# Verify UEFI mode
ls /sys/firmware/efi/efivars

# Connect to WiFi (if needed)
iwctl
station wlan0 connect "WiFi-Name"
exit

# Test internet
ping -c 3 archlinux.org

# Download installer
curl -O https://your-url/arch-zfs-install-v2.sh
chmod +x arch-zfs-install-v2.sh

# Run installer
./arch-zfs-install-v2.sh
```

## Installation Options

### Pool Types

| Type | Disks | Capacity | Fault Tolerance | Use Case |
|------|-------|----------|-----------------|----------|
| Single | 1 | 100% | None | Testing, VMs |
| Mirror | 2+ | 50% (2-disk) | n-1 disks | Workstations |
| RAID-Z | 3+ | (n-1)/n | 1 disk | File servers |
| RAID-Z2 | 4+ | (n-2)/n | 2 disks | Critical data |
| RAID-Z3 | 5+ | (n-3)/n | 3 disks | Enterprise |

### Kernel Options

1. **linux-lts** (RECOMMENDED) - Best ZFS compatibility
2. **linux** - Latest stable, may need DKMS
3. **linux-zen** - Performance-focused
4. **linux-hardened** - Security-focused

### Bootloaders

1. **GRUB** - Most compatible, recommended
2. **systemd-boot** - Simple, UEFI only
3. **ZFSBootMenu** - Advanced, boot environments

### Swap Options

1. **Partition** - Traditional swap on disk
2. **ZRAM** - Compressed swap in RAM
3. **None** - No swap (high RAM systems)

## Default Configuration Values

```
Pool Name:     zroot
Hostname:      archzfs
Locale:        en_US.UTF-8
Keymap:        us
Timezone:      (auto-detected)
Kernel:        linux-lts
Bootloader:    grub
Swap Type:     partition
Swap Size:     8G
EFI Size:      512M
Network:       DHCP
```

## Common Commands

### During Installation

```bash
# List disks
lsblk

# Check partition table
gdisk -l /dev/sdX

# Check network
ip addr
ping archlinux.org

# Manually load ZFS (if needed)
modprobe zfs
```

### After Installation

#### ZFS Pool Management

```bash
# Status
zpool status
zpool list

# Detailed status
zpool status -v

# I/O statistics
zpool iostat 1

# Scrub (verify integrity)
zpool scrub zroot
zpool status

# Clear errors
zpool clear zroot
```

#### ZFS Dataset Management

```bash
# List datasets
zfs list
zfs list -t all

# Create dataset
zfs create zroot/data/projects

# Destroy dataset
zfs destroy zroot/data/projects

# Properties
zfs get all zroot
zfs set compression=zstd zroot/data
```

#### Snapshots

```bash
# Create
zfs snapshot zroot/ROOT/arch@backup

# List
zfs list -t snapshot

# Rollback
zfs rollback zroot/ROOT/arch@backup

# Destroy
zfs destroy zroot/ROOT/arch@backup

# Clone (boot environment)
zfs clone zroot/ROOT/arch@backup zroot/ROOT/arch-test
```

#### System Services

```bash
# ZFS services
systemctl status zfs.target
systemctl status zfs-mount
systemctl status zfs-import-cache

# Network
systemctl status NetworkManager
nmcli device status

# SSH
systemctl status sshd
```

## Partition Layout

### Single Disk Example

```
/dev/sda
├── /dev/sda1    512M    EFI System (ef00)
├── /dev/sda2    8G      Linux Swap (8200)    [optional]
└── /dev/sda3    Rest    ZFS (bf00)
```

### Multi-Disk Example (Mirror)

```
/dev/sda                          /dev/sdb
├── /dev/sda1    512M    EFI     ├── /dev/sdb1    512M    EFI
├── /dev/sda2    8G      Swap    ├── /dev/sdb2    8G      Swap
└── /dev/sda3    Rest    ZFS  ━━━┻━━ /dev/sdb3    Rest    ZFS
                                  (mirrored)
```

## Dataset Structure

### Simple Layout (No Boot Environments)

```
zroot
├── ROOT
│   └── default         (/)
├── home               (/home)
├── var                (/var/log)
└── cache              (/var/cache)
```

### Boot Environment Layout

```
zroot
├── ROOT
│   └── arch           (/)          [current BE]
├── data
│   ├── home           (/home)      [shared]
│   └── root           (/root)      [shared]
├── var                (/var/log)
└── cache              (/var/cache)
```

## Troubleshooting Quick Fixes

### Can't Boot

```bash
# From live USB:
zpool import -f zroot
zfs mount zroot/ROOT/default  # or your BE
mount /dev/sdX1 /mnt/boot/efi
arch-chroot /mnt
grub-mkconfig -o /boot/grub/grub.cfg
grub-install --target=x86_64-efi --efi-directory=/boot/efi
exit
reboot
```

### Pool Won't Import

```bash
# Force import
zpool import -f zroot

# Check for issues
zpool status -v

# Clear errors if healthy
zpool clear zroot
```

### Kernel Update Issues

```bash
# If ZFS module incompatible:
sudo pacman -S zfs-dkms
sudo pacman -R zfs-linux-lts

# Rebuild initramfs
sudo mkinitcpio -P
```

### Out of Space

```bash
# Check usage
zfs list -o space
df -h

# Clean pacman cache
sudo pacman -Sc

# Remove old snapshots
zfs list -t snapshot
zfs destroy zroot/ROOT/arch@old
```

### Network Issues

```bash
# Check status
nmcli device status
ip addr

# Restart NetworkManager
sudo systemctl restart NetworkManager

# Connect to WiFi
nmcli device wifi connect "SSID" password "PASSWORD"

# Manual configuration
sudo nmcli connection edit connection-name
```

## Emergency Recovery

### Boot from Live USB

```bash
# 1. Boot live USB
# 2. Load ZFS module
modprobe zfs

# 3. Import pool
zpool import -f zroot

# 4. Mount root
zfs mount zroot/ROOT/default  # or your BE name

# 5. Mount other filesystems
zfs mount -a

# 6. Mount EFI
mkdir -p /mnt/boot/efi
mount /dev/sdX1 /mnt/boot/efi

# 7. Chroot
arch-chroot /mnt

# 8. Fix issues (reinstall bootloader, etc.)

# 9. Exit and cleanup
exit
zfs umount -a
zpool export zroot
reboot
```

## Performance Tuning

### ARC Size (Cache)

```bash
# Check current ARC
cat /proc/spl/kstat/zfs/arcstats | grep size

# Set max ARC (8GB example)
echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf
```

### Record Size

```bash
# Database (small random I/O)
zfs set recordsize=8K zroot/data/database

# Media files (large sequential I/O)
zfs set recordsize=1M zroot/data/media

# Default (mixed)
zfs set recordsize=128K zroot/data
```

### Compression

```bash
# Fast (default)
zfs set compression=lz4 zroot

# Better compression
zfs set compression=zstd zroot

# Level control (1-19)
zfs set compression=zstd-6 zroot

# No compression
zfs set compression=off zroot/data
```

## Backup Strategies

### Local Snapshot

```bash
# Create recursive snapshot
zfs snapshot -r zroot@backup-$(date +%Y%m%d)

# Send to file
zfs send zroot@backup-date > /mnt/external/backup.zfs

# Restore
zfs receive zroot/restore < /mnt/external/backup.zfs
```

### Remote Backup

```bash
# Full send
zfs send zroot@snap1 | ssh user@remote zfs receive backup/zroot

# Incremental
zfs send -i zroot@snap1 zroot@snap2 | ssh user@remote zfs receive backup/zroot
```

## Useful Aliases

Add to `~/.bashrc`:

```bash
# ZFS aliases
alias zpl='zpool list'
alias zps='zpool status'
alias zfl='zfs list'
alias zflt='zfs list -t all'
alias zfs-snap='zfs list -t snapshot'

# System
alias update='sudo pacman -Syu'
alias clean='sudo pacman -Sc'
```

## Security Checklist

- [ ] Root password set
- [ ] Non-root user created
- [ ] SSH keys configured (not password)
- [ ] Firewall configured (ufw)
- [ ] Automatic updates planned
- [ ] Backup strategy implemented

## Common Pacman Commands

```bash
# Update system
sudo pacman -Syu

# Install package
sudo pacman -S package-name

# Remove package
sudo pacman -R package-name

# Search packages
pacman -Ss search-term

# Clean cache
sudo pacman -Sc

# List installed packages
pacman -Qe
```

## Network Management

```bash
# List connections
nmcli connection show

# Show devices
nmcli device status

# Connect WiFi
nmcli device wifi connect "SSID" password "PASSWORD"

# List available WiFi
nmcli device wifi list

# Disconnect
nmcli device disconnect wlan0

# Connection details
nmcli connection show "connection-name"
```

## System Information

```bash
# Kernel version
uname -r

# Disk usage
df -h

# Memory usage
free -h

# CPU info
lscpu

# PCI devices
lspci

# USB devices
lsusb

# System logs
journalctl -xe
```

## Resources

### Documentation

- https://wiki.archlinux.org/title/ZFS
- https://wiki.archlinux.org/title/Install_Arch_Linux_on_ZFS
- https://openzfs.github.io/openzfs-docs/

### Man Pages

```bash
man zfs
man zpool
man pacman
man networkmanager
```

### Community

- IRC: #archlinux on Libera Chat
- IRC: #zfsonlinux on Libera Chat
- Forums: https://bbs.archlinux.org/

---

**Quick Tip**: Save this file as `/root/QUICK_REFERENCE.md` on your installed system for offline access!

```bash
# Copy to installed system
cp QUICK_REFERENCE-v2.md /root/QUICK_REFERENCE.md
```
