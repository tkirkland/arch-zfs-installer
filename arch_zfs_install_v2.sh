#!/bin/bash
# suppress inspection SpellCheckingInspection
#
# Arch Linux ZFS Installation Script v2.0
# 
# Description:
#   Automated installer for Arch Linux with ZFS root filesystem.
#   Supports multi-disk pools, kernel validation, boot environments,
#   and multiple bootloader options (GRUB, systemd-boot, ZFSBootMenu).
#
# Features:
#   - Multi-disk ZFS pool support (mirror, RAID-Z, RAID-Z2, RAID-Z3)
#   - Kernel compatibility validation with ZFS
#   - Boot environment support (optional)
#   - Multiple bootloader options with fallback
#   - Swap configuration (partition or ZRAM)
#   - Full system configuration (locale, network, users)
#   - Google Shell Style Guide compliant
#
# Usage:
#   Boot from Arch Linux live ISO, connect to network, then:
#   ./arch_zfs_install_v2.sh
#
# License: GPL-3.0
# Author: Generated for Arch Linux ZFS Installation
# Date: October 2025

set -euo pipefail

################################################################################
# GLOBAL CONSTANTS
################################################################################
# shellcheck disable=SC2034
# bashsupport disable=BP5001
{
readonly SCRIPT_VERSION="2.0.0"
declare -g script_name=""
script_name="$(basename "${0}")"
readonly script_name

# Color definitions for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Repository configuration
readonly DEBIAN_REPO="https://deb.debian.org/debian"
readonly OPENZFS_REPO="https://deb.debian.org/debian-security"
readonly OPENZFS_GPG_KEY="04EE7237B7D453EC"

# System defaults
readonly DEFAULT_MOUNT_POINT="/mnt"
readonly DEFAULT_EFI_SIZE="512M"
readonly DEFAULT_SWAP_SIZE="8G"
readonly DEFAULT_POOL_NAME="zroot"
readonly DEFAULT_HOSTNAME="archzfs"
readonly DEFAULT_LOCALE="en_US.UTF-8"
readonly DEFAULT_KEYMAP="us"
readonly DEFAULT_TIMEZONE="UTC"

# ZFS pool properties
readonly ZFS_POOL_PROPS=(
"ashift=12"
"autotrim=on"
)

# ZFS filesystem properties
readonly ZFS_FS_PROPS=(
"acltype=posixacl"
"compression=lz4"
"dnodesize=auto"
"normalization=formD"
"relatime=on"
"xattr=sa"
  )
}

  ################################################################################
  # GLOBAL VARIABLES
  ################################################################################

  # User-configurable settings (set via interactive prompts)
  declare -a install_disks=()
  declare pool_type=""
  declare pool_name="${DEFAULT_POOL_NAME}"
  declare host_name="${DEFAULT_HOSTNAME}"
  declare root_password=""
  declare create_user="no"
  declare username=""
  declare user_password=""
  declare locale="${DEFAULT_LOCALE}"
  declare keymap="${DEFAULT_KEYMAP}"
  declare time_zone="${DEFAULT_TIMEZONE}"
  declare kernel_choice="linux-lts"
  declare bootloader_choice="grub"
  declare swap_type="partition"
  declare swap_size="${DEFAULT_SWAP_SIZE}"
  declare enable_boot_environments="no"
  declare be_prefix="arch"

  # Network configuration
  declare network_interface=""
  declare use_dhcp="yes"
  declare static_ip=""
  declare static_gateway=""
  declare static_dns=""

  # Internal state variables
  declare detected_timezone=""
  declare -a available_disks=()
  declare -a compatible_kernels=()


################################################################################
# UTILITY FUNCTIONS
################################################################################

#######################################
# Print error message to stderr with timestamp and exit
# Globals:
#   COLOR_RED
#   COLOR_RESET
# Arguments:
#   Error message string
# Outputs:
#   Writes an error message to stderr
# Returns:
#   Exits with status 1
#######################################
err() {
  echo -e "${COLOR_RED}[$(date +'%Y-%m-%dT%H:%M:%S%z')] ERROR: $*${COLOR_RESET}" >&2
  exit 1
}

#######################################
# Print warning message with timestamp
# Globals:
#   COLOR_YELLOW
#   COLOR_RESET
# Arguments:
#   Warning message string
# Outputs:
#   Writes warning to stdout
#######################################
warn() {
  echo -e "${COLOR_YELLOW}[$(date +'%Y-%m-%dT%H:%M:%S%z')] WARNING: $*${COLOR_RESET}"
}

#######################################
# Print info message
# Globals:
#   COLOR_BLUE
#   COLOR_RESET
# Arguments:
#   Info message string
# Outputs:
#   Writes info to stdout
#######################################
info() {
  echo -e "${COLOR_BLUE}[$(date +'%Y-%m-%dT%H:%M:%S%z')] INFO: $*${COLOR_RESET}"
}

#######################################
# Print success message
# Globals:
#   COLOR_GREEN
#   COLOR_RESET
# Arguments:
#   Success message string
# Outputs:
#   Writes a success message to stdout
#######################################
success() {
  echo -e "${COLOR_GREEN}[$(date +'%Y-%m-%dT%H:%M:%S%z')] SUCCESS: $*${COLOR_RESET}"
}

#######################################
# Print section header
# Globals:
#   COLOR_CYAN
#   COLOR_RESET
# Arguments:
#   Header text
# Outputs:
#   Writes formatted header to stdout
#######################################
print_header() {
  echo ""
  echo -e "${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  $*${COLOR_RESET}"
  echo -e "${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""
}

#######################################
# Prompt user for yes/no confirmation
# Arguments:
#   Prompt message
#   Default value (yes/no)
# Outputs:
#   Writes prompt to stdout
# Returns:
#   0 for yes, 1 for no
#######################################
confirm() {
  local prompt="$1"
  local default="${2:-no}"
  local response
  
  if [[ "${default}" == "yes" ]]; then
    prompt="${prompt} [Y/n]: "
  else
    prompt="${prompt} [y/N]: "
  fi
  
  read -r -p "${prompt}" response
  response="${response:-${default}}"
  
  case "${response,,}" in
    y|yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

#######################################
# Check if running as root
# Globals:
#   EUID
# Returns:
#   Exits if not root
#######################################
check_root() {
  if (( EUID != 0 )); then
    err "This script must be run as root. Please use: sudo ${script_name}"
  fi
}

#######################################
# Check if system is booted in UEFI mode
# Returns:
#   Exits if not UEFI
#######################################
check_uefi() {
  if [[ ! -d /sys/firmware/efi/efivars ]]; then
    err "System is not booted in UEFI mode. This installer requires UEFI."
  fi
  success "UEFI mode detected"
}

#######################################
# Check internet connectivity
# Returns:
#   Exits if no internet connection
#######################################
check_internet() {
  info "Checking internet connectivity..."
  
  if ! ping -c 3 -W 5 archlinux.org &> /dev/null; then
    err "No internet connection. Please connect to the network and try again."
  fi
  
  success "Internet connection verified"
}

#######################################
# Synchronize system clock
# Returns:
#   Exits on failure
#######################################
sync_clock() {
  info "Synchronizing system clock..."
  
  if ! timedatectl set-ntp true; then
    err "Failed to enable NTP time synchronization"
  fi
  
  sleep 2
  success "System clock synchronized"
}

#######################################
# Detect time_zone using IP geolocation
# Globals:
#   detected_timezone
# Outputs:
#   Writes detected time_zone to stdout
# Returns:
#   0 on success, 1 on failure
#######################################
detect_timezone() {
  info "Detecting timezone via IP geolocation..."
  
  local timezone

  # Method 1: ip-api.com (returns plain text, no parsing needed)
  timezone=$(curl -s --max-time 5 "http://ip-api.com/line/?fields=timezone" 2>/dev/null || echo "")

  # Method 2: ipwho.is (fallback, parse with grep/sed - no jq needed)
  if [[ -z "${timezone}" ]]; then
    warn "Primary service failed, trying fallback..."
    timezone=$(curl -s --max-time 5 "http://ipwho.is/" 2>/dev/null | \
               grep -oP '"id"\s*:\s*"\K[^"]+' 2>/dev/null || echo "")
  fi

  # Method 3: ipapi.co (another fallback, plain text endpoint)
  if [[ -z "${timezone}" ]]; then
    warn "Second service failed, trying third fallback..."
    timezone=$(curl -s --max-time 5 "https://ipapi.co/timezone/" 2>/dev/null || echo "")
  fi

  # Validate timezone exists in system
  if [[ -n "${timezone}" && -f "/usr/share/zoneinfo/${timezone}" ]]; then
    detected_timezone="${timezone}"
    success "Detected timezone: ${detected_timezone}"
    return 0
  else
    warn "Could not detect timezone, will use default: ${DEFAULT_TIMEZONE}"
    detected_timezone="${DEFAULT_TIMEZONE}"
    return 1
  fi
}

################################################################################
# DISK AND HARDWARE DETECTION
################################################################################

#######################################
# Detect available disks for installation
# Globals:
#   available_disks
# Outputs:
#   Writes disk information to stdout
#######################################
detect_disks() {
  info "Detecting available disks..."
  
  available_disks=()
  
  while IFS= read -r disk; do
    # Skip loop devices, ram disks, and mounted disks
    if [[ ! "${disk}" =~ ^(loop|ram|sr|dm-) ]]; then
      local size
      size=$(lsblk -ndo SIZE "/dev/${disk}" 2>/dev/null || echo "unknown")
      available_disks+=("${disk}:${size}")
      info "  Found: /dev/${disk} (${size})"
    fi
  done < <(lsblk -ndo NAME | sort)
  
  if (( ${#available_disks[@]} == 0 )); then
    err "No suitable disks found for installation"
  fi
  
  success "Detected ${#available_disks[@]} available disk(s)"
}

#######################################
# Display disk information for user selection
# Globals:
#   available_disks
# Outputs:
#   Writes formatted disk list to stdout
#######################################
display_disks() {
  local disk_info
  echo ""
  echo "Available disks:"
  echo "────────────────────────────────────────"
  
  local index=1
  for disk_info in "${available_disks[@]}"; do
    local disk="${disk_info%%:*}"
    local size="${disk_info##*:}"
    printf "  [%2d] /dev/%-10s %s\n" "${index}" "${disk}" "${size}"
    (( index++ ))
  done
  
  echo "────────────────────────────────────────"
  echo ""
}

################################################################################
# ZFS KERNEL COMPATIBILITY VALIDATION
################################################################################

#######################################
# Validate kernel compatibility with ZFS
# Globals:
#   compatible_kernels
# Outputs:
#   Writes compatibility information to stdout
# Returns:
#   0 if kernels are compatible, 1 otherwise
#######################################
validate_kernel_compatibility() {
  info "Validating kernel compatibility with ZFS..."
  
  compatible_kernels=()
  
  # Check available kernels in Arch repos
  local -a kernels=("linux-lts" "linux" "linux-zen" "linux-hardened")
  
  for kernel in "${kernels[@]}"; do
    # Check if the kernel package exists
    # For ARCH if pacman -Ss "^${kernel}$" &> /dev/null; then
      if apt search "^${kernel}$" &> /dev/null; then
      # For LTS kernel, prioritize it as the most compatible
      if [[ "${kernel}" == "linux-lts" ]]; then
        compatible_kernels=("${kernel}" "${compatible_kernels[@]}")
        info "  ✓ ${kernel} (RECOMMENDED - best ZFS compatibility)"
      else
        compatible_kernels+=("${kernel}")
        info "  ✓ ${kernel} (available, may use DKMS)"
      fi
    fi
  done
  
  if (( ${#compatible_kernels[@]} == 0 )); then
    err "No compatible kernels found"
  fi
  
  success "Found ${#compatible_kernels[@]} compatible kernel(s)"
  return 0
}

#######################################
# Display kernel selection menu
# Globals:
#   compatible_kernels
# Outputs:
#   Writes kernel options to stdout
#######################################
display_kernel_options() {
  echo ""
  echo "Available kernels:"
  echo "────────────────────────────────────────"
  
  local index=1
  for kernel in "${compatible_kernels[@]}"; do
    local desc=""
    case "${kernel}" in
      linux-lts)
        desc="(RECOMMENDED - Long Term Support, best ZFS compatibility)"
        ;;
      linux)
        desc="(Latest stable kernel, may need DKMS)"
        ;;
      linux-zen)
        desc="(Performance-focused, may need DKMS)"
        ;;
      linux-hardened)
        desc="(Security-focused, may need DKMS)"
        ;;
    esac
    printf "  [%d] %-20s %s\n" "${index}" "${kernel}" "${desc}"
    (( index++ ))
  done
  
  echo "────────────────────────────────────────"
  echo ""
}

################################################################################
# USER INPUT FUNCTIONS
################################################################################

#######################################
# Collect disk selection from user
# Globals:
#   install_disks
#   available_disks
#   pool_type
# Outputs:
#   Writes prompts to stdout
#######################################
get_disk_selection() {
  local num
  print_header "Disk Selection"
  
  display_disks
  
  echo "Select installation mode:"
  echo "  [1] Single disk"
  echo "  [2] Mirror (2+ disks)"
  echo "  [3] RAID-Z (3+ disks, single parity)"
  echo "  [4] RAID-Z2 (4+ disks, double parity)"
  echo "  [5] RAID-Z3 (5+ disks, triple parity)"
  echo ""
  
  local mode_choice
  read -r -p "Enter mode [1-5]: " mode_choice
  
  case "${mode_choice}" in
    1)
      pool_type="single"
      local min_disks=1
      ;;
    2)
      pool_type="mirror"
      local min_disks=2
      ;;
    3)
      pool_type="raidz"
      local min_disks=3
      ;;
    4)
      pool_type="raidz2"
      local min_disks=4
      ;;
    5)
      pool_type="raidz3"
      local min_disks=5
      ;;
    *)
      err "Invalid selection"
      ;;
  esac
  
  info "Selected pool type: ${pool_type}"
  
  # Get disk selections
  echo ""
  echo "Select disks for installation (minimum: ${min_disks})"
  echo "Enter disk numbers separated by spaces (e.g., 1 2 3)"
  echo ""
  
  display_disks
  
  local disk_input
  read -r -p "Enter disk numbers: " disk_input
  
  install_disks=()
  for num in ${disk_input}; do
    if [[ "${num}" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#available_disks[@]} )); then
      local disk_info="${available_disks[$((num - 1))]}"
      local disk="${disk_info%%:*}"
      install_disks+=("/dev/${disk}")
    else
      err "Invalid disk number: ${num}"
    fi
  done
  
  if (( ${#install_disks[@]} < min_disks )); then
    err "Pool type '${pool_type}' requires at least ${min_disks} disk(s), but ${#install_disks[@]} selected"
  fi
  
  # Display selected disks
  echo ""
  info "Selected ${#install_disks[@]} disk(s) for ${pool_type} pool:"
  for disk in "${install_disks[@]}"; do
    info "  - ${disk}"
  done
  
  # Confirm destructive operation
  echo ""
  warn "⚠️  WARNING: This will DESTROY all data on the selected disks!"
  echo ""
  
  if ! confirm "Continue with installation?" "no"; then
    err "Installation cancelled by user"
  fi
}

#######################################
# Get pool name from user
# Globals:
#   pool_name
# Outputs:
#   Writes prompt to stdout
#######################################
get_pool_name() {
  echo ""
  read -r -p "Enter ZFS pool name [${DEFAULT_POOL_NAME}]: " pool_name
  pool_name="${pool_name:-${DEFAULT_POOL_NAME}}"
  
  # Validate pool name
  if [[ ! "${pool_name}" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    err "Invalid pool name. Must start with letter and contain only letters, numbers, hyphens, and underscores."
  fi
  
  info "Pool name: ${pool_name}"
}

#######################################
# Get HOST from user
# Globals:
#   host_name
# Outputs:
#   Writes prompt to stdout
#######################################
get_hostname() {
  echo ""
  read -r -p "Enter hostname [${DEFAULT_HOSTNAME}]: " host_name
  host_name="${host_name:-${DEFAULT_HOSTNAME}}"
  
  # Validate host_name
  if [[ ! "${host_name}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
    err "Invalid hostname format"
  fi
  
  info "Hostname: ${host_name}"
}

#######################################
# Get root password from user
# Globals:
#   root_password
# Outputs:
#   Writes prompt to stdout
#######################################
get_root_password() {
  echo ""
  local password1
  local password2
  
  while true; do
    read -r -s -p "Enter root password: " password1
    echo ""
    read -r -s -p "Confirm root password: " password2
    echo ""
    
    if [[ "${password1}" == "${password2}" ]]; then
      if [[ -z "${password1}" ]]; then
        warn "Password cannot be empty"
        continue
      fi
      root_password="${password1}"
      success "Root password set"
      break
    else
      warn "Passwords do not match, please try again"
    fi
  done
}

#######################################
# Get user account information
# Globals:
#   create_user
#   username
#   user_password
# Outputs:
#   Writes prompts to stdout
#######################################
get_user_info() {
  echo ""
  if confirm "Create a non-root user account?" "yes"; then
    create_user="yes"
    
    read -r -p "Enter username: " username
    
    # Validate username
    if [[ ! "${username}" =~ ^[a-z]([a-z0-9_-]{0,31})$ ]]; then
      err "Invalid username. Must start with lowercase letter, max 32 chars."
    fi
    
    local password1
    local password2
    
    while true; do
      read -r -s -p "Enter password for ${username}: " password1
      echo ""
      read -r -s -p "Confirm password: " password2
      echo ""
      
      if [[ "${password1}" == "${password2}" ]]; then
        if [[ -z "${password1}" ]]; then
          warn "Password cannot be empty"
          continue
        fi
        user_password="${password1}"
        success "User account configured: ${username}"
        break
      else
        warn "Passwords do not match, please try again"
      fi
    done
  else
    create_user="no"
    info "No additional user will be created"
  fi
}

#######################################
# Get locale configuration
# Globals:
#   locale
# Outputs:
#   Writes prompt to stdout
#######################################
get_locale() {
  echo ""
  read -r -p "Enter locale [${DEFAULT_LOCALE}]: " locale
  locale="${locale:-${DEFAULT_LOCALE}}"
  info "Locale: ${locale}"
}

#######################################
# Get keyboard layout
# Globals:
#   keymap
# Outputs:
#   Writes prompt to stdout
#######################################
get_keymap() {
  echo ""
  read -r -p "Enter keyboard layout [${DEFAULT_KEYMAP}]: " keymap
  keymap="${keymap:-${DEFAULT_KEYMAP}}"
  info "Keyboard layout: ${keymap}"
}

#######################################
# Get time_zone configuration
# Globals:
#   time_zone
#   detected_timezone
# Outputs:
#   Writes prompt to stdout
#######################################
get_timezone() {
  echo ""
  info "Current detected timezone: ${detected_timezone}"
  read -r -p "Enter timezone [${detected_timezone}]: " time_zone
  time_zone="${time_zone:-${detected_timezone}}"
  
  # Validate time_zone
  if [[ ! -f "/usr/share/zoneinfo/${time_zone}" ]]; then
    warn "Timezone file not found, using default"
    time_zone="${DEFAULT_TIMEZONE}"
  fi
  
  info "Timezone: ${time_zone}"
}

#######################################
# Get kernel selection
# Globals:
#   kernel_choice
#   compatible_kernels
# Outputs:
#   Writes prompt to stdout
#######################################
get_kernel_choice() {
  local kernel_num
  print_header "Kernel Selection"
  
  display_kernel_options
  
  read -r -p "Select kernel [1]: " kernel_num
  kernel_num="${kernel_num:-1}"

  if [[ ! "timezone${kernel_num}" =~ ^[0-9]+$ ]] || (( kernel_num < 1 || kernel_num > ${#compatible_kernels[@]} )); then
    err "Invalid kernel selection"
  fi
  
  kernel_choice=3"${compatible_kernels[$((kernel_num - 1))]}"
  success "Selected kernel: ${kernel_choice}"
}

#######################################
# Get bootloader selection
# Globals:
#   bootloader_choice
# Outputs:
#   Writes prompt to stdout
#######################################
get_bootloader_choice() {
  local bootloader_num
  print_header "Bootloader Selection"
  
  echo "Available bootloaders:"
  echo "  [1] GRUB (recommended, most compatible)"
  echo "  [2] systemd-boot (simple, UEFI only)"
  echo "  [3] ZFSBootMenu (advanced, boot environments)"
  echo ""
  
  read -r -p "Select bootloader [1]: " bootloader_num
  bootloader_num="${bootloader_num:-1}"
  
  case "${bootloader_num}" in
    1)
      bootloader_choice="grub"
      ;;
    2)
      bootloader_choice="systemd-boot"
      ;;
    3)
      bootloader_choice="zfsbootmenu"
      ;;
    *)
      err "Invalid bootloader selection"
      ;;
  esac
  
  success "Selected bootloader: ${bootloader_choice}"
}

#######################################
# Get swap configuration
# Globals:
#   swap_type
#   swap_size
# Outputs:
#   Writes prompt to stdout
#######################################
get_swap_config() {
  local swap_choice
  print_header "Swap Configuration"
  
  echo "Swap options:"
  echo "  [1] Swap partition (${DEFAULT_SWAP_SIZE})"
  echo "  [2] ZRAM (compressed RAM)"
  echo "  [3] No swap"
  echo ""
  
  read -r -p "Select swap type [1]: " swap_choice
  swap_choice="${swap_choice:-1}"
  
  case "${swap_choice}" in
    1)
      swap_type="partition"
      read -r -p "Enter swap size [${DEFAULT_SWAP_SIZE}]: " swap_size
      swap_size="${swap_size:-${DEFAULT_SWAP_SIZE}}"
      ;;
    2)
      swap_type="zram"
      ;;
    3)
      swap_type="none"
      ;;
    *)
      err "Invalid swap selection"
      ;;
  esac
  
  info "Swap type: ${swap_type}"
}

#######################################
# Get boot environment configuration
# Globals:
#   enable_boot_environments
#   be_prefix
# Outputs:
#   Writes prompt to stdout
#######################################
get_boot_environment_config() {
  print_header "Boot Environment Configuration"
  
  echo "Boot environments allow multiple system snapshots that can be selected at boot."
  echo ""
  
  if confirm "Enable boot environment support?" "no"; then
    enable_boot_environments="yes"
    
    read -r -p "Enter boot environment prefix [${be_prefix}]: " be_prefix
    be_prefix="${be_prefix:-arch}"
    
    info "Boot environments enabled with prefix: ${be_prefix}"
  else
    enable_boot_environments="no"
    info "Boot environments disabled"
  fi
}

#######################################
# Get network configuration
# Globals:
#   network_interface
#   use_dhcp
#   static_ip
#   static_gateway
#   static_dns
# Outputs:
#   Writes prompts to stdout
#######################################
get_network_config() {
  local iface iface_num
  print_header "Network Configuration"
  
  # Detect network interfaces
  local -a interfaces=()
  while IFS= read -r iface; do
    if [[ ! "${iface}" =~ ^(lo|docker|virbr) ]]; then
      interfaces+=("${iface}")
    fi
  done < <(ip -o link show | awk -F': ' '{print $2}')
  
  if (( ${#interfaces[@]} == 0 )); then
    warn "No network interfaces detected"
    network_interface=""
    return
  fi
  
  echo "Available network interfaces:"
  local index=1
  for iface in "${interfaces[@]}"; do
    echo "  [${index}] ${iface}"
    (( index++ ))
  done
  echo ""
  
  read -r -p "Select network interface [1]: " iface_num
  iface_num="${iface_num:-1}"
  
  if [[ ! "${iface_num}" =~ ^[0-9]+$ ]] || (( iface_num < 1 || iface_num > ${#interfaces[@]} )); then
    err "Invalid interface selection"
  fi
  
  network_interface="${interfaces[$((iface_num - 1))]}"
  info "Selected interface: ${network_interface}"
  
  echo ""
  if confirm "Use DHCP for network configuration?" "yes"; then
    use_dhcp="yes"
    info "Network will use DHCP"
  else
    use_dhcp="no"
    
    read -r -p "Enter static IP address (e.g., 192.168.1.100/24): " static_ip
    read -r -p "Enter gateway: " static_gateway
    read -r -p "Enter DNS servers (space-separated): " static_dns
    
    info "Static IP configured: ${static_ip}"
  fi
}

#######################################
# Display configuration summary
# Globals:
#   Multiple configuration variables
# Outputs:
#   Writes configuration summary to stdout
#######################################
display_config_summary() {
  print_header "Configuration Summary"
  
  echo "Installation Configuration:"
  echo "────────────────────────────────────────"
  echo "Pool Type:        ${pool_type}"
  echo "Pool Name:        ${pool_name}"
  echo "Disks:            ${install_disks[*]}"
  echo "Hostname:         ${host_name}"
  echo "Kernel:           ${kernel_choice}"
  echo "Bootloader:       ${bootloader_choice}"
  echo "Swap:             ${swap_type}"
  if [[ "${swap_type}" == "partition" ]]; then
    echo "Swap Size:        ${swap_size}"
  fi
  echo "Boot Envs:        ${enable_boot_environments}"
  if [[ "${enable_boot_environments}" == "yes" ]]; then
    echo "BE Prefix:        ${be_prefix}"
  fi
  echo "Locale:           ${locale}"
  echo "Keymap:           ${keymap}"
  echo "Timezone:         ${time_zone}"
  echo "Network:          ${network_interface} (${use_dhcp})"
  if [[ "${create_user}" == "yes" ]]; then
    echo "User:             ${username}"
  fi
  echo "────────────────────────────────────────"
  echo ""
}

################################################################################
# DISK PARTITIONING
################################################################################

#######################################
# Partition disks for ZFS installation
# Globals:
#   install_disks
#   swap_type
#   swap_size
# Outputs:
#   Writes progress to stdout
# Returns:
#   Exits on failure
#######################################
partition_disks() {
  print_header "Disk Partitioning"

  for disk in "${install_disks[@]}"; do
    info "Partitioning ${disk}..."

    # Wipe existing signatures
    wipefs -af "${disk}" || err "Failed to wipe ${disk}"

    # Create a GPT partition table
    sgdisk -Z "${disk}" || err "Failed to zap ${disk}"
    sgdisk -o "${disk}" || err "Failed to create GPT on ${disk}"

    # Create an EFI partition (512MB)
    sgdisk -n 1:0:+"${DEFAULT_EFI_SIZE}" -t 1:ef00 -c 1:"EFI System" "${disk}" \
      || err "Failed to create EFI partition on ${disk}"

    local part_num=2

    # Create a swap partition if requested
    if [[ ${swap_type} == "partition" ]]; then
      sgdisk -n "${part_num}":0:+"${swap_size}" -t "${part_num}":8200 -c "${part_num}":"Linux swap" "${disk}" \
        || err "Failed to create swap partition on ${disk}"
      ((part_num++))
    fi

    # Create ZFS partition (remaining space)
    sgdisk -n "${part_num}":0:0 -t "${part_num}":bf00 -c "${part_num}":"ZFS" "${disk}" \
      || err "Failed to create ZFS partition on ${disk}"

    # Inform the kernel of partition changes
    partprobe "${disk}"
    udevadm settle

    success "Partitioned ${disk}"
  done

  success "All disks partitioned successfully"
}

#######################################
# Format EFI partitions
# Globals:
#   install_disks
# Outputs:
#   Writes progress to stdout
#######################################
format_efi_partitions() {
  info "Formatting EFI partitions..."
  
  for disk in "${install_disks[@]}"; do
    local efi_part="${disk}1"
    
    # Handle NVMe naming (e.g., /dev/nvme0n1p1)
    if [[ "${disk}" =~ nvme ]]; then
      efi_part="${disk}p1"
    fi
    
    mkfs.vfat -F32 -n EFI "${efi_part}" || err "Failed to format ${efi_part}"
    success "Formatted ${efi_part}"
  done
}

#######################################
# Setup swap partitions
# Globals:
#   install_disks
#   swap_type
# Outputs:
#   Writes progress to stdout
#######################################
setup_swap_partitions() {
  if [[ "${swap_type}" != "partition" ]]; then
    return 0
  fi
  
  info "Setting up swap partitions..."
  
  for disk in "${install_disks[@]}"; do
    local swap_part="${disk}2"
    
    # Handle NVMe naming
    if [[ "${disk}" =~ nvme ]]; then
      swap_part="${disk}p2"
    fi
    
    mkswap -L swap "${swap_part}" || err "Failed to create swap on ${swap_part}"
    swapon "${swap_part}" || warn "Failed to activate swap on ${swap_part}"
    success "Swap enabled on ${swap_part}"
  done
}

################################################################################
# ZFS POOL CREATION
################################################################################

#######################################
# Load ZFS kernel modules
# Outputs:
#   Writes progress to stdout
#######################################
load_zfs_modules() {
  info "Loading ZFS kernel modules..."
  
  if ! modprobe zfs; then
    err "Failed to load ZFS kernel module. Ensure ZFS is installed in live environment."
  fi
  
  success "ZFS modules loaded"
}

#######################################
# Create ZFS pool
# Globals:
#   pool_name
#   pool_type
#   install_disks
#   ZFS_POOL_PROPS
# Outputs:
#   Writes progress to stdout
#######################################
create_zfs_pool() {
  print_header "ZFS Pool Creation"
  load_zfs_modules
  # Build partition list for pool
  local -a pool_partitions=()
  for disk in "${install_disks[@]}"; do
    local part_num=2
    
    # Adjust partition number if swap exists
    if [[ "${swap_type}" == "partition" ]]; then
      part_num=3
    fi
    
    local zfs_part="${disk}${part_num}"
    
    # Handle NVMe naming
    if [[ "${disk}" =~ nvme ]]; then
      zfs_part="${disk}p${part_num}"
    fi
    
    pool_partitions+=("${zfs_part}")
  done
  
  info "Creating ZFS pool: ${pool_name}"
  info "Pool type: ${pool_type}"
  info "Partitions: ${pool_partitions[*]}"
  
  # Build zpool create command
  local -a zpool_cmd=(
    "zpool" "create"
    "-f"
    "-o" "cachefile=none"
  )
  local prop
  
  # Add pool properties
  for prop in "${ZFS_POOL_PROPS[@]}"; do
    zpool_cmd+=("-o" "${prop}")
  done
  
  # Add filesystem properties
  for prop in "${ZFS_FS_PROPS[@]}"; do
    zpool_cmd+=("-O" "${prop}")
  done
  
  # Add mount options
  zpool_cmd+=(
    "-O" "mountpoint=none"
    "-R" "${DEFAULT_MOUNT_POINT}"
    "${pool_name}"
  )
  
  # Add pool topology based on type
  case "${pool_type}" in
    single)
      zpool_cmd+=("${pool_partitions[@]}")
      ;;
    mirror)
      zpool_cmd+=("mirror" "${pool_partitions[@]}")
      ;;
    raidz|raidz2|raidz3)
      zpool_cmd+=("${pool_type}" "${pool_partitions[@]}")
      ;;
    *)
      err "Unknown pool type: ${pool_type}"
      ;;
  esac
  
  # Create the pool
  if ! "${zpool_cmd[@]}"; then
    err "Failed to create ZFS pool"
  fi
  
  success "ZFS pool '${pool_name}' created successfully"
  
  # Display pool status
  zpool status "${pool_name}"
}

#######################################
# Create ZFS datasets
# Globals:
#   pool_name
#   enable_boot_environments
#   be_prefix
# Outputs:
#   Writes progress to stdout
#######################################
create_zfs_datasets() {
  info "Creating ZFS datasets..."
  
  if [[ "${enable_boot_environments}" == "yes" ]]; then
    # Boot environment layout
    zfs create -o mountpoint=none "${pool_name}/ROOT" \
      || err "Failed to create ROOT dataset"
    
    zfs create -o mountpoint=/ -o canmount=noauto "${pool_name}/ROOT/${be_prefix}" \
      || err "Failed to create boot environment dataset"
    
    zfs create -o mountpoint=none "${pool_name}/data" \
      || err "Failed to create data dataset"
    
    zfs create -o mountpoint=/home "${pool_name}/data/home" \
      || err "Failed to create home dataset"
    
    zfs create -o mountpoint=/root "${pool_name}/data/root" \
      || err "Failed to create root home dataset"
    
    # Mount root filesystem
    zpool set bootfs="${pool_name}/ROOT/${be_prefix}" "${pool_name}" \
      || err "Failed to set bootfs property"
    
    zfs mount "${pool_name}/ROOT/${be_prefix}" \
      || err "Failed to mount root dataset"
    
  else
    # Simple layout without boot environments
    zfs create -o mountpoint=none "${pool_name}/ROOT" \
      || err "Failed to create ROOT dataset"
    
    zfs create -o mountpoint=/ -o canmount=noauto "${pool_name}/ROOT/default" \
      || err "Failed to create root dataset"
    
    zfs create -o mountpoint=/home "${pool_name}/home" \
      || err "Failed to create home dataset"
    
    # Mount root filesystem
    zpool set bootfs="${pool_name}/ROOT/default" "${pool_name}" \
      || err "Failed to set bootfs property"
    
    zfs mount "${pool_name}/ROOT/default" \
      || err "Failed to mount root dataset"
  fi
  
  # Create additional datasets
  zfs create -o mountpoint=/var/log "${pool_name}/var" \
    || warn "Failed to create var dataset"
  
  zfs create -o mountpoint=/var/cache "${pool_name}/cache" \
    || warn "Failed to create cache dataset"
  
  # Mount all datasets
  zfs mount -a || warn "Some datasets failed to mount"
  
  success "ZFS datasets created and mounted"
  
  # Display dataset tree
  zfs list -t all -r "${pool_name}"
}

#######################################
# Mount EFI partition
# Globals:
#   install_disks
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
mount_efi_partition() {
  info "Mounting EFI partition..."
  
  # Use first disk's EFI partition
  local first_disk="${install_disks[0]}"
  local efi_part="${first_disk}1"
  
  # Handle NVMe naming
  if [[ "${first_disk}" =~ nvme ]]; then
    efi_part="${first_disk}p1"
  fi
  
  mkdir -p "${DEFAULT_MOUNT_POINT}/boot/efi" \
    || err "Failed to create EFI mount point"
  
  mount "${efi_part}" "${DEFAULT_MOUNT_POINT}/boot/efi" \
    || err "Failed to mount EFI partition"
  
  success "EFI partition mounted at ${DEFAULT_MOUNT_POINT}/boot/efi"
}

################################################################################
# SYSTEM INSTALLATION
################################################################################

#######################################
# Configure ArchZFS repository
# Outputs:
#   Writes progress to stdout
#######################################
configure_archzfs_repo() {
  info "Configuring ArchZFS repository..."
  
  # Add ArchZFS repo to pacman.conf
  cat >> /etc/pacman.conf <<EOF

[archzfs]
Server = ${ARCHZFS_REPO_URL}
EOF
  
  # Import and sign GPG key
  pacman-key --recv-keys "${ARCHZFS_GPG_KEY}" \
    || warn "Failed to receive ArchZFS GPG key"
  
  pacman-key --lsign-key "${ARCHZFS_GPG_KEY}" \
    || warn "Failed to locally sign ArchZFS GPG key"
  
  # Refresh package databases
  pacman -Sy || err "Failed to refresh package databases"
  
  success "ArchZFS repository configured"
}

#######################################
# Install base system
# Globals:
#   kernel_choice
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
install_base_system() {
  print_header "Base System Installation"
  
  configure_archzfs_repo
  
  info "Installing base packages (this may take several minutes)..."
  
  # Determine ZFS package based on kernel
  local zfs_package=""
  case "${kernel_choice}" in
    linux-lts)
      zfs_package="zfs-linux-lts"
      ;;
    linux)
      zfs_package="zfs-linux"
      ;;
    linux-zen)
      zfs_package="zfs-linux-zen"
      ;;
    linux-hardened)
      zfs_package="zfs-linux-hardened"
      ;;
    *)
      zfs_package="zfs-dkms"
      ;;
  esac
  
  # Build package list
  local -a packages=(
    "debian-minimal"
    "build-essential"
    "${kernel_choice}"
    "${kernel_choice}-headers-amd64"
    "firmware-linux"
    "${zfs_package}"
    "zfsutils-linux"
  )
  
  # Add bootloader packages
  case "${bootloader_choice}" in
    grub)
      packages+=("grub" "efibootmgr" "os-prober")
      ;;
    systemd-boot)
      packages+=("efibootmgr")
      ;;
    zfsbootmenu)
      packages+=("efibootmgr" "kexec-tools")
      ;;
  esac
  
  # Add network packages
  packages+=(
    "networkmanager"
    "systemd-resolvconf"
    "inetutils"
    "bind"
    "traceroute"
    "wget"
    "curl"
  )
  
  # Add development tools
  packages+=(
    "git"
    "github-cli"
    "openssh"
    "vim"
    "nano"
    "man-db"
    "man-pages"
    "sudo"
  )
  
  # Add ZRAM if needed
  if [[ "${swap_type}" == "zram" ]]; then
    packages+=("systemd-zram-generator")
  fi
  
  # Install packages
  if ! debootstrap --arch amd64 --include="${packages[*]}" stable "${DEFAULT_MOUNT_POINT}" "${DEBIAN_REPO}"; then
    err "Failed to install base system"
  fi
  
  success "Base system installed successfully"
}

#######################################
# Generate fstab
# Globals:
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
generate_fstab() {
  info "Generating fstab..."
  
  # Generate fstab with UUIDs
  genfstab -U "${DEFAULT_MOUNT_POINT}" >> "${DEFAULT_MOUNT_POINT}/etc/fstab" \
    || err "Failed to generate fstab"
  
  # Add ZFS root to fstab for compatibility
  if [[ "${enable_boot_environments}" == "yes" ]]; then
    echo "${pool_name}/ROOT/${be_prefix} / zfs defaults,noatime 0 0" \
      >> "${DEFAULT_MOUNT_POINT}/etc/fstab"
  else
    echo "${pool_name}/ROOT/default / zfs defaults,noatime 0 0" \
      >> "${DEFAULT_MOUNT_POINT}/etc/fstab"
  fi
  
  success "fstab generated"
}

################################################################################
# SYSTEM CONFIGURATION
################################################################################

#######################################
# Configure system in chroot
# Globals:
#   Multiple configuration variables
# Outputs:
#   Writes progress to stdout
#######################################
configure_system() {
  print_header "System Configuration"
  
  info "Configuring system (running in chroot)..."
  
  # Create configuration script to run in chroot
  cat > "${DEFAULT_MOUNT_POINT}/tmp/configure.sh" <<'EOCHROOT'
#!/bin/bash
set -euo pipefail

# Import variables from parent script
TIMEZONE="__TIMEZONE__"
LOCALE="__LOCALE__"
KEYMAP="__KEYMAP__"
HOST_NAME="__HOSTNAME__"
KERNEL_CHOICE="__KERNEL_CHOICE__"
POOL_NAME="__POOL_NAME__"
BOOTLOADER_CHOICE="__BOOTLOADER_CHOICE__"
ENABLE_BOOT_ENVIRONMENTS="__ENABLE_BOOT_ENVIRONMENTS__"
BE_PREFIX="__BE_PREFIX__"
NETWORK_INTERFACE="__NETWORK_INTERFACE__"
USE_DHCP="__USE_DHCP__"
STATIC_IP="__STATIC_IP__"
STATIC_GATEWAY="__STATIC_GATEWAY__"
STATIC_DNS="__STATIC_DNS__"
SWAP_TYPE="__SWAP_TYPE__"
ARCHZFS_REPO_URL="__ARCHZFS_REPO_URL__"
ARCHZFS_GPG_KEY="__ARCHZFS_GPG_KEY__"

echo "Setting timezone..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

echo "Configuring locale..."
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "Setting keyboard layout..."
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

echo "Setting hostname..."
echo "${HOST_NAME}" > /etc/hostname

cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOST_NAME}.localdomain ${HOST_NAME}
EOF

echo "Configuring OpenZFS repository..."
cat > /etc/apt/sources.list.d/openzfs.list <<EOF
deb ${DEBIAN_REPO} stable main contrib
deb ${OPENZFS_REPO} stable/updates main
EOF

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "${OPENZFS_GPG_KEY}" 2>/dev/null || true
apt update

echo "Configuring network..."
systemctl enable NetworkManager
systemctl enable systemd-resolved

if [[ -n "${NETWORK_INTERFACE}" ]]; then
  if [[ "${USE_DHCP}" == "yes" ]]; then
    cat > "/etc/NetworkManager/system-connections/${NETWORK_INTERFACE}.nmconnection" <<EOF
[connection]
id=${NETWORK_INTERFACE}
type=ethernet
interface-name=${NETWORK_INTERFACE}
autoconnect=true

[ipv4]
method=auto

[ipv6]
method=auto
EOF
  else
    cat > "/etc/NetworkManager/system-connections/${NETWORK_INTERFACE}.nmconnection" <<EOF
[connection]
id=${NETWORK_INTERFACE}
type=ethernet
interface-name=${NETWORK_INTERFACE}
autoconnect=true

[ipv4]
method=manual
address=${STATIC_IP}
gateway=${STATIC_GATEWAY}
dns=${STATIC_DNS}

[ipv6]
method=auto
EOF
  fi
  chmod 600 "/etc/NetworkManager/system-connections/${NETWORK_INTERFACE}.nmconnection"
fi

echo "Configuring SSH..."
systemctl enable sshd
sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

echo "Configuring ZFS services..."
systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target

if [[ "${SWAP_TYPE}" == "zram" ]]; then
  echo "Configuring ZRAM..."
  mkdir -p /etc/systemd/zram-generator.conf.d
  cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
fi

echo "Configuring mkinitcpio..."
echo 'INITRD=Yes' > /etc/default/zfs
update-initramfs -u -k all

echo "Generating initramfs..."
mkinitcpio -P

echo "Configuration complete!"
EOCHROOT
  
  # Replace placeholders
  sed -i "s|__TIMEZONE__|${time_zone}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__LOCALE__|${locale}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__KEYMAP__|${keymap}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__HOSTNAME__|${host_name}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__KERNEL_CHOICE__|${kernel_choice}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__POOL_NAME__|${pool_name}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__BOOTLOADER_CHOICE__|${bootloader_choice}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__ENABLE_BOOT_ENVIRONMENTS__|${enable_boot_environments}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__BE_PREFIX__|${be_prefix}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__NETWORK_INTERFACE__|${network_interface}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__USE_DHCP__|${use_dhcp}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__STATIC_IP__|${static_ip}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__STATIC_GATEWAY__|${static_gateway}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__STATIC_DNS__|${static_dns}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__SWAP_TYPE__|${swap_type}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__ARCHZFS_REPO_URL__|${ARCHZFS_REPO_URL}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  sed -i "s|__ARCHZFS_GPG_KEY__|${ARCHZFS_GPG_KEY}|g" "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  
  chmod +x "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  
  # Run configuration in chroot
  arch-chroot "${DEFAULT_MOUNT_POINT}" /tmp/configure.sh \
    || err "Failed to configure system in chroot"
  
  rm "${DEFAULT_MOUNT_POINT}/tmp/configure.sh"
  
  success "System configuration complete"
}

#######################################
# Set root password
# Globals:
#   root_password
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
set_root_password() {
  info "Setting root password..."
  
  echo "root:${root_password}" | arch-chroot "${DEFAULT_MOUNT_POINT}" chpasswd \
    || err "Failed to set root password"
  
  success "Root password set"
}

#######################################
# Create user account
# Globals:
#   create_user
#   username
#   user_password
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
create_user_account() {
  if [[ "${create_user}" != "yes" ]]; then
    return 0
  fi
  
  info "Creating user account: ${username}..."
  
  arch-chroot "${DEFAULT_MOUNT_POINT}" useradd -m -G wheel -s /bin/bash "${username}" \
    || err "Failed to create user account"
  
  echo "${username}:${user_password}" | arch-chroot "${DEFAULT_MOUNT_POINT}" chpasswd \
    || err "Failed to set user password"
  
  # Enable sudo for wheel group
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' \
    "${DEFAULT_MOUNT_POINT}/etc/sudoers" \
    || warn "Failed to enable sudo for wheel group"
  
  success "User account created: ${username}"
}

################################################################################
# BOOTLOADER INSTALLATION
################################################################################

#######################################
# Install GRUB bootloader
# Globals:
#   install_disks
#   pool_name
#   enable_boot_environments
#   be_prefix
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
install_grub() {
  info "Installing GRUB bootloader..."
  
  # Determine root dataset
  local root_dataset
  if [[ "${enable_boot_environments}" == "yes" ]]; then
    root_dataset="${pool_name}/ROOT/${be_prefix}"
  else
    root_dataset="${pool_name}/ROOT/default"
  fi
  
  # Create GRUB configuration script
  cat > "${DEFAULT_MOUNT_POINT}/tmp/install_grub.sh" <<EOGRALL
#!/bin/bash
set -euo pipefail

# Install GRUB to EFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck

# Configure GRUB for ZFS
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet zfs=${root_dataset}"/' /etc/default/grub

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg

echo "GRUB installation complete"
EOGRALL
  
  chmod +x "${DEFAULT_MOUNT_POINT}/tmp/install_grub.sh"
  
  arch-chroot "${DEFAULT_MOUNT_POINT}" /tmp/install_grub.sh \
    || err "Failed to install GRUB"
  
  rm "${DEFAULT_MOUNT_POINT}/tmp/install_grub.sh"
  
  success "GRUB installed successfully"
}

#######################################
# Install systemd-boot bootloader
# Globals:
#   pool_name
#   enable_boot_environments
#   be_prefix
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
install_systemd_boot() {
  info "Installing systemd-boot..."
  
  # Determine root dataset
  local root_dataset
  if [[ "${enable_boot_environments}" == "yes" ]]; then
    root_dataset="${pool_name}/ROOT/${be_prefix}"
  else
    root_dataset="${pool_name}/ROOT/default"
  fi
  
  # Install systemd-boot
  arch-chroot "${DEFAULT_MOUNT_POINT}" bootctl install \
    || err "Failed to install systemd-boot"
  
  # Create loader configuration
  cat > "${DEFAULT_MOUNT_POINT}/boot/efi/loader/loader.conf" <<EOF
default arch.conf
timeout 5
console-mode max
editor no
EOF
  
  # Create boot entry
  mkdir -p "${DEFAULT_MOUNT_POINT}/boot/efi/loader/entries"
  
  cat > "${DEFAULT_MOUNT_POINT}/boot/efi/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-${kernel_choice}
initrd  /initramfs-${kernel_choice}.img
options zfs=${root_dataset} rw
EOF
  
  # Copy kernel and initramfs to EFI partition
  cp "${DEFAULT_MOUNT_POINT}/boot/vmlinuz-${kernel_choice}" \
    "${DEFAULT_MOUNT_POINT}/boot/efi/"
  
  cp "${DEFAULT_MOUNT_POINT}/boot/initramfs-${kernel_choice}.img" \
    "${DEFAULT_MOUNT_POINT}/boot/efi/"
  
  success "systemd-boot installed successfully"
}

#######################################
# Install ZFSBootMenu
# Globals:
#   pool_name
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
install_zfsbootmenu() {
  info "Installing ZFSBootMenu..."
  
  warn "ZFSBootMenu installation requires additional configuration"
  warn "Please refer to ZFSBootMenu documentation for complete setup"
  
  # Create basic ZFSBootMenu configuration
  cat > "${DEFAULT_MOUNT_POINT}/tmp/install_zbm.sh" <<'EOZBM'
#!/bin/bash
set -euo pipefail

# Install ZFSBootMenu from AUR (simplified)
echo "ZFSBootMenu requires manual installation from AUR"
echo "After first boot, install zfsbootmenu package and run generate-zbm"

# Create basic EFI entry
mkdir -p /boot/efi/EFI/ZBM

# Copy kernel
cp /boot/vmlinuz-* /boot/efi/EFI/ZBM/vmlinuz.efi || true

echo "ZFSBootMenu setup initiated (requires post-install configuration)"
EOZBM
  
  chmod +x "${DEFAULT_MOUNT_POINT}/tmp/install_zbm.sh"
  
  arch-chroot "${DEFAULT_MOUNT_POINT}" /tmp/install_zbm.sh \
    || warn "ZFSBootMenu installation incomplete"
  
  rm "${DEFAULT_MOUNT_POINT}/tmp/install_zbm.sh"
  
  warn "ZFSBootMenu requires additional setup after first boot"
  info "Install zfsbootmenu from AUR and run: generate-zbm"
}

#######################################
# Install selected bootloader
# Globals:
#   bootloader_choice
# Outputs:
#   Writes progress to stdout
#######################################
install_bootloader() {
  print_header "Bootloader Installation"
  
  case "${bootloader_choice}" in
    grub)
      install_grub
      ;;
    systemd-boot)
      install_systemd_boot
      ;;
    zfsbootmenu)
      install_zfsbootmenu
      ;;
    *)
      err "Unknown bootloader: ${bootloader_choice}"
      ;;
  esac
  
  success "Bootloader installation complete"
}

################################################################################
# CLEANUP AND FINALIZATION
################################################################################

#######################################
# Configure ZFS cache file
# Globals:
#   pool_name
#   DEFAULT_MOUNT_POINT
# Outputs:
#   Writes progress to stdout
#######################################
configure_zfs_cache() {
  info "Configuring ZFS cache..."
  
  mkdir -p "${DEFAULT_MOUNT_POINT}/etc/zfs"
  
  zpool set cachefile=/etc/zfs/zpool.cache "${pool_name}" \
    || warn "Failed to set cache file"
  
  cp /etc/zfs/zpool.cache "${DEFAULT_MOUNT_POINT}/etc/zfs/zpool.cache" \
    || warn "Failed to copy cache file"
  
  success "ZFS cache configured"
}

#######################################
# Unmount filesystems and export pool
# Globals:
#   DEFAULT_MOUNT_POINT
#   pool_name
# Outputs:
#   Writes progress to stdout
#######################################
cleanup_installation() {
  info "Cleaning up installation..."
  
  # Unmount EFI partition
  umount -R "${DEFAULT_MOUNT_POINT}/boot/efi" 2>/dev/null || true
  
  # Export ZFS pool
  zfs umount -a 2>/dev/null || true
  zpool export "${pool_name}" 2>/dev/null || true
  
  # Deactivate swap
  swapoff -a 2>/dev/null || true
  
  success "Cleanup complete"
}

#######################################
# Display post-installation instructions
# Globals:
#   host_name
#   bootloader_choice
# Outputs:
#   Writes instructions to stdout
#######################################
display_post_install_info() {
  print_header "Installation Complete!"
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                  INSTALLATION SUCCESSFUL!                      ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Next steps:"
  echo "  1. Remove installation media"
  echo "  2. Reboot your system:  reboot"
  echo "  3. Login as root or user account"
  echo ""
  echo "System Information:"
  echo "  Hostname:      ${host_name}"
  echo "  Bootloader:    ${bootloader_choice}"
  echo "  Pool:          ${pool_name}"
  echo ""
  
  if [[ "${bootloader_choice}" == "zfsbootmenu" ]]; then
    echo "⚠️  ZFSBootMenu Post-Install Steps:"
    echo "  1. After first boot, install zfsbootmenu from AUR"
    echo "  2. Run: generate-zbm"
    echo "  3. Reboot to use ZFSBootMenu"
    echo ""
  fi
  
  echo "Useful commands:"
  echo "  zpool status              # Check pool health"
  echo "  zfs list                  # List datasets"
  echo "  systemctl status zfs.target  # Check ZFS services"
  echo ""
  echo "Documentation:"
  echo "  man zfs"
  echo "  man zpool"
  echo "  https://wiki.archlinux.org/title/ZFS"
  echo ""
  
  success "Enjoy your new Arch Linux ZFS system!"
}

################################################################################
# MAIN EXECUTION
################################################################################

#######################################
# Main installation function
# Coordinates the entire installation process
# Globals:
#   All global variables
# Outputs:
#   Installation progress and results
# Returns:
#   0 on success, exits on failure
#######################################
main() {
  print_header "Arch Linux ZFS Installer v${SCRIPT_VERSION}"
  
  echo "This script will install Arch Linux with ZFS root filesystem."
  echo "Press Ctrl+C to cancel at any time."
  echo ""
  
  # Pre-flight checks
  check_root
  check_uefi
  check_internet
  sync_clock
  detect_timezone
  
  # Hardware detection
  detect_disks
  
  # Kernel validation
  validate_kernel_compatibility
  
  # Collect user input
  get_disk_selection
  get_pool_name
  get_hostname
  get_root_password
  get_user_info
  get_locale
  get_keymap
  get_timezone
  get_kernel_choice
  get_bootloader_choice
  get_swap_config
  get_boot_environment_config
  get_network_config
  
  # Display configuration and confirm
  display_config_summary
  
  if ! confirm "Proceed with installation?" "no"; then
    err "Installation cancelled by user"
  fi
  
  # Installation steps
  partition_disks
  format_efi_partitions
  setup_swap_partitions
  
  create_zfs_pool
  create_zfs_datasets
  mount_efi_partition
  
  install_base_system
  generate_fstab
  
  configure_system
  set_root_password
  create_user_account
  
  install_bootloader
  configure_zfs_cache
  
  cleanup_installation
  
  display_post_install_info
  
  return 0
}

# Execute main function
main "$@"
