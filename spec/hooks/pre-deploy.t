#!/usr/bin/env perl
# Proves that the pre-deploy hook checks the merged manifest of a deploy,
# which is the last place an ops file can override the stemcells, the bpm
# release, or the squid release.
#
# Each case writes a small manifest, points GENESIS_MANIFEST_FILE at it, and
# runs both of the hook's checks.  spruce converts the manifest, as it does in
# a real deploy.  Run it with `prove spec/hooks` or
# `perl spec/hooks/pre-deploy.t`.

use v5.20;
use warnings;

use Cwd qw/abs_path/;
use File::Basename qw/dirname/;
use File::Temp qw/tempdir/;
use Test::More;

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

chomp(my $spruce = `command -v spruce`);
plan skip_all => 'spruce is not installed' unless $spruce;

my $hooks = abs_path(dirname(__FILE__).'/../../hooks');
my $work  = tempdir('squid-predeploy-test-XXXXXX', TMPDIR => 1, CLEANUP => 1);
require "$hooks/pre-deploy.pm";

# check runs both checks on a manifest, with the resolute feature on or off,
# and returns whether they passed and what they printed.
sub check {
	my ($manifest, $feature) = @_;
	open(my $fh, '>', "$work/manifest.yml") or die;
	print {$fh} $manifest;
	close($fh);
	local $ENV{GENESIS_MANIFEST_FILE} = "$work/manifest.yml";
	local $ENV{GENESIS_BOSHVARS_FILE} = undef;
	my $hook = bless {
		label => 'pre-deploy',
		__wanted_features => {($feature ? (resolute => 1) : ())},
	}, 'Genesis::Hook::PreDeploy::Squid';
	my $ok = eval { $hook->_check_resolute_manifest; $hook->_check_squid_release; 1 };
	return ($ok, $@ // '');
}

sub stemcell { "stemcells:\n- alias: default\n  os: $_[0]\n  version: latest\n" }
sub squid    { "releases:\n- name: squid\n  version: $_[0]\n" }

my ($ok, $error);

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0+dev.1'), 1);
ok($ok, 'squid 2.0.0+dev.1 on resolute passes') or diag($error);

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.1.0'), 1);
ok($ok, 'a newer squid on resolute passes') or diag($error);

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('1.1.0'), 1);
ok(!$ok, 'squid 1.1.0 on resolute is refused');
like($error, qr/chpst/, 'the refusal says why');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('1.1.0'), 0);
ok(!$ok, 'squid 1.1.0 on resolute is refused without the feature too');

($ok, $error) = check(stemcell('ubuntu-xenial') . squid('1.1.0'), 0);
ok($ok, 'the default squid 1.1.0 on xenial passes') or diag($error);

($ok, $error) = check(stemcell('ubuntu-xenial') . squid('2.0.0+dev.1'), 0);
ok(!$ok, 'squid 2.0.0 on xenial is refused');
like($error, qr/C\+\+17/, 'the refusal says why');
like($error, qr/ubuntu-xenial/, 'the refusal names the stemcell');

($ok, $error) = check(stemcell('ubuntu-jammy') . squid('2.0.0'), 0);
ok($ok, 'squid 2.0.0 on jammy passes') or diag($error);

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('latest'), 1);
ok(!$ok, 'squid latest on resolute is refused');

($ok, $error) = check(stemcell('ubuntu-noble') . squid('2.0.0'), 1);
ok(!$ok, 'a noble stemcell with the feature is refused');
like($error, qr/ubuntu-noble/, 'the refusal names the stemcell os');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0') . "- name: bpm\n  version: 1.4.22\n", 1);
ok(!$ok, 'bpm 1.4.22 added by an ops file on resolute is refused');
like($error, qr/1\.4\.22/, 'the refusal names the bpm version');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0') . "- name: bpm\n  version: 1.4.41\n", 1);
ok($ok, 'bpm 1.4.41 on resolute passes') or diag($error);

($ok, $error) = check(squid('2.0.0'), 1);
ok(!$ok, 'a manifest without stemcells is refused with the feature');

{
	local $ENV{GENESIS_MANIFEST_FILE} = "$work/missing.yml";
	my $hook = bless {label => 'pre-deploy', __wanted_features => {}}, 'Genesis::Hook::PreDeploy::Squid';
	ok(!eval { $hook->_check_resolute_manifest; 1 }, 'a missing manifest is refused');
}

done_testing();
