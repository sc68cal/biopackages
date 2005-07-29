#$Id: Makefile,v 1.4 2005/07/29 09:03:03 allenday Exp $
PERL=/usr/bin/perl
RPMBUILD=/usr/bin/rpmbuild
#RPMRC=/usr/lib/rpm/rpmrc:/usr/lib/rpm/redhat/rpmrc:./rpmrc
#RPMRC=/usr/lib/rpm/redhat/rpmrc:./rpmrc

####################################
#main build targets
all :: specs

buildall :: specs
	echo 'for i in SPECS/*.spec; do $(MAKE) $${i/.spec/.built}; done' | /bin/bash

buildclean ::
	rm SPECS/*.built

sources ::
	@echo "This target should http or ftp rsync to a FAST repository of a SOURCES/"
	@echo "directory.  Right now this target just prints a message."

specs ::
	echo 'for i in SPECS/*.spec.in; do $(MAKE) $${i/.spec.in/.spec}; done' | /bin/bash

####################################
#extension rules
%.built : %.spec
#	$(RPMBUILD) --rcfile $(RPMRC) -ba $< 2>&1 > $@ || rm $@
	$(RPMBUILD) -ba $< 2>&1 > $@ || rm $@

%.spec : %.spec.in
	cat $< | $(PERL) bin/in2spec.pl > $@

####################################
#stuff for initial environment setup
prep : rpmmacros
	rm -i ~/.rpmmacros
	ln -s ./rpmmacros ~/.rpmmacros

rpmmacros ::
	$(PERL) bin/rpmmacros.pl > ./rpmmacros
