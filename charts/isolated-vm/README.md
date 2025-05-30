# home-orchestrator

This chart deploys crismux

## TL;DR

```console
helm repo add isolated-vm https://smarter-project.github.io/cdd-crismux/
helm install --create-namespace --namespace <namespace to use> isolated-vm hydra/isolated-vm
```

# Overview

Crismux allows more that one containerd to be connected to kubelet

# Prerequisites

This chart assumes a full deployment of k3s with traefik, etc.

* k3s 1.25+
* Helm 3.2.0+

# Uninstalling the Chart

```
helm delete isolated-vm --namespace <namespace to use>
```

# Parameters

## Common parameters

| Name | Description | Value |
| ---- | ----------- | ----- |
| configuration.sshkey | Public ssh key to enable access to the VM (user hailhydra) | |
| configuration.local_node_image_dir | /srv/shared-container-volumes/image | |
| configuration.debug | | |
| configuration.dry_run_only | | |
| configuration.copy_image_backup | | |
| configuration.default_image | | |
| configuration.default_kernel_version | | |
| configuration.vm_username | | |
| configuration.vm_password | | |
| configuration.vm_salt | | |
| configuration.password_encrypted | | |
| configuration.vm_hostname | | |
| configuration.kernel_version | | |
| configuration.default_dir_image | | |
| configuration.default_dir_k3s_var_linux_root | | |
| configuration.default_source_image | | |
| configuration.default_kvm_host_sshd_port | | |
| configuration.default_kvm_host_containerd_port | | |
| configuration.default_csi_grpc_proxy_url | | |
| configuration.default_kvm_ports_redirect | | |
| configuration.kvm_cpu | | |
| configuration.kvm_memory | | |
