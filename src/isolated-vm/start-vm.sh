#!/bin/bash

HW_ACCEL=""
REDIRECT_PORT=""
OS=$(uname -o)
ARCH_M=$(uname -m)
case ${ARCH_M} in
	x86_64)
		ARCH_GEN=amd64
		ARCH=amd64;;
	arm64|aarch64)
		ARCH=arm64
		ARCH_GEN=arm
		ARCH_M=aarch64;;
	*)
		ARCH=${ARCH_M}
		ARCH_GEN=${ARCH_M};;
esac
: ${DEBUG:=0}
[ ${DEBUG} -gt 0 ] && set -x
: ${DRY_RUN_ONLY:=0}
: ${RUN_BARE_KERNEL:=0}
: ${DISABLE_9P_KUBELET_MOUNTS:=0}
: ${DISABLE_CONTAINERD_CSI_PROXY:=0}
: ${ENABLE_VIRTIO_GPU:=0}
: ${DEFAULT_VIRTIO_GPU_VRAM:=4}
: ${ADDITIONAL_9P_MOUNTS:=""}
: ${COPY_IMAGE_BACKUP:=0}
: ${ALWAYS_REUSE_DISK_IMAGE:=0}
: ${DEFAULT_IMAGE:="debian-12-genericcloud-${ARCH}-20250316-2053.qcow2"}
: ${DEFAULT_KERNEL_VERSION:="6.12.22+bpo"}
: ${VM_USERNAME:="hailhydra"}
: ${VM_PASSWORD:="hailhydra"}
: ${VM_SALT:="123456"}
: ${VM_PASSWORD_ENCRYPTED:=""}
: ${VM_HOSTNAME:="hydravm"}
: ${VM_SSH_AUTHORIZED_KEY:=""}
: ${VM_SSH_KEY_FILENAME:=""}
: ${KERNEL_VERSION:="linux-image-${DEFAULT_KERNEL_VERSION}-${ARCH}"}
: ${DEFAULT_DIR_IMAGE:=$(pwd)/image}
: ${DEFAULT_DIR_K3S_VAR_DARWIN:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_NON_ROOT:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_ROOT:=""}
: ${DEFAULT_DIR_K3S_VAR_OTHER:=$(pwd)/k3s-var}
: ${DEFAULT_IMAGE_SOURCE_URL:="https://cloud.debian.org/images/cloud/bookworm/20250316-2053/"}
: ${DEFAULT_KVM_DARWIN_CPU:=2}
: ${DEFAULT_KVM_DARWIN_MEMORY:=8}
: ${DEFAULT_KVM_LINUX_CPU:=2}
: ${DEFAULT_KVM_LINUX_MEMORY:=8}
: ${DEFAULT_KVM_UNKNOWN_CPU:=2}
: ${DEFAULT_KVM_UNKNOWN_MEMORY:=8}
: ${DEFAULT_KVM_DISK_SIZE:=3}
[ ${OS} == "Darwin" ] && {
	: ${DEFAULT_KVM_DARWIN_BIOS:=$(ls -t /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-${ARCH_M}-code.fd 2>/dev/null | head -n 1)}
	: ${DEFAULT_KVM_DARWIN_BIOS_VAR:=""}
#	: ${DEFAULT_KVM_DARWIN_BIOS_VAR:=$(ls -t /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-${ARCH_GEN}-code.fd 2>/dev/null | head -n 1)}
}
: ${DEFAULT_KVM_LINUX_v9_BIOS:=""}
: ${DEFAULT_KVM_LINUX_v9_BIOS_VAR:=""}
: ${DEFAULT_KVM_LINUX_v7_BIOS:="/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"}
: ${DEFAULT_KVM_LINUX_v7_BIOS_VAR:="/usr/share/qemu-efi-aarch64/QEMU_EFI_vars.fd"}
#: ${DEFAULT_KVM_LINUX_BIOS:="/usr/share/qemu/edk2-${ARCH_M}-code.fd"}
: ${DEFAULT_KVM_UNKNWON_BIOS:=""}
: ${DEFAULT_KVM_UNKNWON_BIOS_VAR:=""}
# If these values are empty, the ports will not be redirected.
: ${DEFAULT_KVM_HOST_SSHD_PORT:="5555"}
: ${DEFAULT_KVM_HOST_CONTAINERD_PORT:="35000"}
: ${DEFAULT_KVM_HOST_RIMD_PORT:="35001"}
: ${DEFAULT_CSI_GRPC_PROXY_URL:="https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux-"}
: ${DEFAULT_KVM_PORTS_REDIRECT:=""} # format is <external>:<internal> separated by semicolon
: ${DEFAULT_RIMD_ARTIFACT_URL:="https://gitlab.arm.com/api/v4/projects/576/packages/generic/rimdworkspace/v1.0.1/rimdworkspace.tar.gz"}
: ${RIMD_ARTIFACT_URL_USER:=""}
: ${RIMD_ARTIFACT_URL_PASS:=""}
: ${RIMD_ARTIFACT_URL_TOKEN:=""}
: ${DEFAULT_RIMD_ARTIFACT_FILENAME:="rimdworkspace.tar.gz"}
: ${DEFAULT_RIMD_KERNEL_FILENAME:="Image.gz"}
: ${DEFAULT_RIMD_IMAGE_FILENAME:="initramfs.linux_arm64.cpio"}
: ${DEFAULT_RIMD_FILESYSTEM_FILENAME:="something.qcow2"}

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
					if [ $KVM_VERSION_MAJOR -ge 7 ]
					then
						: ${KVM_CPU_TYPE:="cortex-a76"}
					else
						: ${KVM_CPU_TYPE:="cortex-a72"}
					fi;;
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
	DEFAULT_IMAGE_COMPRESSED="${DEFAULT_IMAGE}"
	if [[ ${DEFAULT_IMAGE} =~ ^.*\.zip$ ]]
	then
		DEFAULT_IMAGE=$(echo "${DEFAULT_IMAGE}" | sed -e "s/[.]zip$//")
	elif [[ ${DEFAULT_IMAGE} =~ ^.*\.gz$ ]]
	then
		DEFAULT_IMAGE=$(echo "${DEFAULT_IMAGE}" | sed -e "s/[.]gz$//")
	elif [[ ${DEFAULT_IMAGE} =~ ^.*\.xz$ ]]
	then
		DEFAULT_IMAGE=$(echo "${DEFAULT_IMAGE}" | sed -e "s/[.]xz$//")
	elif [[ ${DEFAULT_IMAGE} =~ ^.*\.bz2$ ]]
	then
		DEFAULT_IMAGE=$(echo "${DEFAULT_IMAGE}" | sed -e "s/[.]xz$//")
	fi
	if [ -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" ]
	then
		if [ ${IMAGE_RESTART} -eq 0 ]
		then
			echo "Image ${DEFAULT_IMAGE} exists on disk, reusing"
			return
		fi
		echo "Image ${DEFAULT_IMAGE} exists on disk bt restart is required"
		rm "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" > /dev/null
	fi
	if [ ${COPY_IMAGE_BACKUP} -gt 0 -a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp ]
	then
		echo "Using backup image from ${DEFAULT_IMAGE_SOURCE_URL}"
		cp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}"
	else
		echo "Image ${DEFAULT_IMAGE} does not exist on disk, checking if downloading is needed"
		if [ ! -e "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}" ]
		then
			echo "Downloading image ${DEFAULT_IMAGE_COMPRESSED} from ${DEFAULT_IMAGE_SOURCE_URL}"
			wget -O "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}" "${DEFAULT_IMAGE_SOURCE_URL}/${DEFAULT_IMAGE_COMPRESSED}"

			if [ $? -ne 0 ]
			then
				echo "Download unsucceful, bailing out"
				exit 1
			fi
		else
			echo "Using existing image ${DEFAULT_IMAGE_COMPRESSED}"
		fi
		if [[ ${DEFAULT_IMAGE_COMPRESSED} =~ ^.*\.zip$ ]]
		then
			echo "Image is compressed with zip, uncompressing ${DEFAULT_IMAGE_COMPRESSED}"
			unzip -o -d "${DEFAULT_DIR_IMAGE}" -x "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}"
		elif [[ ${DEFAULT_IMAGE_COMPRESSED} =~ ^.*\.gz$ ]]
		then
			echo "Image is compressed with gzip, uncompressing ${DEFAULT_IMAGE_COMPRESSED}"
			gunzip -d "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}"
		elif [[ ${DEFAULT_IMAGE_COMPRESSED} =~ ^.*\.bz2$ ]]
		then
			echo "Image is compressed with bzip2, uncompressing ${DEFAULT_IMAGE_COMPRESSED}"
			bunzip2 -d "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}"
		elif [[ ${DEFAULT_IMAGE_COMPRESSED} =~ ^.*\.xz$ ]]
		then
			echo "Image is compressed with xz, uncompressing ${DEFAULT_IMAGE_COMPRESSED}"
			xz --decompress "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}"
		fi
		[ ${COPY_IMAGE_BACKUP} -gt 0 ] && cp "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}" "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}".bkp
	fi
}

function check_kernel_image() {
	if [ ${IMAGE_RESTART} -eq 0 -a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}" ]
	then
		echo "Image ${DEFAULT_RIMD_ARTIFACT_FILENAME} exists on disk, reusing"
	else
		echo "Download image from ${DEFAULT_RIMD_ARTIFACT_URL}"
		USER_ID="-nv"
		if [ ! -z "${RIMD_ARTIFACT_URL_USER}" ]
		then
			USER_ID="--user=${RIMD_ARTIFACT_URL_USER}"
		fi
		USER_PASS="-nv"
		if [ ! -z "${RIMD_ARTIFACT_URL_USER}" ]
		then
			USER_PASS="--password=${RIMD_ARTIFACT_URL_PASS}"
		fi
		USER_TOKEN="-nv"
		if [ ! -z "${RIMD_ARTIFACT_URL_TOKEN}" ]
		then
			USER_TOKEN="--header=PRIVATE-TOKEN: ${RIMD_ARTIFACT_URL_TOKEN}"
		fi
		wget -nv "${USER_ID}" "${USER_PASS}" "${USER_TOKEN}" -O "image/${DEFAULT_RIMD_ARTIFACT_FILENAME}" "${DEFAULT_RIMD_ARTIFACT_URL}"
		if [ $? -ne 0 ]
		then
			echo "Download unsuccessful, bailing out"
			exit 1
		fi
	fi
	if [ ${IMAGE_RESTART} -eq 0 -a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_KERNEL_FILENAME}" \
		-a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_IMAGE_FILENAME}" \
		-a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}" ]
	then
		return
	fi
	if [[ ${DEFAULT_RIMD_ARTIFACT_FILENAME} =~ ^.*\.zip$ ]]
	then
		unzip -o -d "${DEFAULT_DIR_IMAGE}" -x "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}"
	elif [[ ${DEFAULT_RIMD_ARTIFACT_FILENAME} =~ ^.*\.tar.gz$ || ${DEFAULT_RIMD_ARTIFACT_FILENAME} =~ ^.*\.tar.bz2$ ]]
	then
		(cd "${DEFAULT_DIR_IMAGE}";tar -xf "${DEFAULT_RIMD_ARTIFACT_FILENAME}")
	else
		echo "File termination unknown so unable to unpack it, bailing out"
		exit 1
	fi
}

function check_kvm_version() {
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
	KVM_VERSION_MAJOR=$(echo "${KVM_VERSION}" | cut -d "." -f 1)
	KVM_VERSION_MINOR=$(echo "${KVM_VERSION}" | cut -d "." -f 2)
	KVM_VERSION_REV=$(echo "${KVM_VERSION}" | cut -d "." -f 3)
}

function check_kvm_memory_cpu() {
	if [ "${OS}" == "GNU/Linux" ]
	then
		: ${KVM_CPU:=${DEFAULT_KVM_LINUX_CPU}}
		: ${KVM_MEMORY:=${DEFAULT_KVM_LINUX_MEMORY}}
		if [ ${KVM_VERSION_MAJOR} -ge 9 ]
		then
			: ${KVM_BIOS:=${DEFAULT_KVM_LINUX_v9_BIOS}}
			: ${KVM_BIOS_VAR:=${DEFAULT_KVM_LINUX_v9_BIOS_VAR}}
		else
			: ${KVM_BIOS:=${DEFAULT_KVM_LINUX_v7_BIOS}}
			: ${KVM_BIOS_VAR:=${DEFAULT_KVM_LINUX_v7_BIOS_VAR}}
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
		: ${KVM_BIOS_VAR:=${DEFAULT_KVM_DARWIN_BIOS_VAR}}
		: ${KVM_MACHINE_TYPE:="virt"}
		echo "Using Darwin QEMU machine ${KVM_MACHINE_TYPE} with ${KVM_CPU} CPUs and ${KVM_MEMORY}G"
		return
	else
		: ${KVM_CPU:=${DEFAULT_KVM_UNKNOWN_CPU}}
		: ${KVM_MEMORY:=${DEFAULT_KVM_UNKNOWN_MEMORY}}
		: ${KVM_BIOS:=${DEFAULT_KVM_UNKNOWN_BIOS}}
		: ${KVM_BIOS_VAR:=${DEFAULT_KVM_UNKNOWN_BIOS_VAR}}
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
	IMAGE_TO_RESIZE=$1
	KVM_IMG_RES=$(qemu-img info "${IMAGE_TO_RESIZE}" 2>&1)
	KVM_IMG_SIZE=$((${DEFAULT_KVM_DISK_SIZE}+0))
	if [ $? -ne 0 ]
	then
		echo "qemu-img return $? and '${KVM_IMG_RES}'"
		exit 1
	fi
	KVM_IMG_SIZE=$((${DEFAULT_KVM_DISK_SIZE}+0))
	CURR_IMG_SIZE=$(echo "${KVM_IMG_RES}" | grep '^virtual size' | sed -e "s/^.*(//" -e "s/ .*//")
	CURR_IMG_SIZE=$(((${CURR_IMG_SIZE})/1073741824)) # 1024^3
	if [ ${CURR_IMG_SIZE} -lt ${KVM_IMG_SIZE} ]
	then
		echo "Resizing image to ${KVM_IMG_SIZE}g"
		qemu-img resize "${IMAGE_TO_RESIZE}" ${KVM_IMG_SIZE}g
		if [ $? -ne 0 ]
		then
			echo "qemu-img resize return $?"
			exit 1
		fi
	else
		echo "Image size (${CURR_IMG_SIZE}G) equal or larger than required(${KVM_IMG_SIZE}G)"
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
	if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 -o ! -z "${ADDITIONAL_9P_MOUNTS}" ]
	then
#		cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
#mounts:
#EOF
		VM_MOUNT_POINTS=""
		if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 ]
		then
#			cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
#- [ host0, /var/lib/kubelet, 9p, "trans=virtio,version=9p2000.L" ]
#- [ host1, /var/log/pods, 9p, "trans=virtio,version=9p2000.L" ]
#EOF
			VM_MOUNT_POINTS=',"/var/lib/kubelet","/var/log/pods"'
		fi
		if [ ! -z ${ADDITIONAL_9P_MOUNTS} ]
		then
			MOUNTS="${ADDITIONAL_9P_MOUNTS}"
			MOUNT_ID=100
			while [ ! -z "${MOUNTS}" ]
			do
				MOUNT_USED=$(echo "${MOUNTS}" | cut -d '$' -f 1)
				MOUNTS=$(echo "${MOUNTS}" | cut -d '$' -f 2-)
				if [ "${MOUNTS}" == "${MOUNT_USED}" ]
				then
					MOUNTS=""
				fi
				MOUNT_HOST=$(echo "${MOUNT_USED}" | cut -d '|' -f 1)
				MOUNT_VM=$(echo "${MOUNT_USED}" | cut -d '|' -f 2)
				if [ -z "${MOUNT_HOST}" -o -z "${MOUNT_VM}" ]
				then
					echo "Incorrect specification of mount point in this '${MOUNT_USED}'"
					exit 1
				fi
				VM_MOUNT_POINTS="${VM_MOUNT_POINTS},\"${MOUNT_VM}\""
#				cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
#- [ host${MOUNT_ID}, ${MOUNT_VM}, 9p, "trans=virtio,version=9p2000.L", 0, 0 ]
#EOF
				MOUNT_ID=$((${MOUNT_ID}+1))
			done
		fi
	fi
	: ${VM_PASSWORD_ENCRYPTED:=$(echo ${VM_PASSWORD} | openssl passwd -6 -salt ${VM_SALT} -stdin)}
	cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
users:
- default
- name: ${VM_USERNAME}
  primary_group: ${VM_USERNAME}
  groups: users, admin
  sudo: ALL=(ALL) NOPASSWD:ALL
  lock_passwd: false
  passwd: ${VM_PASSWORD_ENCRYPTED}
EOF
	if [ ! -z "${VM_SSH_AUTHORIZED_KEY}" ]
	then
		cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
  ssh_authorized_keys: ['${VM_SSH_AUTHORIZED_KEY}']
EOF
	fi
	cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
hostname: ${VM_HOSTNAME}
create_hostname_file: true
package_reboot_if_required: true
package_update: true
package_upgrade: true
packages:
EOF
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- containerd
- 9mount
EOF
	cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- ${KERNEL_VERSION}
write_files:
EOF
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
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
    [plugins."io.containerd.grpc.v1.cri".containerd]
            default_runtime_name = "nelly"
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
EOF
	cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- content: |
    Hydra VM installed and configured. SSH and csi-grpc-proxy are running.
    You can login on this terminal with username/password provided
    or using ssh with key provided.
  path: /etc/issue.hydra
runcmd:
EOF
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- [ wget, "${DEFAULT_CSI_GRPC_PROXY_URL}${ARCH}", -O, /usr/bin/csi-grpc-proxy ]
- [ chmod, "a+x", /usr/bin/csi-grpc-proxy ]
- [ bash,"-c","cat /etc/containerd/config.toml.new >> /etc/containerd/config.toml"]
EOF
	cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- [ bash,"-c","cat /etc/issue.hydra >> /etc/issue"]
EOF
	if [ ! -z "${VM_MOUNT_POINTS}" ]
	then
		cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- [ mkdir,"-p"${VM_MOUNT_POINTS} ]
EOF
	fi
	if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 ]
	then
		cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- [ bash,"-c","echo 'host0 /var/lib/kubelet 9p trans=virtio,version=9p2000.L 0 0' >> /etc/fstab" ]
- [ bash,"-c","echo 'host1 /var/log/pods 9p trans=virtio,version=9p2000.L 0 0' >> /etc/fstab" ]
- [ mount, "host0"]
- [ mount, "host1"]
EOF
	fi
	if [ ! -z ${ADDITIONAL_9P_MOUNTS} ]
	then
		MOUNTS="${ADDITIONAL_9P_MOUNTS}"
		MOUNT_ID=100
		while [ ! -z "${MOUNTS}" ]
		do
			MOUNT_USED=$(echo "${MOUNTS}" | cut -d '$' -f 1)
			MOUNTS=$(echo "${MOUNTS}" | cut -d '$' -f 2-)
			if [ "${MOUNTS}" == "${MOUNT_USED}" ]
			then
				MOUNTS=""
			fi
			MOUNT_HOST=$(echo "${MOUNT_USED}" | cut -d '|' -f 1)
			MOUNT_VM=$(echo "${MOUNT_USED}" | cut -d '|' -f 2)
			if [ -z "${MOUNT_HOST}" -o -z "${MOUNT_VM}" ]
			then
				echo "Incorrect specification of mount point in this '${MOUNT_USED}'"
				exit 1
			fi
			VM_MOUNT_POINTS="${VM_MOUNT_POINTS},\"${MOUNT_VM}\""
			cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
- [ bash,"-c","echo 'host${MOUNT_ID} ${MOUNT_VM} 9p trans=virtio,version=9p2000.L 0 0' >> /etc/fstab" ]
- [ mount, "host${MOUNT_ID}"]
EOF
			MOUNT_ID=$((${MOUNT_ID}+1))
		done
	fi
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${DEFAULT_DIR_IMAGE}/cloud-init.dir/user-data" <<EOF
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
    ens3:
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
			echo "Configuration is the same as it was before so reusing the image"
			return
		fi
		echo "Configuration has changed so restart the image"
		rm -rf "${DEFAULT_DIR_IMAGE}/cloud-init.dir.old" || exit $?
	fi
		
	IMAGE_RESTART=1
	if [ ${ALWAYS_REUSE_DISK_IMAGE} -gt 0 ]
	then
		IMAGE_RESTART=0
		echo "---------------------------------------"
		echo "System configuration was chenged that requires the VM to restart from an unitialized disk image"
		echo "but ALWAYS_REUSE_DISK_IMAGE is set so the changes will not be reflected on the VM but will appar"
		echo "on the command line"
		echo "---------------------------------------"
	fi
	case ${OS} in
		Darwin)
			rm "${DEFAULT_DIR_IMAGE}/cloud-init.iso"
			echo "Cloud-init data generated (iso using hdiutil)"
			hdiutil makehybrid -o "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -joliet -iso -default-volume-name cidata "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
			;;
		*)
			rm "${DEFAULT_DIR_IMAGE}/cloud-init.iso"
			echo "Cloud-init data generated (iso using mkisofs)"
			mkisofs -output "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -input-charset utf-8 -volid cidata -joliet -rock "${DEFAULT_DIR_IMAGE}/cloud-init.dir"
		;;
        esac
}

function check_ports_redirection() {
	REDIRECT_PORT=""
	[ -z "${DEFAULT_KVM_HOST_SSHD_PORT}" ] || REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${DEFAULT_KVM_HOST_SSHD_PORT}-:22"
	[ -z "${DEFAULT_KVM_HOST_CONTAINERD_PORT}" ] || REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${DEFAULT_KVM_HOST_CONTAINERD_PORT}-:35000"
	[ -z "${DEFAULT_KVM_HOST_RIMD_PORT}" -o ${RUN_BARE_KERNEL} -eq 0 ] || REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${DEFAULT_KVM_HOST_RIMD_PORT}-:35001"

	if [ -z "${DEFAULT_KVM_PORTS_REDIRECT}" ]
	then
		return
	fi
	if [[ ! ${DEFAULT_KVM_PORTS_REDIRECT} =~ ^([1-9][0-9]+:[[1-9][0-9]+;)*[1-9][0-9]+:[[1-9][0-9]+$ ]]
	then
		echo "Incorrect format for DEFAULT_KVM_PORTS_REDIRECT. It should be either empty, <Port externali>:<Port internal> or sequence of redirects separated by ;."
		exit -1
	fi
	REDIRECTS=${DEFAULT_KVM_PORTS_REDIRECT//;/ }
	for REDIRECT in ${REDIRECTS}
	do
		REDIRECT_HOST=$(echo "${REDIRECT}" | cut -d ":" -f 1)
		REDIRECT_VM=$(echo "${REDIRECT}" | cut -d ":" -f 2)
		[[ "${REDIRECT_HOST}" =~ ^[0-9][0-9]*$ && "${REDIRECT_VM}" =~ ^[0-9][0-9]*$ ]] || continue
		REDIRECT_PORT="${REDIRECT_PORT},hostfwd=tcp:0.0.0.0:${REDIRECT_HOST}-:${REDIRECT_VM}"
	done
}

function check_ssh_authorized_key() {
	if [ ! -z "${VM_SSH_AUTHORIZED_KEY}" ]
	then
		return
	fi
	if [ -z "${VM_SSH_KEY_FILENAME}" ]
	then
		case ${OS} in
			Darwin)
				VM_SSH_KEY_FILENAME=$(ls ~/.ssh/id*.pub 2> /dev/null| head -n 1)
				;;
			GNU/Linux)
				if [ "x${USER}" == "xroot" -o "$(id -u)" -eq 0 ]
				then
					return
				fi
				VM_SSH_KEY_FILENAME=$(ls ~/.ssh/id*.pub 2> /dev/null| head -n 1)
				;;
			*)
				return
				;;
		esac
	fi
	VM_SSH_AUTHORIZED_KEY=$(cat "${VM_SSH_KEY_FILENAME}")
}

function check_k3s_log_pods_dir() {
	if [ ${DISABLE_9P_KUBELET_MOUNTS} -gt 0 ]
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

function check_if_bios_needed() {
	BIOS_OPTION=""
	if [ -z "${KVM_BIOS}" ]
	then
		return
	fi

	if [ ! -e "${KVM_BIOS}" ]
	then
		echo "Bios requested \"${KVM_BIOS}\" not found"
		exit 1
	fi
	BIOS_OPTION="-drive if=pflash,format=raw,readonly,file=${KVM_BIOS}"
	if [ -z "${KVM_BIOS_VAR}" ]
	then
		return
	fi
	if [ ! -e "${KVM_BIOS_VAR}" ]
	then
		echo "Bios requested \"${KVM_BIOS_VAR}\" not found"
		exit 1
	fi
	BIOS_OPTION="${BIOS_OPTION}
 -drive if=pflash,format=raw,file=${KVM_BIOS_VAR}"
}

function check_mount_filesystems() {
	VIRTFS_9P_SECURITY_MODEL="passthrough"
	if [ "${OS}" == "Darwin" ]
	then
		VIRTFS_9P_SECURITY_MODEL="mapped"
	fi
	VIRTFS_9P=""
	if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 ]
	then
		VIRTFS_9P='-virtfs local,path='${DIR_K3S_VAR}/var/lib/kubelet',mount_tag=host0,security_model='${VIRTFS_9P_SECURITY_MODEL}',id=host0
 -virtfs local,path='${DIR_K3S_VAR}/var/log/pods',mount_tag=host1,security_model='${VIRTFS_9P_SECURITY_MODEL}',id=host1'
	fi
	if [ ! -z "${ADDITIONAL_9P_MOUNTS}" ]
	then

		MOUNTS="${ADDITIONAL_9P_MOUNTS}"
		MOUNT_ID=100
		while [ ! -z "${MOUNTS}" ]
		do
			MOUNT_USED=$(echo "${MOUNTS}" | cut -d '$' -f 1)
			MOUNTS=$(echo "${MOUNTS}" | cut -d '$' -f 2-)
			if [ "${MOUNTS}" == "${MOUNT_USED}" ]
			then
				MOUNTS=""
			fi
			MOUNT_HOST=$(echo "${MOUNT_USED}" | cut -d '|' -f 1)
			MOUNT_VM=$(echo "${MOUNT_USED}" | cut -d '|' -f 2)
			if [ -z "${MOUNT_HOST}" -o -z "${MOUNT_VM}" ]
			then
				echo "Incorrect specification of mount point in this '${MOUNT_USED}'"
				exit 1
			fi
			if [ ! -z "${VIRTFS_9P}" ]
			then
				VIRTFS_9P=${VIRTFS_9P}'
	 '
			fi
			VIRTFS_9P=${VIRTFS_9P}'-virtfs local,path='${MOUNT_HOST}',mount_tag=host'${MOUNT_ID}',security_model='${VIRTFS_9P_SECURITY_MODEL}',id=host'${MOUNT_ID}
			MOUNT_ID=$((${MOUNT_ID}+1))
		done
	fi
}

function check_gpu_options() {
	VIRTIO_GPU=""
	KVM_NOGRAPHIC="-nographic"
	if [ ${ENABLE_VIRTIO_GPU} -gt 0 ]
	then
		VIRTIO_GPU='-device virtio-gpu-gl-pci,hostmem='${DEFAULT_VIRTIO_GPU_VRAM}'G,blob=true,venus=true
 -display gtk,gl=on,show-cursor=on
 -object memory-backend-memfd,id=mem1,size='${KVM_MEMORY}'G
 -machine memory-backend=mem1'
		KVM_NOGRAPHIC="-vga none
 -serial mon:stdio"
	fi
}

function check_if_vsock_device_enabledO() {
	VSOCK_DEVICE="-device vhost-vsock-pci,id=vhost-vsock-pci0,guest-cid=3"
	if [ "${OS}" == "Darwin" ]
        then
		VSOCK_DEVICE=""
	fi
}

# ----- Main -------------------------------------------------------------------------------------

check_requirements qemu-system-${ARCH_M}
if [ ${RUN_BARE_KERNEL} -eq 0 ]
then
	if [ ${OS} == "Darwin" ]
	then
		check_requirements wget
	else
		check_requirements mkisofs wget
	fi
fi

check_kvm_version

check_ports_redirection

check_kvm_kvm_hvf

check_image_directory

check_ssh_authorized_key

if [ ${RUN_BARE_KERNEL} -eq 0 ]
then
	check_cloud_init_create

	check_image_exists
else
	check_kernel_image
fi

check_k3s_log_pods_dir

check_kvm_memory_cpu

if [ ${RUN_BARE_KERNEL} -eq 0 ]
then
	resize_kvm_image "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}"
else
	resize_kvm_image "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}"
fi

check_if_bios_needed

check_mount_filesystems

check_gpu_options

if [ ${RUN_BARE_KERNEL} -eq 0 ]
then
	CMD_LINE='qemu-system-'${ARCH_M}'
 -m '${KVM_MEMORY}'g
 -smp '${KVM_CPU}'
 -M '${KVM_MACHINE_TYPE}'
 '${HW_ACCEL}'
 '${BIOS_OPTION}'
 -cpu '${KVM_CPU_TYPE}'
 -drive if=none,format=qcow2,file='${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}',id=hd0
 -drive file='${DEFAULT_DIR_IMAGE}/cloud-init.iso',index=1,media=cdrom
 -device virtio-blk-pci,drive=hd0
 -device virtio-net-pci,netdev=net0,mac=52:54:00:08:06:8b
 -netdev user,id=net0'${REDIRECT_PORT}'
 '${VIRTFS_9P}'
 '${VIRTIO_GPU}'
 '${KVM_NOGRAPHIC}
else
	check_if_vsock_device_enabled

	CMD_LINE='qemu-system-'${ARCH_M}'
 -m '${KVM_MEMORY}'g
 -M '${KVM_MACHINE_TYPE}'
 -smp '${KVM_CPU}'
 '${HW_ACCEL}'
 -cpu '${KVM_CPU_TYPE}'
 -kernel "'${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_KERNEL_FILENAME}'"
 -append "ip=10.0.2.15::10.0.2.2:255.255.255.0:rimd:eth0:on"
 -netdev user,id=n1'${REDIRECT_PORT}'
 -device virtio-net-pci,netdev=n1,mac=52:54:00:94:33:ca
 '${VSOCK_DEVICE}'
 -initrd "'${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_IMAGE_FILENAME}'"
 -drive "if=none,id=drive1,file='${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}'"
 -device virtio-blk-device,id=drv0,drive=drive1
 '${VIRTFS_9P}'
 '${VIRTIO_GPU}'
 -serial mon:stdio
 '${KVM_NOGRAPHIC}
fi

echo "${CMD_LINE}"

[ ${DRY_RUN_ONLY} -gt 0 ] && exit 0

exec ${CMD_LINE}

exit 0
