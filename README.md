# Part of Smart-home security demo using AI - LLMs

This module starts a VM running debian 12 with containerd and enables access to it with TCP connection.
It runs the VM using KVM or HVF acceleration  if possible. 
The script runs under MacOS, Linux, docker and k3s. 

# Requirements

## Linux 
    - KVM
    - wget

## MacOS
    - Homebrew (strongly suggested)
    - KVM
    - wget
    
## Docker
    - docker installed on the host

## K3s
    - running installation of K3s (can be installed using k3sup
    - helm

# Motivation

# Usage

## Helm

```
helm repo add hydra https://smarter-project.github.io/hydra/
helm install \
     --set "isolated-vm.configuration.sshkey=<public ssh key to use>" \
     <local name> hydra/hydra
```
isolated-vm.configuration.sshkey allows ssh login to VM

## Docker

### TL;DR
```
docker run \
    -d \
    --rm \
    --network host \
    --env "VM_SSH_AUTHORIZED_KEY=\"$(cat <file with SSH public key>)\"" \
    -v <local image directory>:/root/image \
    -v /var/lib/kubelet:/var/lib/kubelet \
    -v /var/log/pods:/var/log/pods \
    --device /dev/kvm:/dev/kvm \
    isolated-vm
```

Update `<file with SSH public key>` and `<local image directory>` with the correct files. `<local image directory>` has to have a full path.

### Details

The directory "image" located on the directory `<local image directory>`. The image will be downloaded and configured once and new runs will reuse the umage (much faster startup).
A few variables of list below (user configuration, shared directories for example) will re-download the image. 
SSH will be availabe at port 5555 and Containerd CRI will be available at port 35000. 
A csi-proxy or crismux running on the host can be used to convert that port to a socket if required.

The image will be resized automatically according to the sizes provided. The image will not be reduced in size.

The VM will use acceleration if available.

THe following variables configures the script:

| Variable | Default value | Usage |
| -------- | ------------- | ----- |
| `DRY_RUN_ONLY` | 0 | If > 0 will print the command line for the VM and exit |
| `DEBUG` | 0 | If > 0 will print debug for the script |
| `DISABLE_9P_MOUNTS` | 0 | If > 0 do not enable mounting of /var/lib/kubelet and /var/lib/pods |
| `COPY_IMAGE_BACKUP` | 0 | if > 0 preserve a copy of the image and start form a copy of that image if it exists |
| `DEFAULT_KERNEL_VERSION` | `6.12.12+bpo | kernel version to install |
| `KERNEL_VERSION` | `linux-image-${DEFAULT_KERNEL_VERSION}-${ARCH}` | full version to install if a different kernel is required |
| `DEFAULT_DIR_IMAGE` | `$(pwd)/image` | Where to store the downloaded image |
| `DEFAULT_DIR_K3S_VAR_DARWIN` | `$(pwd)/k3s-var` | Where to point the 9p mounts if running on MacOS |
| `DEFAULT_DIR_K3S_VAR_LINUX_NON_ROOT` | `$(pwd)/k3s-var` | Where to point the 9p mounts if running on Linux as a non-root user |
| `DEFAULT_DIR_K3S_VAR_LINUX_ROOT` | | Where to point the 9p mounts if running on linux machine as root (or inside a container ) |
| `DEFAULT_DIR_K3S_VAR_OTHER` | `$(pwd)/k3s-var` | Where to point the 9p mounts if running on other OS machine |
| `DEFAULT_IMAGE` | `debian-12-genericcloud-${ARCH}-20250316-2053.qcow2` | QCOW image to use as base |
| `DEFAULT_SOURCE_IMAGE` | `https://cloud.debian.org/images/cloud/bookworm/20250316-2053/` | where to download QCOW image |
| `DEFAULT_DIR_IMAGE` | `$(pwd)/image` | Directory to use to store image and artifacts |
| `DEFAULT_KVM_DARWIN_CPU` | 2 | # CPUS allocated to the VM when running in MacOS |
| `DEFAULT_KVM_DARWIN_MEMORY` | 2 | DRAM allocated to the VM to the VM when running in MacOS |
| `DEFAULT_KVM_LINUX_CPU` | 2 | # CPUS allocated to the VM when running in Linux/container |
| `DEFAULT_KVM_LINUX_MEMORY` | 2 | DRAM allocated to the VM to the VM when running in Linux/container | 
| `DEFAULT_KVM_UNKNOWN_CPU` | 2 | # CPUS allocated to the VM when running in unknown OS |
| `DEFAULT_KVM_UNKNOWN_MEMORY` | 2 | DRAM allocated to the VM to the VM when running in unknown OS | 
| `DEFAULT_KVM_DISK_SIZE` | 3 | Maximum size of QCOW disk |
| `DEFAULT_KVM_DARWIN_BIOS` | `/opt/homebrew/Cellar/qemu/9.2.2/share/qemu/edk2-${ARCH}-code.fd` | bios to boot (UEFI) when running under MacOS | 
| `DEFAULT_KVM_LINUX_v9_BIOS` | | bios to boot (UEFI) when running under Linux/container with KVM v9x |
| `DEFAULT_KVM_LINUX_v7_BIOS` | `/usr/share/qemu-efi-aarch64/QEMU_EFI.fd` | bios to boot (UEFI) when running under Linux/container with KVM v7x |
| `DEFAULT_KVM_UNKNWON_BIOS` | | bios to boot (UEFI) when running under unknown OS |
| `DEFAULT_KVM_HOST_SSHD_PORT` | 5555 | TCP port to be used on the host to access port 22 on VM |
| `DEFAULT_KVM_HOST_CONTAINERD_PORT` | 35000 | TCP port to be used on the host to access port 35000 (cs-grpc-proxy) on VM |
| `DEFAULT_CSI_GRPC_PROXY_URL` | `https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux- `| get csi-grpc-proxy binary |
| `KVM_CPU_TYPE` | Use "host" if accelerated, otherise use "cortex-a76" or "qemu64-v1" | CPU type |
| `KVM_CPU` | `DEFAULT_KVM_<OS>_CPU` | # cpus to allocate |
| `KVM_MEMORY` | `DEFAULT_KVM_<OS>_MEMORY` | DRAM to allocate |
| `KVM_BIOS` | `DEFAULT_KVM_<OS>_BIOS` | BIOS to use |
| `KVM_MACHINE_TYPE` | use "virt" or ""pc" | KVM machine type |
| `VM_USERNAME` | vm-user | Usename to created at VM |
| `VM_SALT` | 123456 | Salt to be used when creating the encrypted password |
| `VM_PASSWORD` | vm-user | Cleartext password to be used |
| `VM_PASSWORD_ENCRYPTED` | | Encrypted password to be used, overwrites the cleartext password | 
| `VM_HOSTNAME` | vm-host | Hostname |
| `VM_SSH_AUTHORIZED_KEY` | | ssh public key to add to authorized_key for the user VM_USERNAME |

## Linux and MacOS

### TL;DR
clone the repository and run the script
```
git clone https://github.com/smarter-project/hydra
cd hydra
./start-vm.sh
```

It will start a VM using local directory image. If run as root (linux) it will also try to share the directories `/var/lib/kubelet` and `/var/log/pods`.

