#!/usr/bin/perl
use strict;
use Data::Dumper;
use Getopt::Long;
use constant USAGE => <<"UUU";

USAGE:

$0 --dir <SETTINGS dir with <distro>.<release>/LOGS/*.stderr> --outdir <output directory> --format <"html" or "text"> --help <shows this help>

This simple script just looks at the output from the biopackages cluster build
process and determines which packages have failed building. It creates a text
or html report summarizing this.

UUU


# GLOBALS
my ($dir, $outdir, $format, $help);

my $data = {};

my $arg_count = scalar(@ARGV);

GetOptions ("dir=s"       => \$dir,
            "outdir=s"    => \$outdir,
            "format=s"    => \$format,
            "help"        => \$help,
            );

# USAGE
if ($help or $arg_count == 0) { print USAGE; exit(1); }

my @distros = glob("$dir/*");

foreach my $distro (@distros) {
  $distro =~ /^.*\/([^\/]+)$/;
  my $distro_name = $1;
  my @log_files = glob("$distro/LOGS/*.stderr");
  foreach my $log (@log_files) {
    $log =~ /^.*\/([^\/]+).stderr/;
    my $package = $1;
    #print "Pack: $package $distro_name\n"; die;
    my $errors = 0;
    open LOG, "<$log" or die;
    while(<LOG>) {
      chomp;
      if ($_ =~ /RESOLVE_DEPS FATAL ERROR/) { $errors = 1; }
    }
    close LOG;
    if ($errors) {
      $data->{$package}{$distro_name} = "<img src='red.gif' height='25' width='25'>";
    } else {
      $data->{$package}{$distro_name} = "<img src='green.gif' height='25' width='25'>";
    }
  }
}

# now print this all out

#print Dumper $data;

if ($format eq 'html') {
print <<"UUU";
<html>
<table border="1">
UUU

  my $first = 1;
  foreach my $package (keys %{$data}) {
    if ($first) {
      print "<tr><td> </td><td>";
      print join "</td><td>", sort keys %{$data->{$package}};
      print "</td></tr>\n";
      $first = 0;
    }
    print "<tr><td>";
    print "$package</td><td>";
    print join "</td><td>", map { $data->{$package}{$_} } sort keys %{$data->{$package}};
    print "</td></tr>\n";
  }

print <<"UUU";
</table>
</html>
UUU

} else {
  my $first = 1;
  foreach my $package (keys %{$data}) {
    if ($first) {
      print "\t";
      print join "\t", sort keys %{$data->{$package}};
      print "\n";
      $first = 0;
    }
    print "$package\t";
    print join "\t", map { $data->{$package}{$_} } sort keys %{$data->{$package}};
    print "\n";
  }
}
