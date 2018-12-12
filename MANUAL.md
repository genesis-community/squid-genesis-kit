# Squid Proxy Genesis Kit Manual

The **Squid Proxy Genesis Kit** deploys a Squid HTTP/HTTPS proxy
which you (and your deployments) can use for accessing HTTP
resources on other networks, like the public Internet, without
having direct access.

# Base Parameters

- `port` - The port to listen on.  Defaults to `3128`.

- `acl` - The Squid Proxy Access Control List (ACL) which will
  govern who can use the proxy, and what they are allowed to
  connect to, via what protocol.s

  The default ACL allows private networks to connect out to most
  common HTTP/HTTPS ports.  See the section **Default ACL**,
  later, for more details.

- `vm_type` - What type of VM to deploy.  This type must
  exist in your cloud config.  Defaults to `default`.

- `network` - What network to deploy Squid into.  This network
  must be defined in your cloud config.  Defaults to `squid`.

- `stemcell_os` - The operating system stemcell you want to
  deploy on. (default: `ubuntu-xenial`)

- `stemcell_version` - The specific version of the stemcell you
  want to deploy on. (default: `latest`)

- `availability_zones` - What BOSH HA availability zones to deploy
  the proxy across.  The chosen network must have at least one
  subnet in each of the listed zones, and the zones themselves
  must be defined in your cloud config.  Defaults to `z1`.

  **Note**: This Genesis Kit only deploys a single-instance Squid
  proxy, so availability zone configuration will not bring high
  availability to the deployment.

# Cloud Configuration

By default, Squid uses the following VM types/networks from your
cloud config. Feel free to override them in your environment, if
you would rather they use entities already existing in your cloud
config:

```
params:
  network: squid
  vm_type: default
```

# Available Addons

- `curl` - Test HTTP/HTTPS access, through the deployed proxy,
  to an arbitrary endpoint, using the `curl` utility.  You have to
  install curl, of course, but this lets you run arbitrarily
  complicated HTTP requests through the proxy.

# Examples

To use custom cloud config types:

```
---
kit:
  name:    squid
  version: 0.0.1

params:
  env: acme-us-east-1-prod

  network:   dmz
  vm_type:   std.med.4c.8gb
```

# Default ACLs

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
allow localnet
```

This ACL allows RFC-1918 private networks (10/8, 172.16/12, and
192.168/16) to use the proxy, only allows SSL/TLS on 443, and
tries to limit ports to a sane list.

# History

Version 0.3.0 was the first version to support Genesis 2.6 hooks
for addon scripts and `genesis info`.
