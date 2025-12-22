# Basic Example

Your first NSM connection - client to server communication.

## What You'll Learn

- How NSM connects pods securely
- Network service registration and discovery
- Kernel-based networking (most common approach)

## The Setup

- **Client**: Alpine pod that requests network service
- **Server**: NSE (Network Service Endpoint) that provides service
- **Connection**: Direct kernel-to-kernel link
- **IPs**: Client gets 172.16.1.101, Server has 172.16.1.100

## Deploy & Test

```bash
# Deploy everything
./deploy.sh

# Test the connection
kubectl exec alpine -n ns-kernel2kernel -- ping -c 4 172.16.1.100

# See the NSM interface
kubectl exec alpine -n ns-kernel2kernel -- ip addr show nsm-1
```

## How It Works

1. **Server registers**: NSE tells NSM "I provide kernel2kernel service"
2. **Client requests**: Pod annotation says "I want kernel2kernel service"  
3. **NSM connects**: Creates secure tunnel between pods
4. **Traffic flows**: Direct communication via kernel interface

This is the foundation - all other examples build on this pattern.

## Cleanup

```bash
./cleanup.sh
```

## Issues?

**No ping response:**
```bash
kubectl get pods -n ns-kernel2kernel
kubectl logs -n nsm-system -l app=nsmgr
```
