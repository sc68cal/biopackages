#!/bin/bash
#$Id: pmcheckdeps.sh,v 1.1 2005/07/29 09:24:15 allenday Exp $

UPPER=$1;

#
# iterate over unmet dependencies in $UPPER
#
check_dependencies() {
	PACK=$1;
	NS=${PACK/perl-/};
	NS=${NS/-/::};
	echo "*****checking dependencies of $PACK ($PACK-[0123456789]*.*.rpm)";

	for RPM in `find RPMS -type f -name "$PACK-[0123456789]*.rpm"`; do
		echo "checking $RPM";
		for DEP in `rpm -V -p $RPM | grep 'Unsatisfied' | perl -ne 'while(/perl\((\S+)\)/g){print "$1\n"}'`; do
			if [ -n "`rpm -q --provides -p $RPM | grep perl\($DEP\)`" ]; then
				echo "	$RPM resolves its own dependency on $DEP";
			else
				echo "	requires $DEP";
				resolve_dependency $DEP;
			fi;
		done;
	done;

}

resolve_dependency() {
	PERL_NAMESPACE=$1;
	#
	# See if an RPM has already been built to provide this namespace,
	# but skip ourselves.
	#
	SATISFIED=0;
	for RPM in `find RPMS -type f`; do
		if [ -n "`rpm -q --provides -p $RPM | grep perl\($PERL_NAMESPACE\)`" ]; then
#			echo "already made RPM ($RPM) providing $PERL_NAMESPACE, descending into $RPM";
			echo "	already made RPM ($RPM) providing $PERL_NAMESPACE";
			SATISFIED=1;
			break;
		fi;

	done;

	if [ $SATISFIED == 0 ]; then
		make perl-${PERL_NAMESPACE//::/-}.pm;
	fi;
}

check_dependencies ${UPPER/.spec/}
