package Genesis::Hook::New::Squid v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

# init - Initialize the hook {{{
sub init {
	my ($class, %ops) = @_;
	my $obj = $class->SUPER::init(%ops);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}
# }}}

# perform - Main hook execution {{{
# The kit needs no parameters, so the new environment file holds only the
# kit and the genesis config block.  Features and params are added by hand,
# as MANUAL.md describes.
sub perform {
	my ($self) = @_;

	my $content = "kit:\n";
	$content .= "  name:    $ENV{GENESIS_KIT_NAME}\n";
	$content .= "  version: $ENV{GENESIS_KIT_VERSION}\n";
	$content .= "  features: []\n";
	$content .= "\n";
	$content .= $self->env->genesis_config_block;
	$content .= "params: {}\n";

	$self->env->write_manifest($content);

	return $self->done(1);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
