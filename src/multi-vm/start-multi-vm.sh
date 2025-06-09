#!/bin/bash

# Script to start multiple VMs based on YAML configuration
# This script creates a network and starts multiple VMs that can communicate with each other
# It uses the existing start-vm.sh script as its base

set -e

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed. Please install it first."
    echo "You can install it with: brew install yq"
    exit 1
fi

# Default configuration file
CONFIG_FILE="vm-config.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DIR_IMAGE="${SCRIPT_DIR}/../isolated-vm/image"

# Function to check if a network exists
function check_network_exists() {
    local network_name=$1
    if ! virsh net-info "${network_name}" &>/dev/null; then
        return 1
    fi
    return 0
}

# Function to create a network
function create_network() {
    local network_name=$1
    local subnet=$2
    local gateway=$3
    local dns=$4

    # Create network XML
    cat > /tmp/network.xml << EOF
<network>
  <name>${network_name}</name>
  <forward mode='nat'/>
  <bridge name='${network_name}' stp='on' delay='0'/>
  <ip address='${gateway}' netmask='255.255.255.0'>
    <dhcp>
      <range start='${subnet%.*}.2' end='${subnet%.*}.254'/>
      <host mac='52:54:00:00:00:01' name='hydravm1' ip='192.168.100.10'/>
      <host mac='52:54:00:00:00:02' name='hydravm2' ip='192.168.100.11'/>
    </dhcp>
  </ip>
</network>
EOF

    # Define and start the network
    virsh net-define /tmp/network.xml
    virsh net-start "${network_name}"
    virsh net-autostart "${network_name}"
}

# Function to start a single VM
function start_vm() {
    local vm_config=$1
    local common_config=$2
    local network_name=$3

    # Extract VM configuration
    local name=$(echo "${vm_config}" | yq '.name')
    local hostname=$(echo "${vm_config}" | yq '.hostname')
    local ip=$(echo "${vm_config}" | yq '.ip')
    local mac=$(echo "${vm_config}" | yq '.mac')
    local cpu=$(echo "${vm_config}" | yq '.cpu')
    local memory=$(echo "${vm_config}" | yq '.memory')
    local disk_size=$(echo "${vm_config}" | yq '.disk_size')
    local ssh_port=$(echo "${vm_config}" | yq '.ports.ssh')
    local containerd_port=$(echo "${vm_config}" | yq '.ports.containerd')
    local rimd_port=$(echo "${vm_config}" | yq '.ports.rimd')

    # Extract common configuration
    local username=$(echo "${common_config}" | yq '.username')
    local password=$(echo "${common_config}" | yq '.password')
    local salt=$(echo "${common_config}" | yq '.salt')
    local image=$(echo "${common_config}" | yq '.image')
    local kernel_version=$(echo "${common_config}" | yq '.kernel_version')
    local image_source_url=$(echo "${common_config}" | yq '.image_source_url')

    # Set environment variables for the VM
    export VM_USERNAME="${username}"
    export VM_PASSWORD="${password}"
    export VM_SALT="${salt}"
    export VM_HOSTNAME="${hostname}"
    export DEFAULT_KVM_CPU="${cpu}"
    export DEFAULT_KVM_MEMORY="${memory}"
    export DEFAULT_KVM_DISK_SIZE="${disk_size}"
    export DEFAULT_KVM_HOST_SSHD_PORT="${ssh_port}"
    export DEFAULT_KVM_HOST_CONTAINERD_PORT="${containerd_port}"
    export DEFAULT_KVM_HOST_RIMD_PORT="${rimd_port}"
    export DEFAULT_IMAGE="${image}"
    export DEFAULT_KERNEL_VERSION="${kernel_version}"
    export DEFAULT_IMAGE_SOURCE_URL="${image_source_url}"
    export DEFAULT_DIR_IMAGE="${DEFAULT_DIR_IMAGE}"

    # Create a temporary script to start the VM with the correct parameters
    local temp_script="/tmp/start-vm-${name}.sh"
    cat > "${temp_script}" << EOF
#!/bin/bash
"${SCRIPT_DIR}/../isolated-vm/start-vm.sh" \\
    --network "${network_name}" \\
    --mac "${mac}" \\
    --ip "${ip}" \\
    --hostname "${hostname}" \\
    --username "${username}" \\
    --password "${password}" \\
    --salt "${salt}" \\
    --cpu "${cpu}" \\
    --memory "${memory}" \\
    --disk-size "${disk_size}" \\
    --sshd-port "${ssh_port}" \\
    --containerd-port "${containerd_port}" \\
    --rimd-port "${rimd_port}" \\
    --image "${image}" \\
    --kernel-version "${kernel_version}" \\
    --image-source-url "${image_source_url}"
EOF

    chmod +x "${temp_script}"
    "${temp_script}"
    rm "${temp_script}"
}

# Main script
function main() {
    # Check if configuration file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "Error: Configuration file ${CONFIG_FILE} not found"
        exit 1
    fi

    # Read network configuration
    local network_name=$(yq '.network.name' "${CONFIG_FILE}")
    local subnet=$(yq '.network.subnet' "${CONFIG_FILE}")
    local gateway=$(yq '.network.gateway' "${CONFIG_FILE}")
    local dns=$(yq '.network.dns[]' "${CONFIG_FILE}")

    # Create network if it doesn't exist
    if ! check_network_exists "${network_name}"; then
        echo "Creating network ${network_name}..."
        create_network "${network_name}" "${subnet}" "${gateway}" "${dns}"
    else
        echo "Network ${network_name} already exists"
    fi

    # Read common configuration
    local common_config=$(yq '.common' "${CONFIG_FILE}")

    # Start each VM
    local vm_count=$(yq '.vms | length' "${CONFIG_FILE}")
    for ((i=0; i<vm_count; i++)); do
        local vm_config=$(yq ".vms[${i}]" "${CONFIG_FILE}")
        echo "Starting VM $(yq '.name' <<< "${vm_config}")..."
        start_vm "${vm_config}" "${common_config}" "${network_name}"
    done

    echo "All VMs have been started successfully!"
}

# Run the main function
main "$@" 