# Secure Tunnel Example

HTTP server accessible only through encrypted NSM connection.

## What You'll Learn

- Application-level security with NSM
- Real-world client-server patterns
- Network isolation for web services

## The Setup

- **Client**: Alpine pod with curl (172.16.4.10)
- **Web Server**: Nginx serving HTTP (172.16.4.20)
- **NSM Tunnel**: Encrypted connection between them
- **Isolation**: Server unreachable from outside NSM

## Deploy & Test

```bash
# Deploy everything
./deploy.sh

# Test HTTP connection
kubectl exec tunnel-client -n ns-tunnel -- wget -qO- http://172.16.4.20

# Test basic connectivity
kubectl exec tunnel-client -n ns-tunnel -- ping -c 4 172.16.4.20
```

## Security Features

- **Traffic isolation**: Server only accessible via NSM
- **Identity verification**: SPIFFE-based authentication
- **Encrypted channels**: All traffic encrypted in transit
- **Zero-trust**: No implicit network access

## How It Works

1. **Server starts**: Nginx binds to NSM network interface
2. **NSM connects**: Creates encrypted tunnel
3. **HTTP flows**: Web traffic secured by NSM
4. **Isolation**: No access from cluster network

## When To Use This

- **Microservices**: Secure service-to-service communication
- **Compliance**: Encrypted data in transit requirements
- **Zero-trust**: No network-level trust assumptions
- **API security**: Protect internal APIs

## Cleanup

```bash
./cleanup.sh
```

## Issues?

**HTTP connection fails:**
```bash
kubectl logs tunnel-server -n ns-tunnel
kubectl exec tunnel-client -n ns-tunnel -- telnet 172.16.4.20 80
```
