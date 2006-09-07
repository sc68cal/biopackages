#!/usr/bin/perl
#$Id: pmfetch.pl,v 1.2 2006/09/07 17:02:39 boconnor Exp $
use strict;
use CPANPLUS::Backend;
use File::Copy;
use File::Spec::Functions;
use Data::Dumper;

my $template = join '', <DATA>;
close(DATA);

my $tag = ''; #biopackages.

my $token = {
  'ARCH'         => $ENV{MACHTYPE} || 'noarch', #
  'NOW'          => scalar(localtime()),        #
  'EMAIL'        => $ENV{USER}.'@'.$ENV{HOSTNAME},  #
  'DISTRIBUTION' => 'Custom',                   #
  'VENDOR'       => 'biopackages.net',          #
  'LICENSE'      => 'GPL or Artistic',          #
  'SUMMARY'      => '',                         #
  'NAME'         => '',                         #
  'VERSION'      => '',                         #
  'REQUIRES'     => '',                         #
  'SOURCE'       => '',                         
  'DESCRIPTION'  => '',                         #
};

$token->{NOW} =~ s/\s\S+:\S+//; #specfile doesn't like time of day in Changelog

my %blacklib = map {$_=>1} qw(dl m z);

my $cb = CPANPLUS::Backend->new();

my ($namespace) = @ARGV or die "Usage: $0 perl-Some-Module.made";
$namespace =~ s/\.made$//;

#my $tmpdir = catfile( ($ENV{TMPDIR} || '/tmp'), $namespace );
#if( -d $tmpdir){
#  system("rm -rf $tmpdir");
#}
#mkdir($tmpdir) or die "couldn't mkdir $tmpdir: $!";

$namespace =~ s/^perl-//;
$namespace =~ s/-/::/g;

my $retry = 0;
my $source = undef;
while ( $retry < 10 ) {
  my $rv = $cb->fetch(modules => [$namespace]);
  ($source) = values( %{ $rv->rv() } );

  if($source){
    $source =~ m!\-([^\-]+?)\.(t(ar\.)gz|zip)$!;
    $token->{VERSION} = $1 || 'Unknown';

    my @dirs = File::Spec->splitdir( $source );
    $token->{SOURCE} = $dirs[-1];

    $source =~ m!^.+/(.+?)-\d!;
    $token->{NAME} = $1;

    $rv = $cb->extract(modules => [$namespace]);

    #Summary and Requires from Makefile.PL
    my($extract) = values( %{ $rv->rv() } );

    my $abstract = 'Unknown';

    open( M, catfile($extract,'Makefile.PL') ) or die "no Makefile for $namespace: $!";
    my $makefile = join '', <M>;
    close( M );
    if ( $makefile =~ /ABSTRACT(_FROM)?['"]?\s*?(=>|,)\s*?(['"])(.+?)\3/ ) {
      if ( $1 ) {
        open( P, catfile($extract,$4) );
        my $pod = join '', <P>;
        close( P );
        if ( $pod =~ /=head1 NAME\s+$namespace\s-\s(.+?)\n/s ) {
          $abstract = $1;
        }
      }
      else {
        $abstract = $4;
      }
    }
    if ( $makefile =~ /LIBS['"]?\s*?(=>|,)\s*?\[(.+?)\]/ ) {
      $token->{REQUIRES} = 'Requires: ';
      my $raw = $2;
      while( $raw =~ /\G.*?-l(\w+).*?/g ){
        next if $blacklib{$1};
        $token->{REQUIRES} .= $1 .', ';
      }
      $token->{REQUIRES} =~ s/, $//;
    }    

    $token->{SUMMARY} = $abstract;

    #Summary for Build.PL
    ###FIXME

    #Requires

    $rv = $cb->readme(modules => [$namespace]);

    ($token->{DESCRIPTION}) = values( %{ $rv->rv() } );

    last;
  }

  print STDERR "retry $retry to fetch $namespace\n";
  $retry++;
  sleep(2);
}
exit 1 unless $source;

#move($source, $tmpdir);
move($source, './SOURCES/');

$token->{REQUIRES} = '' if $token->{REQUIRES} =~ /^Requires:\s+$/;

foreach my $t ( keys %$token ) {
  $template =~ s/\@\@$t\@\@/$token->{$t}/gs;
}

open(SPEC,'>SPECS/perl-'.$token->{NAME}.'.spec.in');
print SPEC $template;
close(SPEC);


__DATA__
#$Id: pmfetch.pl,v 1.2 2006/09/07 17:02:39 boconnor Exp $
Distribution: @@DISTRIBUTION@@
Vendor: @@VENDOR@@
Summary: @@SUMMARY@@
Name: perl-@@NAME@@
Version: @@VERSION@@
Release: %{revision}.%{distro}
Packager: @@EMAIL@@
License: @@LICENSE@@
Group: Development/Libraries
URL: http://search.cpan.org/dist/@@NAME@@/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildRequires: perl, biopackages
@@REQUIRES@@
Source0: @@SOURCE@@

%description
@@DESCRIPTION@@

%prep
%setup -q -n @@NAME@@-%{version}

%build
CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL PREFIX=$RPM_BUILD_ROOT%{_prefix}  < /dev/null
make OPTIMIZE="$RPM_OPT_FLAGS"

%install
rm -rf $RPM_BUILD_ROOT

eval `perl '-V:installarchlib'`
mkdir -p $RPM_BUILD_ROOT$installarchlib
%makeinstall

find $RPM_BUILD_ROOT -type f -a \( -name perllocal.pod -o -name .packlist \
  -o \( -name '*.bs' -a -empty \) \) -exec rm -f {} ';'
find $RPM_BUILD_ROOT -type d -depth -exec rmdir {} 2>/dev/null ';'
chmod -R u+w $RPM_BUILD_ROOT/*

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT -type f \
| sed "s@^$RPM_BUILD_ROOT@@g" \
> %{name}-%{version}-%{release}-filelist

eval `perl -V:archname -V:installsitelib -V:installvendorlib -V:installprivlib`
for d in $installsitelib $installvendorlib $installprivlib; do
  [ -z "$d" -o "$d" = "UNKNOWN" -o ! -d "$RPM_BUILD_ROOT$d" ] && continue
  find $RPM_BUILD_ROOT$d/* -type d \
  | grep -v "/$archname\(/auto\)\?$" \
  | sed "s@^$RPM_BUILD_ROOT@%dir @g" \
  >> %{name}-%{version}-%{release}-filelist
done

if [ "$(cat %{name}-%{version}-%{release}-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit 1
fi

%clean
rm -rf $RPM_BUILD_ROOT

%files -f %{name}-%{version}-%{release}-filelist
%defattr(-,root,root,-)

$Log: pmfetch.pl,v $
Revision 1.2  2006/09/07 17:02:39  boconnor
Updates to pm spec file generators


