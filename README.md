# **Hydra: IoT Device Emulation and Isolation Framework**

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/hydra)](https://artifacthub.io/packages/search?repo=hydra)

Hydra is a comprehensive framework for emulating IoT devices with isolated execution environments. It provides one or two isolated Linux environments, each running in separate virtual machines with independent resource and configuration management. Designed as part of a smart-home security demonstration using AI and LLMs, Hydra enables sophisticated container orchestration scenarios with strong isolation guarantees.

## **Overview**

Hydra enables the creation of isolated execution environments for containers, perfect for:

- **Smart Home Security Research**: Simulate IoT devices in isolated virtual machines
- **Multi-Container Orchestration**: Run containers in separate VMs with Kubernetes integration
- **Security Testing**: Test container isolation and security boundaries
- **IoT Device Emulation**: Emulate complete device stacks in virtual environments
- **Edge Computing Research**: Prototype edge computing scenarios with VM-based isolation

### Key Features

- **Dual Environment Architecture**: Host and isolated environments, each in dedicated VMs
- **Kubernetes Integration**: Full k3s support with Crismux for multi-containerd orchestration
- **Cross-Platform Support**: Runs on macOS (Apple Silicon & Intel), Linux, Docker, and Kubernetes
- **Multiple Virtualization Backends**: QEMU/KVM, HVF (Hypervisor.framework), and Krunkit support.
- **Support SME and Vulkan acceleration**: Krunkit supports SME2 on Apple M4 platforms and vulkan on all Apple silicon platforms. QEMU supports vulkan acceleration on Linux.
- **Container Runtime Isolation**: Each VM runs containerd independently
- **Network Configuration**: Flexible networking with port forwarding and CSI proxy
- **Multi-VM Orchestration**: Launch multiple VMs concurrently (see `src/multi-vm/`)
- **Ready to use and highly configurable**: Works out of the box but allows customizations to satisfy specific requirements   

## **Architecture**

The following diagram shows two VMs configuration with one running as host enviroment and another running as isolated enviroment. 

```
┌───────────────────────────────────────────┐
│                Physical Host              │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │               Host Environment (VM) │  │
│  │  ┌──────────────────────────────┐   │  │
│  │  │       k3s / Kubernetes       │   │  │
│  │  │            ▼                 │   │  │
│  │  │         Kubelet              │   │  │
│  │  │            ▼                 │   │  │
│  │  │     ┌── Crismux ──┐          │   │  │
│  │  │     │             ▼          │   │  │
│  │  │     │         Containerd     │   │  │
│  │  └─────│────────────────────────┘   │  │
│  └────────┼────────────────────────────┘  │
│           │                               │
│  ┌────────│────────────────────────────┐  │
│  │        │  Isolated Environment (VM) │  │
│  │  ┌─────│────────────────────────┐   │  │
│  │  │     │(TCP → Unix Socket)     │   │  │
│  │  │     ▼                        │   │  │
│  │  │   csi-grpc-proxy             │   │  │
│  │  │     ▼                        │   │  │
│  │  │  Containerd ("nelly")        │   │  │
│  │  └──────────────────────────────┘   │  │
│  │                                     │  │
│  │  Containers run here with           │  │
│  │  isolation from host environment    │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

The isolated VM can also run directly on the host or inside a container. It attachs to a host running k3s/kubernetes. 

```
┌───────────────────────────────────────────┐
│                Physical Host              │
│                                           │
│     ┌──────────────────────────────┐      │
│     │       k3s / Kubernetes       │      │
│     │            ▼                 │      │
│     │         Kubelet              │      │
│     │            ▼                 │      │
│     │     ┌── Crismux ──┐          │      │
│     │     │             ▼          │      │
│     │     │         Containerd     │      │
│     └─────│────────────────────────┘      │
│           │                               │
│           │                               │
│  ┌────────│────────────────────────────┐  │
│  │        │  Isolated Environment (VM) │  │
│  │  ┌─────│────────────────────────┐   │  │
│  │  │     │(TCP → Unix Socket)     │   │  │
│  │  │     ▼                        │   │  │
│  │  │   csi-grpc-proxy             │   │  │
│  │  │     ▼                        │   │  │
│  │  │  Containerd ("nelly")        │   │  │
│  │  └──────────────────────────────┘   │  │
│  │                                     │  │
│  │  Containers run here with           │  │
│  │  isolation from host environment    │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

### Components

1. **Isolated-VM** (`src/isolated-vm/`): Core VM creation and management
   - QEMU(KVM/HVF) or krunkit(HVF) based virtualization
   - Debian cloud images or RIMDworkspace support
   - Cloud-init configuration (debian cloud images)
   - Port forwarding (SSH, Containerd, RIMD)
   - 9P filesystem mounts for kubelet integration

2. **Add-Crismux** (`src/add-crismux/`): Kubernetes multi-containerd support
   - Crismux installation in k3s/k8s
   - "nelly" runtime class configuration
   - Enables kubelet to route containers to isolated VMs

3. **Multi-VM** (`src/multi-vm/`): Orchestration for multiple VMs
   - YAML-based configuration
   - Parallel VM execution
   - Network configuration and IP management
   - See `src/multi-vm/README.md` for details

## Quick Start

### Prerequisites

#### macOS

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install QEMU and dependencies
brew install qemu wget cri-tools

# Optional: For Krunkit support (macOS only, M4 recommended)
brew install podman krunkit git
# Also needs gvproxy from latest branch. 
# Install go by following: https://go.dev/doc/install
git clone https://github.com/containers/gvisor-tap-vsock.git
cd gvisor-tap-vsock
make
# The binary will be located at bin/gvproxy
```

#### Linux

```bash
# Install QEMU/KVM
sudo apt-get update
sudo apt-get install -y qemu-kvm qemu-utils wget genisoimage

# Verify KVM access
sudo usermod -aG kvm $USER
# Log out and back in for group changes to take effect
```

### Basic Usage

1. **Clone the repository**:

   ```bash
   git clone https://github.com/smarter-project/hydra
   cd hydra
   ```

2. **Start an isolated VM**:

   ```bash
   cd src/isolated-vm
   ./start-vm.sh
   ```

3. **Access the VM**:

   ```bash
   # SSH into the VM (default port 5555)
   ssh hailhydra@localhost -p 5555
   # Password: hailhydra
   
   # Or use the containerd endpoint
   # Configure csi-grpc-proxy first (see Testing section)
   ```

4. **Start multiple VMs** (see multi-vm documentation):

   ```bash
   cd src/multi-vm
   sudo ./start-multi-vm.sh
   ```

## Quick Start

Get Hydra running in under 5 minutes:

### Single VM Quick Start

1. **Clone and enter directory**:

   ```bash
   git clone https://github.com/smarter-project/hydra
   cd hydra/src/isolated-vm
   ```

2. **Start VM (downloads image on first run)**:

   ```bash
   ./start-vm.sh
   ```

3. **In another terminal, SSH into the VM**

   ```bash
   ssh hailhydra@localhost -p 5555
   # Password: hailhydra
   ```

The VM will boot and be ready in about 2-3 minutes. You'll see the login prompt in the terminal running `start-vm.sh`.

### Multiple VMs Quick Start

1. **Navigate to multi-vm directory**

   ```bash
   cd src/multi-vm
   ```

2. **Edit vm-config.yaml to configure your VMs**

3. **Start all VMs**

   ```bash
   sudo ./start-multi-vm.sh
   ```

4. **SSH into VMs (ports configured in vm-config.yaml)**

   ```bash
   ssh hydra@localhost -p 5555  # VM1
   ssh hydra@localhost -p 5556  # VM2
   ```

### Kubernetes Quick Start

1. **Install k3s (if not installed)**

	```bash
	curl -sfL https://get.k3s.io | sh -
	```

2. **Install Crismux**

	```bash
	cd src/add-crismux
	./install_crismux.sh install
	```

3. **Start isolated VM (in another terminal)**

	```bash
	cd ../isolated-vm
	sudo ./start-vm.sh
	```
	
4. **Create a pod with nelly runtime class**

	```bash
	kubectl apply -f - <<EOF
	apiVersion: v1
	kind: Pod
	metadata:
	  name: test-isolated
	spec:
	  runtimeClassName: nelly
	  containers:
	  - name: nginx
	    image: nginx:latest
	EOF
	```

That's it! For more detailed configuration options, see the sections below.

## Detailed Usage

### Isolated-VM Module

The `isolated-vm` module creates and manages virtual machines with container runtimes.

#### Quick Start Scripts

Pre-configured scripts for common scenarios:

- **`run-host.sh`**: Host environment with k3s, crismux, and containerd
- **`run-isolated.sh`**: Isolated environment using Debian cloud image
- **`run-isolated-bare.sh`**: Isolated environment using RIMDworkspace
- **`run-isolated-krunkit-krun.sh`**: Isolated environment using Krunkit (macOS M4)
- **`run-isolated-krunkit-krun-bare.sh`**: RIMDworkspace with Krunkit (macOS M4)

#### Environment Variables

The `start-vm.sh` script is configured via environment variables. Key variables include:

| Category | Variable | Description | Default |
|----------|----------|-------------|---------|
| **VM Identity** | `VM_HOSTNAME` | Hostname inside the VM | `hydravm` |
| | `VM_USERNAME` | Username to create | `hailhydra` |
| | `VM_PASSWORD` | User password | `hailhydra` |
| | `VM_SSH_AUTHORIZED_KEY` | SSH public key | - |
| **Resources** | `DEFAULT_KVM_DARWIN_CPU` | CPU cores (macOS) | `2` |
| | `DEFAULT_KVM_DARWIN_MEMORY` | RAM in GB (macOS) | `8` |
| | `DEFAULT_KVM_LINUX_CPU` | CPU cores (Linux) | `2` |
| | `DEFAULT_KVM_LINUX_MEMORY` | RAM in GB (Linux) | `8` |
| | `DEFAULT_KVM_DISK_SIZE` | Disk size in GB | `3` |
| **Network** | `DEFAULT_KVM_HOST_SSHD_PORT` | SSH port forwarding | `5555` |
| | `DEFAULT_KVM_HOST_CONTAINERD_PORT` | Containerd port | `35000` |
| | `DEFAULT_KVM_HOST_RIMD_PORT` | RIMD server port | `35001` |
| | `DEFAULT_NETWORK_PREFIX` | Network prefix | `10.0.2` |
| **Images** | `DEFAULT_IMAGE` | QCOW2 image filename | Arch-specific |
| | `DEFAULT_IMAGE_SOURCE_URL` | Image download URL | Debian Cloud |
| | `COPY_IMAGE_BACKUP` | Preserve base image | `0` |
| **Features** | `RUN_BARE_KERNEL` | Use kernel/initrd | `0` |
| | `ENABLE_K3S_DIOD` | Install k3s and diod | `0` |
| | `DISABLE_CONTAINERD_CSI_PROXY` | Skip CSI proxy install | `0` |
| | `ENABLE_KRUNKIT` | Use Krunkit backend | `0` |

See the full list in `src/isolated-vm/start-vm.sh` or run with `DEBUG=1`.

#### Examples

**Basic VM with custom resources**:

```bash
cd src/isolated-vm
DEFAULT_KVM_DARWIN_CPU=4 \
DEFAULT_KVM_DARWIN_MEMORY=16 \
DEFAULT_KVM_DISK_SIZE=10 \
./start-vm.sh
```

**VM with SSH key**:

```bash
export VM_SSH_AUTHORIZED_KEY="$(cat ~/.ssh/id_rsa.pub)"
./start-vm.sh
```

**Headless VM**:

```bash
KVM_NOGRAPHIC="-nographic" ./start-vm.sh &
```

**RIMDworkspace VM**:

```bash
RUN_BARE_KERNEL=1 \
RIMD_ARTIFACT_URL_TOKEN="your-token" \
./start-vm.sh
```

### Crismux Integration

Crismux enables Kubernetes to use multiple containerd instances, allowing containers to run in isolated VMs.

#### Installation

```bash
cd src/add-crismux
./install_crismux.sh install
```

This installs:

- Crismux in your k3s/k8s cluster
- "nelly" runtime class for routing containers to isolated VMs
- Required CRDs and controllers

#### Usage

Create pods with the "nelly" runtime class:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: isolated-pod
spec:
  runtimeClassName: nelly
  containers:
    - name: test-container
      image: nginx:latest
```

The pod will run in the isolated VM environment instead of the host.

### Multi-VM Orchestration

For running multiple VMs simultaneously, see `src/multi-vm/README.md`.

## Testing

### Connecting to Containerd

1. **Download csi-grpc-proxy**:

   ```bash
   # macOS (ARM64)
   wget https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-darwin-arm64
   chmod +x csi-grpc-proxy-v0.5.6-darwin-arm64
   
   # Linux
   wget https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux-amd64
   chmod +x csi-grpc-proxy-v0.5.6-linux-amd64
   ```

2. **Start the proxy**:

   ```bash
   BIND_TO=unix:///tmp/socket-csi \
   PROXY_TO=tcp://127.0.0.1:35000 \
   ./csi-grpc-proxy-v0.5.6-darwin-arm64 &
   ```

3. **Use crictl**:

   ```bash
   # List containers
   crictl --runtime-endpoint unix:///tmp/socket-csi ps
   
   # Pull an image
   crictl --runtime-endpoint unix:///tmp/socket-csi pull nginx:latest
   
   # Run a container
   crictl --runtime-endpoint unix:///tmp/socket-csi run \
     --runtime-endpoint unix:///tmp/socket-csi \
     container-id
   ```

See [Kubernetes crictl documentation](https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/) for more examples.

## Deployment Options

### Docker

Run isolated-vm in a container:

```bash
docker run \
  -d \
  --rm \
  --network host \
  --env "VM_SSH_AUTHORIZED_KEY=$(cat ~/.ssh/id_rsa.pub)" \
  -v $(pwd)/image:/root/image \
  -v /var/lib/kubelet:/var/lib/kubelet \
  -v /var/log/pods:/var/log/pods \
  --device /dev/kvm:/dev/kvm \
  ghcr.io/smarter-project/hydra/isolated-vm:main

# View logs
docker logs -f <container-id>

# SSH to VM
ssh -p 5555 hailhydra@localhost
```

### Kubernetes / k3s with Helm

Deploy the complete stack:

#### Add Helm repository

```bash
helm repo add hydra https://smarter-project.github.io/hydra/
```

#### Install

```bash
helm install \
  --create-namespace \
  --namespace hydra \
  --set "isolated-vm.configuration.sshkey=$(cat ~/.ssh/id_rsa.pub)" \
  hydra hydra/hydra
```

#### Verify

```bash
kubectl get pods -n hydra
kubectl get runtimeclass
```

**Note**: For persistent storage, set `configuration.local_node_image_dir` to a host path or PVC.

### Standalone k3s Installation

1. **Install k3s** (if not already installed):

   ```bash
   curl -sfL https://get.k3s.io | sh -
   ```

2. **Install Crismux**:

   ```bash
   cd src/add-crismux
   ./install_crismux.sh install
   ```

3. **Start isolated VM**:

   ```bash
   cd src/isolated-vm
   sudo ./start-vm.sh
   ```

4. **Create pods with nelly runtime class** (see Crismux Integration section)

## Platform-Specific Notes

### macOS

- **Virtualization**: Uses HVF (Hypervisor.framework) for acceleration
- **Krunkit**: Supported on macOS, with full support on M4 machines (SME and Vulkan)
- **Architecture**: Supports both Apple Silicon (ARM64) and Intel (x86_64)
- **BIOS**: Automatically detected from Homebrew QEMU installation

### Linux

- **Virtualization**: Uses KVM for hardware acceleration (if available)
- **Filesystem**: 9P mounts for `/var/lib/kubelet` and `/var/log/pods` (when run as root)
- **Networking**: Supports both user-mode and bridge networking
- **BIOS**: Paths vary by distribution; defaults provided for common setups

## **Architecture Deep Dive**

### Host Environment

The host environment runs:

- **k3s**: Lightweight Kubernetes distribution
- **Kubelet**: Kubernetes node agent
- **Crismux**: Multi-containerd runtime manager
- **Containerd (host)**: Primary container runtime


Containers scheduled with the "nelly" runtime class are routed to the isolated environment.

### Isolated Environment

The isolated environment provides:

- **Containerd (isolated)**: Independent container runtime
- **csi-grpc-proxy**: Converts TCP to Unix socket for Kubernetes integration
- **Network Isolation**: Separate network namespace
- **Resource Isolation**: Dedicated CPU, memory, and disk

### Communication Flow

```
Kubelet (Host)
    │(via Unix socket)
    │
    ▼
Crismux ───────────────────────────┐
    │(via TCP:localhost:35000)     │(via Unix socket)
    │                              ▼
    │                          Containerd
    ▼                              │
csi-grpc-proxy                     ▼
    │(via Unix socket)    Local Container Execution
    │
    ▼
Containerd (Isolated VM)
    │
    ▼
Isolated Container Execution
```

## Troubleshooting

### VM Won't Start

- **Check QEMU installation**: `which qemu-system-aarch64` (or `qemu-system-x86_64`)
- **Verify permissions**: May need `sudo` on Linux for KVM access
- **Check disk space**: Ensure sufficient space for images
- **Review logs**: Run with `DEBUG=1` for detailed output

### Network Issues

- **Port conflicts**: Check if ports 5555, 35000, 35001 are in use
- **Firewall rules**: Ensure firewall allows port forwarding
- **VM networking**: Verify network configuration in cloud-init

### Containerd Connection Issues

- **Proxy not running**: Ensure csi-grpc-proxy is active
- **Wrong endpoint**: Verify `PROXY_TO` points to correct port
- **VM not ready**: Wait for VM to fully boot and containerd to start

### Image Download Failures

- **Network connectivity**: Verify internet access
- **Disk space**: Ensure enough space for image download
- **URL access**: Check if image source URL is accessible

## Contributing

Contributions welcome! Areas for contribution:

- Platform support improvements
- Documentation enhancements
- Performance optimizations
- Security hardening
- Additional virtualization backends

## License

Part of the Smarter Project. See repository for license details.

## Related Projects

- **Crismux**: Multi-containerd runtime manager
- **csi-grpc-proxy**: Container runtime interface proxy
- **RIMDworkspace**: Isolated runtime environment

## Resources

- [Main Documentation](https://github.com/smarter-project/documentation)
- [Artifact Hub](https://artifacthub.io/packages/search?repo=hydra)
- [Multi-VM Documentation](src/multi-vm/README.md)
- [Kubernetes crictl Guide](https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/)

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing documentation
- Review troubleshooting section

---

**Hydra**: Many heads, unified purpose. Isolated execution environments for the modern containerized world.
