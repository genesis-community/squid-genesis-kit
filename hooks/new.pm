#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::New::Squid v4.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/bail info run/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Create environment file
  my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
  open my $fh, ">", $env_file or bail("Cannot open $env_file for writing: $!");

  print $fh "---\n";
  print $fh "kit:\n";
  print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
  print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";

  # Generate and add the genesis_config_block
  my ($out, $rc, $err) = run('genesis_config_block');
  if ($rc != 0) {
    bail("Failed to generate genesis config block: $err");
  }
  print $fh $out;

  close $fh;

  # Offer environment editor
  my ($editor_out, $editor_rc, $editor_err) = run({ interactive => 1 }, 'offer_environment_editor');
  if ($editor_rc != 0) {
    info("Note: Editor exited with non-zero status: $editor_rc");
  }

  return $self->done();
}

1;
