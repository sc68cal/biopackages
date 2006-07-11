#!/usr/bin/perl
use strict;
use Data::Dumper;

my ($spec_file) = @ARGV;

my $build_req = {};
my $missing_build_req = {};
my $req = {};
my $missing_req = {};

parse_req($spec_file, "BuildRequires", $build_req, $missing_build_req, 1);
#parse_req($spec_file, "Requires", $req, $missing_req, 0);

print "\nBuild Req:\n";
print_req($build_req);
print "\nMissing Build Req\n";
print_req($missing_build_req);
print "\nReq:\n";
print_req($req);
print "\nMissing Req:\n";
print_req($missing_req);

sub print_req{
  my ($req) = @_;
  foreach my $key (keys %{$req}) {
    print "$key\n";
  }
}

sub parse_req {
  my ($file_name, $reg_exp, $req, $missing_req, $install) = @_;
  my @files = glob("SPECS/$file_name.spec.in");
  foreach my $file (@files) {
  #print "Processing file of ".scalar(@files).": $file_name $file\n";
  #print "Processing file: $file_name\n";
    if (!-e $file) {
      #print "Missing file $file\n";
      $missing_req->{"$file"} = 1; 
    }
    else {
      #print "Yes, I found the file $file\n";
      $req->{"$file"} = 1;
      open IN, "<$file" or die;
      while (<IN>) {
        chomp;
#	if ($_ =~ /^BuildRequires:\s+(.*)$/) { print "BUILD REQ\n\n"; }
#if ($_ =~ /^Requires:\s+(.*)$/) { print "REQ\n\n$_\n"; }
        if ($_ =~ /^BuildRequires:\s+(.*)$/) {
	print "BUILD REQ: $_\n\n";
          my @tokens = split ", ", $1;
	  foreach my $token (@tokens) {
	    #print "Calling: $token\n";
	    parse_req($token, $reg_exp, $req, $missing_req, $install);
	  }
	}
        elsif ($_ =~ /^Requires:\s+(.*)$/) {
print "REQ: $_\n\n";
          my @tokens = split ", ", $1;
	  foreach my $token (@tokens) {
	    #print "Calling: $token\n";
	    parse_req($token, $reg_exp, $req, $missing_req, $install);
	  }
	}
      }
      close IN;
      $file =~ /SPECS\/(\S+).spec.in$/;
      my $package_name = $1;
      if ($package_name !~ "MODULE_COMPAT" && $package_name !~ " ") {
      print "make SPECS/$package_name.spec SPECS/$package_name.built\n";
      #system("make SPECS/$package_name.spec SPECS/$package_name.built >& $package_name.log");
      if ($install) {
        print("sudo rpm -Uvh RPMS/i386/$package_name*.rpm RPMS/noarch/$package_name*.rpm RPMS/ppc/$package_name*.rpm\n");
        #system("sudo rpm -Uvh RPMS/i386/$package_name*.rpm");
	}
      }
    }
  }
}
