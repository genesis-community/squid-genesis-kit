#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Squid::Curl v4.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Issue raw HTTP requests (via curl) through the Squid proxy, to test reachability.\n".
  "This requires curl to be installed on your system.";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Get proxy information from exodus data
  my $proxy = $env->exodus_lookup('http_proxy');

  # Check if curl is installed
  my ($out, $rc) = run("command -v curl >/dev/null 2>&1");
  if ($rc != 0) {
    bail("!!! install curl first!");
  }

  # Set environment variables and execute curl with the provided arguments
  $ENV{http_proxy} = $proxy;
  $ENV{https_proxy} = $proxy;

  info("http_proxy=$ENV{http_proxy}");
  info("https_proxy=$ENV{https_proxy}");
  info("");

  my $args = join(" ", @{$self->{args}});
  my ($curl_out, $curl_rc, $curl_err) = run({interactive => 1}, "curl $args");

  if ($curl_rc != 0) {
    info("Curl command failed with exit code $curl_rc: $curl_err");
  }

  return $self->done()
}

1;
