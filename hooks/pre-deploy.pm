# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::PreDeploy::Squid;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/info/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::PreDeploy);
sub init {
  my ($class, %ops) = @_;
  my $self = $class->SUPER::init(%ops);
  $self->check_minimum_genesis_version('3.1.0-rc.20');
  return $self;
}

sub perform {
  my ($self) = @_;

  # For Squid, we don't need any specific pre-deployment tasks
  # This is just a placeholder for future implementations

  # Create an empty data file that post-deploy can use
  my $data_file = $self->env->workpath("data");
  open(my $fh, ">", $data_file) or return $self->done(0);
  close($fh);

  return $self->done(1);
}

1;
