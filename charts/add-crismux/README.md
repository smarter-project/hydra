# home-orchestrator

This chart deploys crismux

## TL;DR

```console
helm repo add hydra https://smarter-project.github.io/hydra/
helm install --create-namespace --namespace <namespace to use> add-crismux hydra/add-crismux
```

# Overview

Crismux allows more that one containerd to be connected to kubelet

# Prerequisites

This chart assumes a full deployment of k3s with traefik, etc.

* k3s 1.25+
* Helm 3.2.0+

# Uninstalling the Chart

```
helm delete add-crismux --namespace <namespace to use>
```

# Parameters

## Common parameters

| Name | Description | Value |
| ---- | ----------- | ----- |
