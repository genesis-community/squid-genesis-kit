squid Genesis Kit
=================

The **Squid Proxy Genesis Kit** deploys a Squid HTTP/HTTPS proxy
which you (and your deployments) can use for accessing HTTP
resources on other networks, like the public Internet, without
having direct access.

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

Once created, refer to the deployment repo's README for information on creating

Cloud Config
------------

By default, Squid uses the following VM types/networks from your
cloud config. Feel free to override them in your environment, if
you would rather they use entities already existing in your cloud
config:

```
params:
  network: squid
  vm_type: default
```

Learn More
----------

For more in-depth documentation, check out the [manual][1].

[1]: MANUAL.md
