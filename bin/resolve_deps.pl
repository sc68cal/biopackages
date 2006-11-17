#!/usr/bin/perl
use strict;
use Data::Dumper;
use constant USAGE => <<"UUU";
$0 <Spec-BuildArch> <Spec-Name> <File-Listing-Packages-To-Skip> <File-Listing-Packages-To-Not-Yum-Install> <Remove-Installed-RPMs[0|1]> <Dep-Tree-Output-File> 

This script starts with a certain package name and attempts to build all the
required packages that the given package both needs for build requirements and
also for install requirements.  At the end of this run, all the packages
required to build this package are installed.
UUU

# Usage
if (scalar(@ARGV) < 5) { print USAGE; exit(1); }

# The spec file to start with (name without extension)
my ($arch_str_universal, $spec_file, $no_build_file, $no_yum_install_file, $remove_installed_rpms, $dep_tree_file) = @ARGV;

# a hash to store the names of everything that was either yum installed or build and rpm installed
my $complete_package_list = {};

# Hashes to store dependency tree
my $req = {};
my $missing_req = {};

# keep track of what's been yum installed
my $yum_installed = {};

# keep a list of what not to yum install

my $no_yum_install = read_no_build($no_yum_install_file);

# A list of modules not to build
my $no_build = {};
$no_build = read_no_build($no_build_file);

# Hashes to store which packages have been previously built
my %built_before;
my %parsed_before;

# Should this program install build requirements?
my $install = 1;

# A file for the dependency tree summary
open TREE, ">/tmp/foo" or die $!;

# distro string
my $distro_str = `bp-distro`;
chomp($distro_str);


# The actual process 
parse_req($spec_file, $req, $missing_req, "");

# Done
print "\nBUILD COMPLETE!\n\n";

# Print out missing requirements
print "\nMISSING REQS:\n";
print_req($missing_req); 
close TREE;

# Complete list

print Dumper($complete_package_list);
if($remove_installed_rpms) {
  print "rpm -e ", join(" ", keys(%{$complete_package_list})),"\n";
}

# Subroutines

# Just prints the contents of a hash
sub print_req{
  my ($req) = @_;
  foreach my $key (keys %{$req}) {
    print "+$key\n";
  }
}

# parses the requirements for a given spec file and recursively build them
sub parse_req {
  my ($file_name, $req, $missing_req, $indent) = @_;
  my @files = glob("SPECS/$file_name.spec.in");
  foreach my $file (@files) {
    my $yum_install_status = 0;
    # yum install if there is no spec.in file or it's not in the no_yum_install list
    if (!-e $file || !defined($no_yum_install->{$file_name})) {
      print "\n+Trying to yum install: $file_name\n\n";
      # only missing if there is no spec file
      if (!-e $file ) { 
        $missing_req->{"$file_name"} = 1; 
      }
      print TREE "$indent** $file_name **\n";
      # so there is a dependency that isn't part of the SPEC.in 
      # so it must be either a system dep (e.g. provided by the distro)
      # or it's simply not yet imported into the biopackages repo
      # try to install with yum, it will just fail if it's not available
      if (!defined $yum_installed->{$file_name}) {
        $yum_install_status = system "sudo yum -y install $file_name >& /tmp/yum_output.txt";
        open YUM, "</tmp/yum_output.txt" or die;
        my $output_txt;
        while(<YUM>) {
          chomp;
          $output_txt .= $_;
        }
        close YUM;
        if ($output_txt =~ /Cannot find a package matching/) { $yum_install_status = 1; } 
        # install was OK
        else { $complete_package_list->{$file_name} = 1; }
        $yum_installed->{$file_name} = 1;
      }
      else { print "\n+Previously yum installed\n\n"; }
    }
    # otherwise there is either a spec file (taken care of below) or it's in the no_yum_install 
    # so essentially the yum failed and the status is non-zero
    else {
     print "\n+Coundn't yum install: $file_name\n\n";
     $yum_install_status = 1;
    }
    if ($yum_install_status != 0 && !$parsed_before{$file} && !defined($no_build->{$file_name})) {
      $parsed_before{$file} = 1;
      $req->{"$file"} = 1;
      print "\n+Trying to build from spec: $file_name\n\n";
      print TREE "$indent$file_name\n";

      # vars to hold version string
      my $id_str = "";
      my $version_str = "";

      my $arch_str = $arch_str_universal;
      
      my @deps;
      $file =~ /^(.*).in$/;
      my $spec_file = $1;
      system("make $spec_file");
      open IN, "<$spec_file" or die "Can't open file: $spec_file\n";
      while (<IN>) {
        chomp;
        if ($_ =~ /^BuildRequires:\s+(.*)$/) {
          my @tokens = split ", ", $1;
	  foreach my $token (@tokens) {
	    $token = clean_package_names($token);
            # there are some crufty entries with %{} in the spec files
	    push @deps, $token if ($token !~ /%/); 
	  }
	}
        elsif ($_ =~ /^Requires:\s+(.*)$/) {
          my @tokens = split ", ", $1;
	  foreach my $token (@tokens) {
	    $token = clean_package_names($token);
            # there are some crufty entries with %{} in the spec files
	    push @deps, $token if ($token !~ /%/);
	  }
	}
	elsif ($_ =~ /^Version:\s+(.*)$/) {
          $version_str = $1;
	}
	elsif ($_ =~ /^Release:\s+([\d\.]*)/) {
	  $id_str = $1;
	  if ($id_str =~ /^(.*)\.$/) {
            $id_str = $1;
	  }
	}
        elsif ($_ =~ /^BuildArch:\s+(.*)$/) {
          $arch_str = $1;
          print "\n+Setting arch string to $arch_str for $spec_file\n\n";
	}
      }
      close IN;
      # now recursively examine each
      foreach my $dep (@deps) {
        parse_req($dep, $req, $missing_req, "\t$indent");
      }

      $file =~ /SPECS\/(\S+).spec.in$/;
      my $package_name = $1;
      if ($package_name !~ "MODULE_COMPAT" && $package_name !~ " " && !$built_before{$package_name}) {
        print "\n+make SPECS/$package_name.spec SPECS/$package_name.built\n\n";
        $built_before{$package_name} = 1;
        my $result = system("make SPECS/$package_name.spec SPECS/$package_name.built >& $package_name.log");
	if ($result) { die "There was an error building $package_name with error code $result\n"; }
        if ($install) {
          #print "$version_str $id_str $distro_str $arch_str\n\n";
	  if ($package_name =~ /biopackages/ || $package_name =~ /macosx-release/ || $package_name =~ /usr-local-bin-perl/) {
	    if (!already_installed("$package_name-$version_str-$id_str")) {
              print("\n+sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$arch_str.rpm\n\n");
              $result = system("sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$arch_str.rpm");
              $complete_package_list->{$package_name} = 1;
	    }
	  } else {
	    if (!already_installed("$package_name-$version_str-$id_str.$distro_str")) {
              print ("\n+sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm\n\n");
              $result = system("sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm");
              $complete_package_list->{$package_name} = 1;
	    }
	  }
          if ($result) { die "There was an error RPM RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm with error code $result\n"; }
	}
      }
    }
  }
}

# check to see if the package is already installed
sub already_installed {
  my ($package_name) = @_;
  my @query_result = `rpm -qa | grep $package_name`;
  return(scalar(@query_result));
}

# The tokens from a spec file can include <= and a version string
# This method cleans these up and trys to extract a spec name
sub clean_package_names {
  my ($raw_name) = @_;
  my $name = "";
  if ($raw_name =~ /perl\(([\w\:)]+)\)/) {
    $name = $1;
    $name =~ s/::/-/g;
    $name = "perl-$name";
  }
  elsif ($raw_name =~ /^([\w-]+) [><=]+/) {
    $name = $1;
  }
  else { $name = $raw_name; }
  return($name)
}

sub read_no_build {
  my ($file) = @_;
  my $result = {};
  open INPUT, $file or die "Can't read file: $file\n";
  while (<INPUT>) {
    chomp;
    next if (/^#/);
    $result->{$_} = 1;
  }
  close INPUT;
  return($result);
}
