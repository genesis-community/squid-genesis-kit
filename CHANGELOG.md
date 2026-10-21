# Changelog

## Unreleased

- We added an opt-in `resolute` feature that deploys the proxy on the `ubuntu-resolute` stemcell. It swaps the squid release from 1.1.0 to 2.0.0, because squid 1.1.0 starts Squid with `chpst`, which the resolute stemcell no longer ships. squid 2.0.0 builds Squid 7.7 and starts it with `setpriv` instead. The feature pins the dev release `2.0.0+dev.2` for now, which you upload to the director by hand, and that pin changes to the final release when it's cut. Moving an environment from xenial to the feature recreates the proxy's VM, because the stemcell changes.

- The squid `2.0.0+dev.2` release runs Squid with only the `vcap` group, denies requests to loopback and link-local destinations, writes Squid's cache log to `/var/vcap/sys/log/squid/cache.log`, and kills leftover Squid processes when the job starts or stops. Its README lists every change since 1.1.0.

- The default stays on the `ubuntu-xenial` stemcell with squid 1.1.0, because Squid 7 needs a C++17 compiler that xenial doesn't have.

- The kit refuses an environment that turns the `resolute` feature on while setting `params.stemcell_os` to another os. It also refuses one that sets `params.stemcell_os` to `ubuntu-resolute` without the feature.

- We added a pre-deploy hook that checks the merged manifest, because the blueprint gate reads only params and an ops file can still change the stemcells or the releases. It refuses a squid release older than 2.0.0 on a resolute stemcell, squid 2.0.0 or later on a trusty, xenial, or bionic stemcell, any stemcell on another os when the `resolute` feature is on, and bpm older than 1.4.41 on a resolute stemcell. It also refuses a squid or bpm release with no version or pinned to `latest`, with a separate message for each, and it resolves `((name))` and `((name.key))` placeholders from the BOSH variables file before it checks. The checks read a stemcell's name when it has no os, they count FIPS stemcells as their series, and they treat a squid release candidate such as `2.0.0-rc.1` as the version it leads to. The squid check looks only at the stemcells of the instance groups that run squid, and the hook prints one line when every check passes.

- The `ocfp` feature now works. It names the network and VM type after the environment, pins the proxy to the `squid_ip` reserved on the first OCFP subnet that has one, and places it in that subnet's AZ. It resolves that AZ the way the cloud-config hook does, so it accepts the exodus key, the rendered name, or the `zN` short form, and it uses the director's per-CPI name for the AZ when there is one. Before, the blueprint had no feature handling and the features hook refused every feature, including `ocfp`.

- The cloud-config hook now supports PVE. It builds the network bridge, the VM's CPU, memory, and disk, and the disk storage and format, and reads each from the environment file, then from the OCFP config, before it falls back to a default. It warns when the network bridge or the disk storage falls back to its default, because the default bridge, `vmbr0`, is often the host's own LAN.

- `pve` is now in the kit's supported IaaS list, and the kit requires Genesis 3.1.0.

- Any other feature name now loads `ops/<feature>.yml` from the deployment repo, and the kit refuses a feature that matches nothing. The ops files load after all of the kit's own files, so an ops file can pin another squid release over the one the `resolute` feature pins.

- The kit refuses a `port` below 1024, because Squid runs as `vcap` without any capabilities and can't bind one.

- The hooks now compile. Before, the blueprint hook used an undeclared variable, so the kit couldn't build a manifest at all. The pre-deploy, post-deploy, and addon hooks also pushed a malformed library path onto `@INC`, the post-deploy hook had a syntax error, and the info, new, and pre-deploy hooks named parent classes that Genesis doesn't provide.

- `genesis new` now writes the environment file through Genesis. Before, it ran the old Bash helpers `genesis_config_block` and `offer_environment_editor` as shell commands, which a Perl hook can't reach.

- The `curl` addon now passes each argument to curl as its own word, so arguments with spaces or shell characters reach curl unchanged, and it fails when curl fails. It drops a leading `--`, names the proxy on curl's command line, and clears every proxy variable from your shell, so `no_proxy` can't send the request around Squid. Genesis's trace log shows its arguments as redacted.

- `genesis info` now spells "Environment" correctly and says so when the proxy hasn't been deployed yet.

- We added a spec suite that covers the default, every-parameter, PVE, OCFP, and resolute environments, an ops file that pins squid over the resolute pin, an OCFP AZ that resolves through the director's per-CPI name, and the refused environments, which are the two resolute ones, a port below 1024, and the three OCFP ones with no `squid_ip`, no AZ, or an unknown AZ. Perl tests cover the pre-deploy checks, the port check, the OCFP AZ resolution, and the PVE setting defaults.
