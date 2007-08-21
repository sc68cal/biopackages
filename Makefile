#$Id: Makefile,v 1.106 2007/08/21 03:39:20 jmendler Exp $
include ./Makefile.conf

# FIXME:
# * the cvsupdate target may not actually work (no rsh var set? can't login?)

####################################
#stuff for initial environment setup.
prep ::
	$(PERL) bin/rpmmacros.pl > ~/.rpmmacros
	$(MAKE) settings
	$(MAKE) sources

####################################
#main build targets
# triggers a .spec and .built file for each spec file on each target platform
# also summarizes the build status of each to a log file
# FIXME: add individual targets so you can build all/a package on a certain queue
#cluster_buildprep: prepares cluster for building
#last statment: makes a cbuilt for every SPEC file which in turn triggers cluster builds on all nodes.
###This submits jobs to cluster. Wait until after all build jobs are done on all nodes and then manually run 'make cluster_postbuild' to generate reports, make yum headers and fix ownership.
cluster_buildall ::
	$(MAKE) cluster_buildprep
	echo 'for i in SPECS/*.spec.in; do $(MAKE) $${i/.spec.in/.cbuilt}; done' | /bin/bash 

buildprep :: buildclean update

update ::
	$(MAKE) sources
	cvs update

cluster_buildprep ::
##Prepares the cluster for building -- either for cluster_buildall or make %.cbuilt's
##Various cluster prep steps are given higher priorities to insure execution before build jobs
#buildclean: gets rid of all .cbuilt targets on neuron, so will cleanly build everything even if target SPECs have not changed, also cleans BUILD and tmp directories
#prep/cvs update: locally on neuron
#cluster_buildclean: removes .built and .rbuilt targets on all cluster nodes, also cleans BUILD and tmp directories
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
	echo 'for i in SETTINGS/{$(ALLDISTROS)}.{$(ALLARCH)}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\n\n$(MAKE) buildclean\n" > SETTINGS/$$file/SCRIPTS/cluster_buildclean.sh; qsub -cwd -p 5 -o SETTINGS/$$file/LOGS/cluster_buildclean.stdout -e SETTINGS/$$file/LOGS/cluster_buildclean.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_buildclean.sh; done' | /bin/bash
	
cluster_cvsupdate ::
	echo 'for i in SETTINGS/{$(ALLDISTROS)}.{$(ALLARCH)}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\nsetenv CVS_RSH ssh\ncvs update\n" > SETTINGS/$$file/SCRIPTS/cluster_cvsupdate.sh; qsub -cwd -p 4 -o SETTINGS/$$file/LOGS/cluster_cvsupdate.stdout -e SETTINGS/$$file/LOGS/cluster_cvsupdate.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_cvsupdate.sh; done' | /bin/bash

cluster_prep ::
	echo 'for i in SETTINGS/{$(ALLDISTROS)}.{$(ALLARCH)}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\n$(MAKE) prep\n" > SETTINGS/$$file/SCRIPTS/cluster_prep.sh; qsub -cwd -p 3 -o SETTINGS/$$file/LOGS/cluster_prep.stdout -e SETTINGS/$$file/LOGS/cluster_prep.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_prep.sh; done' | /bin/bash

cluster_yumupdate ::
	echo 'for i in SETTINGS/{$(ALLDISTROS)}.{$(ALLARCH)}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; echo -e "#!/bin/csh\nsudo yum -y update\n" > SETTINGS/$$file/SCRIPTS/cluster_yumupdate.sh; qsub -cwd -p 2 -o SETTINGS/$$file/LOGS/cluster_yumupdate.stdout -e SETTINGS/$$file/LOGS/cluster_yumupdate.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/cluster_yumupdate.sh; done' | /bin/bash

# after a cluster_buildall finishes, 'make cluster_postbuild' to generate reports, migrate packages from testing to stable and make headers/rest of repo (make migrate triggers a make repo).
cluster_postbuild :: report migrate

# creates an HTML output report summarizing the build status of each package based on logs
## FIXME: first line is a temporary fix cause make prep causes too many levels of symlinks
report ::
	sudo mkdir -p $(WEBROOT)/report
	sudo perl bin/build_report.pl --dir SETTINGS --outdir REPORTS --format html
	sudo cp -Rf REPORTS/green.gif REPORTS/red.gif REPORTS/index.html $(WEBROOT)/report
	sudo rsync -rvL --times --whole-file --progress $(CVSPATH)/SETTINGS $(WEBROOT)/report/

# migrate all packages from testing into stable and make new headers for all repositories.
## FIXME: add a migrate target to allow for migration of individual packages in case one does not want to migrate the entire testing repository
migrate :: 
	sudo -H $(MAKE) -C $(WEBROOT)	gpgsignature
	for i in $(WEBROOT)/testing/*/*/*/*.rpm ; do sudo mv -vf $$i $${i/testing/stable} ; done
	$(MAKE) repo

migrate_centos ::
	sudo -H $(MAKE) -C $(WEBROOT) sign_centos 
	for i in $(WEBROOT)/testing/centos/*/*/*.rpm ; do sudo mv -vf $$i $${i/testing/stable} ; done
	sudo -H $(MAKE) -C $(WEBROOT) all_but_sign_centos
	$(MAKE) repo_permissions

migrate_fedora ::
	sudo -H $(MAKE) -C $(WEBROOT) sign_fedora
	for i in $(WEBROOT)/testing/fedora/*/*/*.rpm ; do sudo mv -vf $$i $${i/testing/stable} ; done
	sudo -H $(MAKE) -C $(WEBROOT) all_but_sign_fedora
	$(MAKE) repo_permissions


# perform all actions related to generation and cleanliness of yum repository
repo : repo_headers repo_permissions

# creates yum and legacy yum-arch headers for all biopackages branches. Depends on /biopackages/Makefile
## FIXME: Merge /biopackages/Makefile header creation into this Makefile.
repo_headers ::
	sudo -H $(MAKE) -C $(WEBROOT) all_but_sign

# make root own everything in the repository, except for testing
repo_permissions ::
	sudo chown -Rf root:root $(WEBROOT)
	sudo chown -Rf $(BUILDUSER):$(BUILDGROUP) $(WEBROOT)/testing

all :: specs

buildall :: specs
	echo 'for i in SPECS/*.spec; do $(MAKE) $${i/.spec/.built}; done' | /bin/bash

buildclean ::
	$(RM_RF) SPECS/*.built
	$(RM_RF) SPECS/*.cbuilt
	$(RM_RF) SPECS/*.rbuilt
	$(RM_RF) tmp/*
	$(RM_RF) BUILD/*

settings ::
	perl -e '(-e "/home/bpbuild/SETTINGS.large") ? print "$(MAKE) symlink_settings\n" : print "$(MAKE) local_settings"' | /bin/bash

sources ::
	perl -e '(-e "/home/bpbuild/SOURCES.large") ? print "$(MAKE) symlink_sources\n" : print "$(MAKE) rsync_sources\n"' | /bin/bash

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
	echo 'for i in SETTINGS/{$(ALLDISTROS)}.{$(ALLARCH)}; do spec=$(subst .spec.in,,$<); spec=$${spec#SPECS/}; spec=$${spec}; file=$${i#SETTINGS/}; distro=$${file%.*}; arch=$${file#*.}; rm SETTINGS/$$file/LOGS/$$spec.*; echo -e "#!/bin/csh\n\nsetenv CVS_RSH ssh\n$(MAKE) $(subst .spec.in,.rbuilt,$<)\n" > SETTINGS/$$file/SCRIPTS/$$spec.sh; echo "qsub -cwd -o SETTINGS/$$file/LOGS/$$spec.stdout -e SETTINGS/$$file/LOGS/$$spec.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/$$spec.sh"; qsub -cwd -o SETTINGS/$$file/LOGS/$$spec.stdout -e SETTINGS/$$file/LOGS/$$spec.stderr -q $$file.q SETTINGS/$$file/SCRIPTS/$$spec.sh; done' | /bin/bash
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

########################################################################
#Setup targets, called by various targets above in preparing a system

local_settings ::
	echo 'for d in tmp SETTINGS/{$(DISTRO)$(DISTRO_VER)}.{$(ALLARCH)}/{LOGS,DEP_TREES,SCRIPTS} SOURCES.{small,large} SRPMS BUILD RPMS/{$(ALLARCH)} ; do mkdir -p $${d}; done' | /bin/bash

## FIXME: This works somewhat, but makes too many levels of symlinks (i.e. SETINGS/$$dist/LOGS/LOGS/LOGS)... rm -Rf dir/dir before making again
symlink_settings ::
	echo 'for d in tmp SETTINGS/{$(DISTRO)$(DISTRO_VER)}.{$(ALLARCH)} SOURCES BUILD RPMS ; do mkdir -p $${d}; done' | /bin/bash
	echo 'for dist in {$(ALLDISTROS)}.{$(ALLARCH)} ; do for dir in LOGS DEP_TREES SCRIPTS ; do ln -sf /home/bpbuild/SETTINGS/$${dist}/$${dir} SETTINGS/$${dist}/$${dir} ; done ; done' | /bin/bash
	sudo rm -Rf $(CVSPATH)/SETTINGS/*/{SCRIPTS/SCRIPTS,LOGS/LOGS,DEP_TREES/DEP_TREES}
###FIXME: create symlinks for each distro/architecture to $(WEBROOT)/testing/... for SRPMS and RPMS


#symlink/rsync targets to maintain SOURCES/
symlink_sources : symlink_clean symlink_small symlink_large
symlink_clean : sync_clean

symlink_large ::
	for i in ~bpbuild/SOURCES.large/* ; do ln -s $$i ./SOURCES/ ; done

symlink_small ::
	for i in ~bpbuild/SOURCES.small/* ; do ln -s $$i ./SOURCES/ ; done


## Rsync_sources tests whether a user is anonymous or authorized.
rsync_sources ::
ifeq ($(SYNCUSER),anonymous)
	$(MAKE) anonymous_sync
else
	$(MAKE) authorized_sync
endif



##Rsync procedure for authorized users.
authorized_sync :	sync_clean rsync_notify rsync_up rsync_down rsync_links

rsync_down :	sync_clean rsync_down_small rsync_down_large

sync_clean ::
	@if [[ `find SOURCES/ -type f | grep -vw CVS | wc -l` > 0 ]]; then echo "=================================================================================" && echo "=================================================================================" && echo "====>  Please move your files out of SOURCES/ and into SOURCES.small (less than 10mb) or SOURCES.large (over 10mb), so they are uploaded and not overwritten!  <====" && echo "=================================================================================" && echo "================================================================================="; exit 1; fi
	@find SOURCES/ -type l | grep -vw SOURCES/ | grep -vw SOURCES/CVS | xargs rm -rf
	@find SOURCES/ -type d | grep -vw SOURCES/ | grep -vw SOURCES/CVS | xargs rm -rf

rsync_notify ::
	@echo "--------------------------------------------------------------------------------------------------"
	@echo "You appear to be outside of the lab, so rsyncing sources from $(SYNCHOST). This may take a while..."

rsync_up ::
	@echo "Uploading new sources in SOURCES.small and SOURCES.large."
	rsync -rlv ./SOURCES.small/ $(SYNCUSER)@$(SYNCHOST)::SOURCES.small.auth
	rsync -rlv ./SOURCES.large/ $(SYNCUSER)@$(SYNCHOST)::SOURCES.large.auth

rsync_down_small ::
	rsync -rlv $(SYNCHOST)::SOURCES.small SOURCES.small/

rsync_down_large ::
ifeq ($(ENABLE_LARGE),yes)
	rsync -rlv $(SYNCHOST)::SOURCES.large SOURCES.large/
else
	@echo "ENABLE_large is not set to yes, so skipping large sources."
endif

rsync_links ::
	@echo "Making symlinks. This may take a moment..."
	for i in SOURCES.small/* ; do ln -s $$i $${i/SOURCES.small/SOURCES} ; done
ifeq ($(ENABLE_LARGE),yes)
	for i in SOURCES.large/* ; do ln -s $$i $${i/SOURCES.large/SOURCES} ; done
endif


##The following is for anonymous users to download read-only sources and upload sources through the anonymous rsync server. Upon uploading sources, please open a task on http://sourceforge.net/projects/biopackages so that the sources will be verified and built.

anonymous_sync : anonymous_sync_clean anonymous_up rsync_down_small rsync_down_large rsync_links

anonymous_sync_clean ::
	@if [[ `find SOURCES/ -type f | grep -vw CVS | wc -l` > 0 ]]; then echo "=================================================================================" && echo "=================================================================================" && echo "====>  Please move your files out of SOURCES/ and into SOURCES.upload, so they are uploaded and not overwritten!  <====" && echo "=================================================================================" && echo "================================================================================="; exit 1; fi
	@find SOURCES/ -type l | grep -vw SOURCES/ | grep -vw SOURCES/CVS | xargs rm -rf
	@find SOURCES/ -type d | grep -vw SOURCES/ | grep -vw SOURCES/CVS | xargs rm -rf

anoymous_up ::
	@echo "Uploading sources from SOURCES.upload to anonymous rsync"
	rsync -rlv ./SOURCES.upload/ $(SYNCHOST)::SOURCES.upload.anonymous
