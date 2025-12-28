# Network Service Mesh on AWS EKS

Automated deployment of Network Service Mesh on Amazon EKS with complete infrastructure provisioning, security hardening, and comprehensive examples.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Available Commands](#available-commands)
- [Installation Process](#installation-process)
- [Architecture](#architecture)
- [Verification](#verification)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [FAQ](#faq)
- [Cleanup](#cleanup)
- [Next Steps](#next-steps)
- [Support](#support)
- [Additional Resources](#additional-resources)

## Overview

This repository provides production-ready automation for deploying Network Service Mesh (NSM) on Amazon EKS. Get a fully functional NSM environment in 15-20 minutes with enterprise-grade security and comprehensive examples.

For comprehensive information about Network Service Mesh concepts, architecture, and components, see [NSM Concepts](doc/nsm-concepts.md).

**What You Get**:
- **Complete EKS Cluster** - Managed Kubernetes with optimized configuration
- **NSM v1.14.0** - Latest stable Network Service Mesh deployment
- **SPIFFE/Spire** - Zero-trust identity framework with automatic certificate rotation
- **AWS Integration** - EBS CSI driver, VPC CNI, and IRSA authentication
- **5 Working Examples** - From basic connectivity to advanced policy control
- **Production Ready** - Security hardening and monitoring capabilities

## Repository Structure

```
nsm/
├── README.md                         # This documentation
├── LICENSE                           # Apache 2.0 license
├── doc/                              # Documentation
│   ├── nsm-concepts.md               # NSM concepts and architecture
│   └── understanding-oidc-provider.md # OIDC provider deep dive
├── examples/                         # NSM examples and use cases
│   ├── basic/                        # Kernel-to-kernel connectivity
│   ├── vwire/                        # L2 peer-to-peer communication
│   ├── dns/                          # Secure DNS resolution
│   ├── secure-tunnel/                # Encrypted HTTP communication
│   └── opa-policy/                   # Role-based access control
└── eks-cluster/                      # EKS cluster setup automation
    ├── Makefile                      # Main automation script
    ├── eks-cluster-role-trust.yaml  # EKS cluster service role trust policy
    ├── eks-nodegroup-role-trust.yaml # EKS node group role trust policy
    └── eks-ebs-csi-role-trust.yaml  # EBS CSI driver role trust policy
```

## Prerequisites

### Required Tools
- **AWS CLI v2** - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **kubectl** - [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **make** - Usually pre-installed on macOS/Linux
- **git** - For cloning the repository

### AWS Requirements
- **AWS Account** with appropriate permissions
- **AWS CLI configured** with credentials (`aws configure`)
- **IAM permissions** for EKS, IAM, EC2, and EBS management

### Supported Regions
This automation works in all AWS regions that support EKS. Default region is `eu-central-2`.

### Verify Prerequisites
```bash
# Check AWS CLI and credentials
aws --version
aws sts get-caller-identity

# Check kubectl and make
kubectl version --client
make --version

# Or use the built-in validation
cd nsm/eks-cluster
make validate
```

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/daviderestivo/nsm.git
cd nsm/eks-cluster
```

### 2. Validate Prerequisites
```bash
# Check prerequisites and configuration
make validate
```

### 3. Preview Deployment
```bash
# See what will be created (dry-run)
make plan
```

### 4. Deploy Everything
```bash
# Create complete NSM-enabled EKS cluster
make all
```

**Default Configuration:**
- **Cluster**: `nsm-test` in `eu-central-2`
- **Nodes**: 4x t3.medium instances
- **NSM Version**: v1.14.0
- **Deployment Time**: 15-20 minutes

**Custom Configuration:**
```bash
make all CLUSTER_NAME=my-cluster REGION=us-west-2 NODE_COUNT=6 INSTANCE_TYPE=t3.large
```

### 5. Check Status
```bash
# View cluster status and resources
make status
```

## Available Commands

### Getting Help
```bash
make help                    # Show all available targets and options
```

### Validation and Planning
```bash
make validate               # Check prerequisites and configuration
make plan                   # Preview what resources will be created
make status                 # Show current cluster status
```

### Deployment
```bash
make all                    # Complete setup (recommended)
make create-roles           # Create IAM roles only
make create-cluster         # Create EKS cluster only
make create-oidc-provider   # Create OIDC provider only
make create-nodegroup       # Create node group only
make install-addons         # Install AWS addons only
make install-nsm            # Install NSM components only
make setup-storage          # Configure storage only
```

### Cleanup
```bash
make clean-nsm              # Remove NSM components only
make clean                  # Delete everything (with confirmation)
```

### Configuration Options
```bash
CLUSTER_NAME=my-cluster     # Cluster name (default: nsm-test)
REGION=eu-central-2         # AWS region (default: eu-central-2)
NODE_COUNT=6               # Number of nodes (default: 4)
INSTANCE_TYPE=t3.large     # Instance type (default: t3.medium)
NSM_VERSION=v1.14.0        # NSM version (default: v1.14.0)
```

## Installation Process

The `make all` command performs these steps:
1. **Validate prerequisites** - Check AWS CLI, kubectl, credentials, and region
2. **Create IAM roles** - EKS cluster, node group, and EBS CSI driver roles
3. **Create EKS cluster** - Kubernetes control plane (~10-15 minutes)
4. **Create OIDC provider** - For service account authentication (IRSA)
5. **Create node group** - Worker nodes with auto-scaling
6. **Install AWS addons** - VPC CNI and EBS CSI driver
7. **Install NSM** - Spire (SPIFFE) and Network Service Mesh components
8. **Configure storage** - Default storage class and kubeconfig

## Architecture

### NSM on EKS Components

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "EKS Cluster"
            subgraph "Control Plane"
                API[EKS API Server]
            end
            
            subgraph "Worker Nodes"
                subgraph "NSM System"
                    NSMgr[NSM Manager]
                    Forwarder[NSM Forwarder]
                    Registry[NSM Registry]
                end
                
                subgraph "Spire System"
                    SpireServer[Spire Server]
                    SpireAgent[Spire Agent]
                end
                
                subgraph "Application Pods"
                    NSC[Network Service Client]
                    NSE[Network Service Endpoint]
                end
            end
        end
        
        subgraph "AWS Services"
            IAM[IAM Roles]
            EBS[EBS CSI Driver]
            VPC[VPC CNI]
        end
    end
    
    API --> NSMgr
    NSMgr --> Registry
    NSMgr --> Forwarder
    SpireServer --> SpireAgent
    NSC --> NSMgr
    NSE --> NSMgr
    IAM --> EBS
    IAM --> VPC
```

**Key Components**:
- **NSM Manager**: Orchestrates network service connections
- **NSM Forwarder**: Handles data plane forwarding
- **NSM Registry**: Service discovery and endpoint registration
- **Spire Server/Agent**: SPIFFE identity management
- **Network Service Client (NSC)**: Consumes network services
- **Network Service Endpoint (NSE)**: Provides network services

## Verification

### Check Cluster
```bash
# Verify cluster status
kubectl get nodes
aws eks list-addons --cluster-name nsm-test --region eu-central-2
```

### Check NSM Components
```bash
# Spire components
kubectl get pods -n spire

# NSM system
kubectl get pods -n nsm-system

# Verify NSM readiness
kubectl wait -n nsm-system --for=condition=ready --timeout=3m pod -l app=admission-webhook-k8s
```

### Test Storage
```bash
kubectl get storageclass

# Test PVC creation
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc
kubectl delete pvc test-pvc
```

## Examples

Explore comprehensive NSM examples with detailed documentation:

| Example | Description | Use Case | Complexity |
|---------|-------------|----------|------------|
| [Basic](examples/basic/) | Kernel-to-kernel connectivity | NSM fundamentals | Beginner |
| [Virtual Wire](examples/vwire/) | L2 peer-to-peer communication | Legacy app support | Intermediate |
| [DNS Service](examples/dns/) | Secure DNS resolution | Service discovery | Intermediate |
| [Secure Tunnel](examples/secure-tunnel/) | Encrypted HTTP communication | Zero-trust networking | Advanced |
| [OPA Policy](examples/opa-policy/) | Role-based access control | API authorization | Advanced |

**Learning Path**:
1. Start with [Basic](examples/basic/) to understand NSM fundamentals
2. Try [Virtual Wire](examples/vwire/) for L2 networking concepts
3. Explore [DNS Service](examples/dns/) for service discovery patterns
4. Implement [Secure Tunnel](examples/secure-tunnel/) for application security
5. Master [OPA Policy](examples/opa-policy/) for advanced authorization

## Troubleshooting

**Common Issues**:

| Problem | Cause | Solution |
|---------|-------|----------|
| Cluster creation fails | IAM permissions or subnet issues | Check IAM roles and VPC configuration |
| NSM pods not starting | Resource constraints or image pull issues | Verify node resources and network connectivity |
| Examples not working | NSM system not ready | Wait for all NSM components to be ready |
| Storage issues | EBS CSI driver not configured | Verify EBS CSI driver installation |

**Cluster Creation Fails:**
```bash
# Check IAM roles and subnets
aws iam get-role --role-name EKS-Cluster-Role
aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --region eu-central-2
```

**NSM Installation Issues:**
```bash
# Check logs
kubectl logs -n spire -l app=spire-server
kubectl logs -n nsm-system -l app=admission-webhook-k8s

# Restart NSM
make clean-nsm
make install-nsm
```

**General Debugging:**
```bash
kubectl cluster-info
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl describe nodes
```

## Advanced Configuration

<details>
<summary>Custom Configuration Options</summary>

**Environment Variables**:
```bash
# Cluster configuration
export CLUSTER_NAME=production-nsm
export REGION=us-west-2
export NODE_COUNT=8
export INSTANCE_TYPE=t3.xlarge

# NSM configuration
export NSM_VERSION=v1.15.0
export SPIRE_VERSION=1.8.0

# Deploy with custom settings
make all
```

**Private Subnet Deployment**:
```bash
# Use existing VPC with private subnets
export VPC_ID=vpc-12345678
export SUBNET_IDS=subnet-12345678,subnet-87654321
make create-cluster
```

**Production Hardening**:
```bash
# Enable additional security features
export ENABLE_IRSA=true
export ENABLE_ENCRYPTION=true
export ENABLE_LOGGING=true
make all
```
</details>

<details>
<summary>Monitoring & Observability</summary>

**NSM Metrics**:
```bash
# Enable Prometheus monitoring
kubectl apply -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/main/examples/observability/jaeger.yaml

# Access NSM dashboard
kubectl port-forward -n nsm-system svc/jaeger 16686:16686
```

**Cluster Monitoring**:
```bash
# Check cluster health
kubectl get nodes -o wide
kubectl top nodes
kubectl top pods -A
```
</details>

## FAQ

<details>
<summary>What AWS permissions are required?</summary>

The deployment requires permissions for EKS, IAM, EC2, and EBS services. See the IAM policy examples in the `eks-cluster/` directory for specific permissions.
</details>

<details>
<summary>Can I use an existing EKS cluster?</summary>

Yes, you can install NSM on an existing cluster using `make install-nsm`. Ensure the cluster has the required addons (VPC CNI, EBS CSI driver).
</details>

<details>
<summary>How do I upgrade NSM to a newer version?</summary>

Update the `NSM_VERSION` variable and run `make clean-nsm && make install-nsm`. Always test upgrades in a non-production environment first.
</details>

<details>
<summary>What's the difference between NSM and service mesh solutions like Istio?</summary>

NSM operates at the network layer (L2/L3) providing secure connectivity, while service meshes like Istio focus on application layer (L7) features like traffic management and observability.
</details>

## Cleanup

```bash
# Clean NSM only
make clean-nsm

# Clean everything (cluster, roles, NSM)
make clean
```

**Warning**: `make clean` permanently deletes all resources and data.

## Next Steps

- **Start with Examples**: Follow the [learning path](#examples) from basic to advanced
- **Production Setup**: Configure monitoring, logging, and GitOps workflows
- **Security Hardening**: Implement private subnets and additional security controls
- **Custom Development**: Build your own Network Service Endpoints

## Support

- [Network Service Mesh Documentation](https://networkservicemesh.io/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Spire Documentation](https://spiffe.io/docs/latest/spire/)
- [GitHub Issues](https://github.com/daviderestivo/nsm/issues)

## Additional Resources

- [NSM Concepts](doc/nsm-concepts.md) - Comprehensive NSM concepts and architecture guide
- [Understanding OIDC Provider](doc/understanding-oidc-provider.md) - Deep dive into OIDC providers and IRSA authentication

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
