package Genesis::Hook::PreDeploy::Squid v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/bail run load_json new_enough semver/;

# bpm releases older than this do not compile on the resolute stemcell.  The
# kit does not deploy bpm itself, but an ops file from the deployment repo can
# add it.
my $RESOLUTE_MIN_BPM = '1.4.41';

# squid releases older than this start Squid with chpst, which the resolute
# stemcell does not ship.  From this version on, squid builds Squid 7, which
# needs a C++17 compiler, so it no longer compiles on the older stemcells.
my $SQUID_SETPRIV = '2.0.0';
my $OLD_STEMCELLS = qr/ubuntu-(?:trusty|xenial|bionic)/;

# init - Initialize the hook {{{
sub init {
	my ($class, %ops) = @_;
	my $obj = $class->SUPER::init(%ops);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}
# }}}

# perform - Main hook execution {{{
sub perform {
	my ($self) = @_;
	$self->_check_resolute_manifest;
	$self->_check_squid_release;
	return $self->done(1);
}
# }}}

# _load_yaml - read a YAML file as a hash, redacted from the trace log {{{
# The manifest and the BOSH variables file both hold secrets, so their
# conversion never reaches the trace log.  Bails when the file cannot be read
# or is not a YAML map, naming $what in the message.
sub _load_yaml {
	my ($self, $file, $what) = @_;
	my ($out, $rc, $err) = run({stderr => 0, redact_output => 1}, 'spruce json < "$1"', $file);
	my $data = $rc == 0 ? eval {load_json($out)} : undef;
	bail(
		"Cannot read %s at #C{%s} to check its stemcells and bpm release: %s",
		$what, $file, ($err // '') =~ s/\s+$//r || ($rc ? "spruce exited $rc" : 'not a YAML map')
	) unless ref($data) eq 'HASH';
	return $data;
}
# }}}

# _value - resolve ((name)) placeholders from the BOSH variables file {{{
# BOSH fills ((name)) placeholders at deploy time from the variables file that
# Genesis passes along, so they are resolved the same way before checking.  A
# placeholder that no variable resolves bails, because the check cannot tell
# what it deploys.
sub _value {
	my ($self, $value, $what) = @_;
	return $value unless defined($value) && !ref($value) && $value =~ /\(\(/;
	(my $resolved = $value) =~ s{\(\(\s*([^()\s]+)\s*\)\)}{
		my $name = $1;
		bail(
			"The manifest sets %s to #R{((%s))}, which no BOSH variable in the ".
			"environment resolves, so the resolute checks cannot tell what it ".
			"deploys.  Set it in the environment file instead.", $what, $name
		) unless defined($self->{vars}{$name}) && !ref($self->{vars}{$name});
		$self->{vars}{$name};
	}ge;
	return $resolved;
}
# }}}

# _list - the hash entries of a top-level manifest list {{{
sub _list {
	my ($self, $manifest, $key) = @_;
	my $list = $manifest->{$key} // [];
	bail(
		"The manifest's #c{%s} key must be a list, not %s.", $key, ref($list) || 'a string'
	) unless ref($list) eq 'ARRAY';
	return grep {ref($_) eq 'HASH'} @$list;
}
# }}}

# _check_resolute_manifest - resolute stemcells get a new enough bpm {{{
# The blueprint gate reads params only, so an ops file from the deployment
# repo can still override the stemcells or the bpm release.  The merged
# manifest is the last word, so check that.  A stemcell is resolute when its
# os is ubuntu-resolute, or when it has no os and its name names resolute.
# With the feature on, every stemcell must be resolute.  With any resolute
# stemcell, feature or not, bpm must be pinned to a new enough version.
sub _check_resolute_manifest {
	my ($self) = @_;
	my $feature = $self->want_feature('resolute');

	my $file = $ENV{GENESIS_MANIFEST_FILE};
	bail(
		"Genesis did not pass the manifest to the pre-deploy hook, so its ".
		"stemcells and bpm release cannot be checked."
	) unless defined($file) && -f $file && -r $file;
	my $manifest = $self->_load_yaml($file, 'the manifest');

	my $vars_file = $ENV{GENESIS_BOSHVARS_FILE};
	$self->{vars} = (defined($vars_file) && -f $vars_file && -s $vars_file)
		? $self->_load_yaml($vars_file, 'the BOSH variables file')
		: {};

	my @stemcells = map {{
		alias => $self->_value($_->{alias}, 'a stemcell alias') // '<none>',
		os    => $self->_value($_->{os},    'a stemcell os'),
		name  => $self->_value($_->{name},  'a stemcell name'),
	}} $self->_list($manifest, 'stemcells');
	my $is_resolute = sub {
		my ($s) = @_;
		return defined($s->{os}) ? $s->{os} eq 'ubuntu-resolute'
		                         : ($s->{name} // '') =~ /ubuntu-resolute/;
	};
	$self->{manifest}  = $manifest;
	$self->{stemcells} = \@stemcells;

	if ($feature) {
		bail(
			"The #c{resolute} feature is enabled, but the manifest lists no stemcells."
		) unless @stemcells;
		my @wrong = grep {!$is_resolute->($_)} @stemcells;
		bail(
			"The #c{resolute} feature is enabled, but the manifest deploys these ".
			"stemcells on another OS: %s.  Remove the override that sets them.",
			join(', ', map {
				defined($_->{os})
					? sprintf("%s (os #R{%s})", $_->{alias}, $_->{os})
					: sprintf("%s (name #R{%s})", $_->{alias}, $_->{name} // 'none')
			} @wrong)
		) if @wrong;
	}

	return 1 unless grep {$is_resolute->($_)} @stemcells;

	for my $release ($self->_list($manifest, 'releases')) {
		next unless ($self->_value($release->{name}, 'a release name') // '') eq 'bpm';
		my $version = $self->_value($release->{version}, 'the bpm release version');
		bail(
			"The manifest deploys bpm without a version on a resolute stemcell.  ".
			"Pin bpm to %s or newer.", $RESOLUTE_MIN_BPM
		) unless defined($version) && $version ne '';
		bail(
			"The manifest deploys bpm #R{latest} on a resolute stemcell.  Pin bpm ".
			"to %s or newer, so the deploy cannot pick up an older upload.",
			$RESOLUTE_MIN_BPM
		) if $version eq 'latest';
		bail(
			"The manifest deploys bpm #R{%s} on a resolute stemcell, which needs ".
			"bpm %s or newer.  Remove the override that sets the bpm release.",
			$version, $RESOLUTE_MIN_BPM
		) unless semver($version) && new_enough($version, $RESOLUTE_MIN_BPM);
	}
	return 1;
}
# }}}

# _check_squid_release - the squid release must start on the stemcell {{{
# squid releases before 2.0.0 start Squid with chpst, so they fail on a
# resolute stemcell.  squid 2.0.0 and later build Squid 7, which does not
# compile on trusty, xenial, or bionic.  The check reads the merged manifest,
# so it also catches an ops file that overrides the squid release or the
# stemcells.
sub _check_squid_release {
	my ($self) = @_;
	my @stemcells = @{$self->{stemcells} // []};
	return 1 unless @stemcells;

	my @resolute = grep {
		defined($_->{os}) ? $_->{os} eq 'ubuntu-resolute' : ($_->{name} // '') =~ /ubuntu-resolute/
	} @stemcells;
	my @old = grep {
		defined($_->{os}) ? $_->{os} =~ /^$OLD_STEMCELLS$/ : ($_->{name} // '') =~ $OLD_STEMCELLS
	} @stemcells;
	return 1 unless @resolute || @old;

	for my $release ($self->_list($self->{manifest}, 'releases')) {
		next unless ($self->_value($release->{name}, 'a release name') // '') eq 'squid';
		my $version = $self->_value($release->{version}, 'the squid release version');
		bail(
			"The manifest deploys the squid release without a version.  Pin it, so ".
			"the deploy cannot pick an upload that does not start on the stemcell."
		) unless defined($version) && $version ne '' && $version ne 'latest';
		bail(
			"The manifest deploys the squid release at #R{%s}, which is not a version ".
			"the stemcell check understands.", $version
		) unless semver($version);
		my $setpriv = new_enough($version, $SQUID_SETPRIV);
		bail(
			"The manifest deploys squid #R{%s} on a resolute stemcell.  Releases ".
			"before squid %s start Squid with chpst, which the resolute stemcell ".
			"does not ship.  Enable the #c{resolute} feature, or remove the override ".
			"that sets the squid release.", $version, $SQUID_SETPRIV
		) if @resolute && !$setpriv;
		bail(
			"The manifest deploys squid #R{%s} on the stemcell %s.  squid %s and ".
			"later build Squid 7, which needs a C++17 compiler that this stemcell ".
			"does not have.  Use the #c{resolute} feature, or keep the kit's default ".
			"squid release on this stemcell.",
			$version, join(', ', map {$_->{os} // $_->{name} // $_->{alias}} @old), $SQUID_SETPRIV
		) if @old && $setpriv;
	}
	return 1;
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
