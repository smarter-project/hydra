# hydra

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/hydra)](https://artifacthub.io/packages/search?repo=hydra)

This chart deploys charts crismux and isolated-vm

## TL;DR

```console
helm repo add hydra https://smarter-project.github.io/hydra/
helm install --create-namespace --namespace <namespace to use> hydra hydra/hydra
```

# Overview

Crismux allows more that one containerd to be connected to kubelet

# Prerequisites

This chart assumes a full deployment of k3s with traefik, etc.

* k3s 1.25+
* Helm 3.2.0+

# Uninstalling the Chart

```
helm delete hydra --namespace <namespace to use>
```

# Parameters

## Common parameters

| Name | Description | Value |
| ---- | ----------- | ----- |
| configuration.sshkey | Public ssh key to enable access to the VM (user hailhydra) | |
