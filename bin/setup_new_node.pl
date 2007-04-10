#!/usr/local/bin/perl

# A simple script to setup a new build host.  This will need to be modified
# before the process can be automatic. This process assumes the network has
# been setup already.

# TO DO:
# * the following RPMs for RPMForge should be installed (on the correct VM)
# ** (fc2 doesn't recognize this, so you have to hardcode in yum.conf w/o mirror list) http://ftp.belnet.be/packages/dries.ulyssis.org/fedora/fc2/i386/RPMS.dries/rpmforge-release-0.2-2.1.fc2.rf.i386.rpm
# ** fc2.x86_64: http://ftp.belnet.be/packages/dries.ulyssis.org/fedora/fc2/i386/RPMS.dries/rpmforge-release-0.2-2.1.fc2.rf.x86_64.rpm doesn't work (broken URL) so configure it from the fc2.i386 yum.conf, disable sig check.
# 
#
# * add in passwd set for bpbuild user

use strict;

my ($distro, $dabb, $version, $arch);

# collect some info:
print "What is the distribution (e.g. centos, fedora):\n";
$distro = rl("fedora");
print "What is the distribution abbreviation (e.g. centos, fc):\n";
$dabb = rl("fc");
print "What is the distro version (e.g. 2, 3, 4...):\n";
$version = rl("2");
print "What is the arch (e.g. i386, x86_64):\n";
$arch = rl("i386");

# add bpbuild to sudo users file

system("echo 'bpbuild ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers");

# setup hosts file
system("mv /etc/hosts /etc/hosts.distro");
my $contents = <<END;
# Do not remove the following line, or various programs     -*- tab-width: 8 -*- ex:ts=4:sw=4:
# that require network functionality will fail.
127.0.0.1   localhost.localdomain           localhost
#When this is replicated to the compute nodes, initial logins slow down: 164.67.183.104 neuron.genomics.ctrl.ucla.edu       neuron
10.67.183.1 neuron.genomics.ctrl.ucla.edu       neuron  neuron.i
10.67.183.2 compute-0-00.genomics.ctrl.ucla.edu compute-0-00
10.67.183.3 compute-0-01.genomics.ctrl.ucla.edu compute-0-01
10.67.183.4 compute-0-02.genomics.ctrl.ucla.edu compute-0-02
10.67.183.5 compute-0-03.genomics.ctrl.ucla.edu compute-0-03
10.67.183.6 compute-0-04.genomics.ctrl.ucla.edu compute-0-04
10.67.183.7 compute-0-05.genomics.ctrl.ucla.edu compute-0-05
10.67.183.8 compute-0-06.genomics.ctrl.ucla.edu compute-0-06
10.67.183.9 compute-0-07.genomics.ctrl.ucla.edu compute-0-07
10.67.183.10    compute-0-08.genomics.ctrl.ucla.edu compute-0-08
10.67.183.11    compute-0-09.genomics.ctrl.ucla.edu     compute-0-09
10.67.183.12    compute-0-10.genomics.ctrl.ucla.edu     compute-0-10
10.67.183.13    compute-0-11.genomics.ctrl.ucla.edu     compute-0-11
10.67.183.14    compute-0-12.genomics.ctrl.ucla.edu     compute-0-12
10.67.183.15    compute-0-13.genomics.ctrl.ucla.edu     compute-0-13
10.67.183.16    compute-0-14.genomics.ctrl.ucla.edu compute-0-14
10.67.183.17    compute-0-15.genomics.ctrl.ucla.edu compute-0-15
10.67.183.18    compute-0-16.genomics.ctrl.ucla.edu compute-0-16

# cluster nodes should have both of these lines using the private IP
10.67.183.99    vault.i
164.67.183.99   vault.genomics.ctrl.ucla.edu        vault

# cluster nodes should have both of these lines using the private IP
10.67.183.100   nucleus.i
164.67.183.100  nucleus.genomics.ctrl.ucla.edu      nucleus

# VMWare Virtual Machines
10.67.183.229   fc5.i386.das2 # a temp host for testing
10.67.183.230   fc5.i386.testing # a temp host for testing
10.67.183.231   fc2.i386.testing # a temp host for testing
10.67.183.232   centos4-i386    centos4.i386
10.67.183.233   centos4-x86_64  centos4.x86_64
10.67.183.234   fc2-i386    fc2.i386
10.67.183.235   fc2-x86_64  fc2.x86_64
10.67.183.236   fc5-i386    fc5.i386
10.67.183.237   fc5-x86_64  fc5.x86_64
10.67.183.238   fc6-i386    fc6.i386
10.67.183.239   fc6-x86_64  fc6.x86_64

#
10.67.183.240   nexus.genomics.ctrl.ucla.edu        nexus  nexus.i
10.67.183.248   axis.genomics.ctrl.ucla.edu     axis axis.i
10.67.183.249   torso.genomics.ctrl.ucla.edu        torso torso.i
10.67.183.250   ulna.genomics.ctrl.ucla.edu     ulna ulna.i
10.67.183.251   radius.genomics.ctrl.ucla.edu       radius radius.i das.i
END
printfile("/etc/hosts", $contents);

# resolve
system("mv /etc/resolve.conf /etc/resolve.conf.distro");
$contents = <<END;
search genomics.ctrl.ucla.edu
nameserver 10.67.183.1
nameserver 164.67.128.1
END
printfile("/etc/resolve.conf", $contents);

# setup users and groups
system("groupadd -g 776 bpbuild");
system("useradd -g 776 -u 776 bpbuild");
system("mv /home /home.local");
system("groupadd -g 888 sgeadm");
system("useradd -g 888 -u 888 -d /home.local/sgeadm sgeadmin");

# setup NFS
system("mkdir -p /net/host/nucleus/genomics");
system("mkdir -p /net/host/nucleus/biopackages");
system("mkdir -p /net/host/nucleus/home");
system("mkdir -p /gridware/sge");

# fstab
system("cp /etc/fstab /etc/fstab.distro");
$contents = <<END;
#XSAN
nucleus.i:/genomics     /net/host/nucleus/genomics      nfs     hard,intr,nolock,posix,rsize=8192,wsize=8192,timeo=14   0 0
nucleus.i:/biopackages  /net/host/nucleus/biopackages   nfs     hard,intr,nolock,posix,rsize=8192,wsize=8192,timeo=14   0 0
nucleus.i:/home         /net/host/nucleus/home          nfs     hard,intr,nolock,posix,rsize=8192,wsize=8192,timeo=14   0 0
# SGE
neuron.i:/gridware/sge  /gridware/sge                   nfs     hard,intr,nolock,posix,rsize=8192,wsize=8192,timeo=14    0 0
END
printfile(">/etc/fstab", $contents);
system("mount -a");

# symlinks for NFS
system("ln -s /net/host/nucleus/biopackages /net/biopackages");
system("ln -s /net/host/nucleus/home /net/home");
system("ln -s /net/home /home");

# SGE
system("cp /etc/services /etc/services.distro");
$contents = <<END;
sge_commd 536/tcp # comm port SUN GRID ENGINE
sge_execd 537/tcp # Master port SUN GRID ENGINE
END
printfile(">/etc/services", $contents);

# FIXME:  on neuron: qconf -ah centos4.x86_64
print "FIXME:  on neuron: qconf -ah centos4.x86_64\n";

system("cd /gridware/sge; export SGE_ROOT=/gridware/sge; ./install_execd");

print "FIXME: remove centos4.x86_64 from being an administrative host on SGE\n";

# YUM
print "FIXME: extras needs to be installed, add check for FC2 (only w/o extras?). RPMForge needs to be installed.\n";
system("cp /etc/yum.conf /etc/yum.conf.distro");
$contents = <<'END';
[base]
name=Fedora Core $releasever - $basearch - Base
baseurl=http://mirrors.kernel.org/fedora/core/$releasever/$basearch/os/
END

# install bootstrap packages
system("sudo yum -y install cvs perl-DateManip");
system("rpm -Uvh http://yum.biopackages.net/biopackages/testing/fedora/5/noarch/usr-local-bin-perl-1.0-1.3.noarch.rpm");
system("rpm -Uvh http://yum.biopackages.net/biopackages/testing/fedora/5/noarch/");
system("rpm -Uvh http://yum.biopackages.net/biopackages/testing/fedora/5/noarch/biopackages-1.0.1-1.14.noarch.rpm");

# time server
print "FIXME: need to install and configure ntp!\n";

# setup cvs biopackages dir
system("chown bpbuild:bpbuild /usr/src");
system("chmod 775 /usr/src");
system('export CVS_RSH=ssh; cd /usr/src; su bpbuild -c \'cvs -z3 -d:ext:bpbuild@biopackages.cvs.sourceforge.net:/cvsroot/biopackages co -P biopackages\'; cd /usr/src/biopackages; make prep');

# make symlinks
# FIXME: make prep shouldn't create these!
system("rm -rf /usr/src/biopackages/RPMS/*");
system("for n in i386 noarch x86_64; do ln -s /net/biopackages/testing/$distro/$version/\$n /usr/src/biopackages/RPMS/\$n; done");
# FIXME: shouldn't be created
system("rm -rf /usr/src/biopackages/SRPMS");
system("ln -s /net/biopackages/testing/$distro/$version/SRPMS/ /usr/src/biopackages/SRPMS");

# create a list of RPMs installed on the base system
system("rpm -qa > /home/bpbuild/SETTINGS/$dabb$version.$arch/clean_rpm_list.txt");

# done
print("Setup is complete, reboot the system and take a snapshot\n");



# subroutines

sub printfile { 
  my ($file, $text) = @_;
  open OUT, ">$file" or die;
  print OUT $text;
  close OUT;
}

sub rl {
  my $default = shift;
  print "> ";
  my $value = <STDIN>;
  chomp $value;
  if ($value eq "" && $default ne "") { return $default; }
  return $value;
}


# FIXME: these need to be used to update yum.conf on each platform
# the other mirror seems to be ftp.belnet.be

my $fc2_i386_yum = <<END;
[rpmforge]
name = Fedora Core 2 - i386 - RPMforge.net - dag
baseurl = http://apt.sw.be/fedora/2/en/\$basearch/dag/
enabled = 1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag
gpgcheck = 0
END

my $fc_x86_64_yum = <<END;
[rpmforge]
name = Fedora Core 2 - x86_64 - RPMforge.net - dag
baseurl = http://apt.sw.be/fedora/2/en/\$basearch/dag/
enabled = 1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag
gpgcheck = 0
END

my $fc5_i386_yum = <<END;
[rpmforge]
name = Fedora Core 5 - i386 - RPMforge.net - dries
baseurl = http://apt.sw.be/fedora/5/en/\$basearch/dries/RPMS
enabled = 1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag
gpgcheck = 0
END

my $fc5_x86_64_yum = <<END;
[rpmforge]
name = Fedora Core 5 - x86_64 - RPMforge.net - dries
baseurl = http://apt.sw.be/fedora/5/en/\$basearch/dries/RPMS
enabled = 1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag
gpgcheck = 0
END

my $centos4_i386_yum = <<END;
[rpmforge]
name = Centos 4 - i386 - RPMforge.net - dag
baseurl = http://apt.sw.be/redhat/el4/en/\$basearch/dag/
enabled = 1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag
gpgcheck = 0
END

my $centos4_x86_64_yum = <<END;
[rpmforge]
name = Centos 4 - x86_64 - RPMforge.net - dag
baseurl = http://apt.sw.be/redhat/el4/en/\$basearch/dag/
enabled = 1
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag
gpgcheck = 0
END
