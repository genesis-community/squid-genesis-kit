# Changelog

## Unreleased

- We added an opt-in `resolute` feature that deploys the proxy on the `ubuntu-resolute` stemcell. It swaps the squid release from 1.1.0 to 2.0.0, because squid 1.1.0 starts Squid with `chpst`, which the resolute stemcell no longer ships. squid 2.0.0 builds Squid 7.7 and starts it with `setpriv` instead. The feature pins the dev release `2.0.0+dev.1` for now, which you upload to the director by hand, and that pin changes to the final release when it's cut.

- The default stays on the `ubuntu-xenial` stemcell with squid 1.1.0, because Squid 7 needs a C++17 compiler that xenial doesn't have.

- The kit refuses an environment that turns the `resolute` feature on while setting `params.stemcell_os` to another os. It also refuses one that sets `params.stemcell_os` to `ubuntu-resolute` without the feature.

- We added a pre-deploy hook that checks the merged manifest, because the blueprint gate reads only params and an ops file can still change the stemcells or the releases. It refuses a squid release older than 2.0.0 on a resolute stemcell, squid 2.0.0 or later on a trusty, xenial, or bionic stemcell, any stemcell on another os when the `resolute` feature is on, and bpm older than 1.4.41 on a resolute stemcell. It also refuses a squid or bpm release with no version or pinned to `latest`, and it resolves `((name))` placeholders from the BOSH variables file before it checks.

- The `ocfp` feature now works. It names the network and VM type after the environment, pins the proxy to the `squid_ip` reserved on the first OCFP subnet that has one, and places it in that subnet's AZ. Before, the blueprint had no feature handling and the features hook refused every feature, including `ocfp`.

- The cloud-config hook now supports PVE. It builds the network bridge, the VM's CPU, memory, and disk, and the disk storage and format, and reads each from the environment file, then from the OCFP config, before it falls back to a default.

- `pve` is now in the kit's supported IaaS list, and the kit requires Genesis 3.1.0.

- Any other feature name now loads `ops/<feature>.yml` from the deployment repo, and the kit refuses a feature that matches nothing.

- The hooks now compile. Before, the blueprint hook used an undeclared variable, so the kit couldn't build a manifest at all. The pre-deploy, post-deploy, and addon hooks also pushed a malformed library path onto `@INC`, the post-deploy hook had a syntax error, and the info, new, and pre-deploy hooks named parent classes that Genesis doesn't provide.

- `genesis new` now writes the environment file through Genesis. Before, it ran the old Bash helpers `genesis_config_block` and `offer_environment_editor` as shell commands, which a Perl hook can't reach.

- The `curl` addon now passes each argument to curl as its own word, so arguments with spaces or shell characters reach curl unchanged, and it fails when curl fails.

- `genesis info` now spells "Environment" correctly and says so when the proxy hasn't been deployed yet.

- We added a spec suite that covers the default, every-parameter, PVE, OCFP, and resolute environments, plus the two refused resolute ones, and a Perl test for the pre-deploy checks.
