#!/usr/bin/perl
#$Id: rpmmacros.pl,v 1.2 2005/07/29 09:24:15 allenday Exp $
use strict;

print "%_topdir\t$ENV{PWD}\n";
print "%_tmppath\t$ENV{PWD}/tmp\n";
