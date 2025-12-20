# Understanding OIDC Provider

## What is an OIDC Provider?

**OIDC (OpenID Connect)** is an authentication protocol that allows one service to verify the identity of users/services from another trusted service.

## In AWS Context

An **OIDC Provider** in AWS IAM is a configuration that tells AWS:
> "I trust tokens issued by this external identity provider"

## How it Works in EKS

### The Problem
- Kubernetes pods need to access AWS services (like EBS volumes)
- You don't want to store AWS access keys inside pods (security risk)
- You need a secure way for pods to authenticate with AWS

### The Solution - IRSA (IAM Roles for Service Accounts)

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

### Step-by-Step Authentication Process

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

### Real Example

**OIDC Provider URL:** `https://oidc.eks.eu-central-2.amazonaws.com/id/B86020E942A28CCC8FDC577C0F65D595`

**What this means:**
- AWS will trust tokens issued by this specific EKS cluster
- Each EKS cluster has a unique OIDC provider ID
- The IAM role must be configured to trust this exact provider

### Why Each Cluster is Unique

```bash
Cluster A: oidc.eks.region.amazonaws.com/id/ABC123...
Cluster B: oidc.eks.region.amazonaws.com/id/XYZ789...
```

Each cluster gets its own OIDC provider ID for security - tokens from Cluster A won't work with roles configured for Cluster B.

### The Trust Relationship

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

### Summary

**OIDC Provider** = Identity Broker that allows Kubernetes pods to securely authenticate with AWS without storing credentials.
