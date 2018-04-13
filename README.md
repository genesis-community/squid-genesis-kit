Squid Genesis Kit
=================

This is a genesis kit for [Squid Proxy](http://www.squid-cache.org/).  This kit will deploy a single squid proxy node with a default port of 3128.  

Generally this will be used to allow egress internet traffic for deployments that are in network zones that have restricted or no outside access.  The squid proxy has to be deployed to a network zone that has unrestricted access to where the deployments need to go. This is very useful (and necessary) for example for Cloud Foundry deployments that are in restricted or compliance networks to enable Cloud Foundry to get stemcell updates and release updates when the only way out to these public resources is through a proxy.   



Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2):

```
# create a squid-deployments repo using the latest version of the squid kit
genesis init --kit squid

# create a squid-deployments repo using v1.0.0 of the squid kit
genesis init --kit squid/1.0.0

# create a my-squid-configs repo using the latest version of the squid kit
genesis init --kit squid -d my-squid-configs
```

Once deployed, you can add http_proxy: and https_proxy: params to your manifest to utilize the proxy.

Heads Up!!
-------
The use of the http_proxy and https_proxy parameters in your manifests will require active management of the no_proxy parameter otherwise ALL traffic will forwared through the proxy and that is rarely ideal. A great example of this is defining a proxy for your bosh director.  If your bosh genesis kit manifest looks like this:

```
params:
  static_ip: 10.10.100.1
  http_proxy: http://proxyIP:3128
  https_proxy: http://proxyIP:3128
```

All traffic such as uploading stemcells and releases which is TCP traffic to the local blobstore, will be sent through the proxy and can cause issues. There is no reason for local traffic within a bosh VM to leave that VM. Instead, your bosh genesis kit manifest should look like this:
```
params:
  static_ip: 10.10.100.1
  http_proxy: http://proxyIP:3128
  https_proxy: http://proxyIP:3128
  no_proxy: 10.10.100.1,127.0.0.1
```

Any traffic bound for the local bosh host will ignore the defined proxy settings.



Params
------

```
params.port: 3128
  
params.acl: |
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

Cloud Config
------------

By default squid uses the following vm types and network from your Cloud Config. Feel free to override them in your environment, if you would rather they use vmy types or network already defined in your Cloud Config.

params:
  vm_type: default # Minimum: 1 cpu, 1 gig memory, 4gb disk
  network: squid


