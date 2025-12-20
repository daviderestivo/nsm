# Network Service Mesh on AWS EKS

This repository provides automated setup for Network Service Mesh (NSM) on Amazon EKS with complete infrastructure provisioning and NSM installation.

## Overview

Network Service Mesh (NSM) is a novel approach to solving complicated L2/L3 use cases in Kubernetes that are tricky to address with the existing Kubernetes Network Model. This setup includes:

- **AWS EKS Cluster** - Managed Kubernetes control plane
- **Spire** - SPIFFE identity framework for secure workload identity
- **Network Service Mesh** - Advanced networking capabilities for Kubernetes
- **EBS CSI Driver** - Persistent storage support
- **VPC CNI** - AWS native networking

## Repository Structure

```
nsm/
├── README.md                         # This documentation
├── LICENSE                           # Apache 2.0 license
├── doc/                              # Documentation
│   └── understanding-oidc-provider.md # OIDC provider deep dive
├── examples/                         # NSM examples and use cases
│   └── firewall-service/             # NSM firewall service example
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

### Verify Prerequisites
```bash
# Check AWS CLI and credentials
aws --version
aws sts get-caller-identity

# Check kubectl and make
kubectl version --client
make --version

# Or use the built-in validation
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
- Cluster: `nsm-test` in `eu-central-2`
- Nodes: 4x t3.medium instances
- NSM Version: v1.14.0

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
REGION=us-west-2           # AWS region (default: eu-central-2)
NODE_COUNT=6               # Number of nodes (default: 4)
INSTANCE_TYPE=t3.large     # Instance type (default: t3.medium)
NSM_VERSION=v1.15.0        # NSM version (default: v1.14.0)
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

## Troubleshooting

### Common Issues

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

## Cleanup

```bash
# Clean NSM only
make clean-nsm

# Clean everything (cluster, roles, NSM)
make clean
```

**Warning**: `make clean` permanently deletes all resources and data.

## Next Steps

- Explore NSM examples in the `examples/` directory:
  - [Firewall Service](examples/firewall-service/) - Traffic filtering with NSM
- Configure monitoring and logging for production
- Implement GitOps workflows
- Use private subnets for production deployments

## Support

- [Network Service Mesh Documentation](https://networkservicemesh.io/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Spire Documentation](https://spiffe.io/docs/latest/spire/)
- [GitHub Issues](https://github.com/daviderestivo/nsm/issues)

## Additional Readings

- [Understanding OIDC Provider](doc/understanding-oidc-provider.md) - Deep dive into OIDC providers and IRSA authentication

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
