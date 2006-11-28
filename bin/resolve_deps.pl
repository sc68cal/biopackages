#!/usr/bin/perl
use strict;
use Data::Dumper;
use Getopt::Long;
use constant USAGE => <<"UUU";

USAGE:

$0 --spec <Spec-Name-No-Extension> --arch <Spec-BuildArch> --no-build <File-Listing-Packages-To-Skip> --no-yum <File-Listing-Packages-To-Not-Yum-Install> --remove-rpms (optional, default is no) --dep-tree <Dep-Tree-Output-File> 

This script starts with a certain package name and attempts to build all the
required packages that the given package both needs for build requirements and
also for install requirements.  At the end of this run, all the packages
required to build this package are installed.

The following are optional, if not specified $0 will attempt to automatically
figure out reasonable values according the standard biopackages directory 
structure. If you're building an individual package you want to provide values
for all of these.

--arch (defaults to system arch or noarch depending on the package being built)
--no-build (defaults to /usr/src/biopackages/SETTINGS/<distro>.<arch>/no_build.txt)
--no-yum (defaults to /usr/src/biopackages/SETTINGS/<distro>.<arch>/yum_no_install.txt)
--remove-rpms (defaults to false, RPMs are left on the system)

UUU

# GLOBALS
my ($arch_str_universal, $spec_file, $no_build_file, $no_yum_install_file, $remove_installed_rpms, $dep_tree_file, $help);

my $arg_count = scalar(@ARGV);

GetOptions ("arch=s"      => \$arch_str_universal,
            "spec=s"      => \$spec_file,
            "no-build=s"  => \$no_build_file,
            "no-yum=s"    => \$no_yum_install_file,
            "remove-rpms" => \$remove_installed_rpms,
            "dep-tree=s"  => \$dep_tree_file,
            "help"        => \$help,
            );

# USAGE
if ($help or $arg_count == 0) { print USAGE; exit(1); }


# DEFAULT VALUES
# If resolve_deps is being called from the biopackages cluster build process then several
# options need to be filled in
my $distro = find_distro();
$arch_str_universal = find_arch() if (!defined($arch_str_universal));
$no_build_file = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/no_build.txt" if (!defined($no_build_file));
$no_yum_install_file = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/yum_no_install.txt" if (!defined($no_yum_install_file));
$remove_installed_rpms = 1 if (!defined($remove_installed_rpms));
$dep_tree_file = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/DEP_TREES/$spec_file.deptree" if (!defined($dep_tree_file));


# TRACKING STRUCTURES

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
my $no_build = read_no_build($no_build_file);

# Hashes to store which packages have been previously built
my %built_before;
my %parsed_before;

# Should this program install build requirements?
my $install = 1;

# A file for the dependency tree summary
open TREE, ">$dep_tree_file" or die "RESOLVE_DEPS FATAL ERROR: $!";

# distro string
my $distro_str = `bp-distro`;
chomp($distro_str);


# THE PROGRAM STARTS HERE

# The actual process 
parse_req($spec_file, $req, $missing_req, "");

# Done
print "\nRESOLVE_DEPS: BUILD COMPLETE!\n\n"; 

# Print out missing requirements
print "\nRESOLVE_DEPS: MISSING REQS:\n";
print_req($missing_req); 
close TREE;

# FIXME: here I need to check to make sure the RPM target was created and, if not, report and error to stderr

# Complete list
#print Dumper($complete_package_list);

# uninstall RPMs that were installed during the build
# I'm only removing what was built. An alternative is to remove everything
# that was yum installed too however this could result in core rpms being removed
# i.e. perl.
# FIXME: explore the possibility of removing only RPMs not already installed on the system
if($remove_installed_rpms) {
  my $command = "sudo yum -y remove ", join(" ", keys(%built_before));
  print "$command\n";
  #system($command);
}


# SUBROUTINES

# Just prints the contents of a hash
sub print_req{
  my ($req) = @_;
  foreach my $key (keys %{$req}) {
    print "+$key\n";
  }
}

# THE CENTRAL SUBROUTINE FOR THE PROGRAM
# parses the requirements for a given spec file and recursively build them
sub parse_req {

  # the filename is the package to build, req is FIXME, $missing_req is FIXME, $indent is the tabs to indent the dep tree
  my ($file_name, $req, $missing_req, $indent) = @_;

  # all the spec.in files that match the filename (usually just one)
  my @files = glob("SPECS/$file_name.spec.in");

  # this keeps track of whether or not the yum install was successful, 0 is success
  my $yum_install_status = 0;

  # if there are no spec.in file by that name then must install via yum
  if (scalar(@files) == 0) {
    $yum_install_status = yum_install($file_name, $indent);
  }

  # else if the @files is non-zero then there is (one or more) spec files to be built.
  foreach my $file (@files) {
    
    # the yum install status is reset for each spec.in file
    $yum_install_status = 0;

    # yum install if there is no spec.in file or it's not in the no_yum_install list
    if (!defined($no_yum_install->{$file_name})) {
      $yum_install_status = yum_install($file_name, $indent);      
    }
    
    # otherwise there is either a spec file (taken care of below) or it's in the no_yum_install 
    # so essentially the yum failed and the status is non-zero
    else {
     print "\n+Coundn't yum install: $file_name\n\n";
     $yum_install_status = 1;
    }

    # go ahead and try to build the local spec.in file if 1) yum couldn't install, 2) it wasn't built
    # already, and 3) it's not listed in the no_build file
    if ($yum_install_status != 0 && !$parsed_before{$file} && !defined($no_build->{$file_name})) {

      # prevents recursive loops in the dep tree
      $parsed_before{$file} = 1;

      # FIXME: what is this?
      $req->{"$file"} = 1;

      print "\n+Trying to build from spec: $file_name\n\n";

      # print to dep tree
      print TREE "$indent$file_name\n";

      # vars to hold version string
      my $id_str = "";
      my $version_str = "";

      my $arch_str = $arch_str_universal;
      
      my @deps;
      $file =~ /^(.*).in$/;
      my $spec_file = $1;

      # make the spec file
      my $spec_make_status = system("make $spec_file");
      if ($spec_make_status) { die "RESOLVE_DEPS FATAL ERROR: There was an error making the spec file $spec_file from spec.in file"; }

      # look at the spec file to extract build/install requirements
      open IN, "<$spec_file" or die "RESOLVE_DEPS FATAL ERROR: Can't open file: $spec_file\n";
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

      # at this point all the deps are built/installed
      $file =~ /SPECS\/(\S+).spec.in$/;
      my $package_name = $1;

      # only attempt a build if this is a valid package and it hasn't been built before
      if ($package_name !~ "MODULE_COMPAT" && $package_name !~ " " && !$built_before{$package_name}) {
        print "\n+make SPECS/$package_name.spec SPECS/$package_name.built\n\n";
        $built_before{$package_name} = 1;
	print Dumper(%built_before);
        my $result = system("make SPECS/$package_name.spec SPECS/$package_name.built >& $package_name.log");
	if ($result) { die "RESOLVE_DEPS FATAL ERROR: There was an error building $package_name with error code $result\n"; }

	# at this point the package should be built, if installing go ahead and RPM install it (this program won't work unless install is true)
        if ($install) {

	  # these packages are handled differently (no bp-distro name in RPM name)
	  if ($package_name =~ /biopackages/ || $package_name =~ /macosx-release/ || $package_name =~ /usr-local-bin-perl/) {
	    if (!already_installed("$package_name-$version_str-$id_str")) {
              print("\n+sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$arch_str.rpm\n\n");
              $result = system("sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$arch_str.rpm");
              $complete_package_list->{$package_name} = 1;
	    }
	  # otherwise the RPM is installed like this
	  } else {
	    if (!already_installed("$package_name-$version_str-$id_str.$distro_str")) {
              print ("\n+sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm\n\n");
              $result = system("sudo rpm -Uvh --oldpackage RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm");
              $complete_package_list->{$package_name} = 1;
	    }
	  }
	  # check for RPM install errors
          if ($result) { die "RESOLVE_DEPS FATAL ERROR: There was an error RPM RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm with error code $result\n"; }
	}
      }
    }
  }
}

# try to yum install
sub yum_install {
  my ($file_name, $indent) = @_;

  my $yum_install_status = 0;

  print "\n+Trying to yum install: $file_name\n\n";

  # if yum installing then add to list of missing req FIXME: needed?
  $missing_req->{"$file_name"} = 1;
  
  # printing to dep_tree file with ** to show it's yum installed
  print TREE "$indent** $file_name **\n";
  
  # so there is a dependency that isn't part of the SPEC.in 
  # so it must be either a system dep (e.g. provided by the distro)
  # or it's simply not yet imported into the biopackages repo
  # try to install with yum, it will just fail if it's not available
  
  # check to make sure this hasn't been installed previously
  if (!defined $yum_installed->{$file_name}) {
    # try to yum install
    $yum_install_status = system "sudo yum -y install $file_name >& /tmp/yum_output.txt";
    open YUM, "</tmp/yum_output.txt" or die "RESOLVE_DEPS FATAL ERROR: couldn't open /tmp/yum_output.txt";
    my $output_txt;
    while(<YUM>) {
      chomp;
	$output_txt .= $_;
    }
    close YUM;
    # check to see if the yum install failed, if it did then yum_install_status gets a non-zero value
    # FIXME: I think I need to check for other errors too, such as dependency problems
    if ($output_txt =~ /Cannot find a package matching/) { $yum_install_status = 1; }
    # else install was OK
    else { $complete_package_list->{$file_name} = 1; }
    $yum_installed->{$file_name} = 1;
  }
  # else the package has already been yum installed
  else { print "\n+Previously yum installed\n\n"; }

  return($yum_install_status);
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
  open INPUT, $file or die "RESOLVE_DEPS FATAL ERROR: Can't read file: $file\n";
  while (<INPUT>) {
    chomp;
    next if (/^#/);
    $result->{$_} = 1;
  }
  close INPUT;
  return($result);
}

sub hostname {
  my $hostname = `hostname`;
  chomp($hostname);
  my @tokens = split /\./, $hostname;
  return(\@tokens);
}

sub find_arch {
  my $tokens = hostname();
  return($tokens->[1]);
}

sub find_distro {
  my  $tokens = hostname();
  return($tokens->[0]);
}

