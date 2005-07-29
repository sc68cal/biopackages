#$Id: Makefile,v 1.1 2005/07/29 07:50:33 allenday Exp $
all :: specs

specs ::
	echo 'for i in SPECS/*.spec.in; do $(MAKE) $${i/.spec.in/.spec}; done' | /bin/bash

%.spec : %.spec.in
	echo $<; echo $@;
