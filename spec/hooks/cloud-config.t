#!/usr/bin/env perl
# Proves how the cloud-config hook resolves a PVE CPI setting: the
# environment file first, then the OCFP config, and then a default, which
# it warns about on PVE because the default can be the wrong bridge or
# storage for the host.
#
# Each case hands the hook a stand-in environment that answers only what the
# code under test asks.  Run it with `prove spec/hooks` or
# `perl spec/hooks/cloud-config.t`.

use v5.20;
use warnings;

use Cwd qw/abs_path/;
use File::Basename qw/dirname/;
use Test::More;

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

my $hooks = abs_path(dirname(__FILE__).'/../../hooks');
require "$hooks/cloud-config.pm";

package FakeEnv {
	sub new {my ($class, %data) = @_; bless {iaas => 'pve', %data}, $class}
	sub name {'test-env'}
	sub iaas {$_[0]{iaas}}
	sub is_ocfp {$_[0]{ocfp}}
	sub lookup {
		my ($self, $key, $default) = @_;
		return exists($self->{env}{$key}) ? $self->{env}{$key} : $default;
	}
	sub ocfp_config_lookup {
		my ($self, $key, $default) = @_;
		die "the OCFP config was read outside OCFP\n" unless $self->{ocfp};
		return exists($self->{config}{$key}) ? $self->{config}{$key} : $default;
	}
}

my @warnings;
{
	no warnings qw/redefine once/;
	*Genesis::Hook::CloudConfig::Squid::warning = sub {
		my ($fmt, @args) = @_;
		push @warnings, sprintf($fmt, @args);
	};
}

sub setting {
	my (%data) = @_;
	my $default = exists($data{default}) ? delete($data{default}) : 'vmbr0';
	my $hook = bless {label => 'cloud-config', env => FakeEnv->new(%data)}, 'Genesis::Hook::CloudConfig::Squid';
	@warnings = ();
	my $value = eval { $hook->_pve_cpi_setting('pve_network_bridge', 'network_bridge', $default) };
	return ($value, $@, [@warnings], $hook);
}

my ($value, $error, $warned);

($value, $error, $warned) = setting(env => {'bosh-configs.cpi.pve_network_bridge' => 'ocfp'});
is($value, 'ocfp', 'the environment file setting wins');
is(scalar(@$warned), 0, 'and nothing warns');

($value, $error, $warned) = setting(
	ocfp => 1,
	env => {'bosh-configs.cpi.pve_network_bridge' => 'ocfp'},
	config => {'cpi.pve.network_bridge' => 'vmbr1'},
);
is($value, 'ocfp', 'the environment file setting wins over the OCFP config');

($value, $error, $warned) = setting(ocfp => 1, config => {'cpi.pve.network_bridge' => 'vmbr1'});
is($value, 'vmbr1', 'the OCFP config is next');
is(scalar(@$warned), 0, 'and nothing warns');

($value, $error, $warned) = setting();
is($value, 'vmbr0', 'outside OCFP the default is used, and the OCFP config is never read') or diag($error);
is(scalar(@$warned), 1, 'the default warns once');
like($warned->[0] // '', qr/vmbr0/, 'the warning names the default');
like($warned->[0] // '', qr/bosh-configs\.cpi\.pve_network_bridge/, 'the warning names the environment file setting');
like($warned->[0] // '', qr{cpi/pve:network_bridge}, 'the warning names the OCFP config key');

($value, $error, $warned) = setting(ocfp => 1);
is($value, 'vmbr0', 'under OCFP with nothing set, the default is used');
is(scalar(@$warned), 1, 'and it warns');

($value, $error, $warned) = setting(env => {'bosh-configs.cpi.pve_network_bridge' => ''});
is($value, 'vmbr0', 'an empty environment file setting counts as unset');

($value, $error, $warned) = setting(iaas => 'aws');
is($value, 'vmbr0', 'on another IaaS the default is returned');
is(scalar(@$warned), 0, 'without a warning, because PVE settings do not apply there');

($value, $error, $warned) = setting(default => undef);
is($value, undef, 'a setting with no default and no value');
like($error, qr/No PVE network_bridge configured/, 'is refused');

($value, $error, $warned) = setting(default => undef, iaas => 'aws');
is($error, '', 'but not on another IaaS');

{
	my $hook;
	($value, $error, $warned, $hook) = setting();
	@warnings = ();
	$hook->_pve_cpi_setting('pve_network_bridge', 'network_bridge', 'vmbr0');
	is(scalar(@warnings), 0, 'a second lookup of the same setting does not warn again');
}

done_testing;
