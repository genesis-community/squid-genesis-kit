# Squid Proxy Genesis Kit Manual

## Overview

The Squid Proxy Genesis Kit deploys a single Squid HTTP and HTTPS proxy. Your deployments can use it to reach HTTP resources on other networks, such as the public Internet, when they have no direct access of their own. It's most useful in compliance-driven environments, where direct Internet access is limited or forbidden and the proxy becomes the one controlled egress point.

The kit needs Genesis 3.1.0 or later.

## Parameters

### Network parameters

- `port`

  The port that Squid listens on. It defaults to `3128`, and it has to be from 1024 to 65535. Squid runs as `vcap` without any capabilities, so it can't bind a lower port, and the kit refuses one when it builds the manifest.

- `network`

  The network that Squid is deployed into, which must exist in your cloud config. It defaults to `squid`, and the `ocfp` feature sets it for you.

- `availability_zones`

  The BOSH availability zones for the proxy. The network needs a subnet in each zone, and the zones must exist in your cloud config. It defaults to `z1`. The kit deploys one instance, so listing more zones does not make the proxy highly available. The `ocfp` feature replaces this list with the one AZ of the subnet that reserves the proxy's address.

### VM parameters

- `vm_type`

  The VM type to deploy, which must exist in your cloud config. It defaults to `default`, and the `ocfp` feature sets it for you.

- `stemcell_os`

  The stemcell operating system. It defaults to `ubuntu-xenial`. To deploy on `ubuntu-resolute`, turn on the `resolute` feature instead of setting this parameter, because the feature also changes the squid release.

- `stemcell_version`

  The stemcell version. It defaults to `latest`.

### Squid parameters

- `acl`

  The Squid access control list, which governs who can use the proxy, what they can connect to, and over which protocols. The default lets private networks connect out to the common HTTP and HTTPS ports, and the [ACL configuration](#acl-configuration) section shows it in full.

## Features

### ocfp

The `ocfp` feature deploys the proxy into the OCFP reference architecture. It names the network and VM type `<env>.squid.net-squid` and `<env>.squid.vm-squid`, and the cloud-config hook builds both from the OCFP config.

Other deployments are told the proxy's address, so the address has to stay put. The feature takes it from a `squid_ip` reserved address on the first OCFP subnet that has one, and it places the proxy in that subnet's AZ. Reserve the address in the OCFP config and run `ocfp vault populate` before you deploy. The kit refuses to build the manifest when no subnet reserves a `squid_ip`, when that subnet names no AZ, or when the director's network exodus data doesn't know the AZ.

The feature resolves the subnet's AZ the same way the cloud-config hook does, so the instance group and the subnet always agree. The AZ can be the key in the director's network exodus data, the AZ's rendered name, or the `zN` short form of that name. When the director records a name for the AZ under its CPI, the feature uses that name.

### resolute

The `resolute` feature deploys the proxy on the `ubuntu-resolute` stemcell. It sets `params.stemcell_os` to `ubuntu-resolute`, and it swaps the squid release from 1.1.0 to 2.0.0.

We need the new release because squid 1.1.0 starts Squid with `chpst`, which comes with runit, and the resolute stemcell no longer ships runit. squid 2.0.0 builds Squid 7.7 and starts it with `setpriv` from util-linux instead. Squid 7 needs a C++17 compiler, which the default xenial stemcell doesn't have, so xenial deployments stay on squid 1.1.0.

The kit refuses an environment that turns the feature on while setting `params.stemcell_os` to another os. It also refuses one that sets `params.stemcell_os` to `ubuntu-resolute` without the feature, and the message tells you to enable the feature and remove the parameter.

For now, the feature pins squid `2.0.0+dev.2`, a dev release that isn't published anywhere yet. Upload it to the director yourself before you deploy:

```
genesis my-env bosh upload-release squid-2.0.0+dev.2.tgz
```

Moving an existing environment from xenial to the resolute feature changes the stemcell, so BOSH recreates the proxy's VM, and nothing from squid 1.1.0 is left running on it.

The deployment repo's ops files load after all of the kit's own files, in the order that the features list them. That includes `ops/resolute.yml`, which still applies when the feature is on. So an ops file can change the stemcell, or pin another squid release, such as the final 2.0.0, and its pin wins over the dev release that the feature pins.

### Ops files

Any other feature name loads `ops/<feature>.yml` from the deployment repo, after the kit's own files. The kit refuses a feature name that matches neither a kit feature nor an ops file.

## Deploy-time checks

The blueprint gate reads only params, so an ops file can still change the stemcells or the releases after the gate passes. The pre-deploy hook checks the merged manifest as the last word, and it refuses the deploy in these cases:

- The `resolute` feature is on, but some stemcell is on another os. The check reads a stemcell's `os`, or its `name` when it has no `os`, such as `bosh-aws-xen-hvm-ubuntu-resolute-go_agent`, and it counts the FIPS stemcells as their series.

- A resolute stemcell is paired with a squid release older than 2.0.0, which would fail to start without `chpst`. The check runs with the feature off too. It looks only at the stemcells of the instance groups that run a squid job, and a release candidate such as `2.0.0-rc.1` counts as the version it leads to.

- A trusty, xenial, or bionic stemcell is paired with squid 2.0.0 or later, which would fail to compile Squid 7.

- An ops file adds bpm older than 1.4.41 next to a resolute stemcell, because older bpm releases don't compile there. A release candidate of 1.4.41 counts as older. The kit doesn't deploy bpm itself.

- The squid or bpm release has no version, or is pinned to `latest`, on a stemcell that the checks care about. Each of the two cases has its own message.

The hook resolves `((name))` and `((name.key))` placeholders from the BOSH variables file before it checks, and it refuses a placeholder that no variable resolves. When every check passes, it prints one line that names the releases and the stemcells it checked.

## Cloud config

Outside OCFP, the proxy uses the network and VM type named in your params, which default to these:

```yaml
params:
  network: squid
  vm_type: default
```

The network needs one static address for the proxy, for example:

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

Under OCFP, the cloud-config hook generates the network, the VM type, and a disk type for AWS, OpenStack, and PVE. On PVE, it reads these settings from the environment file first, then from the OCFP config, and falls back to a default when neither sets one:

| Environment file setting | OCFP config key | Default |
|-----|-----|-----|
| `bosh-configs.cpi.pve_network_bridge` | `cpi/pve:network_bridge` | `vmbr0` |
| `bosh-configs.cpi.pve_disk_storage` | `cpi/pve:disk_storage` | `local-lvm` |
| `bosh-configs.cpi.pve_disk_format` | none | `raw` |
| `bosh-configs.cpi.pve_squid_cpu` | none | 2 |
| `bosh-configs.cpi.pve_squid_ram` | none | 2048 MB, or 4096 MB at prod scale |
| `bosh-configs.cpi.pve_squid_disk` | none | 16384 MB |

When neither place sets the network bridge or the disk storage, the hook uses the default and prints a warning that names both settings. The default bridge, `vmbr0`, is often the host's own LAN and not the network that your deployments use, so check the warning before you deploy.

## Addons

Genesis addons are small commands that you run with `genesis do`.

- `curl`

  Sends a request through the deployed proxy with your local `curl`, so you can test that the proxy reaches an endpoint. Every argument goes to curl unchanged, and the addon fails when curl does. You need curl installed.

  ```
  genesis my-env do curl -sI https://www.google.com
  ```

  A leading `--` is dropped, so `do curl -- -sI https://www.google.com` does the same thing. The addon names the proxy on curl's command line and clears `http_proxy`, `https_proxy`, `all_proxy`, `no_proxy`, and their uppercase forms, so your shell's proxy settings can't send the request around Squid. Genesis's trace log shows the arguments as redacted, because they can hold credentials, such as an `Authorization` header.

## Example environments

A minimal environment file deploys the proxy with every default:

```yaml
---
kit:
  name:    squid
  version: latest
  features: []

genesis:
  env: my-env

params: {}
```

An OCFP environment on the resolute stemcell looks like this:

```yaml
---
kit:
  name:    squid
  version: latest
  features:
  - ocfp
  - resolute

genesis:
  env:      ocfp-mgmt
  bosh_env: ocfp-mgmt

params:
  stemcell_version: "0.184"
```

On AWS, put the proxy in a subnet that has Internet access. Your security groups should allow outbound traffic on ports 80 and 443, and inbound traffic on port 3128 from your internal networks.

## Integration with other systems

### BOSH directors

To send a BOSH director through the proxy, add the proxy settings to the director's environment file:

```yaml
params:
  http_proxy:  http://SQUID-IP:3128
  https_proxy: http://SQUID-IP:3128
  no_proxy:    127.0.0.1,localhost,BOSH-DIRECTOR-IP
```

Replace `SQUID-IP` with the proxy's address, which `genesis my-env info` prints, and `BOSH-DIRECTOR-IP` with the director's address.

### Cloud Foundry

Cloud Foundry takes the same settings, and its `no_proxy` list should also name the deployment's internal addresses:

```yaml
params:
  http_proxy:  http://SQUID-IP:3128
  https_proxy: http://SQUID-IP:3128
  no_proxy:    127.0.0.1,localhost,BOSH-DIRECTOR-IP,CF-INTERNAL-IPS
```

## ACL configuration

### The default ACL

You get this access control list unless you set the `acl` parameter:

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
```

The release adds `http_access deny all` after your ACL. The default lets clients on the RFC 1918 private networks, the IPv6 unique local range `fc00::/7`, and the IPv6 link-local range `fe80::/10` use the proxy. It allows CONNECT only to port 443, and it refuses plain requests to a port that isn't in `Safe_ports`, which lists a few well-known ports and every port from 1025 to 65535.

Squid 2.0.0, which the `resolute` feature deploys, also denies requests to loopback and link-local destinations before your ACL. No client can reach the proxy's own loopback services or the cloud metadata service at 169.254.169.254 through it, whatever your ACL allows. Squid 1.1.0 has no such rule.

Squid 7 in squid 2.0.0 already defines the `CONNECT` ACL, and it accepts the `acl CONNECT method CONNECT` line as a harmless repeat, so the same ACL works on both releases. Squid 6 removed Gopher, so the port 70 entry no longer matters on squid 2.0.0, but it does no harm.

### Restricting the source networks

To let only one subnet use the proxy, list only that subnet:

```yaml
params:
  acl: |
    acl restricted_net src 10.10.10.0/24

    acl SSL_ports  port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT

    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    http_access allow restricted_net
```

### Restricting the destination domains

To allow only a few destination domains, add a `dstdomain` ACL and require it:

```yaml
params:
  acl: |
    acl localnet src 10.0.0.0/8
    acl localnet src 172.16.0.0/12
    acl localnet src 192.168.0.0/16

    acl SSL_ports  port 443
    acl Safe_ports port 80
    acl Safe_ports port 443
    acl CONNECT method CONNECT

    acl allowed_domains dstdomain .github.com .rubygems.org .ubuntu.com

    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    http_access allow localnet allowed_domains
```

## Troubleshooting

When clients cannot connect to the proxy, check the network path and the security groups or firewall rules first, and then confirm that the proxy is running with `genesis my-env bosh instances`.

When the proxy denies a request, check that the ACL covers the client's address and the destination port. The access log records every decision, and you can follow it with:

```
genesis my-env bosh logs squid/0 --follow
```

On squid 2.0.0, Squid writes its cache log to `/var/vcap/sys/log/squid/cache.log`, so startup errors, such as a port that won't bind, and runtime errors show up there. The output of the start and stop script goes to `/var/vcap/sys/log/squid/squid.log`. Squid 1.1.0 sends its cache log to `/dev/null`, so on xenial only the errors that Squid prints before it starts in the background reach `squid.log`.

## History

- The next release adds the `resolute` feature, PVE support, and the deploy-time checks. It also rewrites the hooks from Bash as Perl modules for Genesis 3.1.0, with the curl addon in a module of its own.

- Version 1.2.0 moved to squid release 1.1.0 and Genesis 2.7.0.

- Version 1.0.0 was the first stable release.

- Version 0.3.0 was the first version to support Genesis 2.6 hooks for addons and `genesis info`.
