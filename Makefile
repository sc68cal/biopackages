#$Id: Makefile,v 1.143 2008/10/15 01:16:19 bpbuild Exp $
include ./Makefile.conf

.PHONY: rpm-cache help

VPATH = SPECS INSTALLED

# Some Variables that should be moved into Makefile.conf
SORT=sort
PR=pr
AWK=awk
CACHE_WEBROOT=$(WEBROOT)
CACHE_ROOT=$(CACHE_WEBROOT)/cache/$(DISTRO)/$(DISTRO_VER)/$(DISTRO_ARCH)
RPM_Q=rpm -q --queryformat '%-30{NAME} %-10{VERSION} %{ARCH}\n'

# Recursive make variable to extract the full path from a .built file
rpm=$(shell cat SPECS/$<.rpmbuild | grep Wrote | grep -v SRPMS | cut -d ' ' -f 2)
get_rpm_arch=$(shell rpm -qp --queryformat '%{ARCH}' $1)
get_rpm_vers=$(shell cat SPECS/$(subst .built,.spec.in,$@) | \
grep -E 'Version ?:' | \
cut -d ' ' -f 2)

get_rpm_name=$(shell echo $@ | cut -d. -f1)
rpm_name=$(subst .built,,$@)
rpm_ver=$(shell cat SPECS/$(subst .installed,.spec.in,$@) | \
	egrep -ri 'version' - |            \
	perl -e '$$_=<>;                   \
		s/^\s*Version\s*:\s*//;    \
		print $$_;')

define sign-rpms
 @echo Signing RPMs in $1
 cd $1                 ;\
 ls -1                 |\
 grep -v biopackages   |\
 xargs -I{}             \
 find {} -name '*.rpm' |\
 xargs rpm --resign
endef

define install-deps
 @echo Installing deps for: $1
 @for D in $(shell \
  egrep -ri '^$2' SPECS/$(subst SPECS/,,$1)       |\
  perl -e '$$_=<>;                      \
           s/^$2 ?: ?//;                \
           s/ ?>= ?/-/g;                \
           s/ ?= ?/-/g;                 \
           s/ ?<= ?/-/g;                \
           s/ ?< ?/-/g;                 \
           s/ ?> ?/-/g;                 \
           s/,//g;                      \
           s/%{requires}//g;            \
           print $$_;'                  \
 ); do                                  \
 rpm -q --queryformat '%-30{NAME} %-10{VERSION} %{ARCH}\n' $$D || \
 yum -y install $$D; \
 done
endef

all : prep biopackages-client-config R-Biobase R-DBI R-RSQLite R-xtable R-AnnotationDbi R-annotate R-genefilter R-Bioconductor-graph R-Bioconductor-RBGL R-Bioconductor-Category R-Bioconductor-GO.db R-Bioconductor-GOstats R-randomForest R-RCurl R-affyio R-preprocessCore R-affy R-limma R-hopach R-celsius R-heatmap.plus R-Hmisc R-sna R-sma R-impute R-dynamicTreeCut R-moduleColor R-Matrix R-Bioconductor-GO R-Bioconductor-KEGG R-Bioconductor-hgu133plus2 R-Bioconductor-Rgraphviz R-affydata R-matchprobes R-gcrma R-affyPLM R-simpleaffy R-RColorBrewer R-geneplotter R-affyQCReport R-R.methodsS3 R-R.oo R-R.utils R-R.cache R-R.rsp R-R.native R-affxparser R-aroma.light R-R.huge R-aroma.apd R-digest R-matrixStats R-sfit R-aroma.core R-aroma.affymetrix R-plier R-vsn R-plr affyapt celtools perl-celsius-config celsius-etl celsius-database perl-celsius

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

### This is more expensive than it probably needs to be 4*4*2 = 32
YR_REPO := stable testing internal cache
YR_VER := 4 5
YR_ARCH := i386 x64_86 noarch SRPMS
YR_COMB := $$R/$(DISTRO)/$$V/$$A
yum-repo : $(WEBROOT)
	for R in $(YR_REPO); do \
	  for V in $(YR_VER); do \
	    for A in $(YR_ARCH); do \
	      if [ -d $(WEBROOT)/$(YR_COMB) ]; \
	      then \
	          createrepo -u http://yum.biopackages.net/biopackages/$(YR_COMB) \
	          $(WEBROOT)/$(YR_COMB); \
	      else \
                echo Directory WEBROOT/$(YR_COMB) does not exist!; \
	      fi \
	    done \
          done \
        done

### Push RPMs to the repository
yum-repo-testing : $(WEBROOT)
	find SRPMS RPMS -name '*.rpm' | xargs rpm --resign
	rsync -aP SRPMS/ $(WEBROOT)/testing/$(DISTRO)/$(DISTRO_VER)/SRPMS
	rsync -aP RPMS/noarch/ $(WEBROOT)/testing/$(DISTRO)/$(DISTRO_VER)/noarch
	rsync -aP RPMS/$(DISTRO_ARCH)/ $(WEBROOT)/testing/$(DISTRO)/$(DISTRO_VER)/$(DISTRO_ARCH)

	for A in $(DISTRO_ARCH) noarch SRPMS; do \
	  createrepo -u http://yum.biopackages.net/biopackages/testing/$(DISTRO)/$(DISTRO_VER)/$$A \
	    $(WEBROOT)/testing/$(DISTRO)/$(DISTRO_VER)/$$A; \
	done

prep-host : 
	echo "PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$$ '" >> ~/.bashrc
	echo "export PS1" >> ~/.bashrc
	echo "export CVS_RSH=ssh" >> ~/.bashrc
	rsync -a neuron.genome.ucla.edu:/root/.gnupg /root/

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
	mkdir -p INSTALLED
	mkdir -p BUILD
	mkdir -p SRPMS
	mkdir -p RPMS/`uname -i`	
	mkdir -p RPMS/noarch
	mkdir -p $(WEBROOT)
	ln -s $(SOURCES)/ SOURCES
	date >> prep

# creates an HTML output report summarizing the build status of each package based on logs
## FIXME: first line is a temporary fix cause make prep causes too many levels of symlinks
report ::
	find SPECS/ -name '*.built' | xargs egrep -rHE '^start|^Wrote|^end'
#	sudo mkdir -p $(WEBROOT)/report
#	sudo perl bin/build_report.pl --dir SETTINGS --outdir REPORTS --format html
#	sudo cp -Rf REPORTS/green.gif REPORTS/red.gif REPORTS/index.html $(WEBROOT)/report
#	sudo rsync -rvL --times --whole-file --progress $(CVSPATH)/SETTINGS $(WEBROOT)/report/

clean :
	rm -rf SPECS/*.spec
	rm -rf SPECS/*.built
	rm -rf SPECS/*.cbuilt
	rm -rf SPECS/*.rbuilt
	rm -rf SPECS/*.installed	
	rm -rf SPECS/*.rpmbuild	
	rm -rf INSTALLED/*
	rm -rf tmp/*
	rm -rf BUILD/*
	rm -rf prep


% : %.installed
	@$(RPM_Q) $@ > INSTALLED/$@ || rm -rf INSTALLED/$@;

%.installed : %.built
	@$(RPM_Q) $(subst .installed,,$@)-$(rpm_ver) || \
	yum -y install $(subst .installed,,$@)-$(rpm_ver)

	@if [ -e INSTALLED/$< ] ; \
	then \
		true ;\
	else \
		echo "$@: $(get_rpm_name) did not need to be built" ;\
		$(RPM_Q) $(subst .installed,,$@)-$(rpm_ver) || \
		rpm -Uvh `cat INSTALLED/$(subst INSTALLED/,,$<)` ;\
	fi

%.built : %.deps
	@$(RPM_Q) $(rpm_name)-$(get_rpm_vers) || \
	(rpmbuild -ba SPECS/$(subst .deps,.spec,$(subst SPECS/,,$<)) && \
	(find RPMS -follow -name "$(rpm_name)-$(get_rpm_vers)*.rpm" > INSTALLED/$@) && \
	sudo rpm -Uvh `cat INSTALLED/$@`)

%.deps : %.spec
	$(call install-deps,$<,BuildRequires)
	$(call install-deps,$<,Requires)

%.spec : %.spec.in
	cat $< | perl ./bin/in2spec.pl > $(subst .in,,$<) ;

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
	cat $< | perl bin/in2spec.pl > SPECS/$(subst SPECS/,,$@)

# help - The default goal
help:
	$(MAKE) --print-data-base --question |                  \
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/                         \
	{ print substr($$1, 1, length($$1)-1) }' |      \
	$(SORT) |                                               \
	$(PR) --omit-pagination --width=80 --columns=4

