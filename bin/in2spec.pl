#!/usr/bin/perl
#$Id: in2spec.pl,v 1.1 2005/07/29 07:57:13 allenday Exp $
use strict;

my $revision = undef;
while(<>){
  if ( /#\$Id: in2spec.pl,v 1.1 2005/07/29 07:57:13 allenday Exp $/ ) {
    $revision = $1;
    next;
  }
  s/%{revision}/$revision/;
  print;
}
