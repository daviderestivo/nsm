# NSM Firewall Service Example

This example demonstrates how to implement a firewall service using Network Service Mesh (NSM) that filters traffic between client and server applications.

## Architecture

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
│   Client    │───▶│  NSM Firewall   │───▶│   Server    │
│ Application │    │    Service      │    │ Application │
└─────────────┘    └─────────────────┘    └─────────────┘
```

The firewall service acts as an NSM network service that:
- Intercepts traffic between client and server
- Applies configurable firewall rules
- Allows/blocks traffic based on IP, port, and protocol
- Logs all traffic decisions

## Components

- **Firewall Network Service** - NSM service that implements traffic filtering
- **Client Application** - Test client that connects through the firewall
- **Server Application** - Test server that receives filtered traffic
- **Network Service Endpoint** - NSM endpoint configuration
- **Firewall Rules ConfigMap** - Configurable firewall policies

## Quick Start

1. **Deploy the firewall service:**
   ```bash
   kubectl apply -f firewall-service.yaml
   ```

2. **Deploy test applications:**
   ```bash
   kubectl apply -f client-server.yaml
   ```

3. **Test connectivity:**
   ```bash
   kubectl exec -it client -- curl http://server:8080/health
   ```

4. **View firewall logs:**
   ```bash
   kubectl logs -l app=nsm-firewall -f
   ```

## Configuration

Edit the firewall rules in `firewall-rules.yaml`:

```yaml
rules:
  - action: ALLOW
    protocol: TCP
    port: 8080
    source: "10.0.0.0/8"
  - action: BLOCK
    protocol: TCP
    port: 22
  - action: ALLOW
    protocol: ICMP
```

## Customization

- Modify firewall rules in the ConfigMap
- Adjust logging levels
- Add custom metrics collection
- Implement additional protocols

## Cleanup

```bash
kubectl delete -f .
```
