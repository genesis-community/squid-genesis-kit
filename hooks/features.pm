# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Features::Squid;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Squid kit doesn't have any specific features to validate
  # Simply check if any features are provided, and if so, bail
  foreach my $feature (@{$self->{features}}) {
    bail(
      "Feature [$feature] not supported. ".
      "The Squid kit does not support any features."
    );
  }

  return $self->done();
}

1;
