#$Id: Makefile,v 1.2 2005/07/29 07:57:13 allenday Exp $
PERL=/usr/bin/perl

all :: specs

specs ::
	echo 'for i in SPECS/*.spec.in; do $(MAKE) $${i/.spec.in/.spec}; done' | /bin/bash

%.spec : %.spec.in
	cat $< | $(PERL) bin/in2spec.pl > $@
