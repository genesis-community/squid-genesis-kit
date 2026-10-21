# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::CloudConfig::Squid;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw/bail warning/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  my $config = $self->build_cloud_config({
    'networks' => [
      $self->network_definition('squid', strategy => 'ocfp',
        dynamic_subnets => {
          allocation => {
            size => 0,
            statics => 0,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default'],
            },
            aws => {
              'subnet' => $self->network_reference('id'),
            },
            pve => {
              'bridge' => $self->_pve_cpi_setting('pve_network_bridge', 'network_bridge', 'vmbr0'),
            },
          },
        },
      )
    ],
    'vm_types' => [
      $self->vm_type_definition('squid',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.2',
              prod => 'm1.3'
            }, 'm1.2'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 32 # in gigabytes
            },
          },
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.large'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => 16384, # 16GB in MB
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            }
          },
          pve => {
            'cpu'            => scalar($self->env->lookup('bosh-configs.cpi.pve_squid_cpu',  $self->for_scale({ dev => 2, prod => 2 }, 2))),
            'ram'            => scalar($self->env->lookup('bosh-configs.cpi.pve_squid_ram',  $self->for_scale({ dev => 2048, prod => 4096 }, 2048))),
            'disk'           => scalar($self->env->lookup('bosh-configs.cpi.pve_squid_disk', $self->for_scale({ dev => 16384, prod => 16384 }, 16384))),
            'network_bridge' => $self->_pve_cpi_setting('pve_network_bridge', 'network_bridge', 'vmbr0'),
          },
        },
      ),
    ],
    'disk_types' => [
      $self->disk_type_definition('squid',
        common => {
          disk_size => $self->for_scale({
            dev => 32768, # 32GB in MB
            prod => 32768  # 32GB in MB
          }, 32768),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf6',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE
          },
          pve => {
            'storage'     => $self->_pve_cpi_setting('pve_disk_storage', 'disk_storage', 'local-lvm'),
            'disk_format' => scalar($self->env->lookup('bosh-configs.cpi.pve_disk_format', 'raw')),
          },
        },
      ),
    ],
    'vm_extensions' => [
      $self->vm_extension_definition('squid-lb',
        cloud_properties_for_iaas => {
          aws => {
            'lb_target_groups' => ['ocfp-ocf-squid-lb-tg'],
          },
        },
      ),
    ],
  });

  $self->done($config);

  return 1;
}

# _pve_cpi_setting - resolve a PVE CPI setting from the env file, then the OCFP vault config, then a default {{{
# A default can be wrong for the host: vmbr0 is often the host's own LAN and
# not the network the deployments live on.  So falling back to one warns,
# naming both places that could set it, and a setting with no default bails.
sub _pve_cpi_setting {
  my ($self, $env_key, $vault_key, $default) = @_;
  my $value = scalar($self->env->lookup("bosh-configs.cpi.$env_key", undef));
  $value //= scalar($self->env->ocfp_config_lookup("cpi.pve.$vault_key", undef))
    if $self->env->is_ocfp;
  return $value if defined($value) && length($value);

  # The cloud properties are built for every IaaS and only this one's are
  # used, so a missing PVE setting matters only on PVE.
  return $default unless ($self->iaas // '') eq 'pve';

  bail(
    "No PVE %s configured for %s: set #c{bosh-configs.cpi.%s} in the ".
    "environment file, or run #g{ocfp vault populate} so the OCFP config ".
    "provides #c{cpi/pve:%s}.",
    $vault_key, $self->env->name, $env_key, $vault_key
  ) unless defined($default) && length($default);

  unless ($self->{__pve_default_warned}{$env_key}++) {
    warning(
      "No PVE %s is configured for %s, so the cloud config uses #y{%s}.  Set ".
      "#c{bosh-configs.cpi.%s} in the environment file, or #c{cpi/pve:%s} in the ".
      "OCFP config, if that is not the right one for this host.",
      $vault_key, $self->env->name, $default, $env_key, $vault_key
    );
  }
  return $default;
}
# }}}

1;
