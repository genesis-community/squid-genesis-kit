#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Info::Squid v4.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/info/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Get proxy information from exodus data
  my $proxy = $self->env->exodus_lookup('http_proxy');

  info(
    "\nRnvironment variables:\n\n".
    "\texport http_proxy=$proxy\n".
    "\texport https_proxy=$proxy\n"
  );

  return $self->done();
}

1;
