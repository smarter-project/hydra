#!/bin/bash

SYSTEMD_DIR="/etc/systemd/system"
K3S_SERVICE_FILE="${SYSTEMD_DIR}/k3s.service"
CRISMUX_SERVICE_FILE="${SYSTEMD_DIR}/crismux.service"
CONTAINERD_SERVICE_FILE="${SYSTEMD_DIR}/containerd.service"
K3S_DATA_DIR="/var/lib/rancher/k3s"
CONTAINERD_K3s_EXECUTABLE="${K3S_DATA_DIR}/data/current/bin/containerd"
CONTAINERD_K3s_CONFIG="${K3S_DATA_DIR}/agent/etc/containerd/config.toml"
CONTAINERD_K3s_CRIS_CONFIG="${K3S_DATA_DIR}/agent/etc/containerd/config-cris.toml"

if [ ! -f "${K3S_SERVICE_FILE}" ]
then
	echo "k3s service not installed because file "${K3S_SERVICE_FILE}" not found"
	exit 1
fi

# Change k3s service to point to crismux 

CONTAINER_RUNTIME=$(grep -- "--container-runtime-endpoint" "${K3S_SERVICE_FILE}"
if [ ! -z "${CONTAINER_RUNTIME}" ]
then
	echo "k3s service already modified"
else
	if [ -f "${K3S_SERVICE_FILE}".old ]
	rhen
		echo "Something is weird, bailing sice file "${K3S_SERVICE_FILE}".old alrwady exists"
		exit  1
	fi

	cp "${K3S_SERVICE_FILE}" "${K3S_SERVICE_FILE}".old
	sed -e "s#^\([ \t]*\)\(server \)\([\]\)#\1\2\3\n\1    '--container-runtime-endpoint'  '/run/k3s/containerd/crismux.sock' \3#" "${K3S_SERVICE_FILE}"
fi

if [ -f "${CRISMUX_SERVICE_FILE}" ]
then
	echo "crismux service already installed"
else
	sed -e "s/containerd.sock/containerd-cris.sock/" "%{CONTAINERD_K3s_CONFIG }" > "${CONTAINERD_K3s_CRIS_CONFIG}"
	cat << EOF > "${CRISMUX_SERVICE_FILE}"
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
ExecStart=${K3S_DATA_DIR}/data/current/bin/containerd \
	'-c' \
	'${CONTAINERD_K3s_CRIS_CONFIG}' \

EOF
fi
