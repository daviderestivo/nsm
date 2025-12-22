# Virtual Wire Example

Connect two clients directly - like a virtual ethernet cable.

## What You'll Learn

- Peer-to-peer NSM connections
- L2 (ethernet-level) networking
- Multiple clients sharing one service

## The Setup

```
┌─────────────────┐                   ┌─────────────────┐
│    Client A     │                   │    Client B     │
│  Alpine Pod     │                   │  Alpine Pod     │
│ 172.16.2.1      │                   │ 172.16.2.2      │
└─────────┬───────┘                   └─────────┬───────┘
          │                                     │
          │            NSM Network              │
          │         172.16.2.0/24               │
          │                                     │
          └──────────┬─────────────────┬────────┘
                     │                 │
              ┌──────▼─────────────────▼──────┐
              │      Virtual Wire NSE         │
              │    (L2 Bridge Service)        │
              └───────────────────────────────┘
```

- **Client A**: Alpine pod at 172.16.2.1
- **Client B**: Alpine pod at 172.16.2.2  
- **Virtual Wire**: NSE that bridges them together
- **Result**: Clients talk directly to each other

## Deploy & Test

```bash
# Deploy everything
./deploy.sh

# Test both directions
kubectl exec client-a -n ns-vwire -- ping -c 4 172.16.2.2
kubectl exec client-b -n ns-vwire -- ping -c 4 172.16.2.1

# Check the network setup
kubectl exec client-a -n ns-vwire -- ip addr show nsm-1
```

## How It Works

1. **NSE creates bridge**: Virtual wire service acts like ethernet switch
2. **Both clients connect**: Each gets their own IP on same network
3. **Direct communication**: Traffic flows peer-to-peer through NSM

## When To Use This

- **Legacy apps**: Applications that expect L2 connectivity
- **Peer-to-peer**: Direct client-to-client communication
- **Broadcast scenarios**: When you need ethernet-level features

## Cleanup

```bash
./cleanup.sh
```

## Issues?

**Clients can't reach each other:**
```bash
kubectl exec client-a -n ns-vwire -- ip route
kubectl logs -n nsm-system -l app=nsmgr
```
