# Multi-VM Setup

This directory contains scripts and configuration files to set up multiple virtual machines that can communicate with each other over a common network. The setup is based on QEMU/KVM and libvirt, and uses the existing isolated-vm infrastructure.

## Prerequisites

1. QEMU/KVM and libvirt installed on your system
2. The `yq` tool for YAML processing:
   ```bash
   brew install yq
   ```
3. The original `isolated-vm` setup working correctly

## Configuration

The setup is configured through the `vm-config.yaml` file. Here's an explanation of the configuration options:

### Network Configuration
```yaml
network:
  name: "hydra-net"        # Name of the libvirt network
  subnet: "192.168.100.0/24"  # Network subnet
  gateway: "192.168.100.1"    # Network gateway
  dns: ["8.8.8.8", "8.8.4.4"] # DNS servers
```

### VM Configuration
Each VM is configured with:
```yaml
vms:
  - name: "vm1"            # VM name
    hostname: "hydravm1"   # Hostname inside the VM
    ip: "192.168.100.10"   # Static IP address
    mac: "52:54:00:00:00:01" # MAC address
    cpu: 2                 # Number of CPU cores
    memory: 8              # Memory in GB
    disk_size: 3           # Disk size in GB
    ports:                 # Port forwarding
      ssh: 5555           # SSH port
      containerd: 35000   # Containerd port
      rimd: 35001         # RIMD port
```

### Common Settings
Shared settings for all VMs:
```yaml
common:
  username: "hailhydra"    # VM username
  password: "hailhydra"    # VM password
  salt: "123456"          # Salt for password hashing
  image: "debian-12-genericcloud-amd64-20250316-2053.qcow2"  # VM image
  kernel_version: "6.12.22+bpo"  # Kernel version
  image_source_url: "https://cloud.debian.org/images/cloud/bookworm/20250316-2053/"  # Image source
```

## Usage

1. Edit the `vm-config.yaml` file to configure your VMs as needed.

2. Start the VMs:
   ```bash
   ./start-multi-vm.sh
   ```

   This will:
   - Create a libvirt network if it doesn't exist
   - Start all configured VMs
   - Set up networking between VMs
   - Configure port forwarding

3. Access the VMs:
   - SSH: `ssh -p <ssh_port> <username>@localhost`
   - Example for vm1: `ssh -p 5555 hailhydra@localhost`

## Network Communication

The VMs are connected to a common network and can communicate with each other using their static IPs:

- vm1: 192.168.100.10
- vm2: 192.168.100.11

You can test connectivity between VMs using:
```bash
ping 192.168.100.10  # From vm2 to vm1
ping 192.168.100.11  # From vm1 to vm2
```

## Port Forwarding

Each VM has its own set of forwarded ports:

- vm1:
  - SSH: 5555
  - Containerd: 35000
  - RIMD: 35001

- vm2:
  - SSH: 5556
  - Containerd: 35002
  - RIMD: 35003

## Troubleshooting

1. If the network already exists:
   ```bash
   virsh net-destroy hydra-net
   virsh net-undefine hydra-net
   ```

2. To check VM status:
   ```bash
   virsh list --all
   ```

3. To check network status:
   ```bash
   virsh net-list --all
   ```

4. To view VM console:
   ```bash
   virsh console <vm-name>
   ```

## Cleanup

To stop and remove all VMs and the network:
```bash
# Stop all VMs
virsh destroy vm1
virsh destroy vm2

# Undefine VMs
virsh undefine vm1
virsh undefine vm2

# Remove network
virsh net-destroy hydra-net
virsh net-undefine hydra-net
``` 