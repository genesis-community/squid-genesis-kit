# Changelog

## 2.0.0 (unreleased)

- The kit now deploys on the `ubuntu-noble` stemcell with squid release 2.0.0 by default, and it no longer supports xenial. squid 2.0.0 builds Squid 7.7 and starts it with `setpriv`, and the kit pins it with its url and sha1, so BOSH downloads it during the deploy. We removed squid 1.1.0 and every xenial path from the kit. It's a major release, because every existing deployment runs on xenial and changes when it upgrades.

- Upgrading an existing deployment changes its stemcell, so BOSH recreates the proxy's VM on noble, and the proxy is down while BOSH recreates it. An `acl` property that uses an authentication helper for LDAP, Kerberos, or SASL, or any TLS option, no longer works, because this build of Squid leaves those libraries out. The default ACL works unchanged. The manual's upgrade section lists what to check before you deploy.

- The squid 2.0.0 release runs Squid with only the `vcap` group, denies requests to loopback, link-local, and the VM's own address, writes Squid's cache log to `/var/vcap/sys/log/squid/cache.log`, and kills leftover Squid processes when the job starts or stops. Its README lists every change since 1.1.0.

- We added an opt-in `resolute` feature that deploys the proxy on the `ubuntu-resolute` stemcell. It changes only the stemcell, because the noble and resolute stemcells run the same squid release.

- The kit refuses `params.stemcell_os` set to `ubuntu-trusty`, `ubuntu-xenial`, `ubuntu-bionic`, or `ubuntu-jammy`, or to their FIPS forms, because it supports noble and later. It also refuses an environment that turns the `resolute` feature on while setting `params.stemcell_os` to another os, and one that sets `params.stemcell_os` to `ubuntu-resolute` without the feature.

- We added a pre-deploy hook that checks the merged manifest, because the blueprint gate reads only params and an ops file can still change the stemcells or the releases. It refuses a squid release older than 2.0.0 on any stemcell, squid on a trusty, xenial, bionic, or jammy stemcell, any stemcell on another os when the `resolute` feature is on, and bpm older than 1.4.41 on a resolute stemcell. It also refuses a squid release with no version, pinned to `latest`, or with a version it doesn't understand, and a bpm release on a resolute stemcell with no version or pinned to `latest`, with a separate message for each. It resolves `((name))` and `((name.key))` placeholders from the BOSH variables file before it checks. The checks read a stemcell's name when it has no os, they count FIPS stemcells as their series, and they treat a squid release candidate such as `2.0.0-rc.1` as the version it leads to. The stemcell check looks only at the stemcells of the instance groups that run squid, and the hook prints one line when every check passes.

- The `ocfp` feature now works. It names the network and VM type after the environment, pins the proxy to the `squid_ip` reserved on the first OCFP subnet that has one, and places it in that subnet's AZ. It resolves that AZ the way the cloud-config hook does, so it accepts the exodus key, the rendered name, or the `zN` short form, and it uses the director's per-CPI name for the AZ when there is one. Before, the blueprint had no feature handling and the features hook refused every feature, including `ocfp`.

- The cloud-config hook now supports PVE. It builds the network bridge, the VM's CPU, memory, and disk, and the disk storage and format, and reads each from the environment file, then from the OCFP config, before it falls back to a default. It warns when the network bridge or the disk storage falls back to its default, because the default bridge, `vmbr0`, is often the host's own LAN.

- `pve` is now in the kit's supported IaaS list, and the kit requires Genesis 3.1.0.

- Any other feature name now loads `ops/<feature>.yml` from the deployment repo, and the kit refuses a feature that matches nothing. The ops files load after all of the kit's own files, so an ops file can pin another squid release over the kit's pin.

- The kit refuses a `port` below 1024, because Squid runs as `vcap` without any capabilities and can't bind one.

- The hooks now compile. Before, the blueprint hook used an undeclared variable, so the kit couldn't build a manifest at all. The pre-deploy, post-deploy, and addon hooks also pushed a malformed library path onto `@INC`, the post-deploy hook had a syntax error, and the info, new, and pre-deploy hooks named parent classes that Genesis doesn't provide.

- `genesis new` now writes the environment file through Genesis. Before, it ran the old Bash helpers `genesis_config_block` and `offer_environment_editor` as shell commands, which a Perl hook can't reach.

- The `curl` addon now passes each argument to curl as its own word, so arguments with spaces or shell characters reach curl unchanged, and it fails when curl fails. It drops a leading `--`, names the proxy on curl's command line, and clears every proxy variable from your shell, so `no_proxy` can't send the request around Squid. Genesis's trace log shows its arguments as redacted.

- `genesis info` now spells "Environment" correctly and says so when the proxy hasn't been deployed yet.

- We added a spec suite that covers the default, every-parameter, PVE, OCFP, and resolute environments, an ops file that pins squid over the kit's pin, an OCFP AZ that resolves through the director's per-CPI name, and the refused environments, which are the two resolute ones, a xenial stemcell, a port below 1024, and the three OCFP ones with no `squid_ip`, no AZ, or an unknown AZ. Perl tests cover the pre-deploy checks, the port check, the stemcell os check, the OCFP AZ resolution, and the PVE setting defaults.
