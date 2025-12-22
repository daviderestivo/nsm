# DNS Service Example

Secure DNS server accessible only through NSM.

## What You'll Learn

- Service-specific networking with NSM
- Secure service isolation
- Custom DNS configuration

## The Setup

- **DNS Client**: Pod with DNS tools (172.16.3.10)
- **DNS Server**: CoreDNS with custom zones (172.16.3.100)
- **NSM Network**: Only these pods can communicate
- **Custom Zone**: `.local` domain with test entries

## Deploy & Test

```bash
# Deploy everything
./deploy.sh

# Test DNS resolution
kubectl exec dns-client -n ns-dns -- nslookup test.local 172.16.3.100
kubectl exec dns-client -n ns-dns -- nslookup server.local 172.16.3.100

# Test direct connectivity
kubectl exec dns-client -n ns-dns -- ping -c 4 172.16.3.100
```

## Custom DNS Entries

The DNS server knows about:
- `test.local` → 172.16.3.200
- `server.local` → 172.16.3.100

## How It Works

1. **DNS server starts**: CoreDNS loads custom zone configuration
2. **NSM connects**: Client and server join secure network
3. **DNS queries**: Flow securely through NSM tunnel
4. **Isolation**: DNS server unreachable from outside NSM

## When To Use This

- **Service discovery**: Internal DNS for microservices
- **Security**: DNS isolated from main network
- **Custom domains**: Application-specific DNS zones
- **Compliance**: Controlled DNS resolution

## Cleanup

```bash
./cleanup.sh
```

## Issues?

**DNS not resolving:**
```bash
kubectl logs dns-server -n ns-dns
kubectl exec dns-client -n ns-dns -- nslookup google.com 8.8.8.8
```
