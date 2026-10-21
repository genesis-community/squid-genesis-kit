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
	"Every argument is passed to curl as it is, and a leading -- is dropped, so\n".
	"`do curl -sI URL` and `do curl -- -sI URL` do the same thing.  The request\n".
	"always goes through the proxy, whatever proxy settings your shell has.  This\n".
	"requires curl on your system.";
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

	info("Sending the request through the proxy at %s.", $proxy);
	info("");

	# Genesis hands the addon a leading -- when the caller separates the
	# curl arguments with one, and curl would read it as the end of its
	# options and then treat -sI as a URL.
	my @args = @{$self->{args} // []};
	shift @args if @args && $args[0] eq '--';

	# The proxy is named on the command line, and every proxy variable from
	# the caller's shell is unset, so NO_PROXY cannot route the request
	# around Squid and an ALL_PROXY cannot send it somewhere else.  An empty
	# --noproxy tells curl to use the proxy for every host.
	my %unset = map {($_ => undef)} qw/
		http_proxy https_proxy all_proxy no_proxy
		HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
	/;

	# Each argument is passed to curl as its own word, so arguments with
	# spaces or shell characters reach curl unchanged.  They are redacted
	# from the trace log, because they can hold credentials, such as an
	# Authorization header or a -u user:password.
	my (undef, $curl_rc) = run(
		{interactive => 1, env => \%unset},
		'curl --proxy "$1" --noproxy "" "${@:2}"',
		$proxy, map {{redact => $_}} @args
	);

	return $self->done($curl_rc == 0 ? 1 : 0);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
