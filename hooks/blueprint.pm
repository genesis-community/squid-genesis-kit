# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Blueprint::Squid v1.0.0;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail warning mkfile_or_fail count_nouns/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

	$self->add_files(qw(
		manifests/squid.yml
		manifests/releases/squid.yml
	));

	my @invalid = ();
	for my $feature ($self->features) {
		if ($feature eq 'ocfp') {
			$self->add_files('manifests/ocfp.yml');
		} elsif ($feature eq 'resolute') {
			# Handled after the loop so that it overrides every other fragment.
		} elsif (-f "$ENV{GENESIS_ROOT}/ops/${feature}.yml") {
			$self->add_files("$ENV{GENESIS_ROOT}/ops/${feature}.yml");
		} else {
			push @invalid, $feature;
		}
	}

	bail(
		"Invalid %s encountered: %s",
		count_nouns(scalar(@invalid), 'feature', suppress_count => 1),
		join(', ', @invalid)
	) if @invalid;

	$self->_process_ocfp if $self->want_feature('ocfp');
	$self->_process_resolute;

	return $self->done(1);
}

# _process_ocfp - Pin the proxy to its reserved OCFP address {{{
# The proxy is one instance, and its address is the one other deployments
# are told to use, so it takes the squid_ip reserved on the first OCFP subnet
# that has one.  The AZ comes from that subnet, mapped through the director's
# network exodus data.
sub _process_ocfp {
	my ($self) = @_;

	my $subnets = $self->env->ocfp_config_lookup('net.subnets');
	my $prefix  = $self->env->ocfp_subnet_prefix;
	my ($ip, $az);
	for my $subnet (sort grep {/^\Q$prefix\E/} keys %{$subnets // {}}) {
		my $reserved = $subnets->{$subnet}{'reserved-ips'}{'squid_ip'};
		next unless $reserved;
		($ip, $az) = ($reserved, $subnets->{$subnet}{az});
		last;
	}
	bail(
		"No OCFP subnet with prefix #c{%s} reserves a #c{squid_ip}, so the proxy ".
		"has no address.  Reserve one in the OCFP config and run #g{ocfp vault ".
		"populate}.", $prefix
	) unless $ip;
	bail(
		"The OCFP subnet that reserves squid_ip %s names no AZ.", $ip
	) unless $az;

	my $az_map  = $self->env->director_exodus_lookup('/network')->{azs} // {};
	my $az_name = $az_map->{$az}{name};
	bail(
		"The OCFP AZ #c{%s} for squid_ip %s is not in the director's network ".
		"exodus data, so the proxy has no BOSH AZ.", $az, $ip
	) unless $az_name;

	# The top-level azs block lets the deploy-time AZ check match the AZ to
	# the right CPI; Genesis prunes it before bosh deploy.  The instance
	# group's azs is a (( grab )) in the base manifest, so a literal list
	# overwrites it.  Its networks is a literal list, so (( replace )) drops
	# the default network and its static_ips operator.
	my $cpi_name = $self->env->cpi_name;
	my $az_block = "\n- name: $az_name" . (defined($cpi_name) ? "\n  cpi: $cpi_name" : '');
	my $fragment = <<"EOF";
azs:$az_block

instance_groups:
- name: squid
  azs:
  - $az_name
  networks:
  - (( replace ))
  - name: (( grab params.network ))
    static_ips:
    - $ip
EOF
	my $file = "manifests/network.dynamic.yml";
	mkfile_or_fail($self->env->kit->path($file), 0644, $fragment);
	$self->add_files($file);
	return;
}
# }}}

# _process_resolute - Opt-in ubuntu-resolute stemcell support {{{
# Called after every other fragment is added so that it overrides the
# stemcell os default (ubuntu-xenial) and the squid release pin.  A
# deployment repo's ops/resolute.yml is added last, so it can still adjust
# either.
sub _process_resolute {
	my ($self) = @_;

	if ($self->want_feature('resolute')) {
		my $stemcell_os = $self->env->lookup('params.stemcell_os', 'ubuntu-resolute');
		bail(
			"The #c{resolute} feature sets the stemcell os to ubuntu-resolute, but " .
			"the environment sets #c{params.stemcell_os} to #R{%s}.  " .
			"Remove that parameter.", $stemcell_os
		) if $stemcell_os ne 'ubuntu-resolute';
		$self->add_files(
			'manifests/resolute.yml',
			# squid 1.1.0 starts Squid with chpst, which resolute does not ship.
			'manifests/releases/squid-resolute.yml',
		);
		$self->add_files("$ENV{GENESIS_ROOT}/ops/resolute.yml") if -f "$ENV{GENESIS_ROOT}/ops/resolute.yml";
	} elsif ($self->env->lookup('params.stemcell_os', 'ubuntu-xenial') eq 'ubuntu-resolute') {
		bail(
			"The environment sets #c{params.stemcell_os} to ubuntu-resolute " .
			"without the #c{resolute} feature.  Enable the feature and remove " .
			"that parameter."
		);
	}
	return;
}
# }}}

1;
