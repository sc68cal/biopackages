#!/usr/bin/perl
#$Id: in2spec.pl,v 1.2 2005/07/29 08:08:59 allenday Exp $
use strict;

my $rcstag = '#\$'.'Id:';
my $revision = undef;
while(<>){
  if ( /^$rcstag.+?,v (\S+)/ ) {
    $revision = $1;
    next;
  }
  s/%{revision}/$revision/;
  print;
}
