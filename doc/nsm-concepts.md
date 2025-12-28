# Network Service Mesh Concepts

This document provides a comprehensive overview of Network Service Mesh (NSM) concepts, architecture, and components. For practical deployment instructions, see the [main README](../README.md).

## Table of Contents

- [The Problem NSM Solves](#the-problem-nsm-solves)
- [NSM Solution Overview](#nsm-solution-overview)
- [Core Architecture](#core-architecture)
- [Inter-Domain Service Discovery](#inter-domain-service-discovery)
- [Key Components](#key-components)
- [NSM in Kubernetes](#nsm-in-kubernetes)
- [Advanced Features](#advanced-features)
- [NSM vs Traditional Service Mesh](#nsm-vs-traditional-service-mesh)
- [Zero Trust and Security](#zero-trust-and-security)
- [Use Cases](#use-cases)
- [Acronyms](#acronyms)
- [Summary](#summary)

## The Problem NSM Solves

### Problem Statement

How do you enable workloads collaborating together to produce an application to communicate independent of where those workloads are running?

### Background

Traditionally, workloads have been constrained by their Runtime Domain (K8s, VM, or Data Center), with each domain providing exactly one Connectivity Domain. This creates strong coupling between where workloads run and how they communicate.

```mermaid
graph TB
    subgraph Title["Traditional Model"]
        subgraph K8s["K8s Runtime<br/>Domain"]
            K8sConn["K8s Connectivity<br/>Domain"]
        end
        subgraph VM["VM Runtime<br/>Domain"]
            VMConn["VM Connectivity<br/>Domain"]
        end
        subgraph DC["DC Runtime<br/>Domain"]
            DCConn["DC Connectivity<br/>Domain"]
        end
    end
    
    style K8s fill:#e3f2fd
    style VM fill:#fff3e0
    style DC fill:#e8f5e8
    style Title fill:#f5f5f5,stroke:#333,stroke-width:2px
```

**Key Issues**:
- Connectivity domains are strongly coupled to runtime domains
- Workloads can only communicate within their runtime domain
- Multi-cloud and hybrid deployments face connectivity challenges
- No granular control over which workloads can communicate

**Example Scenario**: In a multi-cluster Kubernetes environment:

```mermaid
graph LR
    subgraph ClusterA["Cluster A"]
        RedA["Red Pod"]
        GreenA["Green Pod"]
    end
    subgraph ClusterB["Cluster B"]
        RedB["Red Pod"]
        GreenB["Green Pod"]
    end
    
    RedA -.->|"❌ No Connection"| RedB
    GreenA -.->|"❌ No Connection"| GreenB
    
    style RedA fill:#ffcccc
    style RedB fill:#ffcccc
    style GreenA fill:#ccffcc
    style GreenB fill:#ccffcc
```

Requirements:
• Red Pods need to communicate across clusters
• Green Pods need isolated communication
• Some Pods need multi-network access
• Other Pods should have no cross-cluster access

## NSM Solution Overview

Network Service Mesh decouples connectivity from runtime domains, allowing individual workloads to connect securely to Network Services independent of where they run.

```mermaid
graph TB
    subgraph NSLayer["Network Services Layer"]
        vL3["vL3 Network Service"]
        ServiceMesh["Service Mesh Service"]
        SecureTunnel["Secure Tunnel Service"]
    end
    
    subgraph Domains["Runtime Domains"]
        subgraph K8s["K8s Runtime Domain"]
            AppA["App A"]
            AppB["App B"]
        end
        subgraph VM["VM Runtime Domain"]
            AppC["App C"]
            AppD["App D"]
        end
        subgraph DC["DC Runtime Domain"]
            AppE["App E"]
            AppF["App F"]
        end
    end
    
    NSLayer -.->|"Loose Coupling"| Domains
    vL3 --> AppA
    vL3 --> AppC
    ServiceMesh --> AppB
    ServiceMesh --> AppD
    SecureTunnel --> AppE
    SecureTunnel --> AppF
```

**Key Benefits**:
- **Runtime Independence**: Works across K8s, VMs, and physical servers
- **CNI Compatibility**: Does not replace existing CNI, works alongside it
- **Granular Control**: Per-workload network service connections
- **Secure by Default**: SPIFFE-based identity and encryption

## Core Architecture

### Key Concepts

#### Network Services
A Network Service is a collection of Connectivity, Security, and Observability features at L3 and above. Examples include:
- Distributed virtual L3 networks with optional DNS
- Traditional service meshes (Istio, Linkerd) over virtual networks
- Sophisticated security features (IPS, firewalls)

#### Clients (NSC - Network Service Client)
A Client is a workload that requests connection to a Network Service by name. Clients are:
- Independently authenticated via SPIFFE ID
- Must be authorized to connect to Network Services
- Can be Pods, VMs, or physical servers
- Can connect to multiple Network Services simultaneously

#### vWires (Virtual Wires)
vWires connect Clients to Endpoints with these guarantees:
- Packets ingressing at Client egress at Endpoint
- Packets ingressing at Endpoint egress at Client
- Only packets from the correct source reach the destination
- Each vWire carries traffic for exactly one Network Service

```mermaid
graph LR
    subgraph ClientPod["Client Pod"]
        App["Application"]
        ClientInt["nsm-1 Interface"]
        App --> ClientInt
    end
    
    subgraph EndpointPod["Endpoint Pod"]
        NSE["Network Service Implementation"]
        EndpointInt["nsm-1 Interface"]
        EndpointInt --> NSE
    end
    
    ClientInt <-->|"vWire (Secure Tunnel)"| EndpointInt
    
    style ClientInt fill:#e1f5fe
    style EndpointInt fill:#e8f5e8
```

Properties:
• Bidirectional communication
• Encrypted in transit (SPIFFE/TLS)
• One vWire per Network Service
• Multiple vWires per Client possible

#### Endpoints (NSE - Network Service Endpoint)
Endpoints provide Network Services to Clients. They can be:
- Pods in the same or different K8s clusters
- VMs or physical network components
- Any entity that can process packets

### Network Service API

The NSM API consists of three main operations:

```mermaid
sequenceDiagram
    participant Client
    participant NSM as NSM Manager
    participant Endpoint
    
    Client->>NSM: 1. Request(NetworkService)
    NSM->>Endpoint: 2. Find Endpoint
    Endpoint->>NSM: 3. Establish Connection
    NSM->>Client: 4. Connection Response
    
    Note over Client,Endpoint: Data Flow
    Client<-->Endpoint: Secure Communication
    
    Client->>NSM: 5. Monitor(Connection)
    NSM->>Client: 6. Status Updates
    
    Client->>NSM: 7. Close(Connection)
    NSM->>Endpoint: 8. Cleanup
```

1. **Request**: Creates a vWire between Client and Network Service
2. **Close**: Formally closes a vWire connection
3. **Monitor**: Provides connection status updates and handles expiration

### Registries

NSM uses Network Service Registries (NSR) for service discovery:

#### Network Service Registration
```yaml
apiVersion: networkservicemesh.io/v1
kind: NetworkService
metadata:
  name: my-service
spec:
  payload: IP  # or ETHERNET
```

#### Registry Domains
Network Services can be scoped to domains using `@domain` syntax:
- `service-mesh@finance.example.com`
- Enables internet-scale service discovery
- Supports floating domains not tied to specific runtime domains

## Inter-Domain Service Discovery

NSM enables service discovery across organizational boundaries using DNS-based registry location. This mechanism allows NSM to scale to "internet scale" by leveraging existing DNS infrastructure.

### How Registry Discovery Works

When a client requests a service from a different domain, NSM uses the following process:

```mermaid
sequenceDiagram
    participant Client
    participant DNS as DNS System
    participant Registry as Remote Registry
    participant NSE as Network Service Endpoint
    
    Client->>DNS: 1. SRV lookup for _nsm-registry._tcp.finance.example.com
    DNS->>Client: 2. Returns registry1.finance.example.com:8080
    Client->>Registry: 3. Query for secure-tunnel@finance.example.com
    Registry->>Client: 4. Returns available endpoints
    Client->>NSE: 5. Establish connection to endpoint
```

### Key Concepts

#### **Registry Domain**
- NSM allows multiple independent registry domains (like `finance.example.com`, `marketing.example.com`)
- Each domain has its own Registry Server that stores Network Services and Endpoints
- Think of it like different DNS zones - each manages its own namespace

#### **SRV Record Lookup**
- **SRV records** are a type of DNS record that specifies the hostname and port for specific services
- Format: `_service._protocol.domain.com`
- Example: `_nsm-registry._tcp.finance.example.com` might point to `registry1.finance.example.com:8080`

#### **Discovery Process**
1. **Client wants service**: A client requests `secure-tunnel@finance.example.com`
2. **Domain extraction**: NSM extracts the domain part: `finance.example.com`
3. **SRV lookup**: NSM does a DNS SRV query for `_nsm-registry._tcp.finance.example.com`
4. **Registry location**: DNS returns the actual registry server address and port
5. **Service discovery**: NSM contacts that registry to find the service

### Internet Scale Benefits

**Decentralized Architecture**:
- No single registry bottleneck
- Each organization manages its own services
- Fault tolerance through distributed registries

**DNS Infrastructure Leverage**:
- Uses existing global DNS system
- Inherits DNS caching and performance optimizations
- Standard internet protocols for discovery

**Cross-Organization Collaboration**:
- Companies can expose services to partners
- Secure service sharing across organizational boundaries
- Policy-controlled access to external services

### Real-World Example

```
Company A Domain: finance.companyA.com
Company B Domain: hr.companyB.com

Scenario: Company A needs HR services from Company B

1. Client at Company A requests: hr-service@hr.companyB.com
2. NSM queries DNS: _nsm-registry._tcp.hr.companyB.com
3. DNS returns: hr-registry.companyB.com:8080
4. NSM contacts Company B's registry
5. Secure connection established between companies
```

This flexibility allows NSM to adapt to different organizational requirements while maintaining the core capability of cross-domain service connectivity.

## Key Components

### Control Plane Components

#### Network Service Manager (NSMgr)
- **Purpose**: Core orchestration component
- **Responsibilities**:
  - Network Service and Endpoint discovery
  - Client request processing
  - Connection state management
  - Registry functionality (optional)

#### Registry
- **Purpose**: Storage for Network Services and Endpoints
- **Responsibilities**:
  - Service and endpoint registration
  - Expiration management
  - Inter-domain query proxying

#### Registry Proxy DNS
- **Purpose**: Inter-domain service discovery
- **Responsibilities**:
  - Remote registry IP resolution
  - Cross-domain request proxying
  - URL translation for external access

#### NSMgr Proxy
- **Purpose**: Inter-domain connection establishment
- **Responsibilities**:
  - Cross-domain connection proxying
  - IP address translation
  - Service name translation

### Data Plane Components

#### Forwarder
- **Purpose**: Network interface management
- **Responsibilities**:
  - Client and endpoint interface creation
  - Mechanism selection for connections
  - Statistics collection
  - Load balancing
  - Connection context management

**Available Implementations**:
- **Forwarder VPP**: Uses Vector Packet Processing for high performance
- **Forwarder OVS**: Uses Open vSwitch for flexibility

### Kubernetes Integration Components

#### Admission Webhook K8s
- **Purpose**: Automatic NSM client injection
- **Responsibilities**:
  - Inject NSM clients into annotated Pods
  - Namespace-level injection support

#### Exclude Prefixes K8s
- **Purpose**: IP address management
- **Responsibilities**:
  - Collect Kubernetes network prefixes
  - Prevent NSM/K8s IP conflicts

#### Map IP K8s
- **Purpose**: Inter-domain IP mapping
- **Responsibilities**:
  - Map internal Pod IPs to external node IPs
  - Support cross-cluster connectivity

## NSM in Kubernetes

### Adding Network Services to Pods

Pods request Network Services using annotations:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    networkservicemesh.io: "kernel://my-networkservice-1"
spec:
  # ... pod specification
```

**Annotation Options**:
- **Basic**: `kernel://my-networkservice-1`
- **Named Interface**: `kernel://my-networkservice-1/nsm-1`
- **With Labels**: `kernel://my-networkservice-1/nsm-1?app=foo&version=v1.1`
- **Multiple Services**: `kernel://service-1, kernel://service-2`

### IPAM and Routing

For each Network Service connection:
- New kernel interface injected into Pod
- IP address assigned by the Endpoint
- Routes configured for Network Service traffic
- IP collision prevention with cluster networks

### DNS Integration

Network Services can provide DNS service:
- Scoped to specific domains/subdomains
- Parallel queries to cluster DNS and Network Service DNS
- First positive response returned to Pod

## Advanced Features

### Composition
Network Services can be composed of multiple Endpoints working together:
- Example: Envoy Proxy + vL3 network for service mesh
- Flexible service chaining
- Policy-driven composition

```mermaid
graph LR
    Client["Client Pod"]
    Envoy["Envoy Proxy Endpoint"]
    vL3["vL3 Endpoint"]
    
    Client -->|"vWire 1"| Envoy
    Envoy -->|"vWire 2"| vL3
    
    Client -.->|"Request: service-mesh@finance.example.com"| Envoy
    
    style Client fill:#e1f5fe
    style Envoy fill:#fff3e0
    style vL3 fill:#e8f5e8
```

Flow:
1. Client requests service-mesh network service
2. NSM routes to Envoy Proxy endpoint first
3. Envoy Proxy connects to vL3 endpoint
4. Traffic: Client → Envoy → vL3 → Destination

### Selective Composition
Different clients can receive different service compositions:
- Example: IPS insertion for vulnerable application versions
- Label-based service selection
- Granular security controls

```mermaid
graph TB
    subgraph Vulnerable["App foo v1.1 (vulnerable)"]
        ClientV11["Client foo v1.1<br/>Labels: app=foo, version=v1.1"]
    end
    
    subgraph Patched["App foo v1.2 (patched)"]
        ClientV12["Client foo v1.2<br/>Labels: app=foo, version=v1.2"]
    end
    
    IPS["IPS Endpoint<br/>(Security Filtering)"]
    vL3["vL3 Endpoint<br/>(Network Service)"]
    
    ClientV11 --> IPS
    IPS --> vL3
    ClientV12 --> vL3
    
    style ClientV11 fill:#ffebee
    style ClientV12 fill:#e8f5e8
    style IPS fill:#fff3e0
    style vL3 fill:#e3f2fd
```

Policy Logic:
• v1.1 apps → IPS → vL3 (security filtering)
• v1.2 apps → vL3 (direct access)

### Topologically Aware Features

NSM supports **Topologically Aware Endpoint Selection** and **Scale from Zero** capabilities that optimize resource usage while maintaining performance.

#### Topologically Aware Endpoint Selection

This feature allows NSM to select endpoints based on topology constraints like node location, availability zone, or cloud provider. This improves performance by keeping traffic local.

```mermaid
graph TB
    subgraph Zone1["Availability Zone 1"]
        Client1["Client Pod"]
        Endpoint1["Local Endpoint"]
    end
    subgraph Zone2["Availability Zone 2"]
        Client2["Client Pod"]
        Endpoint2["Local Endpoint"]
    end
    
    Client1 -->|"Prefers local"| Endpoint1
    Client2 -->|"Prefers local"| Endpoint2
    Client1 -.->|"Fallback"| Endpoint2
    
    style Endpoint1 fill:#e8f5e8
    style Endpoint2 fill:#e8f5e8
```

**Example Configuration**:
```yaml
apiVersion: networkservicemesh.io/v1
kind: NetworkService
metadata:
  name: local-vl3@marketing.example.com
spec:
  payload: IP
  matches:
    - source_selector:
      routes:
        - destination_selector:
            nodeName: "{{ .nodeName }}"
```

The `{{ .nodeName }}` template gets replaced with the client's actual node name, ensuring local endpoint selection.

#### Scale from Zero

**The Problem**: Topologically aware selection typically requires pre-deploying endpoints everywhere (expensive in large clusters).

**The Solution**: Create endpoints on-demand only when needed.

```mermaid
sequenceDiagram
    participant Client
    participant NSM as NSM Manager
    participant Supplier
    participant NewEndpoint as New Endpoint
    
    Client->>NSM: 1. Request service
    NSM->>NSM: 2. Try local endpoint (not found)
    NSM->>Supplier: 3. Contact supplier service
    Supplier->>NewEndpoint: 4. Create endpoint on target node
    Supplier->>NSM: 5. Return error (triggers reselect)
    NSM->>NSM: 6. Reselect - try local endpoint again
    NSM->>NewEndpoint: 7. Found new local endpoint
    NSM->>Client: 8. Connection established
```

**Configuration Example**:
```yaml
apiVersion: networkservicemesh.io/v1
kind: NetworkService
metadata:
  name: local-vl3@marketing.example.com
spec:
  payload: IP
  matches:
    - source_selector:
      routes:
        - destination_selector:
            nodeName: "{{ .nodeName }}"  # Try local first
    - source_selector:
      routes:
        - destination_selector:
            supplier: true  # Fallback to supplier
```

**Process Flow**:
1. **First Match**: Look for existing endpoint on same node as client
2. **Second Match**: If no local endpoint, contact supplier service
3. **Supplier Action**: Creates new endpoint on the desired node
4. **Intentional Error**: Supplier returns error to trigger reselection
5. **Reselect**: NSM tries matching again and finds the new endpoint
6. **Connection**: Client connects to the newly created local endpoint

**Benefits**:
- **Resource Efficiency**: Only create endpoints when needed
- **Topology Awareness**: Maintains performance benefits of locality
- **Scalability**: Works in clusters of any size without waste
- **Cost Effective**: Pay only for endpoints actually used

## NSM vs Traditional Service Mesh

### Complementary Technologies

```mermaid
graph TB
    subgraph Stack["Technology Stack"]
        subgraph L7["Layer 7 - Application Layer"]
            TSM["Traditional Service Mesh<br/>(Istio/Linkerd)<br/>• Traffic Management<br/>• Load Balancing<br/>• Circuit Breaking<br/>• Observability"]
        end
        
        subgraph L23["Layer 2/3 - Network Layer"]
            NSM["Network Service Mesh<br/>• Secure Tunneling<br/>• Network Isolation<br/>• Cross-Domain Connectivity<br/>• Identity-based Networking"]
        end
        
        subgraph Infra["Infrastructure Layer"]
            CNI["Kubernetes CNI / Infrastructure"]
        end
    end
    
    TSM -.->|"Better Together"| NSM
    NSM --> CNI
    
    style TSM fill:#e3f2fd
    style NSM fill:#e8f5e8
    style CNI fill:#fff3e0
```

**Traditional Service Mesh** (Istio, Linkerd, Consul):
- Focus on L7 payloads (HTTPS)
- Application-level features
- Traffic management and observability

**Network Service Mesh**:
- Focus on L3/L2 payloads (IP packets)
- Network-level connectivity
- Secure tunneling and isolation

### Better Together
- Traditional service meshes can be Network Services
- Workloads can connect to multiple service meshes
- Cross-company collaboration through shared NSM

## Zero Trust and Security

NSM implements Zero Trust principles:

```mermaid
graph TB
    subgraph Traditional["Traditional Network Security"]
        subgraph TrustedZone["Trusted Zone"]
            AppA1["App A"]
            AppB1["App B"]
        end
        subgraph UntrustedZone["Untrusted Zone"]
            AppC1["App C"]
            AppD1["App D"]
        end
        TrustedZone -.->|"Perimeter-based<br/>Broad access within zones<br/>Vulnerable to lateral movement"| UntrustedZone
    end
    
    subgraph ZeroTrust["NSM Zero Trust Security"]
        AppA2["App A<br/>SPIFFE ID"]
        AppB2["App B<br/>SPIFFE ID"]
        AppC2["App C<br/>SPIFFE ID"]
        AppD2["App D<br/>SPIFFE ID"]
        
        AppA2 <-->|"Mutual TLS"| AppB2
        AppC2 <-->|"Mutual TLS"| AppD2
        AppA2 -.->|"Identity-based<br/>Minimal access per connection<br/>Contained breach impact"| AppC2
    end
    
    style TrustedZone fill:#ffebee
    style UntrustedZone fill:#ffebee
    style AppA2 fill:#e8f5e8
    style AppB2 fill:#e8f5e8
    style AppC2 fill:#e8f5e8
    style AppD2 fill:#e8f5e8
```

**Core Security Features**:
- **SPIFFE Identity**: Cryptographic workload identity
- **Mutual TLS**: All connections authenticated
- **Minimal Access**: Granular Network Service connections
- **Audit Trail**: Cryptographic identity from L3-L7
- **Certificate Management**: Automatic rotation and renewal

**Zero Trust Benefits**:
- Users get minimum required access
- Compromised devices have contained damage
- Cryptographic auditability across network layers
- Policy-driven access control

## Use Cases

### Enterprise Scenarios
- **Multi-cloud Connectivity**: Secure workload communication across clouds
- **Legacy Application Support**: L2/L3 connectivity for existing applications
- **Compliance Requirements**: Encrypted, auditable communications
- **Partner Collaboration**: Selective cross-company workload access

### Technical Applications
- **Database Replication**: Secure DB-to-DB communication
- **Network Function Virtualization**: Chained network services
- **Development/Testing**: Isolated network environments
- **Microservice Security**: Per-service network policies

## Acronyms

| Acronym | Full Form | Description |
|---------|-----------|-------------|
| **NSM** | Network Service Mesh | Cloud-native networking solution for secure workload connectivity |
| **NSC** | Network Service Client | Workload that consumes network services |
| **NSE** | Network Service Endpoint | Component that provides network services |
| **NSR** | Network Service Registries | Storage and discovery system for network services and endpoints |
| **NSMgr** | Network Service Manager | Core orchestration component that manages connections |
| **SPIFFE** | Secure Production Identity Framework for Everyone | Identity framework for workload authentication |
| **vWire** | Virtual Wire | Secure connection between client and endpoint |
| **vL3** | Virtual Layer 3 | Virtual L3 network service providing IP connectivity |

## Summary

Network Service Mesh provides a novel approach to cloud-native networking by:

1. **Decoupling** connectivity from runtime domains
2. **Enabling** secure, granular workload communication
3. **Supporting** multi-cloud and hybrid environments
4. **Implementing** Zero Trust networking principles
5. **Complementing** existing service mesh technologies

This architecture enables organizations to build secure, scalable, and flexible network infrastructures that adapt to modern distributed application requirements.
