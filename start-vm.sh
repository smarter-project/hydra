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
: ${DEBUG:=0}
[ ${DEBUG} -gt 0 ] && set -x
: ${DRY_RUN_ONLY:=0}
: ${DISABLE_9P_MOUNTS:=0}
: ${COPY_IMAGE_BACKUP:=0}
: ${DEFAULT_IMAGE:="debian-12-genericcloud-${ARCH}-20250316-2053.qcow2"}
: ${DEFAULT_KERNEL_VERSION:="6.12.12+bpo"}
: ${VM_USERNAME:="vm-user"}
: ${VM_PASSWORD:="vm-user"}
: ${VM_SALT:="123456"}
: ${VM_PASSWORD_ENCRYPTED:=""}
: ${VM_HOSTNAME:="vm-host"}
: ${VM_SSH_AUTHORIZED_KEY:=""}
: ${KERNEL_VERSION:="linux-image-${DEFAULT_KERNEL_VERSION}-${ARCH}"}
: ${DEFAULT_DIR_IMAGE:=$(pwd)/image}
: ${DEFAULT_DIR_K3S_VAR_DARWIN:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_NON_ROOT:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_ROOT:=""}
: ${DEFAULT_DIR_K3S_VAR_OTHER:=$(pwd)/k3s-var}
: ${DEFAULT_SOURCE_IMAGE:="https://cloud.debian.org/images/cloud/bookworm/20250316-2053/"}
: ${DEFAULT_KVM_DARWIN_CPU:=2}
: ${DEFAULT_KVM_DARWIN_MEMORY:=2}
: ${DEFAULT_KVM_LINUX_CPU:=2}
: ${DEFAULT_KVM_LINUX_MEMORY:=2}
: ${DEFAULT_KVM_UNKNOWN_CPU:=2}
: ${DEFAULT_KVM_UNKNOWN_MEMORY:=2}
: ${DEFAULT_KVM_DISK_SIZE:=3}
: ${DEFAULT_KVM_DARWIN_BIOS:="/opt/homebrew/Cellar/qemu/9.2.2/share/qemu/edk2-${ARCH_M}-code.fd"}
: ${DEFAULT_KVM_LINUX_v9_BIOS:=""}
: ${DEFAULT_KVM_LINUX_v7_BIOS:="/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"}
#: ${DEFAULT_KVM_LINUX_BIOS:="/usr/share/qemu/edk2-${ARCH_M}-code.fd"}
: ${DEFAULT_KVM_UNKNWON_BIOS:=""}
# If these values are empty, the ports will not be redirected.
: ${DEFAULT_KVM_HOST_SSHD_PORT:="5555"}
: ${DEFAULT_KVM_HOST_CONTAINERD_PORT:="35000"}
: ${DEFAULT_CSI_GRPC_PROXY_URL:="https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux-"}
: ${DEFAULT_KVM_PORTS_REDIRECT:=""} # format is <external>:<internal> separated by coma

IMAGE_RESTART=0

function check_requirements() {
	ERROR_STR=""
	for REQUIRED in $*
	do
		EXEC_LOCATION=$(type ${REQUIRED} 2>/dev/null)
		[ $? -gt 0 -o -z "{EXEC_LOCATION}" ] && ERROR_STR="${ERROR_STR}${REQUIRED} not available, please install it\n"
	done
	if [ ! -z "${ERROR_STR}" ]
	then
		echo -en "${ERROR_STR}"
		exit 1
	fi
}

function check_kvm_kvm_hvf() {

	if [ "${OS}" == "GNU/Linux" ]
	then
		# checking if KVM is available
		if [ -c /dev/kvm -a -r /dev/kvm -a -w /dev/kvm ]
		then
			echo "KVM available"
			HW_ACCEL="-accel kvm"
			: ${KVM_CPU_TYPE:="host"}
		else
			echo "KVM not available, running without acceleration"
			case ${ARCH_M} in
				x86_64|amd64)
					: ${KVM_CPU_TYPE:="qemu64-v1"};;
				arm64|aarch64)
					: ${KVM_CPU_TYPE:="cortex-a76"};;
				*)
					: ${KVM_CPU_TYPE:="qemu64-v1"};;
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
			: ${KVM_CPU_TYPE:="host"}
		else
			echo "HVF not available, running without acceleration"
			: ${KVM_CPU_TYPE:="cortex-a76"}
		fi
	else
		echo "Unknownn OS '${OS}', running without acceleration"
		case ${ARCH_M} in
			x86_64|amd64)
				: ${KVM_CPU_TYPE:="qemu64-v1"};;
			arm64|aarch64)
				: ${KVM_CPU_TYPE:="cortex-a76"};;
			*)
				: ${KVM_CPU_TYPE:="qemu64-v1"};;
		esac
	fi
}

function check_image_directory() {
	if [  ! -d "${DEFAULT_DIR_IMAGE}" ]
	then
		echo "Image directory '${DEFAULT_DIR_IMAGE}' does not exist, trying to create"
		mkdir -p "${DEFAULT_DIR_IMAGE}" || exit $?
		if [ $? -ne 0 ]
		then
			echo "Image directory '${DEFAULT_DIR_IMAGE}' could not be created, bailing out"
			exit 1
		fi
	fi
}

function check_image_exists() {
	if [ ${IMAGE_RESTART} -eq 0 -a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" ]
	then
		echo "Image ${DEFAULT_IMAGE} exists on disk, reusing"
		return
	fi
	if [ ${COPY_IMAGE_BACKUP} -gt 0 -a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp ] 
	then
		echo "Using backup image from ${DEFAULT_SOURCE_IMAGE}"
		cp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}"
	else
		echo "Download image from ${DEFAULT_SOURCE_IMAGE}"
		wget -O "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" "${DEFAULT_SOURCE_IMAGE}/${DEFAULT_IMAGE}" 
		if [ $? -ne 0 ]
		then
			echo "Download unsucceful, bailing out"
			exit 1
		fi
		[ ${COPY_IMAGE_BACKUP} -gt 0 ] && cp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp
	fi
}

function check_kvm_memory_cpu() {
	# check qemu version and if is available
	#
	KVM_OUTPUT=$(qemu-system-${ARCH_M} --version)
	if [ $? -ne 0 ]
	then
		echo "Error getting version from QEMU"
		exit 1
	fi
	KVM_VERSION=$(echo "${KVM_OUTPUT}" | grep "QEMU emulator version" | cut -d " " -f 4)
	if [ -z "${KVM_VERSION}" ]
	then
		echo "Could not determine version of qemu, got this ${KVM_VERSION} from qemu-system-${ARCH_M} --versio output '${KVM_OUTPUT}'"
		exit 1
	fi
	if [[ ! "${KVM_VERSION}" =~ ^[0-9][0-9.]*[0-9]$ ]]
	then
		echo "Non numeric version of qemu, got this ${KVM_VERSION} from 'qemu-system-${ARCH_M} --version' output '${KVM_OUTPUT}'"
		exit 1
	fi

	echo "Using QEMU version ${KVM_VERSION}"

	if [ "${OS}" == "GNU/Linux" ]
	then
		: ${KVM_CPU:=${DEFAULT_KVM_LINUX_CPU}}
		: ${KVM_MEMORY:=${DEFAULT_KVM_LINUX_MEMORY}}
		KVM_MAJOR=$(echo "${KVM_VERSION}" | cut -d "." -f 1)
		if [ ${KVM_MAJOR} -ge 9 ]
		then
			: ${KVM_BIOS:=${DEFAULT_KVM_LINUX_v9_BIOS}}
		else
			: ${KVM_BIOS:=${DEFAULT_KVM_LINUX_v7_BIOS}}
		fi
				
		case ${ARCH_M} in
			x86_64|amd64)
				: ${KVM_MACHINE_TYPE:="pc"};;
			arm64|aarch64)
				: ${KVM_MACHINE_TYPE:="virt"};;
			*)
				: ${KVM_MACHINE_TYPE:="pc"};;
		esac
		echo "Using linux QEMU machine ${KVM_MACHINE_TYPE},${KVM_CPU} CPUs, ${KVM_MEMORY}G and bios ${KVM_BIOS}"
		return
	elif [ "${OS}" == "Darwin" ]
	then
		: ${KVM_CPU:=${DEFAULT_KVM_DARWIN_CPU}}
		: ${KVM_MEMORY:=${DEFAULT_KVM_DARWIN_MEMORY}}
		: ${KVM_BIOS:=${DEFAULT_KVM_DARWIN_BIOS}}
		: ${KVM_MACHINE_TYPE:="virt"}
		echo "Using Darwin QEMU machine ${KVM_MACHINE_TYPE} with ${KVM_CPU} CPUs and ${KVM_MEMORY}G"
		return
	else
		: ${KVM_CPU:=${DEFAULT_KVM_UNKNOWN_CPU}}
		: ${KVM_MEMORY:=${DEFAULT_KVM_UNKNOWN_MEMORY}}
		: ${KVM_BIOS:=${DEFAULT_KVM_UNKNOWN_BIOS}}
		case ${ARCH_M} in
			x86_64|amd64)
				: ${KVM_MACHINE_TYPE:="pc"};;
			arm64|aarch64)
				: ${KVM_MACHINE_TYPE:="virt"};;
			*)
				: ${KVM_MACHINE_TYPE:="pc"};;
		esac
		echo "Using unknown OS QEMU machine ${KVM_MACHINE_TYPE} with ${KVM_CPU} CPUs and ${KVM_MEMORY}G"
		return
	fi
}

function resize_kvm_image() {
	KVM_IMG_RES=$(qemu-img info "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" 2>&1)
	if [ $? -ne 0 ]
	then
		echo "qemu-img return $? and '${KVM_IMG_RES}'"
		exit 1
	fi
	CURR_IMG_SIZE=$(echo "${KVM_IMG_RES}" | grep '^virtual size' | sed -e "s/^.*(//" -e "s/ .*//")
	CURR_IMG_SIZE=$((${CURR_IMG_SIZE}/1024/1024/1024))
	if [ ${CURR_IMG_SIZE} -lt ${DEFAULT_KVM_DISK_SIZE} ]
	then
		echo "Resizing image to ${DEFAULT_KVM_DISK_SIZE}g"
		#qemu-img resize "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" ${DEFAULT_KVM_DISK_SIZE}g
		if [ $? -ne 0 ]
		then
			echo "qemu-img resize return $?"
			exit 1
		fi
	else
		echo "Image size (${CURR_IMG_SIZE}G) equal or larger than required(${DEFAULT_KVM_DISK_SIZE}G)"
	fi
}

function check_cloud_init_create() {
	if [ -d "${DEFAULT_DIR_IMAGE}/cloud-init.dir" ]
	then
		if [ -f "${DEFAULT_DIR_IMAGE}/cloud-init.iso" ]
		then
			mv "${DEFAULT_DIR_IMAGE}/cloud-init.dir" "${DEFAULT_DIR_IMAGE}/cloud-init.dir.old"
		else
			rm -rf "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
		fi
	fi
	mkdir "${DEFAULT_DIR_IMAGE}/cloud-init.dir" || exit $?
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
	: ${VM_PASSWORD_ENCRYPTED:=$(echo ${VM_PASSWORD} | openssl passwd -6 -salt ${VM_SALT} -stdin)}
	cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
users:
- default
- name: ${VM_USERNAME}
  primary_group: ${VM_USERNAME}r
  groups: users, admin
  sudo: ALL=(ALL) NOPASSWD:ALL
  lock_passwd: false
  passwd: ${VM_PASSWORD_ENCRYPTED}
EOF
	if [ ! -z "${VM_SSH_AUTHORIZED_KEY}" ]
	then 
		cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
  ssh_authorized_keys:
      - ${VM_SSH_AUTHORIZED_KEY}
EOF
	fi
	cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
hostname: ${VM_HOSTNAME}
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
instance-id: ${VM_HOSTNAME}
local-hostname: ${VM_HOSTNAME}
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
	if [ -d "${DEFAULT_DIR_IMAGE}/cloud-init.dir.old" ]
	then 
		CONFIG_MODIFIED=$(diff "${DEFAULT_DIR_IMAGE}/cloud-init.dir.old" "${DEFAULT_DIR_IMAGE}/cloud-init.dir")
		if [ -z "${CONFIG_MODIFIED}" ]
		then
			rm -rf "${DEFAULT_DIR_IMAGE}/cloud-init.dir.old" || exit $?
			return
		fi
		rm -rf "${DEFAULT_DIR_IMAGE}/cloud-init.dir.old" || exit $?
	fi
		
	IMAGE_RESTART=1
	case ${OS} in
		Darwin)
			hdiutil makehybrid -o "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -joliet -iso -default-volume-name cidata "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
			;;
		*)
			mkisofs -output "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -input-charset utf-8 -volid cidata -joliet -rock "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
			;;
	esac
}

function check_ports_redirection() {
	REDIRECT_PORT=""
	[ -z "${DEFAULT_KVM_HOST_SSHD_PORT}" ] || REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${DEFAULT_KVM_HOST_SSHD_PORT}-:22"
	[ -z "${DEFAULT_KVM_HOST_CONTAINERD_PORT}" ] || REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${DEFAULT_KVM_HOST_CONTAINERD_PORT}-:35000"

	REDIRECTS=${DEFAULT_KVM_PORTS_REDIRECT//;/ } 
	for REDIRECT in ${REDIRECTS}
	do
		REDIRECT_HOST=$(echo "${REDIRECT}" | cut -d ":" -f 1)
		REDIRECT_VM=$(echo "${REDIRECT}" | cut -d ":" -f 2)
		[[ "${REDIRECT_HOST}" =~ ^[0-9][0-9]*$ && "${REDIRECT_VM}" =~ ^[0-9][0-9]*$ ]] || continue
		REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${REDIRECT_HOST}-:${REDIRECT_VM}"
	done
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
			if [ "x${USER}" == "xroot" -o "$(id -u)" -eq 0 ]
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

# ----- Main -------------------------------------------------------------------------------------

check_requirements qemu-system-${ARCH_M} mkisofs wget

check_ports_redirection

check_kvm_kvm_hvf

check_image_directory

check_cloud_init_create

check_image_exists

check_k3s_log_pods_dir

check_kvm_memory_cpu

resize_kvm_image

BIOS_OPTION=""
if [ ! -z "${KVM_BIOS}" ]
then
	BIOS_OPTION="-bios ${KVM_BIOS}"
fi

VIRTFS_9P=""
if [ ${DISABLE_9P_MOUNTS} -eq 0 ]
then
	VIRTFS_9P=" -virtfs local,path=${DIR_K3S_VAR}/var/lib/kubelet,mount_tag=host0,security_model=passthrough,id=host0  \
		   -virtfs local,path=${DIR_K3S_VAR}/var/log/pods,mount_tag=host1,security_model=passthrough,id=host1 " 
fi

echo 'qemu-system-'${ARCH_M}' \
	-m '${KVM_MEMORY}'g \
	-smp '${KVM_CPU}' \
	-M '${KVM_MACHINE_TYPE}' \
	'${HW_ACCEL}' \
	'${BIOS_OPTION}' \
	-cpu '${KVM_CPU_TYPE}' \
	-drive if=none,file="'${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}'",id=hd0 \
	-drive file="'${DEFAULT_DIR_IMAGE}'/cloud-init.iso",index=1,media=cdrom \
	-device virtio-blk-pci,drive=hd0 \
	-device virtio-net-pci,netdev=net0,mac=52:54:00:08:06:8b \
	-netdev user,id=net0'${REDIRECT_PORT}' \
	-serial mon:stdio \
	'${VIRTFS_9P}' \
 	-nographic'

[ ${DRY_RUN_ONLY} -gt 0 ] && exit 0

qemu-system-${ARCH_M} \
	-m ${KVM_MEMORY}g \
	-smp ${KVM_CPU} \
	-M ${KVM_MACHINE_TYPE} \
	${HW_ACCEL} \
	${BIOS_OPTION} \
	-cpu ${KVM_CPU_TYPE} \
	-drive if=none,file="${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}",id=hd0 \
	-drive file="${DEFAULT_DIR_IMAGE}/cloud-init.iso",index=1,media=cdrom \
	-device virtio-blk-pci,drive=hd0 \
	-device virtio-net-pci,netdev=net0,mac=52:54:00:08:06:8b \
	-netdev user,id=net0${REDIRECT_PORT} \
	${VIRTFS_9P} \
 	-nographic

exit 0
