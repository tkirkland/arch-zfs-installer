# Arch Linux ZFS Installer v2.0 - Testing Checklist

## Overview

This document provides comprehensive testing procedures for the Arch Linux ZFS installer v2.0. Testing should be performed in a virtual machine or on dedicated test hardware.

## Test Environment Setup

### Recommended VM Configuration

**Minimum**:
- 2 CPU cores
- 4GB RAM
- 2-3 virtual disks (for testing multi-disk configs)
- UEFI firmware enabled
- Network connectivity

**Optimal**:
- 4 CPU cores
- 8GB RAM
- 5 virtual disks of varying sizes
- UEFI firmware (OVMF)
- Bridged network

### Virtualization Platforms

#### VirtualBox
```bash
# Enable UEFI
VBoxManage modifyvm "VM-Name" --firmware efi

# Add multiple disks
VBoxManage createhd --filename disk2.vdi --size 25600
VBoxManage storageattach "VM-Name" --storagectl "SATA" --port 1 --device 0 --type hdd --medium disk2.vdi
```

#### QEMU/KVM
```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -bios /usr/share/ovmf/OVMF.fd \
  -drive file=disk1.qcow2,format=qcow2 \
  -drive file=disk2.qcow2,format=qcow2 \
  -drive file=arch.iso,format=raw,media=cdrom \
  -boot d \
  -net nic -net user
```

#### VMware Workstation
- Enable EFI in VM settings
- Add multiple virtual disks
- Use NAT or Bridged networking

## Pre-Testing Setup

### 1. Verify Script Integrity

```bash
# Check syntax
bash -n arch-zfs-install-v2.sh

# Verify no common issues
shellcheck arch-zfs-install-v2.sh

# Check line count (should be ~2000 lines)
wc -l arch-zfs-install-v2.sh

# Verify execution permission
chmod +x arch-zfs-install-v2.sh
```

### 2. Boot Arch Linux Live ISO

- [ ] ISO boots successfully in UEFI mode
- [ ] Keyboard works
- [ ] Network auto-configures (or can be manually configured)
- [ ] Can ping archlinux.org

### 3. Environment Preparation

```bash
# Verify UEFI
ls /sys/firmware/efi/efivars
# Expected: List of variables

# Check available RAM
free -h
# Expected: >2GB available

# List disks
lsblk
# Expected: See test disks

# Test internet
ping -c 3 archlinux.org
# Expected: Successful pings
```

## Testing Scenarios

### Test 1: Single Disk, GRUB, Swap Partition

**Configuration**:
- Pool: Single disk
- Kernel: linux-lts
- Bootloader: GRUB
- Swap: Partition (8G)
- Boot Environments: No
- Network: DHCP
- User: Create test user

**Steps**:
1. Run installer
2. Select single disk mode
3. Choose 1 disk
4. Accept default pool name (zroot)
5. Set hostname: test-single
6. Set root password
7. Create user: testuser
8. Accept defaults for locale/keymap/timezone
9. Select linux-lts kernel
10. Select GRUB bootloader
11. Select swap partition
12. Disable boot environments
13. Configure DHCP network
14. Confirm and install

**Expected Results**:
- [ ] Installation completes without errors
- [ ] System boots successfully
- [ ] Can login as root
- [ ] Can login as testuser
- [ ] ZFS pool is healthy (`zpool status`)
- [ ] All datasets mounted (`zfs list`)
- [ ] Network works (`ping archlinux.org`)
- [ ] SSH accessible
- [ ] Swap active (`swapon --show`)

### Test 2: Mirror, systemd-boot, ZRAM

**Configuration**:
- Pool: Mirror (2 disks)
- Kernel: linux-lts
- Bootloader: systemd-boot
- Swap: ZRAM
- Boot Environments: No
- Network: Static IP
- User: No additional user

**Steps**:
1. Run installer
2. Select mirror mode
3. Choose 2 disks
4. Set pool name: zmirror
5. Set hostname: test-mirror
6. Set root password only
7. Skip user creation
8. Accept defaults for localization
9. Select linux-lts kernel
10. Select systemd-boot
11. Select ZRAM swap
12. Disable boot environments
13. Configure static IP
14. Confirm and install

**Expected Results**:
- [ ] Installation completes without errors
- [ ] System boots with systemd-boot
- [ ] Pool shows mirror topology (`zpool status`)
- [ ] Both disks active in mirror
- [ ] ZRAM active (`zramctl`)
- [ ] Static IP configured
- [ ] Network functional
- [ ] Can remove one disk and boot (resilience test)

### Test 3: RAID-Z, GRUB, Boot Environments

**Configuration**:
- Pool: RAID-Z (3 disks)
- Kernel: linux-lts
- Bootloader: GRUB
- Swap: None
- Boot Environments: Yes
- Network: DHCP
- User: Create user

**Steps**:
1. Run installer
2. Select RAID-Z mode
3. Choose 3 disks
4. Set pool name: zraid
5. Set hostname: test-raidz
6. Set root password
7. Create user: admin
8. Accept defaults
9. Select linux-lts
10. Select GRUB
11. Select no swap
12. Enable boot environments (prefix: arch)
13. Configure DHCP
14. Confirm and install

**Expected Results**:
- [ ] Installation completes
- [ ] System boots
- [ ] Pool shows RAID-Z topology
- [ ] 3 disks in RAID-Z configuration
- [ ] Boot environment datasets created
- [ ] Can create snapshots
- [ ] Can clone boot environments
- [ ] Network functional
- [ ] No swap active

### Test 4: RAID-Z2, ZFSBootMenu, Complex Setup

**Configuration**:
- Pool: RAID-Z2 (4 disks)
- Kernel: linux-lts
- Bootloader: ZFSBootMenu
- Swap: Partition (4G)
- Boot Environments: Yes
- Network: DHCP
- User: Create user

**Steps**:
1. Run installer
2. Select RAID-Z2 mode
3. Choose 4 disks
4. Custom pool name: data
5. Custom hostname: test-complex
6. Set root password
7. Create user with custom username
8. Custom locale selection
9. Select linux-lts
10. Select ZFSBootMenu
11. Select swap partition with custom size
12. Enable boot environments with custom prefix
13. Configure network
14. Confirm and install

**Expected Results**:
- [ ] Installation completes
- [ ] System boots (may need ZFSBootMenu post-install)
- [ ] Pool shows RAID-Z2 topology
- [ ] 4 disks with double parity
- [ ] Can survive 2 disk failures (test after install)
- [ ] Boot environments work
- [ ] Swap active
- [ ] Network functional

### Test 5: Error Handling and Edge Cases

#### Test 5a: Invalid Disk Selection
- [ ] Attempt to select non-existent disk number
- [ ] Verify error message displayed
- [ ] Script prompts for re-selection

#### Test 5b: Insufficient Disks for Pool Type
- [ ] Select RAID-Z but only choose 2 disks
- [ ] Verify error about minimum disk requirement
- [ ] Script prompts for more disks or different pool type

#### Test 5c: Invalid Hostname
- [ ] Enter hostname with invalid characters
- [ ] Verify error message
- [ ] Script prompts for valid hostname

#### Test 5d: Password Mismatch
- [ ] Enter different passwords for confirmation
- [ ] Verify warning about mismatch
- [ ] Script prompts to re-enter passwords

#### Test 5e: Invalid Username
- [ ] Enter username starting with number
- [ ] Enter username with spaces
- [ ] Verify error messages
- [ ] Script prompts for valid username

#### Test 5f: Interrupted Installation
- [ ] Start installation
- [ ] Press Ctrl+C during disk partitioning
- [ ] Verify graceful exit
- [ ] Check no partial installation remains

## Functionality Testing

### ZFS Pool Operations

```bash
# After successful installation and boot:

# 1. Check pool status
zpool status
# Expected: Online and healthy

# 2. Check pool properties
zpool get all zroot
# Expected: Verify ashift=12, autotrim=on

# 3. Check filesystem properties
zfs get all zroot
# Expected: Verify compression=lz4, acltype=posixacl

# 4. Create test dataset
zfs create zroot/test
zfs list | grep test
# Expected: Dataset created

# 5. Create snapshot
zfs snapshot zroot/test@snap1
zfs list -t snapshot | grep snap1
# Expected: Snapshot created

# 6. Rollback snapshot
echo "test" > /zroot/test/file.txt
zfs rollback zroot/test@snap1
ls /zroot/test/
# Expected: file.txt removed

# 7. Destroy snapshot
zfs destroy zroot/test@snap1
zfs list -t snapshot | grep snap1
# Expected: Snapshot gone

# 8. Scrub pool
zpool scrub zroot
zpool status
# Expected: Scrub in progress or completed

# 9. Check I/O stats
zpool iostat zroot 1 5
# Expected: Show read/write stats
```

### Boot Environment Testing (if enabled)

```bash
# 1. List boot environments
zfs list | grep ROOT
# Expected: See BE datasets

# 2. Create new BE
zfs snapshot zroot/ROOT/arch@backup
zfs clone zroot/ROOT/arch@backup zroot/ROOT/arch-test
zfs list | grep arch-test
# Expected: New BE created

# 3. Set bootfs (GRUB example)
zpool set bootfs=zroot/ROOT/arch-test zroot
# Expected: Bootfs changed

# 4. Reboot and verify
reboot
# After reboot:
zfs get mounted zroot/ROOT/arch-test
# Expected: Mounted on /
```

### Network Testing

```bash
# 1. Check network status
nmcli device status
# Expected: Interface connected

# 2. Ping external
ping -c 3 archlinux.org
# Expected: Successful

# 3. DNS resolution
nslookup archlinux.org
# Expected: Resolves correctly

# 4. Check routing
ip route
# Expected: Default route present

# 5. Test package download
sudo pacman -Sy
# Expected: Successful database sync
```

### SSH Testing

```bash
# From another machine:

# 1. SSH as root (should fail with password)
ssh root@test-host
# Expected: Requires SSH key

# 2. Copy SSH key
ssh-copy-id root@test-host
# Expected: Key copied

# 3. SSH with key
ssh root@test-host
# Expected: Successful login

# 4. SSH as user (if created)
ssh testuser@test-host
# Expected: Login with password or key
```

### Swap Testing

#### Partition Swap
```bash
# 1. Check swap
swapon --show
# Expected: Swap partition listed

# 2. Test swap usage
stress --vm 2 --vm-bytes 2G --timeout 30s
# Expected: Swap used if RAM fills
```

#### ZRAM
```bash
# 1. Check ZRAM
zramctl
# Expected: ZRAM device listed

# 2. Check compression
cat /sys/block/zram0/comp_algorithm
# Expected: zstd or lz4

# 3. Check stats
cat /sys/block/zram0/mm_stat
# Expected: Usage statistics
```

### Bootloader Testing

#### GRUB
```bash
# 1. Check GRUB config
cat /boot/grub/grub.cfg | grep zfs
# Expected: ZFS parameters present

# 2. List boot entries
efibootmgr
# Expected: GRUB entry present

# 3. Test boot menu
reboot
# During boot: Press Esc or Shift
# Expected: GRUB menu appears
```

#### systemd-boot
```bash
# 1. Check loader config
cat /boot/efi/loader/loader.conf
# Expected: Valid configuration

# 2. Check boot entry
cat /boot/efi/loader/entries/arch.conf
# Expected: ZFS parameters present

# 3. List entries
bootctl list
# Expected: Arch entry listed
```

### System Services

```bash
# 1. ZFS services
systemctl status zfs.target
systemctl status zfs-mount
systemctl status zfs-import-cache
# Expected: All active

# 2. Network services
systemctl status NetworkManager
systemctl status systemd-resolved
# Expected: Active and running

# 3. SSH service
systemctl status sshd
# Expected: Active and listening

# 4. Check failed services
systemctl --failed
# Expected: None failed
```

## Stress Testing

### Disk Failure Simulation (Mirror/RAID-Z)

```bash
# For mirrors and RAID-Z pools:

# 1. Check initial status
zpool status zroot
# Expected: All disks ONLINE

# 2. Offline one disk
zpool offline zroot /dev/sdX
zpool status
# Expected: Pool DEGRADED, one disk OFFLINE

# 3. Test operations
zfs create zroot/failtest
echo "test" > /zroot/failtest/file.txt
# Expected: Operations work

# 4. Online disk
zpool online zroot /dev/sdX
zpool status
# Expected: Resilver starts

# 5. Wait for resilver
zpool status
# Expected: Eventually all ONLINE
```

### High Load Testing

```bash
# 1. Install stress testing tools
sudo pacman -S stress fio

# 2. CPU stress
stress --cpu 4 --timeout 60s
# Expected: System remains responsive

# 3. Memory stress
stress --vm 2 --vm-bytes 1G --timeout 60s
# Expected: System handles gracefully

# 4. I/O stress
fio --name=test --ioengine=libaio --iodepth=32 --rw=randrw --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting
# Expected: I/O completes without errors
```

### Snapshot Stress Test

```bash
# Create many snapshots
for i in {1..100}; do
  zfs snapshot zroot@test$i
done

# List snapshots
zfs list -t snapshot | wc -l
# Expected: 100+ snapshots

# Destroy snapshots
for i in {1..100}; do
  zfs destroy zroot@test$i
done

# Verify cleanup
zfs list -t snapshot | grep test
# Expected: No test snapshots
```

## Performance Benchmarking

### Baseline Tests

```bash
# 1. Disk sequential read
dd if=/dev/zero of=/tmp/testfile bs=1M count=1024 oflag=direct
# Note throughput

# 2. Disk sequential write
dd if=/tmp/testfile of=/dev/null bs=1M iflag=direct
# Note throughput

# 3. ZFS sequential read
dd if=/dev/zero of=/root/testfile bs=1M count=1024
# Compare to disk baseline

# 4. ZFS sequential write
dd if=/root/testfile of=/dev/null bs=1M
# Compare to disk baseline

# 5. Compression ratio
zfs get compressratio zroot
# Expected: >1.00x with LZ4
```

### Database-like Workload

```bash
# Install benchmark tool
sudo pacman -S fio

# Run random I/O test
fio --name=random-rw --ioengine=libaio --iodepth=32 --rw=randrw --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 --group_reporting --directory=/root
# Note IOPS and latency
```

## Regression Testing

After any script modifications, re-run:

- [ ] Test 1 (basic single disk)
- [ ] Test 2 (mirror configuration)
- [ ] Test 3 (RAID-Z with boot environments)
- [ ] Error handling tests (5a-5f)
- [ ] ZFS operations suite
- [ ] Network connectivity
- [ ] SSH access
- [ ] System services

## Code Quality Checks

### Static Analysis

```bash
# ShellCheck
shellcheck arch-zfs-install-v2.sh
# Expected: No errors, minimal warnings

# Syntax check
bash -n arch-zfs-install-v2.sh
# Expected: No syntax errors
```

### Style Compliance

Manual review checklist:
- [ ] Uses `set -euo pipefail`
- [ ] All variables quoted: `"${var}"`
- [ ] Uses `[[ ]]` instead of `[ ]`
- [ ] 2-space indentation
- [ ] 80-character line limit (where practical)
- [ ] Function comments with description, globals, args, outputs
- [ ] Consistent naming (lowercase_with_underscores)
- [ ] Constants in UPPERCASE
- [ ] Error messages to stderr
- [ ] Colored output for readability
- [ ] `readonly` used for constants
- [ ] `local` used in functions
- [ ] Return codes checked

### Documentation Review

- [ ] README complete and accurate
- [ ] Quick reference covers all features
- [ ] Testing checklist comprehensive
- [ ] Code comments clear and helpful
- [ ] Examples work as documented
- [ ] Troubleshooting section addresses common issues

## Post-Installation Validation

### Day 1 Checks

```bash
# 1. System uptime
uptime
# Expected: System stable

# 2. Check logs
journalctl -p err -b
# Expected: No critical errors

# 3. ZFS health
zpool status
# Expected: All ONLINE

# 4. Filesystem usage
df -h
# Expected: Reasonable usage

# 5. Memory usage
free -h
# Expected: Within normal range
```

### Week 1 Checks

```bash
# 1. Long-term stability
uptime
# Expected: Days of uptime

# 2. ZFS errors
zpool status -v
# Expected: No read/write/cksum errors

# 3. Package updates
sudo pacman -Syu
# Expected: Update successful

# 4. Kernel still compatible
uname -r
zfs version
# Expected: Compatible versions
```

## Known Limitations Testing

### Verify Expected Limitations

- [ ] BIOS/Legacy boot attempted (should fail with clear message)
- [ ] Less than 2GB RAM attempted (should warn)
- [ ] Pool type with insufficient disks (should error)
- [ ] ZFSBootMenu requires post-install setup (documented)
- [ ] RAID-Z not recommended for < 3 disks (prevented)

## Test Report Template

```
Test Date: YYYY-MM-DD
Tester: [Name]
Environment: [VirtualBox/QEMU/Physical]
Script Version: 2.0.0

Test Scenario: [Test #]
Configuration:
  - Pool Type: [single/mirror/raidz/raidz2/raidz3]
  - Disks: [count and sizes]
  - Kernel: [linux-lts/linux/etc]
  - Bootloader: [grub/systemd-boot/zfsbootmenu]
  - Swap: [partition/zram/none]
  - Boot Environments: [yes/no]
  
Results:
  Installation: [PASS/FAIL]
  Boot: [PASS/FAIL]
  ZFS Operations: [PASS/FAIL]
  Network: [PASS/FAIL]
  Services: [PASS/FAIL]
  
Issues Found:
  - [List any issues]
  
Notes:
  - [Additional observations]
```

## Continuous Integration (Optional)

For automated testing:

```bash
#!/bin/bash
# Automated test runner

# Create VM
create_test_vm

# Install system with test config
./arch-zfs-install-v2.sh < test-input.txt

# Boot VM
boot_test_vm

# Run validation suite
./validate.sh

# Collect results
save_test_results

# Cleanup
destroy_test_vm
```

## Success Criteria

Installation is considered successful when:

- [ ] Script completes without errors
- [ ] System boots to login prompt
- [ ] ZFS pool is healthy and all datasets mounted
- [ ] Network connectivity works (can ping external)
- [ ] SSH is accessible (with proper authentication)
- [ ] All enabled services are active
- [ ] No critical errors in system logs
- [ ] System is stable for at least 24 hours
- [ ] Can perform updates successfully
- [ ] ZFS operations (snapshot, clone, etc.) work
- [ ] Swap (if configured) is active and working

---

**Last Updated**: October 2025  
**Script Version**: 2.0.0  
**Testing Framework Version**: 1.0
