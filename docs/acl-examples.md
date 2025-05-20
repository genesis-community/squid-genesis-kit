# Squid ACL Configuration Examples

This document provides examples of various Access Control List (ACL) configurations for the Squid proxy deployed with the Genesis Kit.

## ACL Basics

Squid ACLs are composed of two parts:
1. ACL definitions that match specific criteria (like source IP, destination ports, etc.)
2. Access rules that allow or deny access based on those ACL definitions

## Default ACL

Here's the default ACL that ships with the kit:

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

This default ACL:
- Allows RFC-1918 private networks to use the proxy
- Restricts access to a predefined list of "safe" ports
- Only allows SSL/TLS CONNECT methods on port 443
- Denies everything else

## Common ACL Examples

### Restrict Access by Source IP

To limit access to specific IP ranges:

```yaml
params:
  acl: |
    # Only allow specific subnets
    acl development_net src 10.10.10.0/24
    acl production_net src 10.20.30.0/24
    
    acl SSL_ports  port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    http_access allow development_net
    http_access allow production_net
    http_access deny all
```

### Time-Based Access

To restrict internet access to business hours:

```yaml
params:
  acl: |
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16
    
    # Define business hours (8am-6pm, Monday-Friday)
    acl business_hours time M T W H F 8:00-18:00
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    
    # Allow local networks during business hours only
    http_access allow localnet business_hours
    http_access deny all
```

### Destination Domain Filtering

To restrict or allow access to specific domains:

```yaml
params:
  acl: |
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16
    
    # Define allowed and blocked domains
    acl allowed_domains dstdomain .github.com .rubygems.org .ubuntu.com
    acl blocked_domains dstdomain .facebook.com .twitter.com .instagram.com
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    
    # Block access to specified domains
    http_access deny localnet blocked_domains
    
    # Only allow access to permitted domains
    http_access allow localnet allowed_domains
    
    # Deny all other access
    http_access deny all
```

### URL Path Filtering

To filter based on URL paths:

```yaml
params:
  acl: |
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16
    
    # Block downloads of specific file types
    acl blocked_extensions urlpath_regex -i \.(exe|mp3|mp4|avi|mpg|mov)$
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    
    # Block downloads of specified file types
    http_access deny localnet blocked_extensions
    
    # Allow other traffic
    http_access allow localnet
    http_access deny all
```

### User-Agent Filtering

To filter based on User-Agent strings:

```yaml
params:
  acl: |
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16
    
    # Block certain user agents (e.g., outdated browsers)
    acl blocked_agents browser -i "MSIE [1-8]\."
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    
    # Block outdated browsers for security reasons
    http_access deny localnet blocked_agents
    
    # Allow other traffic
    http_access allow localnet
    http_access deny all
```

## Advanced Configurations

### Combining Multiple ACL Types

Complex policy example combining multiple ACL types:

```yaml
params:
  acl: |
    # Define networks with different privilege levels
    acl admin_net src 10.10.10.0/24
    acl regular_net src 10.0.0.0/8
    acl guest_net src 172.16.0.0/12
    
    # Time-based restrictions
    acl business_hours time M T W H F 8:00-18:00
    acl weekend time A S 0:00-23:59
    
    # Content categories
    acl streaming_sites dstdomain .netflix.com .hulu.com .youtube.com
    acl social_media dstdomain .facebook.com .twitter.com .instagram.com
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    
    # Admin network has full access
    http_access allow admin_net
    
    # Regular network has restricted access
    http_access deny regular_net social_media !business_hours
    http_access deny regular_net streaming_sites
    http_access allow regular_net
    
    # Guest network has minimal access
    http_access deny guest_net social_media
    http_access deny guest_net streaming_sites
    http_access allow guest_net business_hours
    http_access allow guest_net weekend
    
    # Deny all other access
    http_access deny all
```

### Authentication-Based ACL

To require user authentication:

```yaml
params:
  acl: |
    auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
    auth_param basic realm Squid Proxy Authentication
    
    acl authenticated proxy_auth REQUIRED
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    
    # Require authentication from local networks
    http_access allow localnet authenticated
    http_access deny all
```

**Note:** This example requires additional Squid configuration and creating a password file on the Squid VM.

## Performance Optimizations

To optimize caching behavior:

```yaml
params:
  acl: |
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16
    
    # Define cacheable content
    acl static_content urlpath_regex -i \.(jpg|jpeg|gif|png|ico|css|js)$
    
    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT
    
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    http_access allow localnet
    http_access deny all
    
    # Cache static content for up to 1 hour
    refresh_pattern -i \.(jpg|jpeg|gif|png|ico|css|js)$ 10080 50% 43200 override-expire
    # Don't cache other content
    refresh_pattern . 0 0% 0
```

## Implementation Notes

1. To apply a custom ACL, include it in your environment file:
   ```yaml
   params:
     acl: |
       # Your ACL rules here...
   ```

2. After changing ACL rules, redeploy the Squid proxy:
   ```
   genesis deploy my-environment
   ```

3. Test your ACL rules after deployment to ensure they work as expected.

4. For complex ACL configurations, consider testing in a staging environment first.