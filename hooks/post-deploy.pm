package Genesis::Hook::PostDeploy::Squid v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::PostDeploy);

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
	return $self->done(1) unless $self->deploy_successful;

	info("");
	info("#M{$ENV{GENESIS_ENVIRONMENT}} Squid proxy deployed!");
	info("");
	info("For details about the deployment, run");
	info("  #G{$ENV{GENESIS_CALL_ENV} info}");
	info("");
	info("To test the proxy, run");
	info("  #G{$ENV{GENESIS_CALL_ENV} do curl -- -sI https://www.google.com}");

	return $self->done(1);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
