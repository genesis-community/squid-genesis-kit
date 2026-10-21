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

	my @invalid = grep {
		$_ ne 'ocfp' && $_ ne 'resolute' && ! -f "$ENV{GENESIS_ROOT}/ops/$_.yml"
	} $self->features;
	bail(
		"Invalid %s encountered: %s",
		count_nouns(scalar(@invalid), 'feature', suppress_count => 1),
		join(', ', @invalid)
	) if @invalid;

	$self->_check_port;

	# The kit's own fragments go first, and the deployment repo's ops files
	# follow in the order the features list them.  An ops file therefore wins
	# over every kit fragment, including the squid release that the resolute
	# feature pins.
	if ($self->want_feature('ocfp')) {
		$self->add_files('manifests/ocfp.yml');
		$self->_process_ocfp;
	}
	$self->_process_resolute;

	for my $feature ($self->features) {
		next if $feature eq 'ocfp';
		my $ops = "$ENV{GENESIS_ROOT}/ops/${feature}.yml";
		$self->add_files($ops) if -f $ops;
	}

	return $self->done(1);
}

# _check_port - Squid runs as vcap, so it cannot bind a privileged port {{{
# The squid job starts Squid as vcap without any capabilities, so a port
# below 1024 would fail to bind, and the kid would exit at every start.  The
# release refuses such a port when it renders its template, but the kit says
# so first, before anything is deployed.
sub _check_port {
	my ($self) = @_;
	my $port = $self->env->lookup('params.port', '3128');
	bail(
		"The environment sets #c{params.port} to #R{%s}, but the proxy needs a ".
		"port from 1024 to 65535.  Squid runs as vcap without any capabilities, ".
		"so it cannot bind a lower port.", ref($port) ? 'a structure' : $port
	) unless !ref($port) && $port =~ /^[0-9]+$/ && $port >= 1024 && $port <= 65535;
	return;
}
# }}}

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

	my $az_name = $self->_bosh_az($az);
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

# _bosh_az - The BOSH AZ name for an OCFP AZ {{{
# The cloud-config hook names each subnet's AZ through Genesis's lookup_az,
# so the instance group has to use the same name, or BOSH rejects the deploy.
# This follows the same rules.  The OCFP AZ can be a key of the director's
# network exodus AZs, an AZ's rendered name, its name for this environment's
# CPI, or the zN short form of a rendered name.  The result is the AZ's name
# for this environment's CPI when the CPI is enabled and the director records
# one, and its rendered name otherwise.
sub _bosh_az {
	my ($self, $az) = @_;
	my $azs = $self->env->director_exodus_lookup('/network')->{azs} // {};
	return unless ref($azs) eq 'HASH' && keys %$azs;

	my $cpi = $self->env->cpi_enabled ? $self->env->cpi_name : undef;
	my $for_cpi = sub {
		my ($key) = @_;
		return unless defined($cpi);
		my $names = $azs->{$key}{for_cpi};
		return ref($names) eq 'HASH' ? $names->{$cpi} : undef;
	};

	my ($key) = grep {$_ eq $az} keys %$azs;
	($key) = grep {($azs->{$_}{name} // '') eq $az} sort keys %$azs unless defined($key);
	($key) = grep {($for_cpi->($_) // '') eq $az} sort keys %$azs unless defined($key);
	if (!defined($key) && $az =~ /^z([0-9]+)$/) {
		my $index = $1;
		($key) = grep {
			my $i = $azs->{$_}{index} // (($azs->{$_}{name} // '') =~ /([0-9]+)$/)[0];
			defined($i) && $i eq $index
		} sort keys %$azs;
	}
	return unless defined($key) && ref($azs->{$key}) eq 'HASH';
	return $for_cpi->($key) // $azs->{$key}{name};
}
# }}}

# _process_resolute - Opt-in ubuntu-resolute stemcell support {{{
# Adds the kit's resolute fragments after the base and OCFP ones, so that
# they override the stemcell os default (ubuntu-xenial) and the squid
# release pin.  The deployment repo's ops files, ops/resolute.yml included,
# load after them, so they can still change either.
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
