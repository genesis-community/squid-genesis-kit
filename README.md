Squid Genesis Kit
=================

This Genesis kit deploys a single, standalone
[Squid Caching Web Proxy][squid], running on the standard port,
TCP/3128.

[squid]: http://www.squid-cache.org/

This allows egress Internet-bound HTTP and HTTPS traffic for
deployments whose network zones have little to no direct outbound
access themselves.

The proxy deployment can be deploying into a DMZ-style network,
which _does_ have egress Internet access, in order to proxy out
requests from inside the network safely, and securely.

This is useful, and often necessary, for Cloud Foundry deployments
in restricted or compliance networks to enable BOSH to download
stemcells and releases, and to enable Cloud Foundry to retrieve online
buildpacks.


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

Once deployed, you can add

```
params:
  http_proxy:  http://proxy-ip:3128
  https_proxy: http://proxy-ip:3128
```

to your BOSH and Cloud Foundry Genesis deployments, and then
re-deploy them to start using the new proxy.


Heads Up!
---------

If you use the `http_proxy` and `https_proxy` parameters in your
manifests, you will have to actively manage the `no_proxy`
parameter as well.  Otherwise **all** traffic will forwared
through the proxy, which is rarely ideal.

For example, if you are leveraging a proxy in a BOSH director,
your Genesis env file may look like this:

```
params:
  static_ip:   10.10.100.1
  http_proxy:  http://proxy-ip:3128
  https_proxy: http://proxy-ip:3128
```

This will send all HTTP / HTTPS traffic through the proxy.  This
includes API traffic that ought to go to your IaaS (like vCenter),
as well as traffic bound for the local blobstore.  This can cause
hard-to-diagnose issues.

To combat this, specify your BOSH VM IPs, including loopback, in
the `no_proxy` parameter:

```
params:
  static_ip:   10.10.100.1
  http_proxy:  http://proxy-ip:3128
  https_proxy: http://proxy-ip:3128
  no_proxy:    10.10.100.1,127.0.0.1
```

Now, HTTP / HTTPS traffic from the BOSH host _to_ the BOSH host
will ignore the proxy and connect directly.


Learn More
----------

For more in-depth documentation, check out the [manual][1].

[1]: MANUAL.md
