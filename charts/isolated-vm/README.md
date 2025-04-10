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
| configuration.sshkey | Public ssh key to enable access to the VM (user vm-user) | |
