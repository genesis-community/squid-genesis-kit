# Squid Proxy Genesis Kit Manual

## Table of Contents

1. [Overview](#overview)
2. [Deployment Parameters](#deployment-parameters)
   - [Network Parameters](#network-parameters)
   - [VM Parameters](#vm-parameters)
   - [Squid Configuration Parameters](#squid-configuration-parameters)
3. [Cloud Configuration](#cloud-configuration)
4. [Available Addons](#available-addons)
5. [Deployment Scenarios](#deployment-scenarios)
   - [Basic Deployment](#basic-deployment)
   - [AWS Deployment](#aws-deployment)
   - [GCP Deployment](#gcp-deployment)
   - [vSphere Deployment](#vsphere-deployment)
6. [Integration with Other Systems](#integration-with-other-systems)
   - [BOSH Director Integration](#bosh-director-integration)
   - [Cloud Foundry Integration](#cloud-foundry-integration)
7. [ACL Configuration](#acl-configuration)
   - [Default ACLs](#default-acls)
   - [Custom ACL Examples](#custom-acl-examples)
8. [Advanced Configuration](#advanced-configuration)
9. [Troubleshooting](#troubleshooting)
10. [History](#history)

## Overview

The **Squid Proxy Genesis Kit** deploys a Squid HTTP/HTTPS proxy
which you (and your deployments) can use for accessing HTTP
resources on other networks, like the public Internet, without
having direct access.

This kit deploys a single instance of Squid proxy that can serve as an egress point for HTTP and HTTPS traffic in restricted network environments. The proxy is particularly useful in compliance-driven environments where direct internet access is limited or prohibited.

## Deployment Parameters

### Network Parameters

- `port` - The port that Squid will listen on. Defaults to `3128`.

- `network` - What network to deploy Squid into. This network
  must be defined in your cloud config. Defaults to `squid`.

- `availability_zones` - What BOSH HA availability zones to deploy
  the proxy across. The chosen network must have at least one
  subnet in each of the listed zones, and the zones themselves
  must be defined in your cloud config. Defaults to `z1`.

  **Note**: This Genesis Kit only deploys a single-instance Squid
  proxy, so availability zone configuration will not bring high
  availability to the deployment.

### VM Parameters

- `vm_type` - What type of VM to deploy. This type must
  exist in your cloud config. Defaults to `default`.

- `stemcell_os` - The operating system stemcell you want to
  deploy on. (default: `ubuntu-xenial`)

- `stemcell_version` - The specific version of the stemcell you
  want to deploy on. (default: `latest`)

### Squid Configuration Parameters

- `acl` - The Squid Proxy Access Control List (ACL) which will
  govern who can use the proxy, and what they are allowed to
  connect to, via what protocols.

  The default ACL allows private networks to connect out to most
  common HTTP/HTTPS ports. See the section [Default ACLs](#default-acls),
  later, for more details.

## Cloud Configuration

By default, Squid uses the following VM types/networks from your
cloud config. Feel free to override them in your environment, if
you would rather they use entities already existing in your cloud
config:

```yaml
params:
  network: squid
  vm_type: default
```

The cloud configuration also needs to define the appropriate network(s) that will be used by the Squid proxy. For example:

```yaml
networks:
- name: squid
  subnets:
  - range: 10.0.0.0/24
    gateway: 10.0.0.1
    dns: [8.8.8.8, 8.8.4.4]
    static: [10.0.0.5]
    cloud_properties:
      name: MY-NETWORK
```

## Available Addons

Genesis kit addons are small add-on scripts that can be run via
`genesis do`.

- `curl` - Test HTTP/HTTPS access, through the deployed proxy,
  to an arbitrary endpoint, using the `curl` utility. You have to
  install curl, of course, but this lets you run arbitrarily
  complicated HTTP requests through the proxy.

  Example:
  ```
  genesis do my-env -- curl https://www.google.com
  ```

## Deployment Scenarios

### Basic Deployment

A basic deployment requires minimal configuration. The following environment file will deploy a Squid proxy with all default settings:

```yaml
---
kit:
  name:    squid
  version: 1.2.0

params:
  env: basic-deployment
```

### AWS Deployment

For AWS deployments, you'll want to ensure the proxy is in a subnet with internet access (like a public subnet):

```yaml
---
kit:
  name:    squid
  version: 1.2.0

params:
  env: aws-deployment
  
  # Use AWS-specific network and VM type from your cloud config
  network: public
  vm_type: t3.small
```

Ensure your AWS security groups allow:
- Outbound traffic on ports 80 and 443 (to the internet)
- Inbound traffic on port 3128 (from your internal networks)

### GCP Deployment

For GCP deployments:

```yaml
---
kit:
  name:    squid
  version: 1.2.0

params:
  env: gcp-deployment
  
  # Use GCP-specific network and VM type from your cloud config
  network: proxy-network
  vm_type: n1-standard-1
```

### vSphere Deployment

For vSphere deployments:

```yaml
---
kit:
  name:    squid
  version: 1.2.0

params:
  env: vsphere-deployment
  
  # Use vSphere-specific network and VM type from your cloud config
  network: dmz
  vm_type: small
```

## Integration with Other Systems

### BOSH Director Integration

To configure a BOSH director to use your Squid proxy, add the following to your BOSH Genesis Kit deployment environment file:

```yaml
params:
  http_proxy: http://SQUID-IP:3128
  https_proxy: http://SQUID-IP:3128
  no_proxy: 127.0.0.1,localhost,BOSH-DIRECTOR-IP
```

Replace `SQUID-IP` with your Squid proxy's IP address and `BOSH-DIRECTOR-IP` with the IP address of your BOSH director.

### Cloud Foundry Integration

For Cloud Foundry deployments to use your Squid proxy, add the following to your CF Genesis Kit deployment environment file:

```yaml
params:
  http_proxy: http://SQUID-IP:3128
  https_proxy: http://SQUID-IP:3128
  no_proxy: 127.0.0.1,localhost,BOSH-DIRECTOR-IP,CF-INTERNAL-IPS
```

Replace `SQUID-IP` with your Squid proxy's IP address, `BOSH-DIRECTOR-IP` with the IP address of your BOSH director, and `CF-INTERNAL-IPS` with a comma-separated list of your CF deployment's internal IP addresses.

## ACL Configuration

### Default ACLs

Here is the default Squid access control list (ACL) that you get
if you don't override it with the `acl` property:

```
acl localnet src 10.0.0.0/8     # RFC 1918 possible internal network
acl localnet src 172.16.0.0/12  # RFC 1918 possible internal network
acl localnet src 192.168.0.0/16 # RFC 1918 possible internal network
acl localnet src fc00::/7       # RFC 4193 local private network range
acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines

acl SSL_ports  port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localnet
http_access deny all
```

This ACL allows RFC-1918 private networks (10/8, 172.16/12, and
192.168/16) to use the proxy, only allows SSL/TLS on 443, and
tries to limit ports to a sane list.

### Custom ACL Examples

#### Restrict Access to Specific Network Ranges

If you want to limit proxy access to only certain network ranges:

```yaml
params:
  acl: |
    acl restricted_net src 10.10.10.0/24  # Only allow this specific subnet
    
    acl SSL_ports  port 443
    acl Safe_ports port 80          # http
    acl Safe_ports port 443         # https
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    http_access allow restricted_net
    http_access deny all
```

#### Allow Access to Only Specific Domains

To restrict outbound access to specific domains only:

```yaml
params:
  acl: |
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    
    # Define allowed domains
    acl allowed_domains dstdomain .github.com .rubygems.org .ubuntu.com
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    # Only allow access to defined domains
    http_access allow localnet allowed_domains
    http_access deny all
```

Note: This requires additional Squid configuration and may need custom Squid packages depending on your requirements.

## Advanced Configuration

For advanced Squid configurations, you may need to customize beyond what the Genesis Kit provides by default. This can be done by deploying a custom BOSH release or by providing a fully customized ACL configuration.

### Monitoring and Metrics

While not built into the Genesis Kit directly, you can monitor your Squid proxy using standard BOSH VM monitoring tools. Key metrics to watch include:

- CPU and memory usage
- Disk space usage (for caching)
- Network throughput
- Number of concurrent connections

### Performance Tuning

For high-traffic environments, consider the following:

1. Increase the VM size (modify `vm_type` parameter)
2. Optimize the Squid cache settings (requires custom ACL)
3. Consider deploying multiple proxies behind a load balancer for true high availability

## Troubleshooting

### Common Issues

1. **Cannot Connect to Proxy**:
   - Verify network connectivity 
   - Check security groups/firewall rules
   - Verify the proxy is running (`bosh -d squid instances`)

2. **Access Denied Errors**:
   - Check ACL configuration
   - Verify client IP is within allowed ranges
   - Check Squid logs for denied requests

3. **Slow Performance**:
   - Check VM resource utilization
   - Verify network bandwidth isn't saturated
   - Consider tuning Squid cache settings

### Viewing Logs

To view the Squid proxy logs:

```
genesis my-env logs squid/0 -f
```

## History

- Version 1.2.0 - Refactored hooks to perl modules, extracted addon functionality.
- Version 1.0.0 - Initial stable release.
- Version 0.3.0 - First version to support Genesis 2.6 hooks for addon scripts and `genesis info`.