#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PreDeploy::Squid v4.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/info/;
use parent qw(Genesis::Hook);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

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
