#!/usr/bin/env bash

HW_ACCEL=""
REDIRECT_PORT=""
OS=$(uname -o)
ARCH_M=$(uname -m)
case ${ARCH_M} in
	x86_64)
		ARCH=amd64;;
	arm64|aarch64)
		ARCH=arm64
		ARCH_M=aarch64;;
	*)
		ARCH=${ARCH_M};;
esac
: ${DISABLE_9P_MOUNTS:=0}
: ${COPY_IMAGE_BACKUP:=0}
: ${DEFAULT_IMAGE:="debian-12-genericcloud-${ARCH}-20250316-2053.qcow2"}
: ${DEFAULT_KERNEL_VERSION:="6.12.12+bpo"}
: ${KERNEL_VERSION:="linux-image-${DEFAULT_KERNEL_VERSION}-${ARCH}"}
: ${DEFAULT_DIR_IMAGE:=$(pwd)/image}
: ${DEFAULT_DIR_K3S_VAR_DARWIN:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_NON_ROOT:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_ROOT:=""}
: ${DEFAULT_DIR_K3S_VAR_OTHER:=$(pwd)/k3s-var}
: ${DEFAULT_SOURCE_IMAGE:="https://cloud.debian.org/images/cloud/bookworm/20250316-2053/"}
: ${DEFAULT_QEMU_DARWIN_CPU:=2}
: ${DEFAULT_QEMU_DARWIN_MEMORY:=2}
: ${DEFAULT_QEMU_LINUX_CPU:=2}
: ${DEFAULT_QEMU_LINUX_MEMORY:=2}
: ${DEFAULT_QEMU_UNKNOWN_CPU:=2}
: ${DEFAULT_QEMU_UNKNOWN_MEMORY:=2}
: ${DEFAULT_QEMU_DISK_SIZE:=3}
: ${DEFAULT_QEMU_DARWIN_BIOS:="/opt/homebrew/Cellar/qemu/9.2.2/share/qemu/edk2-${ARCH_M}-code.fd"}
: ${DEFAULT_QEMU_LINUX_v9_BIOS:=""}
: ${DEFAULT_QEMU_LINUX_v7_BIOS:="/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"}
#: ${DEFAULT_QEMU_LINUX_BIOS:="/usr/share/qemu/edk2-${ARCH_M}-code.fd"}
: ${DEFAULT_QEMU_UNKNWON_BIOS:=""}
# If these values are empty, the ports will not be redirected.
: ${DEFAULT_QEMU_HOST_SSHD_PORT:="5555"}
: ${DEFAULT_QEMU_HOST_CONTAINERD_PORT:="35000"}
: ${DEFAULT_CSI_GRPC_PROXY_URL:="https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux-"}

IMAGE_DOWNLOADED=0

function check_requirements() {
	QEMU_EXECUTABLE=$(type qemu-system-${ARCH_M} 2>/dev/null)
	if [ -z "${QEMU_EXECUTABLE}" ]
	then
		echo "QEMU not available , please install qemu-system"
		exit 1
	fi
	MKISOFS_EXECUTABLE=$(type mkisofs 2>/dev/null)
	if [ -z "${MKISOFS_EXECUTABLE}" ]
	then
		echo "mkisofs not available , please install mkisofs"
		exit 1
	fi
}

function check_qemu_kvm_hvf() {

	if [ "${OS}" == "GNU/Linux" ]
	then
		# checking if KVM is available
		if [ -c /dev/kvm -a -r /dev/kvm -a -w /dev/kvm ]
		then
			echo "KVM available"
			HW_ACCEL="-accel kvm"
			: ${QEMU_CPU_TYPE:="host"}
		else
			echo "KVM not available, running without acceleration"
			case ${ARCH_M} in
				x86_64|amd64)
					: ${QEMU_CPU_TYPE:="qemu64-v1"};;
				arm64|aarch64)
					: ${QEMU_CPU_TYPE:="cortex-a76"};;
				*)
					: ${QEMU_CPU_TYPE:="qemu64-v1"};;
			esac
		fi
	elif [ "${OS}" == "Darwin" ]
	then
		# checking if HVF is available
		RES=$(sysctl kern.hv_support)
		if [ $? -eq 0 -a "${RES}" == "kern.hv_support: 1" ]
		then
			echo "HVF available"
			HW_ACCEL="-accel hvf"
			: ${QEMU_CPU_TYPE:="host"}
		else
			echo "HVF not available, running without acceleration"
			: ${QEMU_CPU_TYPE:="cortex-a76"}
		fi
	else
		echo "Unknownn OS '${OS}', running without acceleration"
		case ${ARCH_M} in
			x86_64|amd64)
				: ${QEMU_CPU_TYPE:="qemu64-v1"};;
			arm64|aarch64)
				: ${QEMU_CPU_TYPE:="cortex-a76"};;
			*)
				: ${QEMU_CPU_TYPE:="qemu64-v1"};;
		esac
	fi
}

function check_image_exists() {
	[ ${COPY_IMAGE_BACKUP} -gt 0 -a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp ] && cp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}"
	if [  ! -d "${DEFAULT_DIR_IMAGE}" ]
	then
		echo "Image directory '${DEFAULT_DIR_IMAGE}' does not exist, trying to create"
		mkdir -p "${DEFAULT_DIR_IMAGE}"
		if [ $? -ne 0 ]
		then
			echo "Image directory '${DEFAULT_DIR_IMAGE}' could not be created, bailing out"
			exit 1
		fi
	else
		echo "Image directory '${DEFAULT_DIR_IMAGE}' exists"
	fi

	if [ -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" ]
	then
		echo "Image ${DEFAULT_IMAGE} exists on disk, reusing"
	else
		echo "Download image from ${DEFAULT_SOURCE_IMAGE}"
		wget -O "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" "${DEFAULT_SOURCE_IMAGE}/${DEFAULT_IMAGE}" 
		if [ $? -ne 0 ]
		then
			echo "Download unsucceful, bailing out"
			exit 1
		fi
		IMAGE_DOWNLOADED=1
		[ ${COPY_IMAGE_BACKUP} -gt 0 ] && cp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp
	fi
}

function check_qemu_memory_cpu() {
	# check qemu version and if is available
	#
	QEMU_OUTPUT=$(qemu-system-${ARCH_M} --version)
	if [ $? -ne 0 ]
	then
		echo "Error getting version from QEMU"
		exit 1
	fi
	QEMU_VERSION=$(echo "${QEMU_OUTPUT}" | grep "QEMU emulator version" | cut -d " " -f 4)
	if [ -z "${QEMU_VERSION}" ]
	then
		echo "Could not determine version of qemu, got this ${QEMU_VERSION} from qemu-system-${ARCH_M} --versio output '${QEMU_OUTPUT}'"
		exit 1
	fi
	if [[ ! "${QEMU_VERSION}" =~ ^[0-9][0-9.]*[0-9]$ ]]
	then
		echo "Non numeric version of qemu, got this ${QEMU_VERSION} from 'qemu-system-${ARCH_M} --version' output '${QEMU_OUTPUT}'"
		exit 1
	fi

	echo "Using QEMU version ${QEMU_VERSION}"

	if [ "${OS}" == "GNU/Linux" ]
	then
		: ${QEMU_CPU:=${DEFAULT_QEMU_LINUX_CPU}}
		: ${QEMU_MEMORY:=${DEFAULT_QEMU_LINUX_MEMORY}}
		QEMU_MAJOR=$(echo "${QEMU_VERSION}" | cut -d "." -f 1)
		if [ ${QEMU_MAJOR} -ge 9 ]
		then
			: ${QEMU_BIOS:=${DEFAULT_QEMU_LINUX_v9_BIOS}}
		else
			: ${QEMU_BIOS:=${DEFAULT_QEMU_LINUX_v7_BIOS}}
		fi
				
		case ${ARCH_M} in
			x86_64|amd64)
				: ${QEMU_MACHINE_TYPE:="pc"};;
			arm64|aarch64)
				: ${QEMU_MACHINE_TYPE:="virt"};;
			*)
				: ${QEMU_MACHINE_TYPE:="pc"};;
		esac
		echo "Using linux QEMU machine ${QEMU_MACHINE_TYPE},${QEMU_CPU} CPUs, ${QEMU_MEMORY}G and bios ${QEMU_BIOS}"
		return
	elif [ "${OS}" == "Darwin" ]
	then
		: ${QEMU_CPU:=${DEFAULT_QEMU_DARWIN_CPU}}
		: ${QEMU_MEMORY:=${DEFAULT_QEMU_DARWIN_MEMORY}}
		: ${QEMU_BIOS:=${DEFAULT_QEMU_DARWIN_BIOS}}
		: ${QEMU_MACHINE_TYPE:="virt"}
		echo "Using Darwin QEMU machine ${QEMU_MACHINE_TYPE} with ${QEMU_CPU} CPUs and ${QEMU_MEMORY}G"
		return
	else
		: ${QEMU_CPU:=${DEFAULT_QEMU_UNKNOWN_CPU}}
		: ${QEMU_MEMORY:=${DEFAULT_QEMU_UNKNOWN_MEMORY}}
		: ${QEMU_BIOS:=${DEFAULT_QEMU_UNKNOWN_BIOS}}
		case ${ARCH_M} in
			x86_64|amd64)
				: ${QEMU_MACHINE_TYPE:="pc"};;
			arm64|aarch64)
				: ${QEMU_MACHINE_TYPE:="virt"};;
			*)
				: ${QEMU_MACHINE_TYPE:="pc"};;
		esac
		echo "Using unknown OS QEMU machine ${QEMU_MACHINE_TYPE} with ${QEMU_CPU} CPUs and ${QEMU_MEMORY}G"
		return
	fi
}

function resize_qemu_image() {
	QEMU_IMG_RES=$(qemu-img info "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" 2>&1)
	if [ $? -ne 0 ]
	then
		echo "qemu-img return $? and '${QEMU_IMG_RES}'"
		exit 1
	fi
	CURR_IMG_SIZE=$(echo "${QEMU_IMG_RES}" | grep '^virtual size' | sed -e "s/^.*(//" -e "s/ .*//")
	CURR_IMG_SIZE=$((${CURR_IMG_SIZE}/1024/1024/1024))
	if [ ${CURR_IMG_SIZE} -lt ${DEFAULT_QEMU_DISK_SIZE} ]
	then
		echo "Resizing image to ${DEFAULT_QEMU_DISK_SIZE}g"
		#qemu-img resize "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" ${DEFAULT_QEMU_DISK_SIZE}g
		if [ $? -ne 0 ]
		then
			echo "qemu-img resize return $?"
			exit 1
		fi
	else
		echo "Image size (${CURR_IMG_SIZE}G) equal or larger than required(${DEFAULT_QEMU_DISK_SIZE}G)"
	fi
}

function check_cloud_init_create() {
	if (( ${IMAGE_DOWNLOADED} ))
	then
		rm -rf "${DEFAULT_DIR_IMAGE}/cloud-init.iso" "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
	fi	
	if [ ! -f "${DEFAULT_DIR_IMAGE}/cloud-init.iso" ]
	then
		echo "cloud-init.iso does not exist, creating"
		if [ -d "${DEFAULT_DIR_IMAGE}/cloud-init.dir" ]
		then
			rm -rf "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
		fi
		mkdir "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
		cat > "${DEFAULT_DIR_IMAGE}/cloud-init.dir/meta-data" <<EOF
EOF
		cat > "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
#cloud-config
EOF
		if [ ${DISABLE_9P_MOUNTS} -eq 0 ]
                then
                        cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
mounts:
- [ host0, /var/lib/kubelet, 9p, "trans=virtio,version=9p2000.L", 0, 0 ]
- [ host1, /var/log/pods, 9p, "trans=virtio,version=9p2000.L", 0, 0 ]
EOF
                fi
                cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
users:
- default
- name: vm-user
  primary_group: vm-user
  groups: users, admin
  sudo: ALL=(ALL) NOPASSWD:ALL
  lock_passwd: false
  passwd: $(echo "vm-user" | openssl passwd -6 -stdin)
hostname: testhost
create_hostname_file: true
package_reboot_if_required: true
package_update: true
package_upgrade: true
packages:
- containerd
- 9mount
- ${KERNEL_VERSION}
write_files:
- content: |
    [Unit]
    Description=TCP proxy for containerd
    After=containerd.service
    
    [Service]
    Environment="PROXY_TO=unix:///run/containerd/containerd.sock"
    Environment="BIND_TO=tcp://0.0.0.0:35000"
    ExecStart=/usr/bin/csi-grpc-proxy
    
    Type=simple
    Delegate=yes
    KillMode=process
    Restart=always
    RestartSec=5
    
    # Having non-zero Limit*s causes performance problems due to accounting overhead
    # in the kernel. We recommend using cgroups to do container-local accounting.
    LimitNPROC=infinity
    LimitCORE=infinity
    
    # Comment TasksMax if your systemd version does not supports it.
    # Only systemd 226 and above support this version.
    TasksMax=infinity
    OOMScoreAdjust=-999
    
    [Install]
    WantedBy=multi-user.target
  path: /etc/systemd/system/csi-grpc-proxy.service
- content: |
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nelly]
            privileged_without_host_devices = false
            runtime_type = "io.containerd.runc.v2"
    
            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nelly.options]
              BinaryName = "/usr/sbin/runc"
              NoPivotRoot = true
              CriuImagePath = ""
              CriuPath = ""
              CriuWorkPath = ""
              IoGid = 0
  path: /etc/containerd/config.toml.new
runcmd:
- [ wget, "${DEFAULT_CSI_GRPC_PROXY_URL}${ARCH}", -O, /usr/bin/csi-grpc-proxy ]
- [ chmod, "a+x", /usr/bin/csi-grpc-proxy ]
- [ bash,"-c","cat /etc/containerd/config.toml.new >> /etc/containerd/config.toml"]
EOF
		if [ ${DISABLE_9P_MOUNTS} -eq 0 ]
                then
                        cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- [ mkdir,"-p","/var/lib/kubelet","/var/log/pods" ]
- [ bash,"-c","echo 'host0 /var/lib/kubelet 9p trans=virtio,version=9p2000.L 0 2' >> /etc/fstab" ]
- [ bash,"-c","echo 'host1 /var/log/pods 9p trans=virtio,version=9p2000.L 0 2' >> /etc/fstab" ]
- [ mount, "host0"]
- [ mount, "host1"]
EOF
                fi
		cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- [ systemctl, daemon-reload ]
- [ systemctl, restart, containerd ]
- [ systemctl, enable, csi-grpc-proxy.service ]
- [ systemctl, start, csi-grpc-proxy.service ]
EOF
		cat > "${DEFAULT_DIR_IMAGE}/cloud-init.dir/vendor-data" <<EOF
EOF
		cat > "${DEFAULT_DIR_IMAGE}/cloud-init.dir/network-config" <<EOF
instance-id: testhost
local-hostname: testhost
network:
  version: 2
  ethernets:
    enp0s1:
      dhcp4: no
      addresses: [10.0.2.15/24]
      nameservers:
           addresses: [10.0.2.3]
      routes:
      - to: 0.0.0.0/0
        via: 10.0.2.2
    enp0s2:
      dhcp4: no
      addresses: [10.0.2.15/24]
      nameservers:
           addresses: [10.0.2.3]
      routes:
      - to: 0.0.0.0/0
        via: 10.0.2.2
    ens4:
      dhcp4: no
      addresses: [10.0.2.15/24]
      nameservers:
           addresses: [10.0.2.3]
      routes:
      - to: 0.0.0.0/0
        via: 10.0.2.2
EOF
		case ${OS} in
			Darwin)
				hdiutil makehybrid -o "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -joliet -iso -default-volume-name cidata "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
				;;
			*)
				mkisofs -output "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -volid cidata -joliet -rock "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
				;;
		esac
	fi
}

function check_ports_redirection() {
	REDIRECT_PORT=""
	if [ ! -z "${DEFAULT_QEMU_HOST_SSHD_PORT}" ]
	then
		REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${DEFAULT_QEMU_HOST_SSHD_PORT}-:22"
	fi
	REDIRECT_PORT=""
	if [ ! -z "${DEFAULT_QEMU_HOST_CONTAINERD_PORT}" ]
	then
		REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${DEFAULT_QEMU_HOST_CONTAINERD_PORT}-:35000"
	fi
}

function check_k3s_log_pods_dir() {
	if [ ${DISABLE_9P_MOUNTS} -gt 0 ]
	then
		return
	fi
	case ${OS} in
		Darwin)
			: ${DIR_K3S_VAR:=${DEFAULT_DIR_K3S_VAR_DARWIN}}
			;;
		GNU/Linux)
			if [ "x${USER}" == "xroot" ]
			then
				: ${DIR_K3S_VAR:=${DEFAULT_DIR_K3S_VAR_LINUX_ROOT}}
			else
				: ${DIR_K3S_VAR:=${DEFAULT_DIR_K3S_VAR_LINUX_NON_ROOT}}
			fi
			;;
		*)
			: ${DIR_K3S_VAR:=${DEFAULT_DIR_K3S_VAR_OTHER}}
			;;
	esac
	if [ ! -z "${DIR_K3S_VAR}" ]
	then
		if [ ! -d "${DIR_K3S_VAR}/var/lib/kubelet" -o ! -d "${DIR_K3S_VAR}/var/log/pods" ]
		then
			mkdir -p "${DIR_K3S_VAR}/var/lib/kubelet" "${DIR_K3S_VAR}/var/log/pods"
		fi
	fi
}

# ----- Main

check_requirements

check_ports_redirection

check_qemu_kvm_hvf

check_image_exists

check_k3s_log_pods_dir

check_qemu_memory_cpu

resize_qemu_image

check_cloud_init_create

BIOS_OPTION=""
if [ ! -z "${QEMU_BIOS}" ]
then
	BIOS_OPTION="-bios ${QEMU_BIOS}"
fi

VIRTFS_9P=""
if [ ${DISABLE_9P_MOUNTS} -eq 0 ]
then
	VIRTFS_9P=" -virtfs local,path=${DIR_K3S_VAR}/var/lib/kubelet,mount_tag=host0,security_model=passthrough,id=host0  \
		   -virtfs local,path=${DIR_K3S_VAR}/var/log/pods,mount_tag=host1,security_model=passthrough,id=host1 " 
fi

echo "qemu-system-${ARCH_M} \
	-m ${QEMU_MEMORY}g \
	-smp ${QEMU_CPU} \
	-M ${QEMU_MACHINE_TYPE} \
	${HW_ACCEL} \
	${BIOS_OPTION} \
	-cpu ${QEMU_CPU_TYPE} \
	-drive if=none,file="${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}",id=hd0 \
	-drive file="${DEFAULT_DIR_IMAGE}/cloud-init.iso",index=1,media=cdrom \
	-device virtio-blk-pci,drive=hd0 \
	-device virtio-net-pci,netdev=net0,mac=52:54:00:08:06:8b \
	-netdev user,id=net0${REDIRECT_PORT} \
	-serial mon:stdio \
	${VIRTFS_9P} \
 	-nographic"

qemu-system-${ARCH_M} \
	-m ${QEMU_MEMORY}g \
	-smp ${QEMU_CPU} \
	-M ${QEMU_MACHINE_TYPE} \
	${HW_ACCEL} \
	${BIOS_OPTION} \
	-cpu ${QEMU_CPU_TYPE} \
	-drive if=none,file="${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}",id=hd0 \
	-drive file="${DEFAULT_DIR_IMAGE}/cloud-init.iso",index=1,media=cdrom \
	-device virtio-blk-pci,drive=hd0 \
	-device virtio-net-pci,netdev=net0,mac=52:54:00:08:06:8b \
	-netdev user,id=net0${REDIRECT_PORT} \
	${VIRTFS_9P} \
 	-nographic

exit 0
