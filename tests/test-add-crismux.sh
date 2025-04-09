#!/bin/bash

# docker run \
#	--env DEBUG=1 \
#	--privileged \
#	-v /bin/systemctl:/bin/systemctl \
#	-v /lib:/lib \
#	-v /sys/fs/cgroup:/sys/fs/cgroup \
#	-v /var/lib/rancher:/var/lib/rancher \
#	-v /etc/systemd:/etc/systemd \
#	-v /run/systemd/system:/run/systemd/system \
#	-v /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
#	-it add-crismux

docker run \
	--privileged \
	-v /bin/systemctl:/bin/systemctl \
	-v /lib:/lib \
	-v /sys/fs/cgroup:/sys/fs/cgroup \
	-v /var/lib/rancher:/var/lib/rancher \
	-v /etc/systemd:/etc/systemd \
	-v /run/systemd/system:/run/systemd/system \
	-v /run/k3s:/run/k3s \
	-v /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
	-it add-crismux $1
