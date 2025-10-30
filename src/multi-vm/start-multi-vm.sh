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

# Detect OS (matching start-vm.sh's detection)
OS=$(uname -o)
if [ "${OS}" == "Darwin" ]; then
    OS_TYPE="darwin"
elif [ "${OS}" == "GNU/Linux" ]; then
    OS_TYPE="linux"
else
    echo "Unsupported OS: ${OS}"
    exit 1
fi

# Default configuration file
CONFIG_FILE="vm-config.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DIR_IMAGE="${SCRIPT_DIR}/../isolated-vm/image"

# Function to create a bridge network (Linux)
function create_bridge_network_linux() {
    local bridge_name=$1
    local subnet=$2
    local gateway=$3

    # Check if bridge already exists
    if ip link show "${bridge_name}" &>/dev/null; then
        echo "Bridge ${bridge_name} already exists"
        return 0
    fi

    # Create bridge
    echo "Creating bridge ${bridge_name}..."
    sudo ip link add "${bridge_name}" type bridge
    sudo ip addr add "${gateway}/24" dev "${bridge_name}"
    sudo ip link set "${bridge_name}" up

    # Enable IP forwarding
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

    # Set up NAT
    sudo iptables -t nat -A POSTROUTING -s "${subnet}/24" -j MASQUERADE
    sudo iptables -A FORWARD -i "${bridge_name}" -j ACCEPT
    sudo iptables -A FORWARD -o "${bridge_name}" -j ACCEPT
}

# Function to create a bridge network (macOS)
function create_bridge_network_darwin() {
    local bridge_name=$1
    local subnet=$2
    local gateway=$3

    # Check if bridge already exists
    if ifconfig "${bridge_name}" &>/dev/null; then
        echo "Bridge ${bridge_name} already exists"
        return 0
    fi

    # Create bridge
    echo "Creating bridge ${bridge_name}..."
    sudo ifconfig "${bridge_name}" create
    sudo ifconfig "${bridge_name}" inet "${gateway}" netmask 255.255.255.0 up

    # Enable IP forwarding
    sudo sysctl -w net.inet.ip.forwarding=1

    # Set up NAT using pfctl
    echo "nat on en0 from ${subnet}/24 to any -> (en0)" | sudo pfctl -f -
    sudo pfctl -e
}

# Function to cleanup bridge network (Linux)
function cleanup_bridge_network_linux() {
    local bridge_name=$1
    local subnet=$2
    
    # Remove iptables rules
    sudo iptables -t nat -D POSTROUTING -s "${subnet}/24" -j MASQUERADE
    sudo iptables -D FORWARD -i "${bridge_name}" -j ACCEPT
    sudo iptables -D FORWARD -o "${bridge_name}" -j ACCEPT

    # Remove bridge
    sudo ip link set "${bridge_name}" down
    sudo ip link delete "${bridge_name}" type bridge
}

# Function to cleanup bridge network (macOS)
function cleanup_bridge_network_darwin() {
    local bridge_name=$1
    
    # Disable NAT
    sudo pfctl -d
    echo "" | sudo pfctl -f -
    
    # Remove bridge
    sudo ifconfig "${bridge_name}" down
    sudo ifconfig "${bridge_name}" delet
}

# Function to start a single VM
function start_vm() {
    local vm_config=$1
    local common_config=$2
    local bridge_name=$3

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

    # Set OS-specific defaults
    if [ "${OS_TYPE}" == "darwin" ]; then
        export DEFAULT_KVM_DARWIN_CPU="${cpu}"
        export DEFAULT_KVM_DARWIN_MEMORY="${memory}"
    else
        export DEFAULT_KVM_LINUX_CPU="${cpu}"
        export DEFAULT_KVM_LINUX_MEMORY="${memory}"
    fi

    # Create a temporary script to start the VM with the correct parameters
    local temp_script="/tmp/start-vm-${name}.sh"
    cat > "${temp_script}" << EOF
#!/bin/bash
"${SCRIPT_DIR}/../isolated-vm/start-vm.sh" \\
    --bridge "${bridge_name}" \\
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
    local bridge_name=$(yq '.network.name' "${CONFIG_FILE}")
    local subnet=$(yq '.network.subnet' "${CONFIG_FILE}")
    local gateway=$(yq '.network.gateway' "${CONFIG_FILE}")
    local dns=$(yq '.network.dns[]' "${CONFIG_FILE}")

    # Create bridge network based on OS
    case ${OS_TYPE} in
        linux)
            create_bridge_network_linux "${bridge_name}" "${subnet}" "${gateway}"
            ;;
        darwin)
            create_bridge_network_darwin "${bridge_name}" "${subnet}" "${gateway}"
            ;;
    esac

    # Read common configuration
    local common_config=$(yq '.common' "${CONFIG_FILE}")

    # Start each VM
    local vm_count=$(yq '.vms | length' "${CONFIG_FILE}")
    for ((i=0; i<vm_count; i++)); do
        local vm_config=$(yq ".vms[${i}]" "${CONFIG_FILE}")
        echo "Starting VM $(yq '.name' <<< "${vm_config}")..."
        start_vm "${vm_config}" "${common_config}" "${bridge_name}"
    done

    echo "All VMs have been started successfully!"
}

# Cleanup function
function cleanup() {
    local bridge_name=$(yq '.network.name' "${CONFIG_FILE}")
    local subnet=$(yq '.network.subnet' "${CONFIG_FILE}")
    
    case ${OS_TYPE} in
        linux)
            cleanup_bridge_network_linux "${bridge_name}" "${subnet}"
            ;;
        darwin)
            cleanup_bridge_network_darwin "${bridge_name}"
            ;;
    esac
}

# Register cleanup function
trap cleanup EXIT

# Run the main function
main "$@" 