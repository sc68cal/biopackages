#$Id: Makefile,v 1.83 2007/06/12 22:57:39 bpbuild Exp $
LN_S=ln -s
PERL=/usr/bin/perl
RM_RF=rm -rf
RM_I=rm -i
RPMBUILD=/usr/bin/rpmbuild
SYNCHOST=neuron.genomics.ctrl.ucla.edu
RECURSIVE_BUILD=bin/resolve_deps.pl

# test

# FIXME:
# * the cvsupdate target may not actually work (no rsh var set? can't login?)

####################################
#stuff for initial environment setup
prep ::
	$(PERL) bin/rpmmacros.pl > ~/.rpmmacros
	echo 'for d in tmp SETTINGS/{fc2,fc5,centos4}.{i386,x86_64} SOURCES SRPMS BUILD RPMS/i386 RPMS/noarch RPMS/ppc RPMS/ppc64 RPMS/x86_64; do mkdir -p $${d}; done' | /bin/bash
	$(MAKE) sources
	$(MAKE) settings

####################################
#main build targets
# triggers a .spec and .built file for each spec file on each target platform
# also summarizes the build status of each to a log file
# FIXME: add individual targets so you can build all/a package on a certain queue
cluster_buildall ::
#cluster_buildprep: prepares cluster for building
#last statment: makes a cbuilt for every SPEC file which in turn triggers cluster builds on all nodes.
###This submits jobs to cluster. Wait until after all build jobs are done on all nodes and then manually run 'make cluster_postbuild' to generate reports, make yum headers and fix ownership.
	$(MAKE) cluster_buildprep
	echo 'for i in SPECS/*.spec.in; do $(MAKE) $${i/.spec.in/.cbuilt}; done' | /bin/bash 

cluster_buildprep ::
##Prepares the cluster for building -- either for cluster_buildall or make %.cbuilt's
##Various cluster prep steps are given higher priorities to insure execution before build jobs
#buildclean: gets rid of all .cbuilt targets on neuron, so will cleanly build everything even if target SPECs have not changed
#prep/cvs update: locally on neuron
#cluster_buildclean: removes .built and .rbuilt targets on all cluster nodes
#cluster_prep: makes sure all sources directories are set up on cluster nodes
#cluster_cvsupdate: cvs update all cluster nodes
#last statment: makes a cbuilt for every SPEC file which in turn triggers cluster builds on all nodes.
	$(MAKE) buildclean
	$(MAKE) prep
	cvs update
	$(MAKE) cluster_buildclean
	$(MAKE) cluster_prep
	$(MAKE) cluster_cvsupdate

cluster_buildclean ::
	echo 'for i in SETTINGS/{fc2,fc5,centos4}.{i386,x86_64}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\n\n$(MAKE) buildclean\n" > SETTINGS/$$file/SCRIPTS/cluster_buildclean.sh; qsub -cwd -p 5 -o SETTINGS/$$file/LOGS/cluster_buildclean.stdout -e SETTINGS/$$file/LOGS/cluster_buildclean.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_buildclean.sh; done' | /bin/bash

cluster_cvsupdate ::
	echo 'for i in SETTINGS/{fc2,fc5,centos4}.{i386,x86_64}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\nsetenv CVS_RSH ssh\ncvs update\n" > SETTINGS/$$file/SCRIPTS/cluster_cvsupdate.sh; qsub -cwd -p 4 -o SETTINGS/$$file/LOGS/cluster_cvsupdate.stdout -e SETTINGS/$$file/LOGS/cluster_cvsupdate.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_cvsupdate.sh; done' | /bin/bash

cluster_prep ::
	echo 'for i in SETTINGS/{fc2,fc5,centos4}.{i386,x86_64}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\n$(MAKE) prep\n" > SETTINGS/$$file/SCRIPTS/cluster_prep.sh; qsub -cwd -p 3 -o SETTINGS/$$file/LOGS/cluster_prep.stdout -e SETTINGS/$$file/LOGS/cluster_prep.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_prep.sh; done' | /bin/bash

cluster_yumupdate ::
	echo 'for i in SETTINGS/{fc2,fc5,centos4}.{i386,x86_64}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\nsudo yum -y update\n" > SETTINGS/$$file/SCRIPTS/cluster_yumupdate.sh; qsub -cwd -p 2 -o SETTINGS/$$file/LOGS/cluster_yumupdate.stdout -e SETTINGS/$$file/LOGS/cluster_yumupdate.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_yumupdate.sh; done' | /bin/bash

# after a cluster_buildall finishes, 'make cluster_postbuild' to generate reports, migrate packages from testing to stable and make headers/rest of repo (make migrate triggers a make repo).
## FIXME: ultimately should report, migrate, repo. At this time take 'make repo' step out of migrate target 
cluster_postbuild :: report migrate

# creates an HTML output report summarizing the build status of each package based on logs
## FIXME: first line is a temporary fix cause make prep causes too many levels of symlinks
report ::
	rm -Rf /usr/src/biopackages/SETTINGS/*/{SCRIPTS/SCRIPTS,LOGS/LOGS,DEP_TREES/DEP_TREES}
	mkdir -p /biopackages/report
	perl bin/build_report.pl --dir SETTINGS --outdir REPORTS --format html
	cp -Rf REPORTS/green.gif REPORTS/red.gif REPORTS/index.html /biopackages/report
	rsync -rvL --progress /usr/src/biopackages/SETTINGS /biopackages/report/

# migrate all packages from testing into stable and make new headers for all repositories.
migrate :: 
	for i in /biopackages/testing/*/*/*/*.rpm ; do mv -vf $$i $${i/testing/stable} ; done
	$(MAKE) repo

# perform all actions related to generation and cleanliness of yum repository
repo : repo_headers repo_permissions

# creates yum and legacy yum-arch headers for all biopackages branches. Depends on /biopackages/Makefile
## FIXME: Merge /biopackages/Makefile header creation into this Makefile.
repo_headers ::
	make -C /biopackages all

# make root own everything in the repository, except for testing
repo_permissions ::
	sudo chown -Rf bpbuild:bpbuild /biopackages/testing

all :: specs

buildall :: specs
	echo 'for i in SPECS/*.spec; do $(MAKE) $${i/.spec/.built}; done' | /bin/bash

buildclean ::
	$(RM_RF) SPECS/*.built
	$(RM_RF) SPECS/*.cbuilt
	$(RM_RF) SPECS/*.rbuilt

sources ::
	perl -e '(-e "/home/bpbuild/SOURCES.large") ? print "$(MAKE) symlink\n" : print "$(MAKE) rsync\n"' | /bin/bash

settings ::
	perl -e '(-e "/home/bpbuild/SETTINGS") ? print "$(MAKE) symlink_settings\n" : print "$(MAKE) rsync_settings"' | /bin/bash

specs ::
	echo 'for i in SPECS/*.spec.in; do $(MAKE) $${i/.spec.in/.spec}; done' | /bin/bash


####################################
#extension rules
# rbuilt is a target for the local machine that calls the recursive build program (resolve_deps)
# FIXME: probably don't need verbose here
%.rbuilt : %.spec
	echo 'spec=$(subst .spec,,$<); spec=$${spec#SPECS/}; perl $(RECURSIVE_BUILD) --verbose --spec $$spec' | /bin/bash
	touch $@

#
# cbuilt is a qsub script that is called to produce a .spec and .built file on each platform
#
# NOTE: If doing an individual 'make .cbuilt' you should manually do a 'make cluster_cvsupdate' before, because all the automatic cvs updates are done by the 'make cluster_buildall' 
%.cbuilt : %.spec.in
	echo 'for i in SETTINGS/{fc2,fc5,centos4}.{i386,x86_64}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; rm SETTINGS/$$file/LOGS/$$spec.*; echo -e "#!/bin/csh\n\nsetenv CVS_RSH ssh\n$(MAKE) $(subst .spec.in,.rbuilt,$<)\n" > SETTINGS/$$file/SCRIPTS/$$spec.sh; echo "qsub -cwd -o SETTINGS/$$file/LOGS/$$spec.stdout -e SETTINGS/$$file/LOGS/$$spec.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/$$spec.sh"; qsub -cwd -o SETTINGS/$$file/LOGS/$$spec.stdout -e SETTINGS/$$file/LOGS/$$spec.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/$$spec.sh; done' | /bin/bash
	touch $@

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
#symlink/rsync targets to maintain SETTINGS
#this dir structure also has the logs dir
## FIXME: This works somewhat, but makes too many levels of symlinks (i.e. SETINGS/$$dist/LOGS/LOGS/LOGS)... rm -Rf dir/dir before making again
symlink_settings ::
	echo 'for dist in {fc2,fc5,centos4}.{i386,x86_64} ; do for dir in LOGS DEP_TREES SCRIPTS ; do ln -sf /home/bpbuild/SETTINGS/$${dist}/$${dir} SETTINGS/$${dist}/$${dir} ; done ; done' | /bin/bash
#
#FIXME: finish following statment to symlink RPMS and SRPMS to Shared Storage as part of symlink_settings target (JMM)
#       echo 'for n in SRPMS RPMS/{i386,noarch,x86_64} ; do unlink $n ; done' | /bin/bash
#       echo 'if [ "$$(hostname|cut -d . -f 1)" = "fc2" ] ; then ln -s /net/biopackages/testing/fedora/2/SRPMS SRPMS && ln -s /net/biopackages/testing/fedora/2/i386 RPMS/i386 && ln -s /net/biopackages/testing/fedora/2/noarch RPMS/noarch && ln -s /net/biopackages/testing/fedora/2/x86_64 RPMS/x86_64 ; elif [ "$$(hostname|cut -d . -f 1)" = "fc5" ] ; then ln -s /net/biopackages/testing/fedora/5/SRPMS SRPMS && ln -s /net/biopackages/testing/fedora/5/i386 RPMS/i386 && ln -s /net/biopackages/testing/fedora/5/noarch RPMS/noarch && ln -s /net/biopackages/testing/fedora/5/x86_64 RPMS/x86_64 ; elif [ "$$(hostname|cut -d . -f 1)" = "centos4" ] ; then ln -s /net/biopackages/testing/centos/4/SRPMS SRPMS && ln -s /net/biopackages/testing/centos/4/i386 RPMS/i386 && ln -s /net/biopackages/testing/centos/4/noarch RPMS/noarch && ln -s /net/biopackages/testing/centos/4/x86_64 RPMS/x86_64 ; else echo "WARNING: CANNOT RESOLVE YOUR HOSTNAME" && echo "BUILT YOUR RPMS & SRPMS WILL NOT BE WRITTEN TO SHARED STORAGE" ; fi ' | /bin/bash

rsync_settings : rsync_settings_down rsync_settings_up
rsync_settings_down ::
	rsync -avr $(SYNCHOST):/home/bpbuild/SETTINGS/ ./SETTINGS
rsync_settings_up ::
	rsync -avr ./SETTINGS/ $(SYNCHOST):/home/bpbuild/SETTINGS

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
	rsync -av $(SYNCHOST):/home/bpbuild/SOURCES.large/ ./SOURCES.large
	cd SOURCES; ln -s ../SOURCES.large/* .;	cd ..

rsync_down_small ::
	rsync -av $(SYNCHOST):/home/bpbuild/SOURCES.small/ ./SOURCES.small
	cd SOURCES; ln -s ../SOURCES.small/* .; cd ..

rsync_up_large ::
	rsync -av ./SOURCES.large/ $(SYNCHOST):/home/bpbuild/SOURCES.large

rsync_up_small ::
	rsync -av ./SOURCES.small/ $(SYNCHOST):/home/bpbuild/SOURCES.small

