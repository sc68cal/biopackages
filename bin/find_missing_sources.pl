#!/usr/bin/perl

# a little script to find missing source files

use strict;

my @files = glob("SPECS/*.spec.in");

foreach my $file (@files) {

  open SPEC, "<$file" or die;
  my $name;
  my $version;
  my @sources;

  while(<SPEC>) {
    chomp;
    if (/^Source\d*:\s+(\S+)$/) { push @sources, $1; }
    elsif (/^Version\d*:\s+(\S+)$/) { $version = $1; }
    elsif (/^Name\d*:\s+(\S+)$/) { $name = $1; }
    #elsif (/^Name\d*:\s+(\S+)$/) { $name = $1; }
    #elsif (/^Name\d*:\s+(\S+)$/) { $name = $1; }
    #elsif (/^Name\d*:\s+(\S+)$/) { $name = $1; }
  }

  foreach my $source (@sources) {
    $source =~ s/\%\{name\}/$name/g;
    $source =~ s/\%\{version\}/$version/g;
    if (!-e "SOURCES/$source") { print "Probably missing: $file SOURCES/$source\n"; }
  }
  
  close SPEC;

}
