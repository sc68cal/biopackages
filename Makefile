#$Id: Makefile,v 1.124 2008/06/25 18:08:15 bret_harry Exp $
include ./Makefile.conf

# Recursive make variable to extract the full path from a .built file
rpm=$(shell cat $< | grep Wrote | grep -v SRPMS | cut -d ' ' -f 2)

####################################
#stuff for initial environment setup.
all :: prep

prep : Makefile.conf
	touch ~/.rpmmacros
	mv ~/.rpmmacros ~/.rpmmacros.bckup
	echo "# Biopackage specific macros"       >> ~/.rpmmacros
	echo "%_topdir $(CVSPATH)"                >> ~/.rpmmacros
	echo "%_tmppath $(CVSPATH)/tmp"           >> ~/.rpmmacros    
	echo "%_signature gpg"                    >> ~/.rpmmacros
	echo "%_gpg_name Biopackages"             >> ~/.rpmmacros
	echo "%_gpgbin /usr/bin/gpg"              >> ~/.rpmmacros
	echo "%distro bp.$(DISTRO)$(DISTRO_VER)"  >> ~/.rpmmacros

	mkdir -p SOURCES
	mkdir -p BUILD
	mkdir -p SRPMS
	mkdir -p RPMS/`uname -i`	
	date >> prep

# creates an HTML output report summarizing the build status of each package based on logs
## FIXME: first line is a temporary fix cause make prep causes too many levels of symlinks
report ::
	find SPECS/ -name '*.built' | xargs egrep -rHE '^start|^Wrote|^end'
#	sudo mkdir -p $(WEBROOT)/report
#	sudo perl bin/build_report.pl --dir SETTINGS --outdir REPORTS --format html
#	sudo cp -Rf REPORTS/green.gif REPORTS/red.gif REPORTS/index.html $(WEBROOT)/report
#	sudo rsync -rvL --times --whole-file --progress $(CVSPATH)/SETTINGS $(WEBROOT)/report/

clean ::
	rm -rf SPECS/*.spec
	rm -rf SPECS/*.built
	rm -rf SPECS/*.cbuilt
	rm -rf SPECS/*.rbuilt
	rm -rf SPECS/*.installed	
	rm -rf tmp/*
	rm -rf BUILD/*
	rm -rf prep

%.installed : %.built
	rpm -Uvh $(rpm)
	date > $@

%.built : %.spec prep
	echo "start: `date`" > $@
	(rpmbuild -ba $< 2>&1 >> $@ && echo "end: `date`" >> $@ ) || rm -rf $@ 

####################################
#extension rules
# rbuilt is a target for the local machine that calls the recursive build program (resolve_deps)
# FIXME: probably don't need verbose here
%.rbuilt : %.spec
	echo 'spec=$(subst .spec,,$<); spec=$${spec#SPECS/}; perl $(RECURSIVE_BUILD) --verbose --no-build $(CVSPATH)/SETTINGS/$(DISTRO)$(DISTRO_VER).$(DISTRO_ARCH)/no_build.txt --rpm-base $(CVSPATH)/SETTINGS/$(DISTRO)$(DISTRO_VER).$(DISTRO_ARCH)/clean_rpm_list.txt --map $(CVSPATH)/SETTINGS/$(DISTRO)$(DISTRO_VER).$(DISTRO_ARCH)/package_name_mapping.txt  --no-yum $(CVSPATH)/SETTINGS/$(DISTRO)$(DISTRO_VER).$(DISTRO_ARCH)/yum_no_install.txt --dep-tree $(CVSPATH)/SETTINGS/$(DISTRO)$(DISTRO_VER).$(DISTRO_ARCH)/DEP_TREES/$$spec.deptree --no-deps $(CVSPATH)/SETTINGS/$(DISTRO)$(DISTRO_VER).$(DISTRO_ARCH)/no_deps.txt --spec $$spec' | /bin/bash
	touch $@

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
	cat $< | perl bin/in2spec.pl > $@
