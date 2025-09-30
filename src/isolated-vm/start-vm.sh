#!/bin/bash

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
[ ${DEBUG:=0} -gt 0 ] && set -x
: ${DRY_RUN_ONLY:=0}
: ${RUN_BARE_KERNEL:=0}
: ${ENABLE_KRUNKIT:=0}
: ${ENABLE_VSOCK_LINUX:=0}
: ${KRUNKIT_HTTP_PORT:=61800}
: ${GVPROXY_HTTP_PORT:=61801}
: ${ADDITIONAL_KERNEL_COMMANDLINE:=""}
: ${DISABLE_9P_KUBELET_MOUNTS:=0}
: ${DISABLE_CONTAINERD_CSI_PROXY:=0}
: ${ENABLE_K3S_DIOD:=0}
: ${ENABLE_VIRTIO_GPU:=0}
: ${DEFAULT_VIRTIO_GPU_VRAM:=4}
: ${ADDITIONAL_9P_MOUNTS:=""}
: ${EXTERNAL_9P_KUBELET_MOUNTS:=0}
: ${COPY_IMAGE_BACKUP:=0}
: ${ALWAYS_REUSE_DISK_IMAGE:=0}
: ${DEFAULT_IMAGE:="debian-13-generic-${ARCH}-20250814-2204.qcow2"}
: ${DEFAULT_KERNEL_VERSION:=""}
: ${INSTALL_ADDITIONAL_DEBS:=""}
: ${VM_USERNAME:="hailhydra"}
: ${VM_PASSWORD:="hailhydra"}
: ${VM_SALT:="123456"}
: ${VM_PASSWORD_ENCRYPTED:=""}
: ${VM_HOSTNAME:="hydravm"}
: ${VM_SSH_AUTHORIZED_KEY:=""}
: ${VM_SSH_KEY_FILENAME:=""}
: ${KERNEL_VERSION:=""}
[ ! -z "${DEFAULT_KERNEL_VERSION}" ] && : ${KERNEL_VERSION:="linux-image-${DEFAULT_KERNEL_VERSION}-${ARCH}"}
: ${DEFAULT_DIR_IMAGE:=$(pwd)/image}
: ${DEFAULT_DIR_TMP_SOCKET:=/tmp/image-$$}
: ${DEFAULT_DIR_K3S_VAR_DARWIN:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_NON_ROOT:=$(pwd)/k3s-var}
: ${DEFAULT_DIR_K3S_VAR_LINUX_ROOT:=""}
: ${DEFAULT_DIR_K3S_VAR_OTHER:=$(pwd)/k3s-var}
: ${DEFAULT_KERNEL_VERSION:=""}
: ${DEFAULT_IMAGE_SOURCE_URL:="https://cloud.debian.org/images/cloud/trixie/20250814-2204"}
: ${DEFAULT_KVM_DARWIN_CPU:=2}
: ${DEFAULT_KVM_DARWIN_MEMORY:=8}
: ${DEFAULT_KVM_LINUX_CPU:=2}
: ${DEFAULT_KVM_LINUX_MEMORY:=8}
: ${DEFAULT_KVM_UNKNOWN_CPU:=2}
: ${DEFAULT_KVM_UNKNOWN_MEMORY:=8}
: ${DEFAULT_KVM_DISK_SIZE:=3}
: ${PIDFILE:=${DEFAULT_DIR_IMAGE}/hydra.pid}
[ ${OS} == "Darwin" ] && {
	: ${DEFAULT_KVM_DARWIN_BIOS:=$(ls -t /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-${ARCH_M}-code.fd 2>/dev/null | head -n 1)}
	: ${DEFAULT_KVM_DARWIN_BIOS_VAR:=""}
#	: ${DEFAULT_KVM_DARWIN_BIOS_VAR:=$(ls -t /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-${ARCH_GEN}-code.fd 2>/dev/null | head -n 1)}
}
: ${DEFAULT_KVM_LINUX_v9_BIOS:=""}
: ${DEFAULT_KVM_LINUX_v9_BIOS_VAR:=""}
: ${ENABLE_REBOOT_AFTER_INSTALLATION:=0}
case ${ARCH} in
	amd64) 
		: ${DEFAULT_KVM_LINUX_v7_BIOS:="/usr/share/ovmf/OVMF.fd"}
		: ${DEFAULT_KVM_LINUX_v7_BIOS_VAR:=""}
		#: ${DEFAULT_KVM_LINUX_v7_BIOS_VAR:="/usr/share/OVMF/OVMF_VARS.fd"}
		;;
	arm64)
		: ${DEFAULT_KVM_LINUX_v7_BIOS:="/usr/share/AAVMF/AAVMF_CODE.fd"}
		: ${DEFAULT_KVM_LINUX_v7_BIOS_VAR:="/usr/share/AAVMF/AAVMF_VARS.fd"}
		;;
	*)
		: ${DEFAULT_KVM_LINUX_v7_BIOS:="/usr/share/ovmf/OVMF.fd"}
		#: ${DEFAULT_KVM_LINUX_v7_BIOS_VAR:="/usr/share/OVMF/OVMF_VARS.fd"}
		;;
esac
: ${DEFAULT_KVM_LINUX_BIOS:="/usr/share/qemu/edk2-${ARCH_M}-code.fd"}
: ${DEFAULT_KVM_UNKNWON_BIOS:=""}
: ${DEFAULT_KVM_UNKNWON_BIOS_VAR:=""}
# If these values are empty, the ports will not be redirected.
: ${DEFAULT_KVM_HOST_SSHD_PORT:="5555"}
: ${DEFAULT_KVM_HOST_DIOD_PORT:="30564"}
: ${DEFAULT_KVM_HOST_CONTAINERD_PORT:="35000"}
: ${DEFAULT_KVM_HOST_RIMD_PORT:="35001"}
: ${DEFAULT_CSI_GRPC_PROXY_URL:="https://github.com/democratic-csi/csi-grpc-proxy/releases/download/v0.5.6/csi-grpc-proxy-v0.5.6-linux-"}
: ${DEFAULT_KVM_PORTS_REDIRECT:=""} # format is <external>:<internal> separated by semicolon
: ${DEFAULT_RIMD_ARTIFACT_URL:="https://gitlab.arm.com/api/v4/projects/research%2Fsmarter%2Fedgeai%2Frimdworkspace/packages/generic/rimdworkspace/Q3_2025_1/rimdworkspace.tar.gz"}
: ${DEFAULT_RIMD_ARTIFACT_DIR:="rimdworkspace_Q3_2025_1"}
: ${RIMD_ARTIFACT_URL_USER:=""}
: ${RIMD_ARTIFACT_URL_PASS:=""}
: ${RIMD_ARTIFACT_URL_TOKEN:=""}
: ${DEFAULT_RIMD_ARTIFACT_FILENAME:="rimdworkspace.tar.gz"}
: ${DEFAULT_RIMD_KERNEL_FILENAME:="Image.gz"}
: ${DEFAULT_RIMD_KERNEL_VERSION:="-6.16"}
: ${DEFAULT_RIMD_IMAGE_FILENAME:="initramfs.linux_arm64.cpio"}
: ${DEFAULT_RIMD_FILESYSTEM_FILENAME:="something.qcow2"}
: ${K3S_VERSION_INSTALL:="v1.32.6+k3s1"}
: ${DEFAULT_GVPROXY:="../../../gvisor-tap-vsock/bin/gvproxy"}

IMAGE_RESTART=0
BIOS_OPTION=""

function check_requirements() {
	ERROR_STR=""
	for REQUIRED in $*
	do
		EXEC_LOCATION=$(type ${REQUIRED} 2>/dev/null || true)
		[ $? -gt 0 -o -z "${EXEC_LOCATION}" ] && ERROR_STR="${ERROR_STR}${REQUIRED} not available, please install it\n"
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
		return
	fi

	# Have to download a new image

	echo "Image ${DEFAULT_IMAGE} does not exist on disk, checking if downloading is needed"
	if [ ! -e "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}" ]
	then
		echo "Downloading image ${DEFAULT_IMAGE_COMPRESSED} from ${DEFAULT_IMAGE_SOURCE_URL}"
		wget -O "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}.download" "${DEFAULT_IMAGE_SOURCE_URL}/${DEFAULT_IMAGE_COMPRESSED}"

		if [ $? -ne 0 ]
		then
			# Remove the file if exists, wget may leave an empty file
			rm "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}.download" 2>/dev/null
			echo "Download unsucceful, bailing out"
			exit 1
		fi
		mv "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}.download" "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE_COMPRESSED}" 2>/dev/null
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

	echo "Image downloaded and available"
}

function check_kernel_image() {
	RIMD_KERNEL_FILENAME=${DEFAULT_RIMD_KERNEL_FILENAME}
	[ ! -z ${DEFAULT_RIMD_KERNEL_VERSION} ] && RIMD_KERNEL_FILENAME="${RIMD_KERNEL_FILENAME}${DEFAULT_RIMD_KERNEL_VERSION}"
	if [ ${IMAGE_RESTART} -eq 0 ]
	then
		if [ -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}" \
			-a -f "${DEFAULT_DIR_IMAGE}/${RIMD_KERNEL_FILENAME}" \
			-a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_IMAGE_FILENAME}" \
			-a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}" ]
		then
			if [ ${ENABLE_KRUNKIT} -eq 0 ]
			then
				echo "Reusing since all the artifacts and original downloaded files exist on ${DEFAULT_DIR_IMAGE}: ${DEFAULT_RIMD_ARTIFACT_FILENAME} ${RIMD_KERNEL_FILENAME} ${DEFAULT_RIMD_IMAGE_FILENAME} ${DEFAULT_RIMD_FILESYSTEM_FILENAME}"
				return
			fi
			if [ -d "${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem" \
				-a -f "${DEFAULT_DIR_IMAGE}/rimd.raw" ]
			then
				echo "Reusing since all the artifacts and original downloaded files exist on ${DEFAULT_DIR_IMAGE}: ${DEFAULT_RIMD_ARTIFACT_FILENAME} ${RIMD_KERNEL_FILENAME} ${DEFAULT_RIMD_IMAGE_FILENAME} ${DEFAULT_RIMD_FILESYSTEM_FILENAME}"
				return
			fi
		fi
	fi
	if [ ${IMAGE_RESTART} -eq 0 -a -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}" ]
	then
		echo "Downloaded artifact ${DEFAULT_RIMD_ARTIFACT_FILENAME} already exists on disk, reusing"
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
		wget -nv "${USER_ID}" "${USER_PASS}" "${USER_TOKEN}" -O "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}.download" "${DEFAULT_RIMD_ARTIFACT_URL}"
		if [ $? -ne 0 ]
		then
			rm "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}.download" 2>/dev/null
			echo "Download unsuccessful, bailing out"
			exit 1
		fi
		mv "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}.download" "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}" 2>/dev/null
	fi
	echo "Processing artifact ${DEFAULT_RIMD_ARTIFACT_FILENAME}"
	if [[ ${DEFAULT_RIMD_ARTIFACT_FILENAME} =~ ^.*\.zip$ ]]
	then
		unzip -o -d "${DEFAULT_DIR_IMAGE}" -x "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}"
	elif [[ ${DEFAULT_RIMD_ARTIFACT_FILENAME} =~ ^.*\.tar.gz$ || ${DEFAULT_RIMD_ARTIFACT_FILENAME} =~ ^.*\.tar.bz2$ ]]
	then
		tar -x -C "${DEFAULT_DIR_IMAGE}" -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_FILENAME}"
	else
		echo "File termination unknown so unable to unpack it, bailing out"
		exit 1
	fi
	if [ ! -f "${DEFAULT_DIR_IMAGE}/${RIMD_KERNEL_FILENAME}" \
	     -o ! -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_IMAGE_FILENAME}" \
	     -o ! -f "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}" ]
	then
		# File was opened but artifacts are in a subdirectory, lets try to get them from there
		if [ ! -e "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_DIR}/${RIMD_KERNEL_FILENAME}" ]
		then
			# Meybe there is not verion, so let's use the non version one
			echo "Kernel requested version ${RIMD_KERNEL_FILENAME} not found on ${DEFAULT_RIMD_ARTIFACT_DIR} from ${DEFAULT_RIMD_ARTIFACT_FILENAME}, trying a non-versioned one"
			RIMD_KERNEL_FILENAME=${DEFAULT_RIMD_KERNEL_FILENAME}
		fi
		mv "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_DIR}/${RIMD_KERNEL_FILENAME}" "${DEFAULT_DIR_IMAGE}/${RIMD_KERNEL_FILENAME}" 2>/dev/null || {
			echo "File ${RIMD_KERNEL_FILENAME} not found on ${DEFAULT_RIMD_ARTIFACT_DIR} from ${DEFAULT_RIMD_ARTIFACT_FILENAME}"
			exit 1
		}
		mv "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_DIR}/${DEFAULT_RIMD_IMAGE_FILENAME}" "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_IMAGE_FILENAME}" 2>/dev/null ||  {
			echo "File ${DEFAULT_RIMD_IMAGE_FILENAME} not found on ${DEFAULT_RIMD_ARTIFACT_DIR} from ${DEFAULT_RIMD_ARTIFACT_FILENAME}"
			exit 1
		}
		mv "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_ARTIFACT_DIR}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}" "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}" 2>/dev/null || {
			echo "File ${DEFAULT_RIMD_FILESYSTEM_FILENAME} not found on ${DEFAULT_RIMD_ARTIFACT_DIR} from ${DEFAULT_RIMD_ARTIFACT_FILENAME}"
			exit 1
		}
	fi

	if [ ${ENABLE_KRUNKIT} -eq 0 ]
	then
		return
	fi

	echo "Creating filesystem for booting on krunkit (rw image with EFI)"
	if [ ! -d "${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem" ]
	then
		echo "Filesystem directory does not exist, creating it"
		mkdir -p "${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem" 
		echo "Copying EFI + grub (debian)"
		tar -xf EFI_GRUB_RIMD.tar.gz -C "${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem" >/dev/null
		echo "Copying kernel + initramfs"
		cp "${DEFAULT_DIR_IMAGE}/${RIMD_KERNEL_FILENAME}" "${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem/boot/Image.gz"
		cp "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_IMAGE_FILENAME}" "${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem/boot/initramfs.linux_arm64.cpio" 
	fi

	sed -i -e 's{\(linux[^/]*/[^ ]*\).*${\1 ip=10.0.2.15::10.0.2.2:255.255.255.0:rimd:eth0:off ENABLE_SSH=true '${EXTRA_APPEND}' '${ADDITIONAL_KERNEL_COMMANDLINE}'{' ${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem/boot/grub/grub.cfg 

	#cat  ${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem/boot/grub/grub.cfg

	echo "Creating raw filesystem"
	hdiutil create -srcfolder ${DEFAULT_DIR_IMAGE}/rimd_raw_filesystem -layout GPTSPUD -volname EFI -fs FAT32 -format UDTO ${DEFAULT_DIR_IMAGE}/rimd || exit 1
	mv ${DEFAULT_DIR_IMAGE}/rimd.cdr ${DEFAULT_DIR_IMAGE}/rimd.raw
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
		echo "Using Darwin machine ${KVM_MACHINE_TYPE} with ${KVM_CPU} CPUs and ${KVM_MEMORY}G"
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

function validate_new_cloud_init() {
	# test if existing configuration exists
	if [ -d "${EXISTING_CLOUD_INIT_DIR}" ]
	then
		# testing if iso file was generated
		if [ -e "${DEFAULT_DIR_IMAGE}/cloud-init.iso" ]
		then
			# Comparing the two configurations
			CONFIG_MODIFIED=$(diff "${NEW_CLOUD_INIT_DIR}" "${EXISTING_CLOUD_INIT_DIR}" 2>/dev/null || true) 
			if [ -z "${CONFIG_MODIFIED}" ]
			then
				rm -rf "${NEW_CLOUD_INIT_DIR}"
				echo "Configuration is the same as it was before so reusing the image"
				return
			fi
		fi
		rm -rf "${EXISTING_CLOUD_INIT_DIR}" "${DEFAULT_DIR_IMAGE}/cloud-init.iso" || true
		echo "Configuration has changed so restart the image"
	fi
	IMAGE_RESTART=1
	mv "${NEW_CLOUD_INIT_DIR}" "${EXISTING_CLOUD_INIT_DIR}"
		
	if [ ${ALWAYS_REUSE_DISK_IMAGE} -gt 0 ]
	then
		IMAGE_RESTART=0
		echo "---------------------------------------"
		echo "System configuration was chenged that requires the VM to restart from an unitialized disk image"
		echo "but ALWAYS_REUSE_DISK_IMAGE is set so the changes will not be reflected on the VM but will appear"
		echo "on the command line"
		echo "---------------------------------------"
	fi
	case ${OS} in
		Darwin)
			rm -f "${DEFAULT_DIR_IMAGE}/cloud-init.iso" || true
			echo "Cloud-init data generated (iso using hdiutil)"
			hdiutil makehybrid -o "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -joliet -iso -default-volume-name cidata "${EXISTING_CLOUD_INIT_DIR}"
			;;
		*)
			rm -f "${DEFAULT_DIR_IMAGE}/cloud-init.iso" || true
			echo "Cloud-init data generated (iso using mkisofs)"
			mkisofs -output "${DEFAULT_DIR_IMAGE}/cloud-init.iso" -input-charset utf-8 -volid cidata -joliet -rock "${EXISTING_CLOUD_INIT_DIR}"
		;;
        esac
}

function cloud_init_create() {
	MOUNT_FILESYSTEM="9P"
	MOUNT_FILESYSTEM_OPTIONS="trans=virtio,version=9p2000.L"
	[ ${ENABLE_KRUNKIT} -gt 0 ] && {
		MOUNT_FILESYSTEM="virtiofs"
		MOUNT_FILESYSTEM_OPTIONS="defaults"
	}
	if [ -d "${NEW_CLOUD_INIT_DIR}" ]
	then
		# If it exists it is leftover from a interrupted installation, so remove it
		rm -rf "${NEW_CLOUD_INIT_DIR}"
	fi
	mkdir -p "${NEW_CLOUD_INIT_DIR}" 
	cat > "${NEW_CLOUD_INIT_DIR}/meta-data" <<EOF
EOF
	cat > "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
#cloud-config
EOF
	VM_MOUNT_POINTS=""
	if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 -o ! -z "${ADDITIONAL_9P_MOUNTS}" ]
	then
		if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 ]
		then
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
				MOUNT_ID=$((${MOUNT_ID}+1))
			done
		fi
	fi
	: ${VM_PASSWORD_ENCRYPTED:=$(echo ${VM_PASSWORD} | openssl passwd -6 -salt ${VM_SALT} -stdin)}
	cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
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
		cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
  ssh_authorized_keys: ['${VM_SSH_AUTHORIZED_KEY}']
EOF
	fi
	cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
hostname: ${VM_HOSTNAME}
create_hostname_file: true
package_reboot_if_required: true
package_update: true
package_upgrade: true
packages:
EOF
	[ ${ENABLE_K3S_DIOD} -gt 0 ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- diod
EOF
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- containerd
- 9mount
EOF
	[ ! -z "${KERNEL_VERSION}" ] &&	cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- ${KERNEL_VERSION}
EOF
	cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
write_files:
EOF
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- content: |
    [Unit]
    Description=TCP proxy for containerd
    After=containerd.service
    
    [Service]
    Environment="PROXY_TO=unix:///run/containerd/containerd.sock"
    Environment="BIND_TO=tcp://0.0.0.0:35000"
    ExecStartPre=/usr/bin/wait_for_mounts.sh
    ExecStart=/usr/bin/csi-grpc-proxy
    
    Type=simple
    Delegate=yes
    KillMode=process
    Restart=always
    RestartSec=5
    TimeoutSec=infinity
    
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
- owner: root:root
  permissions: '0744'
  content: |
    #!/bin/bash
    
    # check if mount exist on fstab
    KUBELET_MOUNT=/var/lib/kubelet
    PODS_MOUNT=/var/log/pods
    
    KUBELET_FSTAB=\$(grep "\${KUBELET_MOUNT}" /etc/fstab)
    PODS_FSTAB=\$(grep "\${PODS_MOUNT}" /etc/fstab)
    
    if [ ! -z "\${KUBELET_FSTAB}" ]
    then
    	findmnt "\${KUBELET_MOUNT}" >/dev/null ||
    	while true
    	do
    		echo "Trying to mount \${KUBELET_MOUNT}"
    		mount "\${KUBELET_MOUNT}"
    		if [ \$? -eq 0 ]
    		then
    			break
    		fi
    		sleep 5
    	done
    fi
    if [ ! -z "\${PODS_FSTAB}" ]
    then
    	findmnt "\${PODS_MOUNT}" >/dev/null ||
    	while true
    	do
    		echo "Trying to mount \${PODS_MOUNT}"
    		mount "\${PODS_MOUNT}"
    		if [ \$? -eq 0 ]
    		then
    			break
    		fi
    		sleep 5
    	done
    fi
    exit 0
  path: /usr/bin/wait_for_mounts.sh
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
	[ ${ENABLE_K3S_DIOD} -gt 0 ] && {
		cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- content: |
    --
    -- /etc/diod.conf - config file for diod distributed I/O daemon
    --
    -- NOTE: This config file is a lua script that diod runs, then extracts
    -- the value of certain globally defined variables.  See diod.conf(5).

    listen = { "0.0.0.0:564" }
    -- nwthreads = 16
    -- auth_required = 1
    auth_required = 0
    -- logdest = "syslog:daemon:err"

    exports = { "/var/lib/kubelet","/var/log/pods" }

    -- allsquash = 0
    -- squashuser = "nobody"
  path: /etc/diod.conf.new
- encoding: b64
  owner: root:root
  permissions: '0744'
  content: |
EOF
                base64 -w 80 -i $SCRIPT_DIR/../add-crismux/install_crismux.sh | sed -e "s/^/    /" >> "${NEW_CLOUD_INIT_DIR}/user-data"

                cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
  path: /usr/bin/install_crismux.sh
EOF
        }
	cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- owner: root:root
  permissions: '0744'
  content: |
    #!/bin/bash
    
    if [ -z "\$1" ]
    then
            exit 0
    fi
    
    mkdir /tmp/install_debs > /dev/null
    cd /tmp/install_debs
    
    DEBS="\$1"
    while [ ! -z "\${DEBS}" ]
    do
            DEBS_USED=\$(echo "\${DEBS}" | cut -d '\$' -f 1)
            DEBS=\$(echo "\${DEBS}" | cut -d '$' -f 2-)
            if [ "\${DEBS}" == "\${DEBS_USED}" ]
            then
                    DEBS=""
            fi
            wget -O debs_install.deb "\${DEBS_USED}"
            if [ -e debs_install.deb ]
            then
                    dpkg -i debs_install.deb
            fi
    done
    exit 0
  path: /usr/bin/install_debs.sh
- owner: root:root
  permissions: '0755'
  content: |
    #!/bin/bash
    
    IFS=";"
    echo -en "\e[18t"
    read -s -n 20 -d "t" t r c
    echo "rows is \$r, cols is \$c"
    stty rows \$r cols \$c
  path: /usr/bin/set-term-size.sh
- content: |
    Hydra VM installed and configured. SSH and csi-grpc-proxy are running.
    You can login on this terminal with username/password provided
    or using ssh with key provided.
  path: /etc/issue.hydra
runcmd:
EOF
	[ ! -z "${INSTALL_ADDITIONAL_DEBS}" ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ /usr/bin/install_debs.sh, "${INSTALL_ADDITIONAL_DEBS}" ]
EOF
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ wget, "${DEFAULT_CSI_GRPC_PROXY_URL}${ARCH}", -O, /usr/bin/csi-grpc-proxy ]
- [ chmod, "a+x", /usr/bin/csi-grpc-proxy ]
- [ bash,"-c","cat /etc/containerd/config.toml.new >> /etc/containerd/config.toml"]
EOF
	cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ bash,"-c","cat /etc/issue.hydra >> /etc/issue"]
EOF
	[ ${ENABLE_K3S_DIOD} -gt 0 ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ bash,"-c","wget -O - https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION_INSTALL} sh -"]
- [ bash,"-c","NELLY_HOSTNAME=10.0.2.2 /usr/bin/install_crismux.sh install"]
- [ bash,"-c","cat /etc/diod.conf.new > /etc/diod.conf"]
- [ bash,"-c","sed -ie 's/DIOD_ENABLE=false/DIOD_ENABLE=true/g' /etc/default/diod"]
- [ systemctl, daemon-reload ]
- [ systemctl, restart, diod ]
EOF
	if [ ! -z "${VM_MOUNT_POINTS}" ]
	then
		cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ mkdir,"-p"${VM_MOUNT_POINTS} ]
EOF
	fi
	if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 ]
	then
		if [ ${EXTERNAL_9P_KUBELET_MOUNTS} -eq 0 ]
		then
			cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ bash,"-c","echo 'host0 /var/lib/kubelet ${MOUNT_FILESYSTEM} ${MOUNT_FILESYSTEM_OPTIONS} 0 0' >> /etc/fstab" ]
- [ bash,"-c","echo 'host1 /var/log/pods ${MOUNT_FILESYSTEM} ${MOUNT_FILESYSTEM_OPTIONS} 0 0' >> /etc/fstab" ]
EOF
		else
			cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ bash,"-c","echo '10.0.2.2 /var/lib/kubelet 9p noauto,uname=root,aname=/var/lib/kubelet,access=user,trans=tcp,port=30564 0 0' >> /etc/fstab" ]
- [ bash,"-c","echo '10.0.2.2 /var/log/pods 9p noauto,uname=root,aname=/var/log/pods,access=user,trans=tcp,port=30564 0 0' >> /etc/fstab" ]
EOF
		fi
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
			cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ bash,"-c","echo 'host${MOUNT_ID} ${MOUNT_VM} ${MOUNT_FILESYSTEM} ${MOUNT_FILESYSTEM_OPTIONS} 0 0' >> /etc/fstab" ]
- [ mount, "host${MOUNT_ID}"]
EOF
			MOUNT_ID=$((${MOUNT_ID}+1))
		done
	fi
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -eq 0 ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ systemctl, enable, csi-grpc-proxy.service ]
- [ systemctl, daemon-reload ]
- [ systemctl, restart, containerd ]
- [ systemctl, start, csi-grpc-proxy.service ]
EOF
	[ ${ENABLE_REBOOT_AFTER_INSTALLATION} -gt 0 ] && cat >> "${NEW_CLOUD_INIT_DIR}/user-data" <<EOF
- [ shutdown, -r, 0 ]
EOF
	cat > "${NEW_CLOUD_INIT_DIR}/vendor-data" <<EOF
EOF
	cat > "${NEW_CLOUD_INIT_DIR}/network-config" <<EOF
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
    enp0s3:
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
    eth0:
      dhcp4: no
      addresses: [10.0.2.15/24]
      nameservers:
           addresses: [10.0.2.2]
      routes:
      - to: 0.0.0.0/0
        via: 10.0.2.2
EOF
}

function check_ports_redirection() {
	[ -z "${DEFAULT_KVM_HOST_SSHD_PORT}" -o ${ENABLE_KRUNKIT} -gt 0 ] || {
		if [ -z "${DEFAULT_KVM_PORTS_REDIRECT}" ] 
		then
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_HOST_SSHD_PORT}:22"
		else
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_PORTS_REDIRECT};${DEFAULT_KVM_HOST_SSHD_PORT}:22"
		fi
	}
	[ ${DISABLE_CONTAINERD_CSI_PROXY} -gt 0 -o -z "${DEFAULT_KVM_HOST_CONTAINERD_PORT}" ] || {
		if [ -z "${DEFAULT_KVM_PORTS_REDIRECT}" ] 
		then
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_HOST_CONTAINERD_PORT}:35000"
		else
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_PORTS_REDIRECT};${DEFAULT_KVM_HOST_CONTAINERD_PORT}:35000"
		fi
	}
	[ ${ENABLE_K3S_DIOD} -eq 0 -o -z "${DEFAULT_KVM_HOST_DIOD_PORT}" ] || {
		if [ -z "${DEFAULT_KVM_PORTS_REDIRECT}" ] 
		then
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_HOST_DIOD_PORT}:564"
		else
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_PORTS_REDIRECT};${DEFAULT_KVM_HOST_DIOD_PORT}:564"
		fi
	}
	[ -z "${DEFAULT_KVM_HOST_RIMD_PORT}" -o ${RUN_BARE_KERNEL} -eq 0 ] || {
		if [ -z "${DEFAULT_KVM_PORTS_REDIRECT}" ] 
		then
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_HOST_RIMD_PORT}:35001"
		else
		       	DEFAULT_KVM_PORTS_REDIRECT="${DEFAULT_KVM_PORTS_REDIRECT};${DEFAULT_KVM_HOST_RIMD_PORT}:35001"
		fi
	}
	if [ -z "${DEFAULT_KVM_PORTS_REDIRECT}" ]
	then
		return
	fi
	if [[ ! ${DEFAULT_KVM_PORTS_REDIRECT} =~ ^([1-9][0-9]+:[[1-9][0-9]+;)*[1-9][0-9]+:[[1-9][0-9]+$ ]]
	then
		echo "Incorrect format for DEFAULT_KVM_PORTS_REDIRECT. It should be either empty, <Port externali>:<Port internal> or sequence of redirects separated by ;."
		exit -1
	fi
	if [ ${ENABLE_KRUNKIT} -gt 0 ]
	then
		return
	fi
	REDIRECT_PORT=""
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
	VM_SSH_AUTHORIZED_KEY=$(cat "${VM_SSH_KEY_FILENAME}" 2>/dev/null || true)
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
	if [ -z "${KVM_BIOS}" ]
	then
		return
	fi

	if [ ! -e "${KVM_BIOS}" ]
	then
		echo "Bios requested \"${KVM_BIOS}\" not found"
		exit 1
	fi
	BIOS_OPTION="-drive if=pflash,format=raw,readonly=on,file=${KVM_BIOS}"
	if [ -z "${KVM_BIOS_VAR}" ]
	then
		return
	fi
	if [ ! -e "${KVM_BIOS_VAR}" ]
	then
		echo "Bios requested \"${KVM_BIOS_VAR}\" not found"
		exit 1
	fi
	KVM_BIOS_VAR_LOCAL=$(basename "${KVM_BIOS_VAR}")
	cp "${KVM_BIOS_VAR}" "${DEFAULT_DIR_IMAGE}/${KVM_BIOS_VAR_LOCAL}"
	BIOS_OPTION="${BIOS_OPTION}
 -drive if=pflash,format=raw,file=${DEFAULT_DIR_IMAGE}/${KVM_BIOS_VAR_LOCAL}"
}

function check_mount_filesystems() {
	VIRTFS_9P_SECURITY_MODEL="passthrough"
	if [ "${OS}" == "Darwin" ]
	then
		VIRTFS_9P_SECURITY_MODEL="mapped"
	fi
	VIRTFS_9P=""
	if [ ${DISABLE_9P_KUBELET_MOUNTS} -eq 0 -a ${EXTERNAL_9P_KUBELET_MOUNTS} -eq 0 ]
	then
		if [ ${ENABLE_KRUNKIT} -eq 0 ]
		then
			VIRTFS_9P='-virtfs local,path='${DIR_K3S_VAR}/var/lib/kubelet',mount_tag=host0,security_model='${VIRTFS_9P_SECURITY_MODEL}',id=host0
 -virtfs local,path='${DIR_K3S_VAR}/var/log/pods',mount_tag=host1,security_model='${VIRTFS_9P_SECURITY_MODEL}',id=host1'
 		else
			VIRTFS_9P='--device virtio-fs,sharedDir='${DIR_K3S_VAR}/var/lib/kubelet',mountTag=host0
 --device virtio-fs,sharedDir='${DIR_K3S_VAR}/var/log/pods',mountTag=host1'
		fi
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
			if [ ${ENABLE_KRUNKIT} -eq 0 ]
			then
				VIRTFS_9P=${VIRTFS_9P}'-virtfs local,path='${MOUNT_HOST}',mount_tag=host'${MOUNT_ID}',security_model='${VIRTFS_9P_SECURITY_MODEL}',id=host'${MOUNT_ID}
			else
				VIRTFS_9P='--device virtio-fs,sharedDir='${MOUNT_HOST}',mountTag=host'${MOUNT_ID}
			fi
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

function check_if_vsock_device_enabled() {
	VSOCK_DEVICE=""
	if [ "${OS}" != "Darwin" -a ${ENABLE_VSOCK_LINUX} -gt 0 ]
	then
		VSOCK_DEVICE="-device vhost-vsock-pci,id=vhost-vsock-pci0,guest-cid=3"
	fi
}

function check_if_9p_remote_local_bare_kernel(){
	if [ ${EXTERNAL_9P_KUBELET_MOUNTS} -eq 0 ]
	then
		EXTRA_APPEND="9P_TRANSPORT=virtio"
	else
		EXTRA_APPEND="9P_TRANSPORT=tcp"
	fi
}

function create_tmp_socket_krunkit(){
	if [  -d "${DEFAULT_DIR_TMP_SOCKET}" ]
	then
		echo "Image directory '${DEFAULT_DIR_TMP_SOCKET}' exists, removing"
		rm -rf "${DEFAULT_DIR_TMP_SOCKET}" || true
	else
		echo "Image directory '${DEFAULT_DIR_TMP_SOCKET}' does not exist, trying to create"
	fi
	mkdir -p "${DEFAULT_DIR_TMP_SOCKET}" || exit $?
	if [ $? -ne 0 ]
	then
		echo "Image directory '${DEFAULT_DIR_TMP_SOCKET}' could not be created, bailing out"
		exit 1
	fi
}

function krunkitcleanup()
{
	echo "killing all processes krunkit (${KRUNKITPID}) and gvproxy (${GVPROXYPID})"
	kill ${KRUNKITPID} ${GVPROXYPID} 2>/dev/null || true
	wait ${KRUNKITPID} ${GVPROXYPID} 2>/dev/null || true
}

# ----- Main -------------------------------------------------------------------------------------

if [ ${ENABLE_KRUNKIT} -eq 0 ]
then
	# Using QEMU
	check_requirements qemu-system-${ARCH_M} qemu-img

	check_kvm_version

	check_kvm_memory_cpu

	check_kvm_kvm_hvf

	check_if_bios_needed
else
	check_requirements krunkit "${DEFAULT_GVPROXY}"

	check_kvm_memory_cpu
fi

if [ ${RUN_BARE_KERNEL} -eq 0 ]
then
	if [ ${OS} == "Darwin" ]
	then
		check_requirements wget
	else
		check_requirements mkisofs wget
	fi
fi

check_ports_redirection

check_image_directory

check_ssh_authorized_key

if [ ${RUN_BARE_KERNEL} -eq 0 ]
then
	NEW_CLOUD_INIT_DIR="${DEFAULT_DIR_IMAGE}/cloud-init.dir.new"
	EXISTING_CLOUD_INIT_DIR="${DEFAULT_DIR_IMAGE}/cloud-init.dir"

	cloud_init_create

	validate_new_cloud_init

	check_image_exists
else
	check_if_9p_remote_local_bare_kernel
	check_if_vsock_device_enabled
	check_kernel_image
fi

check_k3s_log_pods_dir


if [ ${RUN_BARE_KERNEL} -eq 0 ]
then
	resize_kvm_image "${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}"
else
	resize_kvm_image "${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}"
fi

check_mount_filesystems

check_gpu_options

APPEND=""

if [ ${ENABLE_KRUNKIT} -eq 0 ]
then
	if [ ${RUN_BARE_KERNEL} -eq 0 ]
	then
		CMD_LINE='qemu-system-'${ARCH_M}'
 -m '${KVM_MEMORY}'g
 -smp '${KVM_CPU}'
 -M '${KVM_MACHINE_TYPE}'
 '${HW_ACCEL}'
 -pidfile '${PIDFILE}'
 '${BIOS_OPTION}'
 -cpu '${KVM_CPU_TYPE}'
 -drive if=none,format=qcow2,file='${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}',id=hd0
 -drive file='${DEFAULT_DIR_IMAGE}/cloud-init.iso',index=1,media=cdrom
 -object rng-random,id=rng0,filename=/dev/urandom
 -device virtio-rng-pci,rng=rng0,max-bytes=1048576,period=1000
 -device virtio-blk-pci,drive=hd0
 -device virtio-net-pci,netdev=net0,mac=52:54:00:08:06:8b
 -netdev user,id=net0'${REDIRECT_PORT}'
 '${VIRTFS_9P}'
 '${VIRTIO_GPU}'
 '${KVM_NOGRAPHIC}
	else
		APPEND_OPTIONS="ip=10.0.2.15::10.0.2.2:255.255.255.0:rimd:eth0:off console=/dev/ttyAMA0 ENABLE_SSH=true ${EXTRA_APPEND} ${ADDITIONAL_KERNEL_COMMANDLINE}"
		APPEND="-append"

		CMD_LINE='qemu-system-'${ARCH_M}'
 -m '${KVM_MEMORY}'g
 -M '${KVM_MACHINE_TYPE}',gic-version=max
 -smp '${KVM_CPU}'
 '${HW_ACCEL}'
 -pidfile '${PIDFILE}'
 -cpu '${KVM_CPU_TYPE}'
 '${BIOS_OPTION}'
 -kernel '${DEFAULT_DIR_IMAGE}/${RIMD_KERNEL_FILENAME}'
 -netdev user,id=n1'${REDIRECT_PORT}'
 -device virtio-net-pci,netdev=n1,mac=52:54:00:94:33:ca
 -object rng-random,id=rng0,filename=/dev/urandom
 -device virtio-rng-pci,rng=rng0,max-bytes=1048576,period=1000
 '${VSOCK_DEVICE}'
 -initrd '${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_IMAGE_FILENAME}'
 -drive if=none,id=drive1,format=qcow2,file='${DEFAULT_DIR_IMAGE}/${DEFAULT_RIMD_FILESYSTEM_FILENAME}'
 -device virtio-blk-device,id=drv0,drive=drive1
 -serial mon:stdio
 '${VIRTFS_9P}'
 '${VIRTIO_GPU}'
 '${KVM_NOGRAPHIC}
	# -serial mon:stdio
	fi

	if [ ! -z "${APPEND}" ]
	then
		echo "${CMD_LINE}
	  ${APPEND} ${APPEND_OPTIONS}"
	else
		echo "${CMD_LINE}"
	fi

	[ ${DRY_RUN_ONLY} -gt 0 ] && exit 0

	if [ ! -z "${APPEND}" ]
	then
		exec ${CMD_LINE} ${APPEND} "${APPEND_OPTIONS}"
	else
		exec ${CMD_LINE}
	fi
else
	create_tmp_socket_krunkit


	GVPROXY_NETWORKPREFIX="10.0.2"
	GVPROXY_NETWORK=${GVPROXY_NETWORKPREFIX}".0/24"
	GVPROXY_HOSTIP=${GVPROXY_NETWORKPREFIX}".2"
	GVPROXY_GATEWAYIP=${GVPROXY_NETWORKPREFIX}".2"
	GVPROXY_DEVICEIP=${GVPROXY_NETWORKPREFIX}".15"

	rm -f "${DEFAULT_DIR_IMAGE}/gvproxy.pid" "${DEFAULT_DIR_IMAGE}/gvproxy.log" || true

	GVPROXYCMDLINE=${DEFAULT_GVPROXY}'
	 -mtu 1500 
	 --listen unix://'${DEFAULT_DIR_TMP_SOCKET}'/network.sock 
	 -listen-vfkit unixgram://'${DEFAULT_DIR_TMP_SOCKET}/gvproxy.sock'
	 -ssh-port '${DEFAULT_KVM_HOST_SSHD_PORT}'
	 -pid-file '${DEFAULT_DIR_IMAGE}'/gvproxy.pid
	 -log-file '${DEFAULT_DIR_IMAGE}'/gvproxy.log
	 -deviceIP '${GVPROXY_DEVICEIP}'
	 -gatewayIP '${GVPROXY_GATEWAYIP}'
	 -hostIP '${GVPROXY_HOSTIP}'
	 -subnetIP '${GVPROXY_NETWORK}

	echo "${GVPROXYCMDLINE}"

	[ ${DRY_RUN_ONLY} -eq 0 ] && {
		${GVPROXYCMDLINE}&

		echo "Waiting for gvproxy"
		sleep 2

		GVPROXYPID=$(cat "${DEFAULT_DIR_IMAGE}/gvproxy.pid" 2>/dev/null || true)
		if [ -z ${GVPROXYPID} ]
		then
			echo "gvproxy failed, please look at log at ${DEFAULT_DIR_IMAGE}/gvproxy.log"
			exit 1
		fi
		GVPROXY_RUNNING=$(ps -efp ${GVPROXYPID} || true)
		if [ -z "${GVPROXY_RUNNING}" ]
		then
			echo "gvproxy failed, please look at log at ${DEFAULT_DIR_IMAGE}/gvproxy.log"
			exit 1
		fi

		trap krunkitcleanup EXIT

		PORTS_TO_OPEN="${DEFAULT_KVM_PORTS_REDIRECT}"
		PORT_ID=100
		PORTS_JSON=""
		while [ ! -z "${PORTS_TO_OPEN}" ]
		do
			PORT_TO_OPEN=$(echo "${PORTS_TO_OPEN}" | cut -d ';' -f 1)
			PORTS_TO_OPEN=$(echo "${PORTS_TO_OPEN}" | cut -d ';' -f 2-)
			if [ "${PORT_TO_OPEN}" == "${PORTS_TO_OPEN}" ]
			then
				PORTS_TO_OPEN=""
			fi
			PORT_HOST=$(echo "${PORT_TO_OPEN}" | cut -d ':' -f 1)
			PORT_VM=$(echo "${PORT_TO_OPEN}" | cut -d ':' -f 2)
			if [ -z "${PORT_HOST}" -o -z "${PORT_HOST}" ]
			then
				echo "Incorrect specification of ports in this '${PORT_TO_OPEN}'"
				exit 1
			fi
			PORT_JSON='{"local":":'${PORT_HOST}'","remote":"'${GVPROXY_DEVICEIP}':'${PORT_VM}'"}'
			curl  -s --unix-socket ${DEFAULT_DIR_TMP_SOCKET}/network.sock http:/unix/services/forwarder/expose -X POST -d "${PORT_JSON}"
			PORT_ID=$((${PORT_ID}+1))
		done

		echo "Ports configured on gvproxy, below is a list of enabled ports"

		curl  -s --unix-socket ${DEFAULT_DIR_TMP_SOCKET}/network.sock http:/unix/services/forwarder/all | jq .
	}

	if [ ${RUN_BARE_KERNEL} -eq 0 ]
	then
		IMAGE_FORMAT=qcow2
		CMD_LINE='krunkit 
 --krun-log-level 3 
 --cpus '${KVM_CPU}'
 --memory '$((${KVM_MEMORY}*1024))'
 --bootloader efi,variable-store='${DEFAULT_DIR_IMAGE}/efi-bl-krunkit,create' 
 --device virtio-serial,logFilePath='${DEFAULT_DIR_IMAGE}/vm-output.log'
 --device virtio-blk,path='${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}',format='${IMAGE_FORMAT}'
 --device virtio-blk,path='${DEFAULT_DIR_IMAGE}/cloud-init.iso',format=raw 
 --device virtio-rng 
 --restful-uri tcp://localhost:'${KRUNKIT_HTTP_PORT}'
 --device virtio-net,unixSocketPath='${DEFAULT_DIR_TMP_SOCKET}/gvproxy.sock',mac=5a:94:ef:e4:0c:ee 
 --device virtio-vsock,port=1025,socketURL='${DEFAULT_DIR_IMAGE}/krunkit.sock',listen 
 --device virtio-vsock,port=1024,socketURL='${DEFAULT_DIR_IMAGE}/krunkit-ignition.sock',listen
 '${VIRTFS_9P}
 #--device virtio-blk,path='${DEFAULT_DIR_IMAGE}/${DEFAULT_IMAGE}',format='${IMAGE_FORMAT}'
	else
		IMAGE_FORMAT=raw
		CMD_LINE='krunkit 
 --krun-log-level 3 
 --cpus '${KVM_CPU}'
 --memory '$((${KVM_MEMORY}*1024))'
 --bootloader efi,variable-store='${DEFAULT_DIR_IMAGE}/efi-bl-krunkit,create' 
 --device virtio-serial,logFilePath='${DEFAULT_DIR_IMAGE}/vm-output.log'
 --device virtio-blk,path='${DEFAULT_DIR_IMAGE}/rimd.raw',format='${IMAGE_FORMAT}'
 --device virtio-blk,path='${DEFAULT_DIR_IMAGE}/something.qcow2',format=qcow2
 --device virtio-rng 
 --restful-uri tcp://localhost:'${KRUNKIT_HTTP_PORT}'
 --device virtio-net,unixSocketPath='${DEFAULT_DIR_TMP_SOCKET}/gvproxy.sock',mac=5a:94:ef:e4:0c:ee 
 --device virtio-vsock,port=1025,socketURL='${DEFAULT_DIR_IMAGE}/krunkit.sock',listen 
 --device virtio-vsock,port=1024,socketURL='${DEFAULT_DIR_IMAGE}/krunkit-ignition.sock',listen
 '${VIRTFS_9P}
 	fi

	if [ ! -z "${APPEND}" ]
	then
		echo "${CMD_LINE}
	  ${APPEND} ${APPEND_OPTIONS}"
	else
		echo "${CMD_LINE}"
	fi

	[ ${DRY_RUN_ONLY} -eq 0 ] && {

		if [ ! -z "${APPEND}" ]
		then
			${CMD_LINE} ${APPEND} "${APPEND_OPTIONS}"&
			KRUNKITPID=$!
		else
			${CMD_LINE}&
			KRUNKITPID=$!
		fi
		wait ${KRUNKITPID}
	}
fi

exit 0
