# home-orchestrator

This chart deploys home-orchestrator

## TL;DR

```console
helm repo add home-orchestrator https://smarter-project.github.io/home-orchestrator/
helm install --create-namespace --namespace <namespace to use> home-orchestrator home-orchestrator/home-orchestrator
```

# Overview

The home-orchestrator manages ML models to demonstrate a home security application.

# Prerequisites

This chart assumes a full deployment of k3s with traefik, etc.

* k3s 1.25+
* Helm 3.2.0+

# Uninstalling the Chart

```
helm delete home-orchestrator --namespace <namespace to use>
```

# Parameters

## Common parameters

| Name | Description | Value |
| ---- | ----------- | ----- |
| configuration.nameGuest | set DNS service name to access ollama-guest | home-orchestrator-ollama-guest |
| configuration.portGuest | set TCP port ollama-guest will used | 31434 |
| configuration.nameHost | set DNS service name to access ollama-host | home-orchestrator-ollama-host |
| configuration.portHost | set TCP port ollama-host will used | 31435 |
| configuration.model | set model to preload | llama3.2:1b-instruct-q4_K_M |
| configuration.ollamaVersion | set ollama version to use | "latest" |
