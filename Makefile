#$Id: Makefile,v 1.18 2006/11/14 02:44:21 bpbuild Exp $
LN_S=ln -s
PERL=/usr/bin/perl
RM_RF=rm -rf
RM_I=rm -i
RPMBUILD=/usr/bin/rpmbuild

####################################
#main build targets
all :: specs

buildall :: specs
	echo 'for i in SPECS/*.spec; do $(MAKE) $${i/.spec/.built}; done' | /bin/bash

buildclean ::
	$(RM_RF) SPECS/*.built

sources ::
	perl -e 'print $$ENV{HOSTNAME}=~ /ucla.edu$$/ ? "make symlink\n" : "make rsync\n"'  | /bin/bash

sources-local ::
	ln -s /home/bpbuild/SOURCES.{small,large}/* /usr/src/biopackages/SOURCES/

specs ::
	echo 'for i in SPECS/*.spec.in; do $(MAKE) $${i/.spec.in/.spec}; done' | /bin/bash

####################################
#extension rules
%.built : %.spec
	perl -e '($$f,$$e,$$d,$$c,$$b,$$a)=localtime();print "#rpmbuild begin ".join(":",$$a+1900,$$b,$$c,$$d,$$e,$$f),"\n"' > $@
	($(RPMBUILD) -ba $< 2>&1 >> $@ && \
	perl -e '($$f,$$e,$$d,$$c,$$b,$$a)=localtime();print "#rpmbuild end ".join(":",$$a+1900,$$b,$$c,$$d,$$e,$$f),"\n"' >> $@) || $(RM_RF) $@

%.clean :
	find . -name "$(@:.clean=)*" -exec $(RM_RF) {} \;

%.pm :
	# bail out if locked, or if special and needs manual build
	`echo 'if [ -f $(@:.pm=.pmlock) ]; then exit 1 ; else exit 0 ; fi' | /bin/bash`;
	`echo 'if [ -f SPECS/$(@:.pm=.spec) ]; then exit 1 ; else exit 0 ; fi' | /bin/bash`;

	# lock
	touch $(@:.made=.lock);
	$(PERL) bin/pmfetch.pl $@ 2>$(@:.pm=.pmlog);

	#this could be brittle on make -jN where N > 1
	$(PERL) bin/pmbuild.pl SPECS/`ls -rt1 SPECS/ | tail -1` $(@:.pm=);

	# cleanup and unlock
	$(RM) *debuginfo*;
	$(RM) $(@:.pm=.pmlock);

	#check dependencies and recurse
	/bin/bash bin/pmcheckdeps.sh `ls -rt1 SPECS/ | tail -1` $(TARGETARCH);

	#mark it done
	touch $@;

%.spec : %.spec.in
	cat $< | $(PERL) bin/in2spec.pl > $@

####################################
#symlink/rsync targets to maintain SOURCES/
symlink : symlink_clean symlink_small symlink_large
symlink_clean : sync_clean

symlink_large ::
	ln -s ~bpbuild/SOURCES.large/* ./SOURCES/

symlink_small ::
	ln -s ~bpbuild/SOURCES.small/* ./SOURCES/

rsync :		sync_clean rsync_down rsync_up
rsync_down :	sync_clean rsync_down_small rsync_down_large
rsync_up :	sync_clean rsync_up_small rsync_up_large
rsync_small :	sync_clean rsync_down_small rsync_up_small
rsync_large :	sync_clean rsync_down_large rsync_up_large

sync_clean ::
	@if [[ `find SOURCES/ -type f | grep -vw CVS | wc -l` > 0 ]]; then echo "Move your files from SOURCES/ to one of ~bpbuild/SOURCES.{large,small}"; exit 1; fi
	@find SOURCES/ -type l | grep -vw SOURCES/ | grep -vw SOURCES/CVS | xargs rm -rf
	@find SOURCES/ -type d | grep -vw SOURCES/ | grep -vw SOURCES/CVS | xargs rm -rf

rsync_down_large ::
	rsync -av neuron.genomics.ctrl.ucla.edu:/home/bpbuild/SOURCES.large/ ./SOURCES.large
	cd SOURCES
	ln -s ../SOURCES.large/* .
	cd ..

rsync_down_small ::
	rsync -av neuron.genomics.ctrl.ucla.edu:/home/bpbuild/SOURCES.small/ ./SOURCES.small
	cd SOURCES
	ln -s ../SOURCES.small/* .
	cd ..

rsync_up_large ::
	rsync -av ./SOURCES.large/ neuron.genomics.ctrl.ucla.edu:/home/bpbuild/SOURCES.large

rsync_up_small ::
	rsync -av ./SOURCES.small/ neuron.genomics.ctrl.ucla.edu:/home/bpbuild/SOURCES.small

####################################
#stuff for initial environment setup
prep ::
	echo '' >> ~/.rpmmacros
	$(RM_I) ~/.rpmmacros
	$(PERL) bin/rpmmacros.pl > ~/.rpmmacros
	echo 'for d in SRPMS BUILD RPMS/i386 RPMS/noarch RPMS/ppc RPMS/ppc64 RPMS/x86_64; do mkdir -p $${d}; done' | /bin/bash

