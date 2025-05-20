# Squid Proxy Architecture Guide

This document provides an overview of the Squid Proxy architecture as deployed by the Genesis Kit, including network design considerations, component interactions, and deployment models.

## Overview

The Squid Genesis Kit deploys a single Squid proxy server that acts as an intermediary between clients in restricted networks and internet resources. The proxy provides:

1. **Controlled Internet Access**: Allows specified internal systems to access external resources
2. **Access Control**: Enforces policies about who can access what
3. **Content Filtering**: Can filter access based on URLs, domains, and content types
4. **Caching**: Improves performance by caching frequently accessed content
5. **Logging and Auditing**: Records all access attempts for security and compliance

## Architectural Components

### Core Components

The deployment consists of these primary components:

1. **Squid Proxy Service**: The main proxy service running on port 3128
2. **Access Control Lists (ACLs)**: Rules defining access permissions
3. **Cache Manager**: Handles caching of web content
4. **Logging System**: Records all proxy activity

### Network Architecture

A typical deployment follows this network architecture:

```
┌────────────────┐     ┌──────────────┐     ┌────────────┐
│                │     │              │     │            │
│  Internal      │     │  Squid Proxy │     │  External  │
│  Networks      ├────►│  (3128)      ├────►│  Internet  │
│                │     │              │     │            │
└────────────────┘     └──────────────┘     └────────────┘
       │                      ▲                    ▲
       │                      │                    │
       │                      │                    │
       │                      │                    │
┌──────┴───────────┐ ┌────────┴─────────┐ ┌───────┴─────────┐
│  BOSH Director   │ │  Cloud Foundry   │ │  Other Internal │
│  Deployment      │ │  Deployment      │ │  Systems        │
└──────────────────┘ └──────────────────┘ └─────────────────┘
```

### Deployment Model

The Squid Genesis Kit follows the BOSH deployment model:

1. **Single VM**: Deployed as a standalone virtual machine
2. **BOSH Managed**: Lifecycle managed by BOSH
3. **Configuration via Genesis**: Parameters defined in Genesis environment files
4. **Single Availability Zone**: Deployed to a single AZ (no built-in HA)

## Network Design Considerations

### Placement in Network Topology

Optimal placement depends on your specific needs:

1. **DMZ Deployment**: 
   - Place the proxy in a DMZ network
   - Allows controlled access from internal networks to the internet
   - Maintains security boundary between internal and external networks

2. **Perimeter Deployment**:
   - Place directly at the network edge
   - Provides filtering for all outbound traffic
   - May require additional hardening

3. **Internal Network Deployment**:
   - Place within the internal network
   - Easier for internal systems to access
   - Requires additional network rules for internet access

### Network Security Groups / Firewall Rules

Required network rules:

1. **Inbound Rules**:
   - Allow TCP/3128 from internal networks to the proxy
   - Allow management access from BOSH director

2. **Outbound Rules**:
   - Allow TCP/80 (HTTP) from proxy to internet
   - Allow TCP/443 (HTTPS) from proxy to internet
   - Allow DNS (UDP/53) for name resolution

### IP Addressing

Considerations for proxy IP assignment:

1. **Static IP**: Assign a static IP to the proxy for client configurations
2. **DNS Records**: Consider creating DNS records for easy client configuration
3. **IP Visibility**: Ensure the proxy IP is routable from all client networks

## High Availability Considerations

The standard deployment does not provide high availability. For increased reliability:

### Manual HA Options

1. **Multiple Independent Proxies**:
   - Deploy multiple separate Squid instances
   - Configure clients with multiple proxy addresses
   - Use client-side failover

2. **Load Balancer Approach**:
   - Deploy multiple Squid instances
   - Place a load balancer in front
   - Clients connect to the load balancer VIP

3. **Active/Passive Setup**:
   - Deploy primary and standby proxies
   - Use floating IP or DNS switching for failover
   - Implement health checks for automatic failover

### Configuration Synchronization

For multi-proxy setups, maintain configuration consistency:

1. Use identical Genesis environment files for all proxies
2. Consider configuration management tools for ACL synchronization
3. Deploy proxies from the same Genesis environment

## Logical Architecture

### Request Flow

When a client makes a request through the proxy:

1. Client sends HTTP/HTTPS request to the proxy
2. Proxy checks ACLs to determine if request is allowed
3. If allowed and cached, proxy returns cached content
4. If allowed and not cached, proxy fetches from the internet
5. Proxy logs the request
6. Response is returned to the client

### Caching Behavior

The default Squid configuration includes caching:

1. **Cache Location**: `/var/spool/squid`
2. **Cache Size**: Determined by available disk space
3. **Cache Policy**: Standard Squid rules for cacheable content
4. **Cache Hierarchy**: Single-level cache (no peer caches)

## Integration with Other Systems

### BOSH Director Integration

```
┌─────────────────┐     ┌──────────────┐     ┌────────────┐
│                 │     │              │     │            │
│  BOSH Director  ├────►│  Squid Proxy ├────►│  Internet  │
│                 │     │              │     │            │
└─────────────────┘     └──────────────┘     └────────────┘
```

- Director configured with proxy environment variables
- Used for stemcell and release downloads
- Director components bypass proxy for internal communications

### Cloud Foundry Integration

```
┌─────────────────┐     ┌──────────────┐     ┌────────────┐
│                 │     │              │     │            │
│  Cloud Foundry  ├────►│  Squid Proxy ├────►│  Internet  │
│                 │     │              │     │            │
└─────────────────┘     └──────────────┘     └────────────┘
```

- Used for buildpack downloads
- Used for application dependency fetching
- Service broker external communications
- Bypassed for internal CF traffic

## Security Architecture

### Access Control Model

The Squid Genesis Kit uses a layered security approach:

1. **Network-Level Security**:
   - Firewall rules control which clients can connect to the proxy
   - IP-based ACLs restrict access to authorized networks

2. **Protocol-Level Security**:
   - Restrict allowed methods (GET, POST, CONNECT, etc.)
   - Limit ports (80, 443, etc.)

3. **Content-Level Security** (with custom configuration):
   - URL filtering
   - Domain restrictions
   - Content-type filtering

### Authentication Options

The default configuration doesn't include authentication, but these methods can be added:

1. **IP-Based Authentication**: Default approach using source IP restriction
2. **Basic Authentication**: Username/password (requires custom configuration)
3. **LDAP Integration**: Enterprise authentication (requires custom configuration)

## Performance Considerations

### Sizing Guidelines

Size your Squid proxy based on expected load:

| Usage Level | Concurrent Users | VM Size Recommendation | Disk Cache |
|-------------|------------------|------------------------|------------|
| Small       | <50              | 1 vCPU, 2GB RAM        | 5-10GB     |
| Medium      | 50-200           | 2 vCPU, 4GB RAM        | 10-20GB    |
| Large       | 200-500          | 4 vCPU, 8GB RAM        | 20-50GB    |
| Very Large  | 500+             | 8+ vCPU, 16GB+ RAM     | 50GB+      |

### Performance Tuning

For optimal performance:

1. **Memory Allocation**:
   - Consider increasing VM memory for busy proxies
   - More memory improves caching performance

2. **Disk I/O**:
   - Use fast storage for the cache directory
   - Consider SSD for high-traffic deployments

3. **Network Bandwidth**:
   - Ensure adequate bandwidth between proxy and internet
   - Monitor for network bottlenecks

## Operational Architecture

### Monitoring Points

Key monitoring points in the architecture:

1. **VM Health**: CPU, memory, disk usage
2. **Squid Process**: Service status and resource usage
3. **Network Traffic**: Bandwidth utilization, connection counts
4. **Cache Performance**: Hit ratio, object counts, memory usage
5. **Client Metrics**: Request rates, response times, error rates

### Backup Considerations

For proxy backup:

1. **Configuration Backup**: 
   - Back up Genesis environment files
   - Version control for custom ACLs

2. **Cache Backup**: 
   - Generally unnecessary to back up cache data
   - Cache will rebuild naturally with use

3. **Log Backup**:
   - Ship logs to a central log management system
   - Retain logs according to compliance requirements

## Conclusion

The Squid Proxy deployed by this Genesis Kit provides a robust, centralized gateway for HTTP/HTTPS traffic from restricted networks to the internet. While simple in its default deployment model, it can be configured and integrated to meet a wide variety of network security and access requirements.

By understanding this architecture, you can better plan, deploy, and manage your Squid proxy to ensure it meets your organization's needs for secure internet access.