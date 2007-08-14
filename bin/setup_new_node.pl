#!/usr/bin/perl

# A simple script to setup a new build host.  This will need to be modified
# before the process can be automatic. This process assumes the network has
# been setup already.

# TO DO:
# * yum.conf for RPMForge should be configured, see the end of this script for the strings
# * add in passwd set for bpbuild user

use strict;

my ($vmtype, $distro, $dabb, $version, $arch, $answer, $contents, $testing);

## collect some info:
print "Is this a build, development, or testing virtual machine? [build, dev, test]\n";
$vmtype = rl("build");
print "What is the distribution (e.g. centos, fedora):\n";
$distro = rl("fedora");
	if ($distro eq 'centos') {$dabb = "centos";}
	if ($distro eq 'fedora') {$dabb = "fc";}
print "Abbreviating as $dabb...\n";
print "What is the distro version (e.g. 2, 3, 4...):\n";
$version = rl("2");
print "What is the arch (e.g. i386, x86_64):\n";
$arch = rl("i386");

##General config
# resolv.conf
  system("cp /etc/resolv.conf /etc/resolv.conf.distro");
  system("echo 'search genomics.ctrl.ucla.edu' > /etc/resolve.conf && echo 'nameserver 10.67.183.1' >> /etc/resolve.conf && echo 'nameserver 164.67.128.1' >> /etc/resolv.conf");


# YUM
	system("cp /etc/yum.conf /etc/yum.conf.distro");


### Testing
if($vmtype eq 'test')  {
	# yum
	system("wget http://www.biopackages.net/stable/$distro/$version/noarch/rpmforge-release-0.0.1-1.7.bp.centos4.noarch.rpm http://www.biopackages.net/stable/$distro/$version/noarch/biopackages-client-config-1.0-1.5.bp.centos4.noarch.rpm && rpm -Uvh rpmforge-release-0.0.1-1.7.bp.centos4.noarch.rpm biopackages-client-config-1.0-1.5.bp.centos4.noarch.rpm");

	print "Would you like to enable the biopackages testing repository? (e.g. yes, no):\n";
	$testing = <STDIN>;
	chomp($testing);
	if ($testing = "yes") { system("wget http://www.biopackages.net/stable/$distro/$version/noarch/biopackages-client-config-testing-1.0-1.5.bp.centos4.noarch.rpm && rpm -Uvh biopackages-client-config-testing-1.0-1.5.bp.centos4.noarch.rpm"); }
}

### Build and Dev
if ($vmtype eq 'build' || $vmtype eq 'dev') {

  # Enable RPMForge repositroy
  system("wget http://www.biopackages.net/stable/$distro/$version/noarch/rpmforge-release-0.0.1-1.7.bp.centos4.noarch.rpm && rpm -Uvh rpmforge-release-0.0.1-1.7.bp.centos4.noarch.rpm");

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
  
  #
  10.67.183.240   nexus.genomics.ctrl.ucla.edu        nexus  nexus.i
  10.67.183.248   axis.genomics.ctrl.ucla.edu     axis axis.i
  10.67.183.249   torso.genomics.ctrl.ucla.edu        torso torso.i
  10.67.183.250   ulna.genomics.ctrl.ucla.edu     ulna ulna.i
  10.67.183.251   radius.genomics.ctrl.ucla.edu       radius radius.i das.i
END
  my @ifconfig;
  my $line;
  my @E;
  my @F;
  my $ipaddress;
  @ifconfig=split(/\n/,`ifconfig`);
  foreach $line (@ifconfig){
    if($line =~ /inet addr:/){
      @E=split(/:/,$line);
      @F=split(/ /,$E[1]);
      $ipaddress=$F[0];
      last;
    }
  }
  $contents.="  ".$ipaddress."   ".`hostname`;
  printfile("/etc/hosts", $contents);
  
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
  #nucleus.i:/genomics     /net/host/nucleus/genomics      nfs     hard,intr,nolock,posix,rsize=8192,wsize=8192,timeo=14   0 0
  vault.i:/genomics     /net/host/nucleus/genomics      nfs     hard,intr,nolock,posix,rsize=8192,wsize=8192,timeo=14   0 0
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
  
  # time server
  system("sudo yum -y install ntp");
  my $contents = <<END;
  # Prohibit general access to this service.
  restrict default ignore
 
  # Permit all access over the loopback interface, only read from tick and nucleus.
  # Allow 10.67.183.0/24 subnet to be clients.
  restrict        127.0.0.1
  restrict        164.67.62.194   mask 255.255.255.255    nomodify notrap noquery
  restrict        164.67.183.100  mask 255.255.255.255    nomodify notrap noquery
  restrict        10.67.183.0     mask 255.255.255.0      notrust nomodify notrap
  server          nucleus.genomics.ctrl.ucla.edu          prefer
  server          tick.ucla.edu
  #server         0.pool.ntp.org
  #server         1.pool.ntp.org
  #server         2.pool.ntp.org
 
  # --- GENERAL CONFIGURATION ---
  # Undisciplined Local Clock. This is a fake driver intended for backup
  # and when no outside source of synchronized time is available. The
  # default stratum is usually 3, but in this case we elect to use stratum
  # 0. Since the server line does not have the prefer keyword, this driver
  # is never used for synchronization, unless no other other
  # synchronization source is available. In case the local host is
  # controlled by some external source, such as an external oscillator or
  # another protocol, the prefer keyword would cause the local host to
  # disregard all other synchronization sources, unless the kernel
  # modifications are in use and declare an unsynchronized condition.
  server  127.127.1.0     # local clock
  fudge   127.127.1.0 stratum 10

  # Drift file.  Put this in a directory which the daemon can write to.
  # No symbolic links allowed, either, since the daemon updates the file
  # by creating a temporary in the same directory and then rename()'ing
  # it to the file.
  driftfile /var/lib/ntp/drift
  broadcastdelay  0.008

  # Authentication delay.  If you use, or plan to use someday, the
  # authentication facility you should make the programs in the auth_stuff
  # directory and figure out what this number should be on your machine.
  authenticate yes

  # Keys file.  If you want to diddle your server at run time, make a
  # keys file (mode 600 for sure) and define the key number to be
  # used for making requests.
  #
  # PLEASE DO NOT USE THE DEFAULT VALUES HERE. Pick your own, or remote
  # systems might be able to reset your clock at will. Note also that
  # ntpd is started with a -A flag, disabling authentication, that
  # will have to be removed as well.
  keys            /etc/ntp/keys
END
  printfile("/etc/ntp.conf", $contents);
  system("/etc/init.d/ntpd start");
  system("chkconfig --level 5 ntpd on");

  # setup cvs biopackages dir
  system("chown bpbuild:bpbuild /usr/src");
  system("chmod 775 /usr/src");
  system("mkdir -p /usr/src/biopackages/RPMS");
  system("sudo yum -y install cvs");
  system('export CVS_RSH=ssh; cd /usr/src; chown bpbuild:bpbuild /usr/src; chmod 775 /usr/src; chown -Rf bpbuild:bpbuild /usr/src/biopackages; chmod 775 /usr/src/biopackages; su bpbuild -c \'cvs -z 3 -d :ext:bpbuild@biopackages.cvs.sourceforge.net:/cvsroot/biopackages co -P biopackages; cd /usr/src/biopackages; make prep\'');

  # make symlinks
  # FIXME: make prep shouldn't create these!
  system("rm -rf /usr/src/biopackages/RPMS/*");
  system("for n in i386 noarch x86_64; do ln -s /net/biopackages/testing/$distro/$version/\$n /usr/src/biopackages/RPMS/\$n; done");
  # FIXME: shouldn't be created
  system("rm -rf /usr/src/biopackages/SRPMS");
  system("ln -s /net/biopackages/testing/$distro/$version/SRPMS/ /usr/src/biopackages/SRPMS");
  
  # create a list of RPMs installed on the base system
  system("rpm -qa > /home/bpbuild/SETTINGS/$dabb$version.$arch/clean_rpm_list.txt");
  
  # install bootstrap packages
  system("sudo yum -y install cvs perl-DateManip rpm-build biopackages usr-local-bin-perl rpmforge-release");
}


### Build only
if ($vmtype eq 'build') {
  # SGE
  system("cp /etc/services /etc/services.distro");
  $contents = <<END;
  sge_commd 536/tcp # comm port SUN GRID ENGINE
  sge_execd 537/tcp # Master port SUN GRID ENGINE
END
  printfile(">/etc/services", $contents);
                                                                                                                                                             
  # FIXME:  on neuron: qconf -ah centos4.x86_64
  print "FIXME:  on neuron: qconf -ah centos4.x86_64.\nEnter yes when ready.\n";
  $answer = rl("yes");
  system("sudo yum -y install binutils");
  system("cd /gridware/sge; export SGE_ROOT=/gridware/sge; ./install_execd");
                                                                                                                                                             
  print "FIXME: remove node from being an administrative host on SGE\n";
  print 'FIXME: [root@neuron]# qconf -dh centos4.i386.JMM\nEner yes when ready.\n';
  $answer = rl("yes");
}

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
