#$Id: Makefile,v 1.130 2008/07/13 00:14:11 bret_harry Exp $
include ./Makefile.conf

.PHONY: rpm-cache help

VPATH = SPECS INSTALLED

# Some Variables that should be moved into Makefile.conf
SORT=sort
PR=pr
AWK=awk
CACHE_WEBROOT=$(CVSPATH)/WEBROOT
CACHE_ROOT=$(CACHE_WEBROOT)/cache/$(DISTRO)/$(DISTRO_VER)/$(DISTRO_ARCH)


# Recursive make variable to extract the full path from a .built file
rpm=$(shell cat $< | grep Wrote | grep -v SRPMS | cut -d ' ' -f 2)
get_rpm_arch=$(shell rpm -qp --queryformat '%{ARCH}' $1)
#get_rpm_vers=$$(shell echo $@ | cut -d '.' -f 1)-`cat SPECS/$(shell echo $@ | cut -d '.' -f 1).spec.in | grep -E 'Version ?:' | cut -d ' ' -f 2`
get_rpm_vers=$(shell cat SPECS/$(shell echo $@ | \
 cut -d '.' -f 1).spec.in | \
grep -E 'Version ?:' | \
cut -d ' ' -f 2)

define sign-rpms
 @echo Signing RPMs in $1
 cd $1                 ;\
 ls -1                 |\
 grep -v biopackages   |\
 xargs -I{}             \
 find {} -name '*.rpm' |\
 xargs rpm --resign
endef

####################################
#stuff for initial environment setup.
all :: prep

rpm-cache : ~/.gnupg/ $(CACHE_WEBROOT)
	$(call sign-rpms, $(YUM_CACHE))
	mkdir -p $(CACHE_ROOT)
	ls -1 $(YUM_CACHE)                             |\
	grep -v biopackages                            |\
	xargs -I{} find $(YUM_CACHE)/{} -name '*.rpm'  |\
	xargs -I{}                                      \
	rsync -aP                                       \
		--ignore-existing                       \
		{}                                      \
		$(CACHE_ROOT)
	createrepo -u \
	http://yum.biopackages.net/biopackages/cache/$(DISTRO)/$(DISTRO_VER)/$(DISTRO_ARCH) \
	$(CACHE_ROOT)

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
	mkdir -p INSTALLED
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
	rm -rf INSTALLED/*
	rm -rf tmp/*
	rm -rf BUILD/*
	rm -rf prep

#%: %.built
##	rpm -Uvh $(rpm)
#	date > SPECS/$@

#%.installed : %.built
#	rpm -Uvh $(rpm)
#	date > $@

#	$(shell echo $@ | cut -d '.' -f 1)-`cat SPECS/$(shell echo $@ | cut -d '.' -f 1).spec.in |\
#	$@-`cat SPECS/$(shell echo $@ | cut -d '.' -f 1).spec.in |\

%: %.spec prep
	yum -y install \
	$@-$(get_rpm_vers) |\
	if rpm -q $@-$(get_rpm_vers); \
	then \
		echo $@ "is installed"; \
	else \
		echo "Bulding $(shell echo $@ | cut -d '.' -f 1)" \
		echo "start build: `date`" > INSTALLED/$@; \
		(rpmbuild -ba $< 2>&1 >> $@) || rm -rf $@; \
	fi
	echo "end: `date`" >> INSTALLED/$@

#	if rpm -q $(shell echo $@ | cut -d '.' -f 1)-`cat SPECS/$(shell echo $@ | cut -d '.' -f 1).spec.in |\
#        grep -E 'Version ?:' | cut -d ' ' -f 2` ;\
#	then \
#		echo "true" ;\
#	else \
#		echo "false" ;\
#	fi

#	yum -y install $@-`cat SPECS/$@.spec.in | grep -E 'Version ?:' | cut -d ' ' -f 2`
#	rpm -q $@

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

# help - The default goal
help:
	$(MAKE) --print-data-base --question |                  \
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/                         \
	{ print substr($$1, 1, length($$1)-1) }' |      \
	$(SORT) |                                               \
	$(PR) --omit-pagination --width=80 --columns=4

