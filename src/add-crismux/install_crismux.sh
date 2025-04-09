#!/bin/bash

: ${DEBUG:=0}
[ ${DEBUG} -gt 0 ] && set -x
: ${SYSTEMD_DIR:="/etc/systemd/system"}
: ${K3S_SERVICE_FILE:="${SYSTEMD_DIR}/k3s.service"}
: ${K3S_DATA_DIR:="/var/lib/rancher/k3s"}
: ${K3S_SOCKET_DIR:="/run/k3s/containerd"}
: ${CRISMUX_SERVICE_FILE:="${SYSTEMD_DIR}/crismux.service"}
: ${CRISMUX_CONFIG_DIR:="${K3S_DATA_DIR}/agent/etc/crismux"}
: ${CRISMUX_CONFIG_FILE:="${CRISMUX_CONFIG_DIR}/config.yaml"}
: ${CRISMUX_EXECUTABLE_FILE:="${K3S_DATA_DIR}/data/current/bin/crismux"}
: ${CRISMUX_SOCKET_FILE:="${K3S_SOCKET_DIR}/crismux.sock"}
: ${CRISMUX_ARTIFACT_URL:=""}
: ${CRISMUX_ARTIFACT_LOCAL:="$(pwd)/crismux"}
: ${CONTAINERD_SERVICE_NAME:="containerd-k3s"}
: ${CONTAINERD_SERVICE_FILE:="${SYSTEMD_DIR}/${CONTAINERD_SERVICE_NAME}.service"}
: ${CONTAINERD_K3S_EXECUTABLE:="${K3S_DATA_DIR}/data/current/bin/containerd"}
: ${CONTAINERD_K3S_CONFIG:="${K3S_DATA_DIR}/agent/etc/containerd/config.toml"}
: ${CONTAINERD_K3S_CRIS_CONFIG:="${K3S_DATA_DIR}/agent/etc/containerd/config-crismux.toml"}
: ${CONTAINERD_SOCKET_FILE:="${K3S_SOCKET_DIR}/containerd-crismux.sock"}

function modify_existing_k3s() {
	if [ ! -f "${K3S_SERVICE_FILE}" ]
	then
		echo "k3s service not installed because file ${K3S_SERVICE_FILE} not found"
		exit 1
	fi

	# Change k3s service to point to crismux 

	CONTAINER_RUNTIME=$(grep -- "--container-runtime-endpoint" "${K3S_SERVICE_FILE}")
	if [ ! -z "${CONTAINER_RUNTIME}" ]
	then
		echo "k3s service already modified"
		K3S_MODIFIED=0
	else
		if [ -f "${K3S_SERVICE_FILE}".old ]
		then
			echo "Something is weird, bailing since file ${K3S_SERVICE_FILE}.old alrwady exists"
			exit  1
		fi

		cp "${K3S_SERVICE_FILE}" "${K3S_SERVICE_FILE}".old
		sed -e "s#^\([ \t]*\)\(server \)\([\]\)#\1\2\3\n\1    '--container-runtime-endpoint'  '${CRISMUX_SOCKET_FILE}' \3#"  \
		    -e "s#^\(After=network-online.target\)#\1\nAfter=crismux#" \
			"${K3S_SERVICE_FILE}".old > "${K3S_SERVICE_FILE}"
		K3S_MODIFIED=1
	fi
}


function revert_existing_k3s() {
	if [ ! -f "${K3S_SERVICE_FILE}" ]
	then
		echo "k3s service does not exist because file ${K3S_SERVICE_FILE} not found"
		exit 1
	fi

	# Change k3s service to point to crismux 

	CONTAINER_RUNTIME=$(grep -- "--container-runtime-endpoint" "${K3S_SERVICE_FILE}")
	if [ -z "${CONTAINER_RUNTIME}" ]
	then
		echo "k3s service not modified so not changing anything"
		rm "${K3S_SERVICE_FILE}".old 2>/dev/null
		K3S_MODIFIED=0
	else
		if [ ! -f "${K3S_SERVICE_FILE}".old ]
		then
			echo "Something is weird, bailing since file ${K3S_SERVICE_FILE}.old does not exist"
			exit  1
		fi

		mv "${K3S_SERVICE_FILE}".old "${K3S_SERVICE_FILE}"
		K3S_MODIFIED=1
	fi
}

function check_k3s_modified() {
	if [ ! -f "${K3S_SERVICE_FILE}" ]
	then
		echo "k3s service does not exist because file ${K3S_SERVICE_FILE} not found"
		exit 1
	fi

	# check if k3s service to point to crismux 

	CONTAINER_RUNTIME=$(grep -- "--container-runtime-endpoint" "${K3S_SERVICE_FILE}")
	if [ -z "${CONTAINER_RUNTIME}" ]
	then
		echo "k3s service not modified"
		return
	fi
	echo "k3s service modified"
	if [ ! -f "${K3S_SERVICE_FILE}".old ]
	then
		echo "Something is weird beacuse file ${K3S_SERVICE_FILE}.old does not exist but original is modified"
		exit  1
	fi
}

function add_containerd() {
	if [ -f "${CONTAINERD_SERVICE_FILE}" ]
	then
		echo "containerd service already installed"
	else
		sed -e "s[${K3S_SOCKET_DIR}/containerd.sock[${CONTAINERD_SOCKET_FILE}[" "${CONTAINERD_K3S_CONFIG}" > "${CONTAINERD_K3S_CRIS_CONFIG}"
		cat << EOF > "${CONTAINERD_SERVICE_FILE}"
[Unit]
Description=Containerd from k3s 
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/etc/systemd/system/containerd.service.env
KillMode=process
Delegate=yes
User=root
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStart=${K3S_DATA_DIR}/data/current/bin/containerd \\
	'-c' \\
	'${CONTAINERD_K3S_CRIS_CONFIG}' \\

EOF
	fi
}

function remove_containerd() {
	if [ ! -f "${CONTAINERD_SERVICE_FILE}" ]
	then
		echo "containerd-k3s not installed"
	else
		rm -f "${CONTAINERD_K3S_CRIS_CONFIG}" "${CONTAINERD_SERVICE_FILE}"
	fi
}

function ckeck_containerd() {
	if [ -f "${CONTAINERD_SERVICE_FILE}" -a -f "${CONTAINERD_K3S_CRIS_CONFIG}" ]
	then
		echo "containerd-k3s installed"
		return
	fi
	if [ ! -f "${CONTAINERD_SERVICE_FILE}" -a ! -f "${CONTAINERD_K3S_CRIS_CONFIG}" ]
	then
		echo "containerd-k3s not installed"
		return
	fi
	echo "containerd-k3s partially installed"
	echo -n "  -${CONTAINERD_K3S_CRIS_CONFIG} "
	if [ ! -f "${CONTAINERD_K3S_CRIS_CONFIG}" ]
	then	
		echo " does not exist"
	else
		echo " exists"
	fi
	echo -n "  -${CONTAINERD_SERVICE_FILE} "
	if [ ! -f "${CONTAINERD_SERVICE_FILE}" ]
	then	
		echo " does not exist"
	else
		echo " exists"
	fi
	exit 1
}

function add_crismux() {
	if [ -f "${CRISMUX_SERVICE_FILE}" ]
	then
		echo "crismux service already installed"
	else
		if [ ! -d "${CRISMUX_CONFIG_DIR}" ]
		then
			mkdir "${CRISMUX_CONFIG_DIR}"
			if [ $? -gt 0 ]
			then
				echo "Confiuration directory ${CRISMUX_CONFIG_DIR} of crismux invalid"
				exit 1
			fi
		fi
		if [ ! -z "${CRISMUX_ARTIFACT_URL}" ]
		then
			wget -O ${CRISMUX_EXECUTABLE_FILE} "${CRISMUX_ARTIFACT_URL}"
			if [ $? -gt 0 ]
			then
				echo "getting ${CRISMUX_EXECUTABLE_FILE} from ${CRISMUX_ARTIFACT_URL} failed"
				exit 1
			fi
		elif [ ! -z "${CRISMUX_ARTIFACT_LOCAL}" ]
		then
			cp "${CRISMUX_ARTIFACT_LOCAL}" "${CRISMUX_EXECUTABLE_FILE}"
			chmod a+x "${CRISMUX_EXECUTABLE_FILE}"
		else
			echo "Do not have access to crismux plese set either CRISMUX_ARTIFACT_LOCAL or CRISMUX_ARTIFACT_URL"
			exit 1
		fi
		cat << EOF > "${CRISMUX_CONFIG_FILE}"
runtimes:
  default: "unix://${CONTAINERD_SOCKET_FILE}"
# This is the runtime for the secure containers
  nelly:   "tcp:localhost:35000"
tls:
  cert: "/path/to/cert.pem"
  key: "/path/to/key.pem"
  ca: "/path/to/ca.pem"
EOF
		cat << EOF > "${CRISMUX_SERVICE_FILE}"
[Unit]
Description=Crismux for k3s
Wants=network-online.target
After=network-online.target
After=containerd-k3s

[Install]
WantedBy=multi-user.target

[Service]
Type=exec
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/etc/systemd/system/crismux.service.env
KillMode=process
Delegate=yes
User=root
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc 'rm -f ${CRISMUX_SOCKET_FILE}'
ExecStart=${CRISMUX_EXECUTABLE_FILE} \
	'-config' \
	'${CRISMUX_CONFIG_FILE}' \
	'-socket' \
	'${CRISMUX_SOCKET_FILE}' \

EOF
	fi
}

function remove_crismux() {
	if [ ! -f "${CRISMUX_SERVICE_FILE}" ]
	then
		echo "crismux not installed"
	else
		rm -f "${CRISMUX_SERVICE_FILE}" "${CRISMUX_EXECUTABLE_FILE}" "${CRISMUX_SOCKET_FILE}" 
		rm -rf "${CRISMUX_CONFIG_DIR}"
	fi
}

function check_crismux() {
	if [ -f "${CRISMUX_SERVICE_FILE}" -a -f "${CRISMUX_EXECUTABLE_FILE}" -a -e "${CRISMUX_CONFIG_FILE}" ]
	then 
		echo "crismux installed"
		return
	fi
	if [ ! -f "${CRISMUX_SERVICE_FILE}" -a ! -f "${CRISMUX_EXECUTABLE_FILE}" -a ! -e "${CRISMUX_CONFIG_FILE}" ]
	then 
		echo "crismux not installed"
		return
	fi
	echo "crismux partially installed"
	echo -n "  -${CRISMUX_SERVICE_FILE} "
	if [ ! -f "${CRISMUX_SERVICE_FILE}" ]
	then	
		echo " does not exist"
	else
		echo " exists"
	fi
	echo -n "  -${CRISMUX_EXECUTABLE_FILE} "
	if [ ! -f "${CRISMUX_EXECUTABLE_FILE}" ]
	then	
		echo " does not exist"
	else
		echo " exists"
	fi
	echo -n "  -${CRISMUX_CONFIG_FILE} "
	if [ ! -e "${CRISMUX_CONFIG_FILE}" ]
	then	
		echo " does not exist"
	else
		echo " exists"
	fi
	exit 1
}

function start_services() {
	systemctl daemon-reload
	systemctl stop -f k3s
	i=0
	while [ $i -lt 12 ]
	do
		STATUS=$(systemctl show $1)
		if [ $? -gt 0 ]
		then
			echo "Something wrong with systemctl ${STATUS}"
			exit 1
		fi
		STATUS_SERVICES=$(echo "${STATUS}" | grep SubState | cut -d "=" -f 2)
		if [ "x${STATUS_SERVICES}" != "xrunning" ]
		then
			break
		fi
		sleep 5
		i=$(($i+1))
	done
	systemctl enable containerd-k3s crismux
	systemctl start k3s containerd-k3s crismux
}

function stop_service() {
	STATUS=$(systemctl show $1)
	if [ $? -gt 0 ]
	then
		echo "Something wrong with systemctl ${STATUS}"
		exit 1
	fi
	LOAD_STATUS_SERVICE=$(echo "${STATUS}" | grep LoadState | cut -d "=" -f 2)
	UNIT_STATUS_SERVICE=$(echo "${STATUS}" | grep UnitFileState | cut -d "=" -f 2)
	ACTIVE_STATUS_SERVICE=$(echo "${STATUS}" | grep ActiveState | cut -d "=" -f 2)
	SUB_STATUS_SERVICE=$(echo "${STATUS}" | grep SubState | cut -d "=" -f 2)
	if [ "x${UNIT_STATUS_SERVICE}" == "xenabled" ]
	then
		systemctl disable $1
	fi
	if [ "x${LOAD_STATUS_SERVICE}" == "xloaded" -o "x${ACTIVE_STATUS_SERVICE}" == "xactive" -o "x${SUB_STATUS_SERVICE}" == "xrunning" ]
	then
		systemctl stop -f $1
	fi
}

function report_status_service() {
	STATUS=$(systemctl show $1)
	if [ $? -gt 0 ]
	then
		echo "Something wrong with systemctl ${STATUS}"
		exit 1
	fi
	STATUS_SERVICES=$(echo "${STATUS}" | grep UnitFileState | cut -d "=" -f 2)
	: ${STATUS_SERVICES:="not installed"}
	STATUS_STATE=$(echo "${STATUS}" | grep ActiveState | cut -d "=" -f 2)
	STATUS_RUN=$(echo "${STATUS}" | grep SubState | cut -d "=" -f 2)
	echo "$1 service is ${STATUS_SERVICES}, ${STATUS_STATE} and ${STATUS_RUN}"
}

function execute_install() {
	modify_existing_k3s
	add_containerd
	add_crismux
	: ${K3S_MODIFIED:=0}
	if [ ${K3S_MODIFIED} -gt 0 ]
	then
		start_services
	else
		report_status_service k3s
		report_status_service crismux
		report_status_service containerd-k3s
	fi
}

function execute_verify() {
	check_k3s_modified
	report_status_service k3s
	check_crismux
	report_status_service crismux
	ckeck_containerd
	report_status_service containerd-k3s
}

function execute_clean() {
	stop_service containerd-k3s
	stop_service crismux
	revert_existing_k3s
	remove_crismux
	remove_containerd
	: ${K3S_MODIFIED:=0}
	if [ ${K3S_MODIFIED} -gt 0 ]
	then
		systemd stop k3s
		systemd daemon-reload
		systemd start k3s
	fi
}

function usage() {
        echo -e "Usage: $0 <command>\n" \
             "   commands available: clean, install, verify\n" \
             1>&2
        exit 1
}

while getopts ":" o; do
    case "${o}" in
        r)
            EXECUTE=1
            ;;
        k)
            SSH_KEY=${OPTARG}
            ;;
        e)
            K3SUP=${OPTARG}
            ;;
        u)
            USER_ACCESS=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

COMMAND=verify
[ $# -gt 0 ] && COMMAND=$1

case $COMMAND in
	clean)
		execute_clean;;
	install)
		execute_install;;
	verify)
		execute_verify;;
	*)
		usage;;
esac

exit 0

