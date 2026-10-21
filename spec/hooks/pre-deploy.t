#!/usr/bin/env perl
# Proves that the pre-deploy hook checks the merged manifest of a deploy,
# which is the last place an ops file can override the stemcells, the bpm
# release, or the squid release.  The kit supports ubuntu-noble and later,
# and it deploys squid 2.0.0 on every stemcell.
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
# and returns whether they passed and what they printed.  When a variables
# file is given, it is passed the way Genesis passes the BOSH variables file.
sub check {
	my ($manifest, $feature, $vars) = @_;
	open(my $fh, '>', "$work/manifest.yml") or die;
	print {$fh} $manifest;
	close($fh);
	if (defined($vars)) {
		open(my $vh, '>', "$work/vars.yml") or die;
		print {$vh} $vars;
		close($vh);
	}
	local $ENV{GENESIS_MANIFEST_FILE} = "$work/manifest.yml";
	local $ENV{GENESIS_BOSHVARS_FILE} = defined($vars) ? "$work/vars.yml" : undef;
	my $hook = bless {
		label => 'pre-deploy',
		__wanted_features => {($feature ? (resolute => 1) : ())},
	}, 'Genesis::Hook::PreDeploy::Squid';
	my $ok = eval { $hook->_check_resolute_manifest; $hook->_check_squid_release; 1 };
	return ($ok, $@ // '');
}

sub stemcell { "stemcells:\n- alias: default\n  os: $_[0]\n  version: latest\n" }
sub named    { "stemcells:\n- alias: default\n  name: $_[0]\n  version: latest\n" }
sub squid    { "releases:\n- name: squid\n  version: $_[0]\n" }

# group is an instance group that runs a job from the given release on the
# stemcell with the given alias.
sub group {
	my ($name, $release, $alias) = @_;
	return "- name: $name\n  stemcell: $alias\n  jobs:\n  - name: $release\n    release: $release\n";
}

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

($ok, $error) = check(stemcell('ubuntu-noble') . squid('2.0.0'), 0);
ok($ok, 'the default squid 2.0.0 on noble passes') or diag($error);

($ok, $error) = check(stemcell('ubuntu-noble') . squid('1.1.0'), 0);
ok(!$ok, 'squid 1.1.0 on noble is refused');
like($error, qr/chpst/, 'the refusal says why');
like($error, qr/loopback/, 'the refusal names the missing deny rules');

($ok, $error) = check(stemcell('ubuntu-noble-fips') . squid('1.2.0-rc.3'), 0);
ok(!$ok, 'squid 1.2.0-rc.3 on a noble FIPS stemcell is refused');

($ok, $error) = check(stemcell('some-custom-os') . squid('1.1.0'), 0);
ok(!$ok, 'squid 1.1.0 is refused on a stemcell the checks do not know');

($ok, $error) = check(squid('1.1.0'), 0);
ok(!$ok, 'squid 1.1.0 is refused when the manifest lists no stemcells');

($ok, $error) = check(stemcell('ubuntu-xenial') . squid('2.0.0+dev.1'), 0);
ok(!$ok, 'squid 2.0.0 on xenial is refused');
like($error, qr/does\s+not\s+compile\s+on\s+trusty,\s+xenial,\s+or\s+bionic/, 'the refusal says why');
like($error, qr/ubuntu-xenial/, 'the refusal names the stemcell');
like($error, qr/ubuntu-noble and later/, 'the refusal names the supported series');

($ok, $error) = check(stemcell('ubuntu-xenial') . squid('1.1.0'), 0);
ok(!$ok, 'the old default, squid 1.1.0 on xenial, is refused');

($ok, $error) = check(stemcell('ubuntu-jammy') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on jammy is refused');
like($error, qr/ubuntu-jammy/, 'the refusal names the stemcell');

($ok, $error) = check(stemcell('ubuntu-jammy-fips') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on a jammy FIPS stemcell is refused');

($ok, $error) = check(stemcell('ubuntu-bionic') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on bionic is refused');

($ok, $error) = check(stemcell('ubuntu-trusty') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on trusty is refused');

($ok, $error) = check(stemcell('ubuntu-jammy-next') . squid('2.0.0'), 0);
ok($ok, 'an os that only starts with ubuntu-jammy is not jammy') or diag($error);

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

# Stemcells listed by name, with no os.
($ok, $error) = check(named('bosh-openstack-kvm-ubuntu-resolute-go_agent') . squid('2.0.0'), 1);
ok($ok, 'a resolute stemcell named without an os passes') or diag($error);

($ok, $error) = check(named('bosh-openstack-kvm-ubuntu-resolute-go_agent') . squid('1.1.0'), 0);
ok(!$ok, 'squid 1.1.0 on a resolute stemcell named without an os is refused');
like($error, qr/chpst/, 'the refusal says why');

($ok, $error) = check(named('bosh-aws-xen-hvm-ubuntu-xenial-go_agent') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on a xenial stemcell named without an os is refused');
like($error, qr/bosh-aws-xen-hvm-ubuntu-xenial-go_agent/, 'the refusal names the stemcell');

($ok, $error) = check(named('bosh-aws-xen-hvm-ubuntu-noble-go_agent') . squid('2.0.0'), 1);
ok(!$ok, 'a noble stemcell named without an os is refused with the feature');

($ok, $error) = check(named('bosh-aws-xen-hvm-ubuntu-noble-go_agent') . squid('2.0.0'), 0);
ok($ok, 'a noble stemcell named without an os passes without the feature') or diag($error);

($ok, $error) = check(named('bosh-aws-xen-hvm-ubuntu-jammy-go_agent') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on a jammy stemcell named without an os is refused');

# The series is matched whole, so a longer os name never matches it, while a
# FIPS stemcell counts as its series.
($ok, $error) = check(stemcell('ubuntu-resolute-fips') . squid('2.0.0'), 1);
ok($ok, 'a resolute FIPS stemcell passes with the feature') or diag($error);

($ok, $error) = check(stemcell('ubuntu-xenial-fips') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on a xenial FIPS stemcell is refused');

($ok, $error) = check(named('bosh-aws-xen-hvm-ubuntu-xenial-fips-go_agent') . squid('2.0.0'), 0);
ok(!$ok, 'squid 2.0.0 on a xenial FIPS stemcell named without an os is refused');

($ok, $error) = check(stemcell('ubuntu-resolute-next') . squid('2.0.0'), 1);
ok(!$ok, 'an os that only starts with ubuntu-resolute is not resolute');

# ((var)) placeholders, resolved from the BOSH variables file.
($ok, $error) = check(stemcell('((stemcell_os))') . squid('((squid_version))'), 1,
	"stemcell_os: ubuntu-resolute\nsquid_version: 2.0.0\n");
ok($ok, 'placeholders that the variables file resolves pass') or diag($error);

($ok, $error) = check(stemcell('((stemcell_os))') . squid('((squid_version))'), 0,
	"stemcell_os: ubuntu-resolute\nsquid_version: 1.1.0\n");
ok(!$ok, 'a resolved squid 1.1.0 on a resolved resolute stemcell is refused');
like($error, qr/1\.1\.0/, 'the refusal names the resolved version');

($ok, $error) = check(stemcell('((stemcell_os))') . squid('2.0.0'), 1, "other: value\n");
ok(!$ok, 'a placeholder that the variables file does not resolve is refused');
like($error, qr/\(\(stemcell_os\)\)/, 'the refusal names the placeholder');

($ok, $error) = check(stemcell('((stemcell_os))') . squid('2.0.0'), 1);
ok(!$ok, 'a placeholder with no variables file is refused');

($ok, $error) = check(stemcell('((stemcell.os))') . squid('2.0.0'), 1,
	"stemcell:\n  os: ubuntu-resolute\n");
ok($ok, 'a dotted placeholder walks into the variables file') or diag($error);

($ok, $error) = check(stemcell('((stemcell.os))') . squid('2.0.0'), 1,
	"stemcell:\n  name: ubuntu-resolute\n");
ok(!$ok, 'a dotted placeholder with a missing leaf is refused');

# Several stemcells.  The squid check looks at the stemcells that run squid.
my $two = "stemcells:\n- alias: default\n  os: ubuntu-resolute\n  version: latest\n".
          "- alias: old\n  os: ubuntu-xenial\n  version: latest\n";
($ok, $error) = check($two . squid('2.0.0') . "instance_groups:\n" .
	group('squid', 'squid', 'default') . group('other', 'other', 'old'), 0);
ok($ok, 'squid 2.0.0 passes when only another instance group is on xenial') or diag($error);

($ok, $error) = check($two . squid('2.0.0') . "instance_groups:\n" .
	group('squid', 'squid', 'old') . group('other', 'other', 'default'), 0);
ok(!$ok, 'squid 2.0.0 is refused when its instance group is on xenial');
like($error, qr/ubuntu-xenial/, 'the refusal names the stemcell');

($ok, $error) = check($two . squid('2.0.0'), 0);
ok(!$ok, 'without instance groups, every stemcell counts');

($ok, $error) = check($two . squid('2.0.0') . "instance_groups:\n" . group('squid', 'squid', 'default'), 1);
ok(!$ok, 'with the feature on, a second stemcell on another os is refused');
like($error, qr/old \(os .*ubuntu-xenial/, 'the refusal names the stemcell alias and os');

# Versions.
($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0-rc.1'), 1);
ok($ok, 'squid 2.0.0-rc.1 counts as part of the 2.x line on resolute') or diag($error);

($ok, $error) = check(stemcell('ubuntu-xenial') . squid('2.0.0-rc.1'), 0);
ok(!$ok, 'squid 2.0.0-rc.1 on xenial is refused');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('1.2.0-rc.3'), 1);
ok(!$ok, 'squid 1.2.0-rc.3 on resolute is refused');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0-beta'), 1);
ok(!$ok, 'a squid version that is not semver is refused');
like($error, qr/not a\s+version/, 'the refusal says the version is not understood');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('latest'), 1);
like($error, qr/release .*latest.*Pin it to a version/s, 'squid latest gets its own message');

($ok, $error) = check(stemcell('ubuntu-noble') . squid('latest'), 0);
ok(!$ok, 'squid latest on noble is refused without the feature');
like($error, qr/Pin it to a version/, 'the refusal says to pin it');

($ok, $error) = check(stemcell('ubuntu-noble') . "releases:\n- name: squid\n", 0);
ok(!$ok, 'a squid release without a version on noble is refused');

($ok, $error) = check(stemcell('ubuntu-resolute') . "releases:\n- name: squid\n", 1);
ok(!$ok, 'a squid release without a version is refused');
like($error, qr/without a version/, 'the refusal says the version is missing');


# bpm without a version, at latest, and as a release candidate.
($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0') . "- name: bpm\n", 1);
ok(!$ok, 'bpm without a version on resolute is refused');
like($error, qr/bpm without a version/, 'the refusal says the version is missing');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0') . "- name: bpm\n  version: latest\n", 1);
ok(!$ok, 'bpm latest on resolute is refused');
like($error, qr/bpm .*latest/, 'the refusal names latest');

($ok, $error) = check(stemcell('ubuntu-resolute') . squid('2.0.0') . "- name: bpm\n  version: 1.4.41-rc.1\n", 1);
ok(!$ok, 'bpm 1.4.41-rc.1 on resolute is refused, because a candidate comes before the fix');

($ok, $error) = check(stemcell('ubuntu-noble') . squid('2.0.0') . "- name: bpm\n  version: 1.4.22\n", 0);
ok($ok, 'an old bpm on noble is not checked') or diag($error);

# The success line.
{
	open(my $fh, '>', "$work/manifest.yml") or die;
	print {$fh} stemcell('ubuntu-resolute') . squid('2.0.0+dev.2');
	close($fh);
	local $ENV{GENESIS_MANIFEST_FILE} = "$work/manifest.yml";
	local $ENV{GENESIS_BOSHVARS_FILE} = undef;
	my $hook = bless {
		label => 'pre-deploy', __wanted_features => {resolute => 1},
	}, 'Genesis::Hook::PreDeploy::Squid';
	my $printed = '';
	{
		local *STDERR;
		open(STDERR, '>', \$printed) or die;
		no warnings qw/redefine once/;
		local *Genesis::Hook::PreDeploy::Squid::done = sub {1};
		$hook->perform;
	}
	like($printed, qr/Pre-deploy checks passed for squid 2\.0\.0\+dev\.2 on ubuntu-resolute/,
		'a passing check prints one line that says so') or diag($printed);
}

done_testing();
