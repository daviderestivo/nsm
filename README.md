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
├── examples/                         # NSM examples and use cases
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
```

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/daviderestivo/nsm.git
cd nsm/eks-cluster
```

### 2. Deploy Everything
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
make all CLUSTER_NAME=my-cluster REGION=us-west-2 NODE_COUNT=6
```

## Installation Steps

The `make all` command performs these steps:
1. **Create IAM roles** - EKS cluster, node group, and EBS CSI driver roles
2. **Create EKS cluster** - Kubernetes control plane (~10-15 minutes)
3. **Create OIDC provider** - For service account authentication (IRSA)
4. **Create node group** - Worker nodes with auto-scaling
5. **Install AWS addons** - VPC CNI and EBS CSI driver
6. **Install NSM** - Spire (SPIFFE) and Network Service Mesh components
7. **Configure storage** - Default storage class and kubeconfig

### Manual Step-by-Step
For granular control, run individual steps:
```bash
make create-roles
make create-cluster
make create-oidc-provider
make create-nodegroup
make install-addons
make install-nsm
make setup-storage
```

## Understanding OIDC Provider

### What is an OIDC Provider?

**OIDC (OpenID Connect)** is an authentication protocol that allows one service to verify the identity of users/services from another trusted service.

### In AWS Context

An **OIDC Provider** in AWS IAM is a configuration that tells AWS:
> "I trust tokens issued by this external identity provider"

### How it Works in EKS

#### The Problem
- Kubernetes pods need to access AWS services (like EBS volumes)
- You don't want to store AWS access keys inside pods (security risk)
- You need a secure way for pods to authenticate with AWS

#### The Solution - IRSA (IAM Roles for Service Accounts)

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   EKS Cluster   │    │   OIDC Provider  │    │   AWS IAM       │
│                 │    │   (Identity      │    │                 │
│ ┌─────────────┐ │    │    Broker)       │    │ ┌─────────────┐ │
│ │ Pod with    │ │    │                  │    │ │ IAM Role    │ │
│ │ Service     │────┼─│  "I verify this  │────┼─│ "I trust    │ │
│ │ Account     │ │    │   pod is who it  │    │ │  tokens     │ │
│ │             │ │    │   claims to be"  │    │ │  from OIDC" │ │
│ └─────────────┘ │    │                  │    │ └─────────────┘ │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

#### Step-by-Step Authentication Process

1. **Pod requests AWS access:**
   - Pod: "I'm the `ebs-csi-controller-sa` service account"

2. **EKS issues a token:**
   - EKS: "Here's a signed JWT token proving your identity"

3. **Pod presents token to AWS:**
   - Pod: "Here's my token, I want to create an EBS volume"

4. **AWS validates with OIDC Provider:**
   - AWS: "Is this token valid?"
   - OIDC Provider: "Yes, it's from a trusted EKS cluster"

5. **AWS grants access:**
   - AWS: "Token is valid, you can assume the IAM role"

#### Real Example

**OIDC Provider URL:** `https://oidc.eks.eu-central-2.amazonaws.com/id/B86020E942A28CCC8FDC577C0F65D595`

**What this means:**
- AWS will trust tokens issued by this specific EKS cluster
- Each EKS cluster has a unique OIDC provider ID
- The IAM role must be configured to trust this exact provider

#### Why Each Cluster is Unique

```bash
Cluster A: oidc.eks.region.amazonaws.com/id/ABC123...
Cluster B: oidc.eks.region.amazonaws.com/id/XYZ789...
```

Each cluster gets its own OIDC provider ID for security - tokens from Cluster A won't work with roles configured for Cluster B.

#### The Trust Relationship

In the IAM role trust policy:
```json
{
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.region.amazonaws.com/id/B86020E942A28CCC8FDC577C0F65D595"
  },
  "Condition": {
    "StringEquals": {
      "oidc.eks.region.amazonaws.com/id/B86020E942A28CCC8FDC577C0F65D595:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
    }
  }
}
```

This says: *"I trust tokens from this OIDC provider, but only for the specific service account `ebs-csi-controller-sa`"*

#### Summary

**OIDC Provider** = Identity Broker that allows Kubernetes pods to securely authenticate with AWS without storing credentials.

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

- Explore NSM examples in the `examples/` directory
- Configure monitoring and logging for production
- Implement GitOps workflows
- Use private subnets for production deployments

## Support

- [Network Service Mesh Documentation](https://networkservicemesh.io/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Spire Documentation](https://spiffe.io/docs/latest/spire/)
- [GitHub Issues](https://github.com/daviderestivo/nsm/issues)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
