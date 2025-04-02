# Part of Smart-home security demo using AI - LLMs

This module starts a VM running debian 12 with containerd and enables access to it with TCP connection.
It runs the VM using QEMU and acceleration if possible. 
The script runs under MacOS, Linux, docker and k3s. 

# Requirements

## Linux and MacOS
    - QEMU

## Docker
    - docker installed on the host

## K3s
    - running installation of K3s

# Motivation

# Usage

## Linux and MacOS

### TL;DR
clone the repository and run the script
```
git clone https://github.com/smarter-project/hydra
cd hydra
./start-vm.sh
```

### Details

The directory "image" located on the directory that start-vm.sh was run will be used to store the image for the VM. The image will be downloaded and configured once and new runs will reuse the umage (much faster startup).
Removing the directory or the qcow2 file inside the image directory will download and configured.
Containerd CRI will be available at localhost port 35000.
A csi-proxy or crismux running on the host can be used to convert that port to a socket if required.

The image will be resized automatically according to the sizes provided. The image will not be reduced in size.

The QEMU will use acceleration if available.

THe following variables configures the script:

| Variable | Default value | Usage |
| -------- | ------------- | ----- |
| `DEFAULT_IMAGE` | `debian-12-genericcloud-${ARCH}-20250316-2053.qcow2` | QCOW image to use as base |
| `DEFAULT_SOURCE_IMAGE` | `https://cloud.debian.org/images/cloud/bookworm/20250316-2053/` | where to download QCOW image |
| `DEFAULT_DIR_IMAGE` | `$(pwd)/image` | Directory to use to store image and artifacts |
| `DEFAULT_QEMU_DARWIN_CPU` | 2 | # CPUS allocated to the VM when running in MacOS |
| `DEFAULT_QEMU_DARWIN_MEMORY` | 2 | DRAM allocated to the VM to the VM when running in MacOS |
| `DEFAULT_QEMU_LINUX_CPU` | 2 | # CPUS allocated to the VM when running in Linux/container |
| `DEFAULT_QEMU_LINUX_MEMORY` | 2 | DRAM allocated to the VM to the VM when running in Linux/container | 
| `DEFAULT_QEMU_UNKNOWN_CPU` | 2 | # CPUS allocated to the VM when running in unknown OS |
| `DEFAULT_QEMU_UNKNOWN_MEMORY` | 2 | DRAM allocated to the VM to the VM when running in unknown OS | 
| `DEFAULT_QEMU_DISK_SIZE` | 3 | Maximum size of QCOW disk |
| `DEFAULT_QEMU_DARWIN_BIOS` | `/opt/homebrew/Cellar/qemu/9.2.2/share/qemu/edk2-${ARCH}-code.fd` | bios to boot (UEFI) when running under MacOS | 
| `DEFAULT_QEMU_LINUX_v9_BIOS` | | bios to boot (UEFI) when running under Linux/container with QEMU v9x |
| `DEFAULT_QEMU_LINUX_v7_BIOS` | `/usr/share/qemu-efi-aarch64/QEMU_EFI.fd` | bios to boot (UEFI) when running under Linux/container with QEMU v7x |
| `DEFAULT_QEMU_UNKNWON_BIOS` | | bios to boot (UEFI) when running under unknown OS |
| `DEFAULT_QEMU_HOST_SSHD_PORT` | 5555 | TCP port to be used on the host to access port 22 on VM |
| `DEFAULT_QEMU_HOST_CONTAINERD_PORT` | 35000 | TCP port to be used on the host to access port 35000 (cs-grpc-proxy) on VM |
| `DEFAULT_CSI_GRPC_PROXY_URL` | `https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux- `| get csi-grpc-proxy binary |
| `QEMU_CPU_TYPE` | Use "host" if accelerated, otherise use "cortex-a76" or "qemu64-v1" | CPU type of QEMU |
| `QEMU_CPU` | `DEFAULT_QEMU_<OS>_CPU` | # cpus to allocate |
| `QEMU_MEMORY` | `DEFAULT_QEMU_<OS>_MEMORY` | DRAM to allocate |
| `QEMU_BIOS` | `DEFAULT_QEMU_<OS>_BIOS` | BIOS to use |
| `QEMU_MACHINE_TYPE` | use "virt" or ""pc" | QEMU machine type |

## Docker

### TL;DR
```
docker run grhc.io/smarter-project/hydra 
```

with accelleration

```
docker run --device /dev/kvm:/dev/kvm grhc.io/smarter-project/hydra 
```

### Details

If the image directory is not a shared directory with the host, the VM state will not be preserved in multiple runs
use:
```
docker run -v image:/root/image --device /dev/kvm:/dev/kvm grhc.io/smarter-project/hydra
```
to preserve VM image.


Containerd will be available at the IP of the containerd port 35000
