# NSM Examples

Learn Network Service Mesh through practical examples on AWS EKS.

## Examples by Complexity

| Example | Level | What You'll Learn | Real-World Use Case |
|---------|-------|-------------------|---------------------|
| [basic](basic/) | Beginner | NSM fundamentals, kernel connectivity | Understanding NSM basics |
| [vwire](vwire/) | Beginner | L2 networking, peer-to-peer | Legacy app migration |
| [dns](dns/) | Intermediate | Service-specific networking | Secure service discovery |
| [secure-tunnel](secure-tunnel/) | Intermediate | Application connectivity | Secure microservices |
| [opa-policy](opa-policy/) | Advanced | Policy enforcement | Zero-trust security |

## Quick Start

```bash
# 1. Choose an example
cd basic

# 2. Deploy
./deploy.sh

# 3. Test (commands in each README)
kubectl exec <pod> -n <namespace> -- <test-command>

# 4. Clean up
./cleanup.sh
```

## Network Layout

Each example uses isolated networks to avoid conflicts:

| Example | Namespace | Network | Client → Server |
|---------|-----------|---------|-----------------|
| basic | ns-kernel2kernel | 172.16.1.100/31 | 172.16.1.101 → 172.16.1.100 |
| vwire | ns-vwire | 172.16.2.0/24 | 172.16.2.1 ↔ 172.16.2.2 |
| dns | ns-dns | 172.16.3.0/24 | 172.16.3.10 → 172.16.3.100 |
| secure-tunnel | ns-tunnel | 172.16.4.0/24 | 172.16.4.10 → 172.16.4.20 |
| opa-policy | ns-opa | 172.16.5.0/24 | 172.16.5.10 → 172.16.5.20 |

## Prerequisites

- EKS cluster with NSM installed ([setup guide](../README.md))
- kubectl configured for your cluster

## Learning Path

**New to NSM?** Start with `basic` → `vwire` → `dns`

**Need security?** Try `secure-tunnel` → `opa-policy`

**Production ready?** All examples show production patterns

## Troubleshooting

### Quick Fixes

**Example won't deploy:**
```bash
# Check NSM is running
kubectl get pods -n nsm-system

# Check cluster resources
kubectl get nodes
kubectl describe node <node-name>
```

**Pods stuck pending:**
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

**Network not working:**
```bash
# Check NSM interface created
kubectl exec <pod> -n <namespace> -- ip addr show nsm-1

# Check NSM logs
kubectl logs -n nsm-system -l app=nsmgr
```

### Common Issues

- **NSM pods not running**: Run `make status` in `eks-cluster/` directory
- **Pod scheduling fails**: Check node resources with `kubectl top nodes`
- **Network interface missing**: Verify pod annotations and NSM logs
- **Connection timeout**: Check security groups and network policies

### Getting Help

1. Check the specific example's troubleshooting section
2. Review NSM logs: `kubectl logs -n nsm-system -l app=nsmgr`
3. Verify setup: `make validate` in `eks-cluster/` directory
