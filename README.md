# Part of Smart-home security demo using AI - LLMs

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/hydra)](https://artifacthub.io/packages/search?repo=hydra)

Hydra allows emulatoion of IoT devices that provides one or two isolated enviroments, both running linux. Each enviroment runs in a seperate VM providing independent resource anf configuration management.
Each enviroment is expected to run containers. The emulated "host" enviroment runs a debian cloud image where k3s, crismux and containerd are installed and configured. 
The "isolated" enciroment runs either a debian cloud image with containerd, or a rimdworkspace image. The "isolated" enviroment is designed to be managed by a "host" enviroment.  
The "isolated" enviroment runs a proxy enabling TCP access to containerd (csi-grpc-proxy). Even though the "host and isolated environment are configured to work together, they can be started and used seepratedly, any.

Hydra is composed by two separate modules: isolated-vm and add-crismux. Isolated-vm starts a VM with desired properties. Isolated-vm can be used as stand-alone by directly running start-vm.sh script or using auxiliary scripts that configures start-vm.sh for a specific use, as docker container or run using a helm chart. 
The second module install crismux in a k3s/k8s installation. It also installs a "nelly" runtime class. This runtime class will direct kubelet to use the isolated VM to run the container instead of running it on the host.

Isolated-vm VM utilizes KVM or HVF acceleration if available. 
The scripts run under MacOS, Linux, docker and k3s. 

# Requirements

## MacOS
    - Homebrew (strongly suggested)
    - Virtualization engine (either or both)
        * KVM
            - brew install qemu
        * krunkit
            - brew install podman
            - brew install krunkit
    - wget
    		- brew install qemu
    
    - for testing 
    		- cri-tools
    			- brew install cri-tools)
    
## Linux 
    - KVM
    - wget
    - mkisofs

## Docker
    - docker installed on the host

## K3s
    - running installation of K3s (can be installed using k3sup)
    - helm

# Usage


The start-vm.sh script had the following environment vaiables that configures what and how the VM will run.


THe following variables configures the script:

| Variable | Usage | Default value |
| -------- | ----- | ------------- |
| `DRY_RUN_ONLY` | If > 0 will print the command line for the VM and exit | 0 |
| `DEBUG` | If > 0 will print debug for the script | 0 |
| `DISABLE_9P_KUBELET_MOUNTS` | If > 0 do not enable mounting of /var/lib/kubelet and /var/lib/pods | 0 |
| `ADDITIONAL_9P_MOUNTS` | additional mounts format `<host dir>|<vm mount dir>[$<host dir>|<vm mount dir>]` |  |
| `COPY_IMAGE_BACKUP` | if > 0 preserve a copy of the image and start form a copy of that image if it exists | 0 |
| `ALWAYS_REUSE_DISK_IMAGE` | if > 0 reuse existing disk image even if configuration has changed | 0 |
| `DEFAULT_KERNEL_VERSION` | kernel version to install | `6.12.12+bpo` |
| `KERNEL_VERSION` | full version to install if a different kernel is required | `linux-image-${DEFAULT_KERNEL_VERSION}-${ARCH}` |
| `ENABLE_VSOCK_LINUX` | Enable VSOCK for linux if > 0 | 0 |
| `DEFAULT_DIR_IMAGE` | Where to store the downloaded image | `$(pwd)/image` |
| `DEFAULT_DIR_K3S_VAR_DARWIN` | Where to point the 9p mounts if running on MacOS | `$(pwd)/k3s-var` |
| `DEFAULT_DIR_K3S_VAR_LINUX_NON_ROOT` | Where to point the 9p mounts if running on Linux as a non-root user | `$(pwd)/k3s-var` |
| `DEFAULT_DIR_K3S_VAR_LINUX_ROOT` | Where to point the 9p mounts if running on linux machine as root (or inside a container ) | |
| `DEFAULT_DIR_K3S_VAR_OTHER` | Where to point the 9p mounts if running on other OS machine | `$(pwd)/k3s-var` |
| `DEFAULT_IMAGE` | QCOW image to use as base | `debian-12-genericcloud-${ARCH}-20250316-2053.qcow2` |
| `DEFAULT_IMAGE_SOURCE_URL` | where to download QCOW image | `https://cloud.debian.org/images/cloud/bookworm/20250316-2053/` |
| `DEFAULT_DIR_IMAGE` | Directory to use to store image and artifacts | `$(pwd)/image` |
| `DEFAULT_KVM_DARWIN_CPU` | # CPUS allocated to the VM when running in MacOS | 2 |
| `DEFAULT_KVM_DARWIN_MEMORY` | DRAM allocated to the VM to the VM when running in MacOS | 2 |
| `DEFAULT_KVM_LINUX_CPU` | # CPUS allocated to the VM when running in Linux/container | 2 |
| `DEFAULT_KVM_LINUX_MEMORY` | DRAM allocated to the VM to the VM when running in Linux/container | 2 | 
| `DEFAULT_KVM_UNKNOWN_CPU` | # CPUS allocated to the VM when running in unknown OS | 2 |
| `DEFAULT_KVM_UNKNOWN_MEMORY` | DRAM allocated to the VM to the VM when running in unknown OS | 2 | 
| `DEFAULT_KVM_DISK_SIZE` | Maximum size of QCOW disk | 3 |
| `DEFAULT_KVM_DARWIN_BIOS` | bios to boot (UEFI) when running under MacOS | `/opt/homebrew/Cellar/qemu/9.2.2/share/qemu/edk2-${ARCH}-code.fd` | 
| `DEFAULT_KVM_LINUX_v9_BIOS` | bios to boot (UEFI) when running under Linux/container with KVM v9x | |
| `DEFAULT_KVM_LINUX_v7_BIOS` | bios to boot (UEFI) when running under Linux/container with KVM v7x | `/usr/share/qemu-efi-aarch64/QEMU_EFI.fd` |
| `DEFAULT_KVM_LINUX_v7_BIOS`(aarch64) | bios to boot (UEFI) when running under Linux/container with KVM v7x | `/usr/share/AAVMF/AAVMF_CODE.fd` |
| `DEFAULT_KVM_LINUX_v7_BIOS`(amd64) | bios to boot (UEFI) when running under Linux/container with KVM v7x | `/usr/share/ovmf/OVMF.fd` |
| `DEFAULT_KVM_UNKNWON_BIOS` | bios to boot (UEFI) when running under unknown OS | |
| `DEFAULT_KVM_HOST_SSHD_PORT` | TCP port to be used on the host to access port 22 on VM | 5555 |
| `DEFAULT_KVM_HOST_CONTAINERD_PORT` | TCP port to be used on the host to access port 35000 (cs-grpc-proxy) on VM | 35000 |
| `DEFAULT_CSI_GRPC_PROXY_URL` | URL to get csi-grpc-proxy binary | `https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux- `|
| `KVM_CPU_TYPE` | CPU type | Use "host" if accelerated, otherise use "cortex-a76" or "qemu64-v1" |
| `KVM_CPU` | # cpus to allocate | `DEFAULT_KVM_<OS>_CPU`|
| `KVM_MEMORY` | DRAM to allocate | `DEFAULT_KVM_<OS>_MEMORY` |
| `KVM_BIOS` | BIOS to use | `DEFAULT_KVM_<OS>_BIOS` |
| `KVM_MACHINE_TYPE` | KVM machine type | use "virt" or "pc" |
| `VM_USERNAME` | Usename to created at VM | hailhydra |
| `VM_SALT` | Salt to be used when creating the encrypted password | 123456 |
| `VM_PASSWORD` | Cleartext password to be used | hailhydra |
| `VM_PASSWORD_ENCRYPTED` | Encrypted password to be used, overwrites the cleartext password | | 
| `VM_HOSTNAME` | Hostname | vm-host |
| `VM_SSH_AUTHORIZED_KEY` | ssh public key to add to authorized\_key for the user VM_USERNAME | |
| `VM_SSH_KEY_FILENAME` | Use this file to load the public key into authorized_key |  |
| `RUN_BARE_KERNEL` | if > 0 then Use kernel and initrd instead of cloud image | 0 | 
| `DEFAULT_KVM_PORTS_REDIRECT` | format is `<external>:<internal>[;<external>:<internal>]` |  |
| `DEFAULT_RIMD_ARTIFACT_URL` | where to download the artifacts (kernel + initrd) | https://gitlab.arm.com/api/v4/projects/576/jobs/146089/artifacts |
| `RIMD_ARTIFACT_URL_USER` | User to authenticate to get artifacts from URL |  | 
| `RIMD_ARTIFACT_URL_PASS` | Password to authenticate to get artifacts from URL |  |
| `RIMD_ARTIFACT_URL_TOKEN` | Token to authenticate to get artifacts from URL |   |
| `DEFAULT_RIMD_ARTIFACT_FILENAME` | Filename to use when storing the downloaded file | artifacts.zip |
| `DEFAULT_RIMD_KERNEL_FILENAME` | Filename that contains the kernel to run | `final_artifact/Image.gz` |
| `DEFAULT_RIMD_IMAGE_FILENAME` | Filename that contains the initrd to run | `final_artifact/initramfs.linux_arm64.cpio` |
| `DEFAULT_RIMD_FILESYSTEM_FILENAME` | Filename that contains the read/write filesystem for the VM | `final_artifact/something.qcow2` |
| `ADDITIONAL_KERNEL_COMMANDLINE` | When running a bare kernel add this to kernel command line |  |
| `DISABLE_CONTAINERD_CSI_PROXY` | Disable installation of containerd and csi proxy | 0 |
| `ENABLE_K3S_DIOD` |  Enable installation of k3s and diod on VM | 0 |
| `ENABLE_VIRTIO_GPU` | Enable Vulkan acceleration on VM (not ready yet) | 0 |
| `DEFAULT_VIRTIO_GPU_VRAM` | How much ram to enable for GPU | 4 |
| `ADDITIONAL_9P_MOUNTS` | Add this additional 9P mounts to VM |  |
| `EXTERNAL_9P_KUBELET_MOUNTS` | Use tcp transport instead of local transport for 9P mounts | 0 |
| `DEFAULT_KVM_HOST_DIOD_PORT` | Host port to use for access of DioD on the VM | 30564 |
| `DEFAULT_KVM_HOST_CONTAINERD_PORT` | Host port to use for access of containerd on the VM | 35000 |
| `DEFAULT_KVM_HOST_RIMD_PORT` | Host port to use for RIMD server on the VM | 35001 |
| `DEFAULT_CSI_GRPC_PROXY_URL` | Where to get csi-grpc-proxy | `https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux-` |
| `K3S_VERSION_INSTALL` | Version of K3s to install | `v1.32.6+k3s1` |
| `ENABLE_KRUNKIT` | Use krunkit instead of KVM | 0 |
| `KRUNKIT_HTTP_PORT` | Port of HTTP interface of krunkit | 61800 |
| `GVPROXY_HTTP_PORT` | Port of HTTP interface of gvproxy | 61801 |
| `DEFAULT_DIR_TMP_SOCKET` | Directory to use for sockets (path < 100 bytes) | `/tmp/image-$$` |
| `DEFAULT_NETWORK_PREFIX` | Network prefix used for VM interface | 10.0.2 |
| `DEFAULT_DEVICE_IP` | IP used on the VM interface | `${DEFAULT_NETWORK_PREFIX}.15` |
| `DEFAULT_GATEWAY_IP` | IP use for the gateway | `${DEFAULT_NETWORK_PREFIX}.2` |
| `DEFAULT_DNS_IP` | IP used for DNS (inside VM) | `${DEFAULT_NETWORK_PREFIX}.3` |

The directory `<DEFAULT_DIR_IMAGE>` will be use to store all the files created or downloaded. Files downloaded will be cached locally and only redownloaded if a new epty version of that file is required.
SSH will be availabe at port 5555 (if the envviroment variable is not changed). and Containerd CRI will be available at port 35000. 
A csi-proxy or crismux running on the host can be used to convert that port to a socket if required.

The image will be resized automatically according to the sizes provided. The image will not be reduced in size.

The VM will use acceleration if available.

The following scripts are provided so specific enviroments can be easily run.

"run-host.sh" uses QEMU and run a host enviroment with k3s/crismux and containerd.
"run-isolated.sh" uses QEMU and run an isolated enviroment using debian.
"run-isolated-bare.sh" uses QEMU and run an isolated enviroment from rimdworkspacve
"run-isolated-krunkit-krun.sh' uses krunkit and gvproxy to run an isolated environment using debian
"run-isolated-krunkit-krun-bare.sh"  used krunkit and gvproxy to run an isolated environment using rimdworspace.

Any host can be connected with any isolated environment. More than one host or more than one isolated environemt is not supported.

## MacOSo

Krunkit is only supported on MacOS. On a M4 machine both SME and vulkan are supported as acceleration.  

### Crismux

## Linux

clone the repository
```
git clone https://github.com/smarter-project/hydra
```

### Isolated-vm

#### TL;DR

The terminal will output VM console messages and the last message should be a login prompt. When running the script directly this will be printed in the current terminal that the script is running. Use `VM_USERNAME`, `VM_PASSWORD` to login. Ssh and csi-grpc-proxy interfaces are available through the network.

Two options to exit the VM after it has been started.

+ stop the hypervisor by typing "control-a" and "c" and at the hypervisor prompt, type "quit"
+ login to the VM using the `VM_USERNAME`, `VM_PASSWORD` and execute "`sudo shutdown -h 0"

Run the script start-vm.sh to create the VM using debian cloud image
```
cd hydra/src/isolated-vm
./start-vm.sh
```

It will start a VM using local directory image. If run as root (linux) it will also try to share the directories `/var/lib/kubelet` and `/var/log/pods`.

Run the script start-vm.sh to create the VM using the kernel/initrd instead of cloud image
```
cd hydra/src/isolated-vm
RUN_BARE_KERNEL=1 RIMD_ARTIFACT_URL_TOKEN=<access token> ./start-vm.sh

## MacOS

clone the repository
```
git clone https://github.com/smarter-project/hydra
```

### Isolated-vm

#### TL;DR

The terminal will output VM console messages and the last message should be a login prompt. When running the script directly this will be printed in the current terminal that the script is running. Use `VM_USERNAME`, `VM_PASSWORD` to login. Ssh and csi-grpc-proxy interfaces are available through the network.

Two options to exit the VM after it has been started.

+ stop the hypervisor by typing "control-a" and "c" and at the hypervisor prompt, type "quit"
+ login to the VM using the `VM_USERNAME`, `VM_PASSWORD` and execute "`sudo shutdown -h 0"

Run the script start-vm.sh to create the VM using debian cloud image
```
cd hydra/src/isolated-vm
./start-vm.sh
```

It will start a VM using local directory image. If run as root (linux) it will also try to share the directories `/var/lib/kubelet` and `/var/log/pods`.

Run the script start-vm.sh to create the VM using the kernel/initrd instead of cloud image
```
cd hydra/src/isolated-vm
RUN_BARE_KERNEL=1 RIMD_ARTIFACT_URL_TOKEN=<access token> ./start-vm.sh

#### Testing

Use csi-grpc-proxy running on the host to convert from a tcp port to an unix socket 
```
wget https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-darwin-arm64
chmod u+x csi-grpc-proxy-v0.5.6-darwin-arm64
BIND_TO=unix:///tmp/socket-csi PROXY_TO=tcp://127.0.0.1:35000 ./csi-grpc-proxy-v0.5.6-darwin-arm64 &
```

Now you can run crictl to send commands to containerd running on the isolated enviroment.  Start/stop/list containers, download/remove images, etc.
This webpage has examples of how to use crictl `https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/`
```
crictl --runtime-endpoint unix:///tmp/socket-csi ps
```

### Crismux (needed if using kubernetes)

Run the script install_crismux.sh to enable crismux
```
cd hydra/src/add-crismux
./install_crismux.sh install
```

## Helm (install both crismux and isolated-vm charts)

```
helm repo add hydra https://smarter-project.github.io/hydra/
helm install \
     --set "isolated-vm.configuration.sshkey=<public ssh key to use>" \
     <local name> hydra/hydra
```
isolated-vm.configuration.sshkey allows ssh login to VM

add
```
--set "configuration.local_node_image_dir="
```
to store images at the container and not on the node, because the container filesystem is not persistent, all files will be lost if the container is stopped. 


## Docker

### Isolated-vm

#### TL;DR

Change `$(pwd)/image` to another directory if that is not appropriate. and `i$(ls ${HOME}/.ssh/*\..pub | head -n 1 | xrgs cat 2>/dev/null)` to the appropriate key to be used (this scirpt will select the first key available)..

```
docker run \
    -d \
    --rm \
    --network host \
    --env "VM_SSH_AUTHORIZED_KEY=$(ls ${HOME}/.ssh/*\.pub 2?dev/null | head -n 1 | xargs cat 2>/dev/null)" \
    -v $(pwd)/image:/root/image \
    -v /var/lib/kubelet:/var/lib/kubelet \
    -v /var/log/pods:/var/log/pods \
    --device /dev/kvm:/dev/kvm \
    ghcr.io/smarter-project/hydra/isolated-vm:main
```

This command will run the container without logs. use the following command to observe the logs
```
docker logs -f <container ID> 
```

and this one to have a shell into the container. but preferably use ssh 

```
docker exec -it <container ID> /bin/bash
```

```
ssh -p <DEFAULT_KVM_HOST_SSHD_PORT> <VM_USERNAME>@localhost
```

#### Details
