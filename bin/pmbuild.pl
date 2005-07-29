#!/usr/bin/perl
#$Id: pmbuild.pl,v 1.1 2005/07/29 09:24:15 allenday Exp $
use strict;

my($spec, $base) = @ARGV;
print(  "rpmbuild -ba $spec 2>&1 >> $base.$arch.pmlog\n" );
system( "rpmbuild -ba $spec 2>&1 >> $base.$arch.pmlog" ) && exit(1);
exit(0);
