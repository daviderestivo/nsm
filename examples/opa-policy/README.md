# OPA Policy Example

HTTP API with role-based access control using Open Policy Agent.

## What You'll Learn

- Policy-driven security with NSM
- Role-based access control (RBAC)
- Integration of OPA with network services

## The Setup

```
┌─────────────────┐    NSM Network    ┌─────────────────┐
│     Client      │◄─────────────────►│   Web Server    │
│ Alpine + curl   │   172.16.5.0/24   │ Nginx + OPA     │
│ 172.16.5.10     │                   │ 172.16.5.20     │
└─────────────────┘                   └─────────┬───────┘
         │                                      │
         │ HTTP + X-User: alice                 │
         └──────────────────────────────────────┘
                                                │
                                         ┌──────▼──────┐
                                         │ OPA Policy  │
                                         │ Engine      │
                                         │             │
                                         │ alice: user │
                                         │ bob: mgr    │
                                         │ david: hr   │
                                         └─────────────┘
```

- **Client**: Alpine pod with curl (172.16.5.10)
- **Web Server**: Nginx with OPA sidecar (172.16.5.20)
- **Policy Engine**: OPA evaluates access requests
- **Rules**: Different roles get different access

## Access Rules

- **alice** (user): Can access `/public/*` only
- **bob** (manager): Can access `/public/*` and `/admin/*`
- **david** (hr): Can access `/public/*` and `/hr/*`

## Deploy & Test

```bash
# Deploy everything
./deploy.sh

# Test public access (works for everyone)
kubectl exec opa-client -n ns-opa -- curl -H "X-User: alice" http://172.16.5.20/public/info

# Test admin access (managers only)
kubectl exec opa-client -n ns-opa -- curl -H "X-User: bob" http://172.16.5.20/admin/users

# Test unauthorized access (should fail)
kubectl exec opa-client -n ns-opa -- curl -H "X-User: alice" http://172.16.5.20/admin/users
```

## How It Works

1. **Client sends request**: HTTP request with `X-User` header
2. **Nginx intercepts**: Forwards to OPA for authorization
3. **OPA evaluates**: Checks user role against path
4. **Decision made**: Allow or deny based on policy

## When To Use This

- **API security**: Control access to REST endpoints
- **Compliance**: Enforce access policies
- **Zero-trust**: Policy-based authorization
- **Microservices**: Service-level access control

## Cleanup

```bash
./cleanup.sh
```

## Issues?

**Access denied unexpectedly:**
```bash
kubectl logs opa-server -c opa -n ns-opa
kubectl logs opa-server -c nginx -n ns-opa
```
