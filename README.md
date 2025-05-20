Squid Genesis Kit
=================

This Genesis kit deploys a single, standalone
[Squid Caching Web Proxy][squid], running on the standard port,
TCP/3128.

[squid]: http://www.squid-cache.org/

This allows egress Internet-bound HTTP and HTTPS traffic for
deployments whose network zones have little to no direct outbound
access themselves.

The proxy deployment can be deployed into a DMZ-style network,
which _does_ have egress Internet access, in order to proxy out
requests from inside the network safely and securely.

This is useful in various scenarios:
- For BOSH directors to download stemcells and releases in restricted networks
- For Cloud Foundry deployments to retrieve online buildpacks
- For development environments that need controlled internet access
- For compliance and security requirements where internet traffic must be filtered
- For any deployment that requires HTTP/HTTPS access in air-gapped environments

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌────────────┐
│                 │     │              │     │            │
│  Restricted     │     │  Squid Proxy │     │  External  │
│  Network        ├────►│  (3128)      ├────►│  Internet  │
│                 │     │              │     │            │
└─────────────────┘     └──────────────┘     └────────────┘
       │                                            ▲
       │                                            │
       │                                            │
       └────────────────────────────────────────────┘
                      Blocked Direct Path
```

Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis 2.7.0 or later):

```
# create a squid-deployments repo using the latest version of the squid kit
genesis init --kit squid

# create a squid-deployments repo using v1.2.0 of the squid kit
genesis init --kit squid/1.2.0

# create a my-squid-configs repo using the latest version of the squid kit
genesis init --kit squid -d my-squid-configs
```

After creating your deployment repo, create a new environment and deploy:

```
# Create a new environment file for deployment
cd squid-deployments
genesis new my-environment

# Deploy the Squid proxy
genesis deploy my-environment
```

Once deployed, you can get information about the proxy, including its IP address:

```
# Get deployment information and proxy URL
genesis info my-environment
```

To test that your proxy is working correctly:

```
# Test proxy connectivity
genesis my-environment do -- curl https://www.google.com
```

Finally, configure other deployments to use your proxy by adding these parameters:

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
parameter as well. Otherwise **all** traffic will be forwarded
through the proxy, which is rarely ideal.

For example, if you are leveraging a proxy in a BOSH director,
your Genesis env file may look like this:

```
params:
  static_ip:   10.10.100.1
  http_proxy:  http://proxy-ip:3128
  https_proxy: http://proxy-ip:3128
```

This will send all HTTP/HTTPS traffic through the proxy. This
includes API traffic that ought to go to your IaaS (like vCenter),
as well as traffic bound for the local blobstore. This can cause
hard-to-diagnose issues.

To combat this, specify your BOSH VM IPs, including loopback, in
the `no_proxy` parameter:

```
params:
  static_ip:   10.10.100.1
  http_proxy:  http://proxy-ip:3128
  https_proxy: http://proxy-ip:3128
  no_proxy:    10.10.100.1,127.0.0.1,localhost
```

Now, HTTP/HTTPS traffic from the BOSH host _to_ the BOSH host
will ignore the proxy and connect directly.

For cloud provider deployments, you should typically also include the API endpoints 
in your `no_proxy` setting:

```
# For AWS
no_proxy: 10.10.100.1,127.0.0.1,localhost,169.254.169.254,*.amazonaws.com

# For GCP
no_proxy: 10.10.100.1,127.0.0.1,localhost,metadata.google.internal,*.googleapis.com

# For Azure
no_proxy: 10.10.100.1,127.0.0.1,localhost,169.254.169.254,*.azure.com
```

Troubleshooting
--------------

### Common Issues

1. **Cannot connect to the proxy**:
   - Verify network connectivity to the proxy IP address (`ping proxy-ip`)
   - Check that port 3128 is accessible (`telnet proxy-ip 3128`)
   - Ensure your network security groups/firewall allow traffic on port 3128

2. **Proxy returns errors**:
   - Verify the proxy is running (`genesis my-environment instances`)
   - Check proxy logs (`genesis my-environment logs squid/0`)
   - Ensure the ACL allows your source IP address

3. **Traffic not going through proxy**:
   - Verify environment variables are set correctly (`echo $http_proxy`)
   - Some applications may need to be explicitly configured to use a proxy
   - Check for conflicting proxy settings in your environment

For more advanced troubleshooting, you can SSH into the proxy VM:

```
genesis my-environment ssh squid/0
```

Learn More
----------

For more in-depth documentation, check out the [manual][1].

[1]: MANUAL.md