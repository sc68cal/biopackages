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
structure. If you are building an individual package you want to provide values
for all of these.

--arch (defaults to system arch or noarch depending on the package being built)
--no-build (defaults to /usr/src/biopackages/SETTINGS/<distro>.<arch>/no_build.txt)
--no-yum (defaults to /usr/src/biopackages/SETTINGS/<distro>.<arch>/yum_no_install.txt)
--remove-rpms (defaults to true, RPMs are removed from the system)
--rpm-base (defaults to /usr/src/biopackages/SETTINGS/<distro>.<arch>/clean_rpm_list.txt)

UUU


# GLOBALS
my ($arch_str_universal, $spec_file, $no_build_file, $no_deps_file, $no_yum_install_file, $remove_installed_rpms, $base_rpm_list, $dep_tree_file, $help, $verbose);

my $arg_count = scalar(@ARGV);

GetOptions ("arch=s"      => \$arch_str_universal,
            "spec=s"      => \$spec_file,
            "no-build=s"  => \$no_build_file,
            "no-deps=s"   => \$no_deps_file,
            "no-yum=s"    => \$no_yum_install_file,
            "remove-rpms" => \$remove_installed_rpms,
            "rpm-base"    => \$base_rpm_list,
            "dep-tree=s"  => \$dep_tree_file,
            "help"        => \$help,
            "verbose"     => \$verbose,
            );

# USAGE
if ($help or $arg_count == 0) { print USAGE; exit(1); }


# DEFAULT VALUES
# If resolve_deps is being called from the biopackages cluster build process then several
# options need to be filled in
my $distro = find_distro();
$arch_str_universal = find_arch() if (!defined($arch_str_universal));
$no_build_file = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/no_build.txt" if (!defined($no_build_file));
$no_deps_file = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/no_deps.txt" if (!defined($no_deps_file));
$no_yum_install_file = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/yum_no_install.txt" if (!defined($no_yum_install_file));
$remove_installed_rpms = 1 if (!defined($remove_installed_rpms));
$base_rpm_list = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/clean_rpm_list.txt" if (!defined($base_rpm_list));
$dep_tree_file = "/usr/src/biopackages/SETTINGS/$distro.$arch_str_universal/DEP_TREES/$spec_file.deptree" if (!defined($dep_tree_file));

# blacklist: packages that should never be built (because they are not real packages
my $blacklist = {
  'WITH_ITHREADS'   => 1,
  'WITH_THREADS'    => 1,
  'WITH_LARGEFILES' => 1,
  'MODULE_COMPAT'   => 1,
  ' '               => 1,
};

# TRACKING STRUCTURES

# a hash to store the names of everything that was either yum installed or build and rpm installed
my $complete_package_list = {};

# Hashes to store dependency tree
my $req = {};
my $missing_req = {};

# keep track of what has been yum installed
my $yum_installed = {};

# keep a list of what not to yum install
my $no_yum_install = read_no_build($no_yum_install_file);

# a list of packages that have circular deps and need to be forced if RPM installed
my $no_deps_install = read_no_build($no_deps_file);

# A list of modules not to build
my $no_build = read_no_build($no_build_file);

# Hashes to store which packages have been previously built
my %built_before;
my %parsed_before;

# Should this program install build requirements?
my $install = 0;

# A file for the dependency tree summary
open TREE, ">$dep_tree_file" or die "RESOLVE_DEPS FATAL ERROR: $!";

# distro string
my $distro_str;
open IN, "/usr/bin/bp-distro | " or die;
while (<IN>) { chomp; $distro_str = $_; last; }
close IN;


# THE PROGRAM STARTS HERE

# fail if on the no_build list
if (defined $no_build->{$spec_file}) { print STDERR "RESOLVE_DEPS FATAL ERROR: this package $spec_file is on the no_build list\n"; }

# The actual process 
parse_req($spec_file, $req, $missing_req, "", $install);

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
# I am only removing what was built. An alternative is to remove everything
# that was yum installed too however this could result in core rpms being removed
# i.e. perl.
# FIXME: explore the possibility of removing only RPMs not already installed on the system
if($remove_installed_rpms) {
  my $base_rpms = read_no_build($base_rpm_list);
  my $rpms_now = get_new_rpms($base_rpms);
  my $command = "sudo rpm -e ".join(" ", keys(%{$rpms_now}));
  print "$command\n";
  system($command);
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
  my ($file_name, $req, $missing_req, $indent, $install_deps) = @_;

  print "+Calling parse_req on $file_name.\n";

  # there is a blacklist of "packages" that are not really packages that should just be skipped
  my $continue = 1;
  foreach my $key (keys %{$blacklist}) {
    if ($file_name =~ /$key/i) { $continue = 0; print "+Bogus package request, ignoring: $file_name\n"; }
  }

  if ($continue) {

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
  
      # yum install if there is no spec.in file or it is not in the no_yum_install list
      if (!defined($no_yum_install->{$file_name})) {
        $yum_install_status = yum_install($file_name, $indent);      
      }
      
      # otherwise there is either a spec file (taken care of below) or it is in the no_yum_install 
      # so essentially the yum failed and the status is non-zero
      else {
       print "\n+Cound not yum install: $file_name\n\n";
       $yum_install_status = 1;
      }
  
      # go ahead and try to build the local spec.in file if 1) yum could not install, 2) it was not built
      # already, and 3) it is not listed in the no_build file
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
        print STDERR "make $spec_file\n";
        my $spec_make_status = system("make $spec_file");
        if ($spec_make_status) { die "RESOLVE_DEPS FATAL ERROR: There was an error making the spec file $spec_file from spec.in file"; }
  
        # look at the spec file to extract build/install requirements
        open IN, "<$spec_file" or die "RESOLVE_DEPS FATAL ERROR: Cannot open file: $spec_file\n";
        while (<IN>) {
          chomp;
          if ($_ =~ /BuildRequires:\s+(.*)$/) {
            my @tokens = split ", ", $1;
  	  foreach my $token (@tokens) {
  	    $token = clean_package_names($token);
              # there are some crufty entries with %{} in the spec files
  	    push @deps, $token if ($token !~ /%/); 
  	  }
  	}
          elsif ($_ =~ /Requires:\s+(.*)$/) {
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
          parse_req($dep, $req, $missing_req, "\t$indent", 1);
        }
  
        # at this point all the deps are built/installed
        $file =~ /SPECS\/(\S+).spec.in$/;
        my $package_name = $1;
  
        # only attempt a build if this is a valid package and it has not been built before
        if (!defined($blacklist->{$package_name}) && !$built_before{$package_name}) {
          print "\n+make SPECS/$package_name.spec SPECS/$package_name.built\n\n";
          $built_before{$package_name} = 1;
          my $result;
          if ($verbose) { $result = system("make SPECS/$package_name.spec SPECS/$package_name.built"); }
          else { $result = system("make SPECS/$package_name.spec SPECS/$package_name.built >& $package_name.log"); }
  	if ($result != 0 && $result != 512) { die "RESOLVE_DEPS FATAL ERROR: There was an error building $package_name with error code $result\n"; }
  
  	# at this point the package should be built, if installing go ahead and RPM install it (this program will not work unless install is true)
          if ($install_deps) {
  
          #nodeps, a small number of packages need force installs because of circular deps
          my $nodeps_string = "";
          if (defined($no_deps_install->{$package_name})) { $nodeps_string = "--nodeps"; }

  	  # these packages are handled differently (no bp-distro name in RPM name)
  	  if ($package_name =~ /biopackages/ || $package_name =~ /macosx-release/ || $package_name =~ /usr-local-bin-perl/) {
  	    if (!already_installed("$package_name-$version_str-$id_str")) {
                # now check to see if the RPM is there, if not then this build failed!!
                die "RESOLVE_DEPS FATAL ERROR: RPM file RPMS/$arch_str/$package_name-$version_str-$id_str.$arch_str.rpm is not there!!" if (!file_exists("RPMS/$arch_str/$package_name*-$version_str-$id_str.$arch_str.rpm"));
                print("\n+sudo rpm -Uvh $nodeps_string --oldpackage RPMS/$arch_str/$package_name*-$version_str-$id_str.$arch_str.rpm\n\n");
                $result = system("sudo rpm -Uvh $nodeps_string --oldpackage RPMS/$arch_str/$package_name*-$version_str-$id_str.$arch_str.rpm");
                $complete_package_list->{$package_name} = 1;
  	    }
  
  	  # otherwise the RPM is installed like this
  	  } else {
  	    if (!already_installed("$package_name-$version_str-$id_str.$distro_str")) {
                # now check to see if the RPM is there, if not then this build failed!!
                die "RESOLVE_DEPS FATAL ERROR: RPM file RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm is not there!!" if (!file_exists("RPMS/$arch_str/$package_name*-$version_str-$id_str.$distro_str.$arch_str.rpm"));
                print ("\n+sudo rpm -Uvh $nodeps_string --oldpackage RPMS/$arch_str/$package_name*-$version_str-$id_str.$distro_str.$arch_str.rpm\n\n");
                $result = system("sudo rpm -Uvh $nodeps_string --oldpackage RPMS/$arch_str/$package_name*-$version_str-$id_str.$distro_str.$arch_str.rpm");
                $complete_package_list->{$package_name} = 1;
  	    }
  	  }
  
  	  # check for RPM install errors
            if ($result != 0 && $result != 512) { die "RESOLVE_DEPS FATAL ERROR: There was an error RPM RPMS/$arch_str/$package_name-$version_str-$id_str.$distro_str.$arch_str.rpm with error code $result\n"; }
  	}
        }
      }
    }
  }
}

# checks if an RPM is there
sub file_exists {
  my ($file_glob) = @_;
  my @files = glob($file_glob);
  return(scalar(@files) > 0);
}

# try to yum install
sub yum_install {
  my ($file_name, $indent) = @_;

  my $yum_install_status = 0;

  print "\n+Trying to yum install: $file_name\n\n";

  # if yum installing then add to list of missing req FIXME: needed?
  $missing_req->{"$file_name"} = 1;
  
  # printing to dep_tree file with ** to show it is yum installed
  print TREE "$indent** $file_name **\n";
  
  # so there is a dependency that is not part of the SPEC.in 
  # so it must be either a system dep (e.g. provided by the distro)
  # or it is simply not yet imported into the biopackages repo
  # try to install with yum, it will just fail if it is not available
  
  # check to make sure this has not been installed previously
  if (!defined $yum_installed->{$file_name}) {
    # try to yum install
    $yum_install_status = system "sudo yum -y install $file_name >& /tmp/yum_output.txt";
    open YUM, "</tmp/yum_output.txt" or die "RESOLVE_DEPS FATAL ERROR: could not open /tmp/yum_output.txt";
    my $output_txt;
    while(<YUM>) {
      chomp;
	$output_txt .= $_;
    }
    close YUM;
    # check to see if the yum install failed, if it did then yum_install_status gets a non-zero value
    # FIXME: I think I need to check for other errors too, such as dependency problems
    if ($output_txt =~ /Cannot find a package matching/ || $output_txt =~ /No Match for argument/) { $yum_install_status = 1; }
    # else install was OK
    else {
      $complete_package_list->{$file_name} = 1; 
      # if this condition is true then the package being build was yum
      # installed, so log a message that the build report program can trap
      if ($file_name eq $spec_file) {
        print STDERR "RESOLVE_DEPS PACKAGE YUM INSTALLED\n";
      }
    }
    $yum_installed->{$file_name} = 1;
  }
  # else the package has already been yum installed
  else { print "\n+Previously yum installed\n\n"; }

  return($yum_install_status);
}

# check to see if the package is already installed
sub already_installed {
  my ($package_name) = @_;
  my @query_result;
  open IN, "rpm -qa | grep $package_name | " or die;
  while(<IN>) {
    chomp;
    push @query_result, $_;
  }
  close IN;
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

sub get_new_rpms {
  my ($base_rpms) = @_;
  system("rpm -qa > /tmp/rpm_list.txt");
  my $current_rpms = read_no_build("/tmp/rpm_list.txt");
  my $new_rpms = {};
  foreach my $rpm (keys %{$current_rpms}) {
    if (!defined($base_rpms->{$rpm})) { $new_rpms->{$rpm} = 1; }
  }
  return($new_rpms);
}

sub read_no_build {
  my ($file) = @_;
  my $result = {};
  open INPUT, $file or die "RESOLVE_DEPS FATAL ERROR: Cannot read file: $file\n";
  while (<INPUT>) {
    chomp;
    next if (/^#/);
    $result->{$_} = 1;
  }
  close INPUT;
  return($result);
}

sub hostname {
  my $hostname;
  open IN, "hostname | " or die;
  while (<IN>) { chomp; $hostname = $_; last; }
  close IN;
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

