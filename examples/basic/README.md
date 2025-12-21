# Basic NSM Example - Kernel2Kernel

This is a simple Network Service Mesh example showing kernel-to-kernel connectivity.

## Overview

- **Client (NSC)**: Alpine pod requesting kernel2kernel network service
- **Server (NSE)**: Kernel NSE providing the network service
- **Mechanism**: kernel (simple and reliable)
- **Network**: 172.16.1.100/31 subnet

## Quick Start

```bash
# Deploy everything
./deploy.sh

# Clean up
./cleanup.sh
```

## Manual Deploy

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Deploy network service
kubectl apply -f netsvc.yaml

# Deploy NSE (server)
kubectl apply -f nse-base.yaml -n ns-kernel2kernel

# Deploy NSC (client)  
kubectl apply -f client.yaml -n ns-kernel2kernel
```

## Test

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready --timeout=1m pod -l app=alpine -n ns-kernel2kernel
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ns-kernel2kernel

# Test connectivity
kubectl exec pods/alpine -n ns-kernel2kernel -- ping -c 4 172.16.1.100
```

## Cleanup

```bash
kubectl delete ns ns-kernel2kernel
```
