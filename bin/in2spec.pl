#!/usr/bin/perl
#$Id: in2spec.pl,v 1.12 2008/07/30 18:15:48 bret_harry Exp $
use strict;
use Text::Wrap;
use Date::Manip;

$Text::Wrap::columns = 72;

# figure out what distro we have
my @results = `rpm -qa | grep 'release' | grep -v rpmforge | grep -v notes`;
chomp $results[0];

my ($distro, $distro_release);

$results[0] =~ /^([^-]+)-release-([^-]+)/;
$distro = $1;
$distro_release = $2;

print STDERR "$0: distro: $distro release: $distro_release\n";

my %day   = (
             1 => 'Mon',
             2 => 'Tue',
             3 => 'Wed',
             4 => 'Thu',
             5 => 'Fri',
             6 => 'Sat',
             7 => 'Sun',
             
            );
my %month = (
             1 => 'Jan',
             2 => 'Feb', 
             3 => 'Mar', 
             4 => 'Apr', 
             5 => 'May', 
             6 => 'Jun', 
             7 => 'Jul', 
             8 => 'Aug', 
             9 => 'Sep', 
            10 => 'Oct', 
            11 => 'Nov', 
            12 => 'Dec', 
           );

my $i_tab = '- ';
my $s_tab = '  ';

my $rcstag = '#\$'.'[Ii]d:';
my $logtag = '\$'.'Log: .+? \$';
my $revision = undef;

my $spec = join '', <>;

my ( $revision ) = $spec =~ /^$rcstag.+?,v (\S+)/s;
my ( $version )  = $spec =~ /\nVersion:\s+(\S+)\n/s;

$spec =~ s/%{revision}/$revision/gs;

print STDERR "$0: revision: $revision\n";

#check distro, if matches then include this line otherwise don't
$spec =~ s/%{ifdistro $distro} ?(.*)/$1/g;
$spec =~ s/%{ifdistro \w+}(.*)//g;

#check distro and release, if matches then include line otherwise don't
$spec =~ s/%{ifdistro_release $distro $distro_release} ?(.*)/$1/g;
$spec =~ s/%{ifdistro_release \w+ \d+}(.*)//g;

$spec =~ s/$logtag(.+)$//s;
my $cvslog = $1;
my @revisions = split /\nRevision\s+/, $cvslog;
shift @revisions;

print $spec;

print "\%changelog\n";
foreach my $revision ( @revisions ) {
  my ( $v, $y, $m, $d, $u, $c ) = $revision =~ m/^([\d\.]+)\s+(\d+)\/(\d+)\/(\d+)\s+[\d:]+\s+(\S+)\n(.+)$/s;
  print sprintf("* %s %s %02d %04d %s %s %s-%s\n",
    $day{int(Date_DayOfWeek($m,$d,$y))},
    $month{int($m)},
    $d,
    $y,
    $u,
    $u,
    $version,
    $v
  );
  print wrap($i_tab, $s_tab, $c);
};



__DATA__

%changelog
* Tue Jul 19 2005 Allen Day <allenday@ucla.edu> 2-1
- New specfile

$Log: in2spec.pl,v $
Revision 1.12  2008/07/30 18:15:48  bret_harry
changed revision regex to handle Id and id

Revision 1.11  2008/07/15 22:42:52  bret_harry
allow a space in ifdistro regex

Revision 1.10  2008/07/03 19:08:42  bret_harry
fixed distro detection for centos 5

Revision 1.9  2008/07/02 23:06:49  bret_harry
Thought I was clever -- I was wrong.

Revision 1.8  2008/07/02 22:51:46  bret_harry
removed Date::Manip dep

Revision 1.7  2007/09/25 21:02:41  bpbuild
greping for release was finding rpmforge, so instead grep for release and exclude rpmforge

Revision 1.6  2006/09/13 06:00:06  boconnor
Added ifdistro and ifdistro_release tags to the pre-processor. Currently it just supports one line but it would be nice if this could be a multi-line enclosed by a fi

Revision 1.5  2006/08/25 01:15:38  jmendler
fixed whitespace bug

Revision 1.4  2006/01/04 22:16:09  allenday
transform cvs log to rpm changelog

Revision 1.3  2006/01/04 22:12:19  allenday
transform cvs log to rpm changelog

Revision 1.3  2006/01/04 21:35:04  allenday
make sure celsniff is installed

Revision 1.2  2006/01/04 21:33:52  allenday
add cellsniff util.  testing syncing of cvs log with rpm changelog


               use Text::Wrap

               $initial_tab = "\t";    # Tab before first line
               $subsequent_tab = "";   # All other lines flush left

               print wrap($initial_tab, $subsequent_tab, @text);
               print fill($initial_tab, $subsequent_tab, @text);

               @lines = wrap($initial_tab, $subsequent_tab, @text);

               @paragraphs = fill($initial_tab, $subsequent_tab, @text);

