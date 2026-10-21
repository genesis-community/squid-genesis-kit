#!/usr/bin/env perl
# Proves the blueprint's port check and its OCFP AZ resolution.  The AZ has
# to come out the way the cloud-config hook names the subnet's AZ, which is
# through Genesis's lookup_az, or BOSH rejects the deploy.
#
# Each case hands the hook a stand-in environment that answers only what the
# code under test asks.  Run it with `prove spec/hooks` or
# `perl spec/hooks/blueprint.t`.

use v5.20;
use warnings;

use Cwd qw/abs_path/;
use File::Basename qw/dirname/;
use Test::More;

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

my $hooks = abs_path(dirname(__FILE__).'/../../hooks');
require "$hooks/blueprint.pm";

package FakeEnv {
	sub new {my ($class, %data) = @_; bless {%data}, $class}
	sub name {'test-env'}
	sub cpi_enabled {defined($_[0]{cpi})}
	sub cpi_name {$_[0]{cpi}}
	sub director_exodus_lookup {return {azs => $_[0]{azs}}}
	sub lookup {
		my ($self, $key, $default) = @_;
		return exists($self->{params}{$key}) ? $self->{params}{$key} : $default;
	}
}

sub hook {
	my %data = @_;
	return bless {label => 'blueprint', env => FakeEnv->new(%data)}, 'Genesis::Hook::Blueprint::Squid';
}

# The port check
for my $port (qw/1024 3128 8080 65535/) {
	my $ok = eval { hook(params => {'params.port' => $port})->_check_port; 1 };
	ok($ok, "port $port passes") or diag($@);
}
ok(eval { hook()->_check_port; 1 }, 'the default port passes') or diag($@);
for my $port ('80', '1023', '0', '65536', '31 28', 'http') {
	my $ok = eval { hook(params => {'params.port' => $port})->_check_port; 1 };
	ok(!$ok, "port '$port' is refused");
	like($@, qr/1024 to\s+65535/, "the refusal for '$port' names the range");
}
ok(!eval { hook(params => {'params.port' => [3128]})->_check_port; 1 }, 'a list for the port is refused');

# The OCFP AZ
my $azs = {
	z1 => {name => 'mgmt-z1', index => 1, for_cpi => {'proto-main.pve' => 'mgmt-z1-pve'}},
	z2 => {name => 'mgmt-z2', index => 2},
	z3 => {name => 'mgmt-z3'},
};

is(hook(azs => $azs)->_bosh_az('z2'), 'mgmt-z2', 'a key resolves to the rendered name');
is(hook(azs => $azs)->_bosh_az('mgmt-z2'), 'mgmt-z2', 'a rendered name resolves to itself');
is(hook(azs => $azs)->_bosh_az('z1'), 'mgmt-z1', 'without a CPI, for_cpi is ignored');
is(hook(azs => $azs, cpi => 'proto-main.pve')->_bosh_az('z1'), 'mgmt-z1-pve', 'with the CPI, the key resolves to its for_cpi name');
is(hook(azs => $azs, cpi => 'proto-main.pve')->_bosh_az('mgmt-z1'), 'mgmt-z1-pve', 'with the CPI, the rendered name resolves to its for_cpi name');
is(hook(azs => $azs, cpi => 'proto-main.pve')->_bosh_az('mgmt-z1-pve'), 'mgmt-z1-pve', 'a for_cpi name resolves to itself');
is(hook(azs => $azs, cpi => 'proto-main.pve')->_bosh_az('z2'), 'mgmt-z2', 'an AZ with no for_cpi name falls back to its rendered name');
is(hook(azs => $azs, cpi => 'other.cpi')->_bosh_az('z1'), 'mgmt-z1', 'a for_cpi name for another CPI is ignored');

my $rendered = {
	'pve-a' => {name => 'lab-z1', index => 1},
	'pve-b' => {name => 'lab-z2'},
};
is(hook(azs => $rendered)->_bosh_az('z1'), 'lab-z1', 'the zN short form matches the index');
is(hook(azs => $rendered)->_bosh_az('z2'), 'lab-z2', 'the zN short form matches the trailing digits of the name');
is(hook(azs => $rendered)->_bosh_az('pve-b'), 'lab-z2', 'a key that is not zN still resolves');
is(hook(azs => $rendered)->_bosh_az('z3'), undef, 'an AZ that matches nothing resolves to nothing');
is(hook(azs => {})->_bosh_az('z1'), undef, 'no AZs in the exodus data resolves to nothing');
is(hook(azs => undef)->_bosh_az('z1'), undef, 'missing exodus AZ data resolves to nothing');

done_testing;
