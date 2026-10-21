package Genesis::Hook::Addon::Squid::Curl v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Addon);

use Genesis qw/bail info run/;

# init - Initialize the hook {{{
sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}
# }}}

# cmd_details - help text for the addon {{{
sub cmd_details {
	return
	"Issue raw HTTP requests (via curl) through the Squid proxy, to test reachability.\n".
	"Arguments after -- are passed to curl as they are.  This requires curl on\n".
	"your system.";
}
# }}}

# perform - Main hook execution {{{
sub perform {
	my ($self) = @_;

	my $proxy = $self->env->exodus_lookup('http_proxy', '');
	bail(
		"No proxy address in the exodus data for %s.  Deploy the environment first.",
		$self->env->name
	) unless $proxy;

	my (undef, $rc) = run('command -v curl >/dev/null 2>&1');
	bail("curl is not installed.  Install curl first.") unless $rc == 0;

	info("http_proxy=%s", $proxy);
	info("https_proxy=%s", $proxy);
	info("");

	# Each argument is passed to curl as its own word, so arguments with
	# spaces or shell characters reach curl unchanged.
	local $ENV{http_proxy}  = $proxy;
	local $ENV{https_proxy} = $proxy;
	my (undef, $curl_rc) = run({interactive => 1}, 'curl "$@"', @{$self->{args} // []});

	return $self->done($curl_rc == 0 ? 1 : 0);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
