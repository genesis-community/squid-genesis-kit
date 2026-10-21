package Genesis::Hook::Info::Squid v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/info/;

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

	my $proxy = $self->env->exodus_lookup('http_proxy', '');
	unless ($proxy) {
		info("#Y{No proxy address in the exodus data.}  Deploy the environment first.");
		return $self->done(1);
	}

	info("");
	info("Squid proxy: #C{%s}", $proxy);
	info("");
	info("Environment variables:");
	info("");
	info("  export http_proxy=%s", $proxy);
	info("  export https_proxy=%s", $proxy);
	info("");

	return $self->done(1);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
