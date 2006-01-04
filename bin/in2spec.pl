#!/usr/bin/perl
#$Id: in2spec.pl,v 1.3 2006/01/04 22:12:19 allenday Exp $
use strict;
use Date::Manip;
use Text::Wrap;
$Text::Wrap::columns = 72;

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

my $rcstag = '#\$'.'Id:';
my $logtag = '\$Log: in2spec.pl,v $
my $logtag = '\Revision 1.3  2006/01/04 22:12:19  allenday
my $logtag = '\transform cvs log to rpm changelog
my $logtag = '\';
my $revision = undef;

my $spec = join '', <>;

my ( $revision ) = $spec =~ /^$rcstag.+?,v (\S+)/s;
my ( $version )  = $spec =~ /\nVersion: (\S+)\n/s;

$spec =~ s/%{revision}/$revision/gs;

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

