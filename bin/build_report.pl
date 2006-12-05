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
      if ($_ =~ /RESOLVE_DEPS PACKAGE YUM INSTALLED/) { $errors = -1; }
    }
    close LOG;
    if ($errors == 1) {
      $data->{$package}{$distro_name} = "<img src='red.gif' height='25' width='25'>";
    } elsif ($errors == 0) {
      $data->{$package}{$distro_name} = "<img src='green.gif' height='25' width='25'>";
    } elsif ($errors == -1) {
      $data->{$package}{$distro_name} = "yum";
    }
  }
}

# now print this all out

#print Dumper $data;

if ($format eq 'html') { open OUT, ">$outdir/index.html" or die "Can't open output file: $outdir/index.html"; }
else { open OUT, ">$outdir/report.txt" or die "Can't open output file: $outdir/report.txt"; }

if ($format eq 'html') {
print OUT <<"UUU";
<html>
<table border="1">
UUU

foreach my $distro (@distros) {
  $distro =~ /^.*\/([^\/]+)$/;
  my $distro_name = $1;
  print OUT "<tr><td><b>$distro_name</b></td>";
  print OUT "<td><a href='SETTINGS/$distro_name/no_build.txt'>no_build.txt</a></td>";
  print OUT "<td><a href='SETTINGS/$distro_name/no_deps.txt'>no_deps.txt</a></td>";
  print OUT "<td><a href='SETTINGS/$distro_name/yum_no_install.txt'>yum_no_install.txt</a></td>";
  print OUT "<td><a href='SETTINGS/$distro_name/clean_rpm_list.txt'>clean_rpm_list.txt</a></td></tr>";
}

print OUT <<"UUU";
</table>
<table border="1">
UUU

  my $first = 1;
  foreach my $package (keys %{$data}) {
    if ($first) {
      print OUT "<tr><td> </td><td>";
      print OUT join "</td><td>", sort keys %{$data->{$package}};
      print OUT "</td></tr>\n";
      $first = 0;
    }
    print OUT "<tr><td>";
    print OUT "$package</td><td>";
    print OUT join "</td><td>", map { $data->{$package}{$_} } sort keys %{$data->{$package}};
    print OUT "</td></tr>\n";
  }

print OUT <<"UUU";
</table>
</html>
UUU

} else {
  my $first = 1;
  foreach my $package (keys %{$data}) {
    if ($first) {
      print OUT "\t";
      print OUT join "\t", sort keys %{$data->{$package}};
      print OUT "\n";
      $first = 0;
    }
    print OUT "$package\t";
    print OUT join "\t", map { $data->{$package}{$_} } sort keys %{$data->{$package}};
    print OUT "\n";
  }
}

close OUT;

