#!/usr/bin/perl -w
# nagios: -epn

#######################################################
#                                                     #
#  Name:    check_rhev3                               #
#                                                     #
#  Version: 1.4.0-alpha                               #
#  Created: 2012-08-13                                #
#  Last Update: 2013-12-23                            #
#  License: GPL - http://www.gnu.org/licenses         #
#  Copyright: (c)2012,2013 ovido gmbh                 #
#  Author:  Rene Koch <r.koch@ovido.at>               #
#  URL: https://github.com/ovido/check_rhev3          #
#                                                     #
#######################################################

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw(POST);
use HTTP::Headers;
use Getopt::Long;
use XML::Simple;

# for debugging only
use Data::Dumper;

# Configuration
# all values can be overwritten via command line options
my $rhevm_port	= 8443;			# default port
my $rhevm_api	= "/api";		# default api path
my $rhevm_timeout = 15;			# default timeout

# create performance data
# 0 ... disabled
# 1 ... enabled
my $perfdata	= 1;


# Variables
my $prog	= "check_rhev3";
my $version	= "1.4.0-alpha";
my $projecturl  = "https://github.com/ovido/check_rhev3";
my $cookie	= "/var/tmp";	# default path to cookie file

my $o_verbose	= undef;	# verbosity
my $o_help	= undef;	# help
my $o_rhevm_host = undef;	# rhevm hostname
my $o_rhevm_port = undef;	# rhevm port
my $o_rhevm_api	= undef;	# rhevm api path
my $o_version	= undef;	# version
my $o_timeout	= undef;	# timeout
my $o_warn;			# warning
my $o_crit;			# critical
my $o_auth	= undef;	# authentication
my $o_authfile	= undef;	# authentication file
my $o_ca_file	= undef;	# certificate authority
my $o_cookie	= undef;	# cookie authentication
my $o_rhev_dc	= undef;	# rhev data center
my $o_rhev_cluster = undef;	# rhev cluster
my $o_rhev_host	= undef;	# rhev host
my $o_rhev_storage = undef;	# rhev storage domain
my $o_rhev_vm	= undef;	# rhev vm
my $o_rhev_vmpool = undef;	# rhev vm pool
my $o_check	= undef;
my $o_subcheck	= undef;
my @o_nics;

my %status	= ( ok => "OK", warning => "WARNING", critical => "CRITICAL", unknown => "UNKNOWN");
my %ERRORS	= ( "OK" => 0, "WARNING" => 1, "CRITICAL" => 2, "UNKNOWN" => 3);
my ($rhevm_user,$rhevm_pwd) = undef;

#***************************************************#
#  Function: parse_options                          #
#---------------------------------------------------#
#  parse command line parameters                    #
#                                                   #
#***************************************************#
sub parse_options(){
  Getopt::Long::Configure ("bundling");
  GetOptions(
	'v+'	=> \$o_verbose,		'verbose+'	=> \$o_verbose,
	'h'	=> \$o_help,		'help'		=> \$o_help,
	'H:s'	=> \$o_rhevm_host,	'hostname:s'	=> \$o_rhevm_host,
	'p:i'	=> \$o_rhevm_port,	'port:i'	=> \$o_rhevm_port,
	'A:s'	=> \$o_rhevm_api,	'api:s'		=> \$o_rhevm_api,
	'V'	=> \$o_version,		'version'	=> \$o_version,
	't:i'	=> \$o_timeout,		'timeout:i'	=> \$o_timeout,
	'a:s'	=> \$o_auth,		'authorization:s' => \$o_auth,
	'f:s'	=> \$o_authfile,	'authfile:s'	=> \$o_authfile,
	'D:s'	=> \$o_rhev_dc,		'dc:s'		=> \$o_rhev_dc,
	'C:s'	=> \$o_rhev_cluster,	'cluster:s'	=> \$o_rhev_cluster,
	'R:s'	=> \$o_rhev_host,	'host:s'	=> \$o_rhev_host,
	'S:s'	=> \$o_rhev_storage,	'storage:s'	=> \$o_rhev_storage,
	'M:s'	=> \$o_rhev_vm,		'vm:s'		=> \$o_rhev_vm,
	'P:s'	=> \$o_rhev_vmpool,	'vmpool:s'	=> \$o_rhev_vmpool,
	'l:s'	=> \$o_check,		'check:s'	=> \$o_check,
	's:s'	=> \$o_subcheck,	'subcheck:s'	=> \$o_subcheck,
	'w:s'	=> \$o_warn,		'warning:s'	=> \$o_warn,
	'c:s'	=> \$o_crit,		'critical:s'	=> \$o_crit,
					'ca-file:s'	=> \$o_ca_file,
	'o'	=> \$o_cookie,		'cookie'	=> \$o_cookie,
	'n:s'	=> \@o_nics,		'nics:s'	=> \@o_nics
  );

  # process options
  print_help()		if defined $o_help;
  print_version()	if defined $o_version;
  if (! defined( $o_rhevm_host )){
    print "RHEV Manager hostname is missing.\n";
    print_usage();
    exit $ERRORS{$status{'unknown'}};
  }
  if ( (! defined( $o_rhev_dc )) && (! defined( $o_rhev_cluster )) && (! defined( $o_rhev_host )) && (! defined ( $o_rhev_storage)) && (! defined ( $o_rhev_vm)) && (! defined ( $o_rhev_vmpool)) ){
    print "Data Center, Cluster, RHEV Host, Storage domain, VM or VM Pool is missing.\n";
    print_usage();
    exit $ERRORS{$status{'unknown'}};
  };
  $o_verbose = 0	if (! defined $o_verbose);
  $o_verbose = 0	if $o_verbose <= 0;
  $o_verbose = 3	if $o_verbose >= 3;
  $rhevm_port = $o_rhevm_port	if defined $o_rhevm_port;
  $rhevm_api = $o_rhevm_api	if defined $o_rhevm_api;
  $rhevm_timeout = $o_timeout	if defined $o_timeout;
  
  # Get username and password via parameters or via file
  # format must be username@domain:password
  if (defined( $o_auth )){
    my @auth = split(/:/, $o_auth);
    if (! $auth[0]){ 
     print "RHEV Username/Domain is missing.\n";
     print_help();
    }else{	$rhevm_user = $auth[0];	}
    if (! $auth[1]){
      print "RHEV Password is missing.\n";
      print_help();
    }else{	$rhevm_pwd = $auth[1];	}
    my @tmp_auth = split(/@/, $auth[0]);
    if (! $tmp_auth[0]){ 
      print "RHEV Username is missing.\n";
      print_help(); }
    if (! $tmp_auth[1]){ 
      print "RHEV Domain is missing.\n";
      print_help(); }
  }else{
    if (! defined $o_authfile){
      print "Please provide credentials either via -a or -f option.\n";
      print_help();
    }
    # get auth from file
    open (AUTHFILE, $o_authfile) || die "Can't open auth file $o_authfile!\n";
    while (<AUTHFILE>){
      # remove white spaces
      $_ =~ s/\s+//g;
      chomp $_;
      if ($_ =~ /^username=/){
	my @tmp = split(/=/, $_);
	my @tmp_auth = split(/@/, $tmp[1]);
	if (! $tmp_auth[0]){
	  print "RHEV Username is missing.\n";
	  print_help();
	}elsif (! $tmp_auth[1]){
	  print "RHEV Domain ins missing.\n";
	  print_help();
	}
	$rhevm_user = $tmp[1];
      }elsif ($_ =~ /^password=/){
	my @tmp = split(/=/, $_);
        if (! $tmp[1]){
	  print "RHEV Password is missing.\n";
	  print_help();
	}
	$rhevm_pwd = $tmp[1];
      }
    }
    close (AUTHFILE);
    if (! $rhevm_user || ! $rhevm_pwd){
      print "Error getting values from auth file!\n";
      exit $ERRORS{$status{'unknown'}};
    }
  }

  if (defined $o_ca_file){
    if (! -r $o_ca_file){
      print "Can't read Certificate Authority file: $o_ca_file!\n";
      exit $ERRORS{$status{'unknown'}};
    }
  }
  
  # storage warnings and criticals can be % or M/G/T
  if (defined $o_rhev_storage){
  	# convert warning into bytes
  	if (defined $o_warn){
  	  if ($o_warn =~ /^(\d)+M$/){
  	    $o_warn =~ s/M//g;
  	    $o_warn = $o_warn * 1024 * 1024;
  	  }elsif ($o_warn =~ /^(\d)+G$/){
  	  	$o_warn =~ s/G//g;
  	  	$o_warn = $o_warn * 1024 * 1024 * 1024;
  	  }elsif ($o_warn =~ /^(\d)+T$/){
  	  	$o_warn =~ s/T//g;
  	  	$o_warn = $o_warn * 1024 * 1024 * 1024 * 1024;
  	  }elsif ($o_warn =~ /^(\d)+%$/){
  	  	$o_warn =~ s/%//g;
  	  }elsif ($o_warn !~ /^(\d)+$/ && $o_warn !~ /^(\d)+.(\d)+$/){
  	    print "Invalid character in warning argument: $o_warn\n";
  	    exit $ERRORS{$status{'unknown'}};
  	  }
  	}
  	# convert critical into bytes
  	if (defined $o_crit){
  	  if ($o_crit =~ /^(\d)+M$/){
  	    $o_crit =~ s/M//g;
  	    $o_crit = $o_crit * 1024 * 1024;
  	  }elsif ($o_crit =~ /^(\d)+G$/){
  	  	$o_crit =~ s/G//g;
  	  	$o_crit = $o_crit * 1024 * 1024 * 1024;
  	  }elsif ($o_crit =~ /^(\d)+T$/){
  	  	$o_crit =~ s/T//g;
  	  	$o_crit = $o_crit * 1024 * 1024 * 1024 * 1024;
  	  }elsif ($o_crit =~ /^(\d)+%$/){
  	  	$o_crit =~ s/%//g;
  	  }elsif ($o_crit !~ /^(\d)+$/ && $o_crit !~ /^(\d)+.(\d)+$/){
  	    print "Invalid character in critical argument: $o_crit\n";
  	    exit $ERRORS{$status{'unknown'}};
  	  }
  	}
  }else{
  	if (defined $o_warn && $o_warn !~ /^(\d)+$/ && $o_warn !~ /^(\d)+%$/){
  	  print "Invalid character in warning argument: $o_warn\n";
  	  exit $ERRORS{$status{'unknown'}};
  	}
  	if (defined $o_crit && $o_crit !~ /^(\d)+$/ && $o_crit !~ /^(\d)+%$/){
  	  print "Invalid character in critical argument: $o_crit\n";
  	  exit $ERRORS{$status{'unknown'}};
  	}
  	# chop %
  	chop $o_warn if defined $o_crit && $o_warn =~ /^(\d)+%$/;
  	chop $o_crit if defined $o_crit && $o_crit =~ /^(\d)+%$/;
  }
}


#***************************************************#
#  Function: print_usage                            #
#---------------------------------------------------#
#  print usage information                          #
#                                                   #
#***************************************************#
sub print_usage(){
  print "Usage: $0 [-v] -H <hostname> [-p <port>] -a <auth> | -f <authfile> [--ca-file <ca-file> [-o ] \n";
  print "       [-A <api>] [-t <timeout>] -D <data center> | -C <cluster> | -R <rhev host> [-n <nic>] \n";
  print "       | -S <storage domain> | -M <vm> | -P <vmpool> [-w <warn>] [-c <critical>] [-V] \n";
  print "       [-l <check>] [-s <subcheck>]\n"; 
}


#***************************************************#
#  Function: print_help                             #
#---------------------------------------------------#
#  print help text                                  #
#                                                   #
#***************************************************#
sub print_help(){
  print "\nRed Hat Enterprise Virtualization checks for Icinga/Nagios version $version\n";
  print "GPL license, (c)2012-2013	 - Rene Koch <r.koch\@ovido.at>\n\n";
  print_usage();
  print <<EOT;

Options:
 -h, --help
    Print detailed help screen
 -V, --version
    Print version information
 -H, --hostname
    Host name or IP Address of RHEV Manager
 -p, --port=INTEGER
    port number (default: $rhevm_port)
 -a, --authorization=AUTH_PAIR
    Username\@domain:password required for login to REST-API
 -f, --authfile=AUTH_FILE
    Format of file:
    username=Username\@Domain
    password=Passowrd
 --ca-file=CA_FILE
    Path to RHEV CA for SSL certificate verification
 -o, --cookie
    Use cookie based authenticated sessions (requires RHEV >= 3.1)
 -A, --api
    REST-API path (default: $rhevm_api)
 -t, --timeout=INTEGER
    Seconds before connection times out (default: $rhevm_timeout)
 -D, --dc
    RHEV data center name
 -C, --cluster
    RHEV cluster name
 -R, --host
    RHEV Hypervisor name
 -S, --storage
    RHEV Storage domain name
 -M, --vm
    RHEV virtual machine name
 -P, --vmpool
    RHEV vm pool
 -l, --check
    DC/Cluster/Hypervisor/VM/Storage Pool Check
    see $projecturl or README for details
 -s, --subcheck
    DC/Cluster/Hypervisor/VM/Storage Pool Subcheck
    see $projecturl or README for details
 -n, --nics
    Specify host nic(s) to check
    see $projecturl or README for details
 -w, --warning=DOUBLE
    Value to result in warning status
 -c, --critical=DOUBLE
    Value to result in critical status
 -v, --verbose
    Show details for command-line debugging
    (Icinga/Nagios may truncate output)

Send email to r.koch\@ovido.at if you have questions regarding use
of this software. To submit patches of suggest improvements, send
email to r.koch\@ovido.at
EOT

exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function: print_version                          #
#---------------------------------------------------#
#  Display version of plugin and exit.              #
#                                                   #
#***************************************************#

sub print_version{
  print "$prog $version\n";
  exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function: main                                   #
#---------------------------------------------------#
#  The main program starts here.                    #
#                                                   #
#***************************************************#

# parse command line options
parse_options();
print "[V] Starting the main script.\n" if $o_verbose >= 2;
print "[V] This is $prog version $version.\n" if $o_verbose >= 2;

# What to check?
print "[V] Checking which component to monitor.\n" if $o_verbose >= 2;
&check_dc	if defined $o_rhev_dc;
&check_cluster	if defined $o_rhev_cluster;
&check_host	if defined $o_rhev_host;
&check_storage	if defined $o_rhev_storage;
&check_vm	if defined $o_rhev_vm;
&check_vmpool	if defined $o_rhev_vmpool;


#***************************************************#
#  Datacenter checks                                #
#---------------------------------------------------#
#  This sections covers datacenter checks.          #
#                                                   #
#***************************************************#

sub check_dc{
  print "[D] check_dc: Called function check_dc\n" if $o_verbose == 3;
  print "[V] Datacenter: Checking datacenter $o_rhev_dc.\n" if $o_verbose >= 2;
  # is check given?
  if (defined $o_check){
    check_cstatus("data_centers",$o_rhev_dc) if ($o_check eq "status");
    &check_dc_version if $o_check eq "version";
    if ($o_check eq "storage"){
      if (defined $o_subcheck){
	check_istatus("data_centers",$o_rhev_dc,"storagedomains") if $o_subcheck eq "status";
	check_statistics("data_centers",$o_rhev_dc,"dcstorage")  if $o_subcheck eq "usage";
	print_unknown("storage domain");
      }else{	check_istatus("data_centers",$o_rhev_dc,"storagedomains");	}
    }else{	
      print "[V] Datacenter: Given datacenter check $o_check is not defined.\n" if $o_verbose >= 2;
      print_unknown("data center");
    }
  }else{	
    print "[V] Datacenter: No check is specified, checking datacenter status.\n" if $o_verbose >= 2;
    check_cstatus("data_centers",$o_rhev_dc);
  }
}


#***************************************************#
#  function check_dc_version                        #
#---------------------------------------------------#
#  Get version of datacenter and exit.              #
#                                                   #
#***************************************************#

sub check_dc_version{
  print "[D] check_dc_version: Called function check_dc_version\n" if $o_verbose == 3;
  my $vref = get_result("/datacenters?search=name%3D$o_rhev_dc","data_centers","version");
  my %version = %{ $vref };
  my $versions = undef;
  foreach my $v (keys %version){
    $versions .= "$v: $version{$v}{major}.$version{$v}{minor} ";
  }
  exit_plugin('ok',"Version",$versions);
}


#***************************************************#
#  Cluster checks                                   #
#---------------------------------------------------#
#  This sections covers cluster checks.             #
#                                                   #
#***************************************************#

sub check_cluster{
  print "[D] check_cluster: Called function check_cluster\n" if $o_verbose == 3;
  print "[V] Cluster: Checking cluster $o_rhev_cluster.\n" if $o_verbose >= 2;
  # is check given?
  if (defined $o_check){
    check_cluster_status("hosts") if $o_check eq "hosts";
    check_cluster_status("vms")   if $o_check eq "vms";
    check_istatus("clusters",$o_rhev_cluster,"networks")   if $o_check eq "networks";
    print_unknown("cluster");
  }else{
    print "[V] Cluster: No check is specified, checking cluster host status.\n" if $o_verbose >= 2;
    check_cluster_status("hosts");	
  }
}


#***************************************************#
#  function check_cluster_status                    #
#---------------------------------------------------#
#  Check status of all hosts which belong to this   #
#  cluster.                                         #
#  ARG1: components to check (hosts/networks/...)   #
#  Note: can be used for network status in future   #
#        releases too...                            #
#***************************************************#

sub check_cluster_status{
  print "[D] check_cluster_status: Called function check_cluster_status.\n" if $o_verbose == 3;
  print "[V] Status: Checking status of $_[0].\n" if $o_verbose >= 2;
  my $subcheck = $_[0];
  print "[D] check_cluster_status: Input parameter \$subcheck: $subcheck\n" if $o_verbose == 3;
  # get cluster id
  my $iref = get_result("/clusters?search=name%3D$o_rhev_cluster","clusters","id");
  # get host status with cluster id  
  my %id = %{ $iref };
  print "[D] check_cluster_status: \%id: " if $o_verbose == 3; print Dumper(%id) if $o_verbose == 3;
  my $size = 0;
  my $ok = 0;
  print "[D] check_cluster_status: Looping through \%id\n" if $o_verbose == 3;
  foreach my $key (keys %id){
    # get status for this cluster id
    my $rref = check_status($subcheck,"",$id{ $key },"cluster");
    my @result = @{$rref};
    print "[D] check_cluster_status: \@result: " if $o_verbose == 3; print @result . "\n" if $o_verbose == 3;
    print "[D] check_cluster_status: Looping through \@result.\n" if $o_verbose == 3;
    # count hosts in cluster and hosts with status ok
    foreach (@result){
      $size++;
      $ok++ if $_ eq "up";		# host and vm status
    }
    print "[V] Status: Cluster $key: Value of \$ok: $ok, \$size: $size " if $o_verbose >= 2;
  }
  my $state = "UP";

  $o_warn = $size unless defined $o_warn;
  $o_crit = $size unless defined $o_crit;
  print "[V] Status: warning value: $o_warn.\n" if $o_verbose >= 2;
  print "[V] Status: critical value: $o_crit.\n" if $o_verbose >= 2;
  my $perf = undef;
  if ($perfdata == 1){ 
    $perf = "|$subcheck=$ok;$o_warn;$o_crit;0;";
    print "[V] Status: Performance data: $perf.\n" if $o_verbose >= 2;
  }else{ 
    $perf = ""; 
  }
  if ( ( ($ok == $size) && ($size != 0) ) || ( ($ok > $o_warn) && ($ok > $o_crit) ) ){
    exit_plugin('ok',"Cluster","$ok/$size " . ucfirst($subcheck) . " with state $state" . $perf);
  }elsif ($ok > $o_crit){
    exit_plugin('warning',"Cluster","$ok/$size " . ucfirst($subcheck) . " with state $state" . $perf);
  }else{
    exit_plugin('critical',"Cluster","$ok/$size " . ucfirst($subcheck) . " with state $state" . $perf);
  }

  print_notfound("Cluster", $o_rhev_cluster);
}


#***************************************************#
#  Host checks                                      #
#---------------------------------------------------#
#  This sections covers host checks.                #
#                                                   #
#***************************************************#

sub check_host{
  print "[D] check_host: Called function check_host.\n" if $o_verbose == 3;
  print "[V] Host: Checking host $o_rhev_host.\n" if $o_verbose >= 2;
  # is check given?
  if (defined $o_check){
    check_cstatus("hosts","$o_rhev_host")  if $o_check eq "status";
    check_statistics("hosts","$o_rhev_host","cpu.load.avg.5m") if $o_check eq "load";
    check_statistics("hosts","$o_rhev_host","cpu") if $o_check eq "cpu";
    check_statistics("hosts","$o_rhev_host","ksm.cpu.current") if $o_check eq "ksm";
    if ($o_check eq "memory"){
      if (defined $o_subcheck){
	check_statistics("hosts","$o_rhev_host","memory") if $o_subcheck eq "mem";
	check_statistics("hosts","$o_rhev_host","swap") if $o_subcheck eq "swap";
	print_unknown("memory");
      }else{
	print "[V] Host: No subcheck is specified, checking memory usage.\n" if $o_verbose >= 2; 
	check_statistics("hosts","$o_rhev_host","memory");
      }
    }
    if ($o_check eq "network"){
      if (defined $o_subcheck){
	check_istatus("hosts",$o_rhev_host,"network") if $o_subcheck eq "status";
	check_statistics("hosts","$o_rhev_host","traffic") if $o_subcheck eq "traffic";
	check_statistics("hosts","$o_rhev_host","errors") if $o_subcheck eq "errors";
	print_unknown("network");
      }else{	check_istatus("hosts",$o_rhev_host,"network");	}
    }else{ 
      print "[V] Host: Given host check $o_check is not defined.\n" if $o_verbose >= 2;
      print_unknown("host");
    }
  }else{
    print "[V] Host: No check is specified, checking host status.\n" if $o_verbose >= 2; 
    check_cstatus("hosts","$o_rhev_host");
  }
}


#***************************************************#
#  Storage checks                                   #
#---------------------------------------------------#
#  This sections covers storage domain checks.      #
#                                                   #
#***************************************************#

sub check_storage{
  print "[D] check_storage: Called function check_storage.\n" if $o_verbose == 3;
  print "[V] Storage: Checking host $o_rhev_storage.\n" if $o_verbose >= 2;
  # is check given?
  if (defined $o_check){
    check_cstatus("storage_domains","$o_rhev_storage") if $o_check eq "status";
    check_statistics("storage_domains",$o_rhev_storage,"storage") if $o_check eq "usage";
    print_unknown("storagedomains");
  }else{	
    print "[V] Storage: No check is specified, checking storage status.\n" if $o_verbose >= 2; 
    check_cstatus("storage_domains","$o_rhev_storage");
  }
}


#***************************************************#
#  VM checks                                        #
#---------------------------------------------------#
#  This sections covers virtual machine checks.     #
#                                                   #
#***************************************************#

sub check_vm{
  print "[D] check_vm: Called function check_vm.\n" if $o_verbose == 3;
  print "[V] VM: Checking vm $o_rhev_vm.\n" if $o_verbose >= 2;
  # is check given?
  if (defined $o_check){
    check_cstatus("vms","$o_rhev_vm") if $o_check eq "status";
    check_statistics("vms","$o_rhev_vm","cpu") if $o_check eq "cpu";
    check_statistics("vms","$o_rhev_vm","memory") if $o_check eq "memory";
    if ($o_check eq "network"){
      if (defined $o_subcheck){
	check_statistics("vms","$o_rhev_vm","traffic") if $o_subcheck eq "traffic";
	check_statistics("vms","$o_rhev_vm","errors") if $o_subcheck eq "errors";
	print_unknown("network");
      }else{
	print "[V]: VM: No check is specified, checking network traffic.\n" if $o_verbose >= 2;
	check_statistics("vms","$o_rhev_vm","traffic");
      }
    }else{
      print "[V] VM: Given vm check $o_check is not defined.\n" if $o_verbose >= 2;
      print_unknown("vm");
    }
  }else{ 
    print "[V] VM: No check is specified, checking vm status.\n" if $o_verbose >= 2; 
    check_cstatus("vms","$o_rhev_vm");
  }
}


#***************************************************#
#  VM Pool checks                                   #
#---------------------------------------------------#
#  This sections covers virtual machine pool checks.#
#                                                   #
#***************************************************#

sub check_vmpool{
  print "[D] check_vmpool: Called function check_vmpool.\n" if $o_verbose == 3;
  print "[V] VM Pool: Checking vm $o_rhev_vmpool.\n" if $o_verbose >= 2;
  # is check given?
  if (defined $o_check){
    &check_vmpool_usage if $o_check eq "usage";
    print_unknown("vmpool");
  }else{	
    print "[V] VM Pool: No check is specified, checking vmpool usage.\n" if $o_verbose >= 2; 
    &check_vmpool_usage;
  }
}


#***************************************************#
#  VM Pool usage                                    #
#---------------------------------------------------#
#  Check the usage of a vm pool. Usage means number #
#  of host in status up.                            #
#                                                   #
#***************************************************#

# Check if this function can be merged with check_cluster_status to reduce amount of code.
# Planned for version 1.1

sub check_vmpool_usage{
  print "[D] check_vmpool_usage: Called function check_vmpool_usage.\n" if $o_verbose == 3;
  # get vmpool id
  my $iref = get_result("/vmpools?search=name%3D$o_rhev_vmpool","vmpools","id");
  # get vm status with vmpool id  
  my %id = %{ $iref };
  print "[D] check_vmpool_usage: \%id: " if $o_verbose == 3; print Dumper(%id) if $o_verbose == 3;
  my $size = 0;
  my $ok = 0;
  print "[D] check_vmpool_usage: Looping through \%id\n" if $o_verbose == 3;
  foreach my $key (keys %id){
    my $rref = check_status("vms","",$id{ $key },"vmpool");
    my @result = @{$rref};
    print "[D] check_vmpool_usage: \@result: " if $o_verbose == 3; print @result . "\n" if $o_verbose == 3;
    print "[D] check_vmpool_usage: Looping through \@result.\n" if $o_verbose == 3;
    # count vms and vms with status up belonging to this pool
    foreach (@result){
      $size++;
      $ok++ if $_ eq "up";		# host and vm status
    }
    print "[V] Usage: VM Pool $key: Value of \$ok: $ok, \$size: $size " if $o_verbose >= 2;
  }

  $o_warn = $size unless defined $o_warn;
  $o_crit = $size unless defined $o_crit;
  print "[V] Usage: warning value: $o_warn.\n" if $o_verbose >= 2;
  print "[V] Usage: critical value: $o_crit.\n" if $o_verbose >= 2;
  my $perf = undef;
  if ($perfdata == 1){ 
    $perf = "|vmpool=$ok;$o_warn;$o_crit;0;";
    print "[V] Status: Performance data: $perf.\n" if $o_verbose >= 2;
  }else{ 
    $perf = ""; 
  }
  if ( ( $ok < $size ) && ( $ok < $o_warn ) && ( $ok < $o_crit ) ){
    exit_plugin('ok',"VM Pool",$size-$ok . "/$size vms free" . $perf);
  }elsif ($ok < $o_crit){
    exit_plugin('warning',"VM Pool",$size-$ok . "/$size vms free" . $perf);
  }else{
    exit_plugin('critical',"VM Pool",$size-$ok . "/$size vms free" . $perf);
  } 
  print_notfound("VM Pool", $o_rhev_vmpool);
}


#***************************************************#
#  Status check                                     #
#---------------------------------------------------#
#  Check the status of a datacenter, cluster, host  #
#  and a virtual machine.                           #
#  ARG1: component to check                         #
#  ARG2: search string                              #
#  ARG3: ID of Cluster or VM Pool (optional)        #
#  ARG4: search for Cluster or VM Pool (optional)   #
#***************************************************#

sub check_status {
  print "[D] check_status: Called function check_status.\n" if $o_verbose == 3;
  print "[V] Status: Checking status of $_[0].\n" if $o_verbose >= 2;
  my $components = $_[0];
  my $search	 = $_[1];
  my $id	 = undef;
  my $searchid	 = undef;
  $id 		 = $_[2] if $_[2];
  $searchid 	 = $_[3] if $_[3];
  print "[D] check_status: Input parameter \$components: $components\n" if $o_verbose == 3;
  print "[D] check_status: Input parameter \$search: $search\n" if $o_verbose == 3;
  print "[D] check_status: Input parameter \$id: $id\n" if ( ($o_verbose == 3) && (defined $id) );
  print "[D] check_status: Input parameter \$searchid: $searchid\n" if ( ($o_verbose == 3) && (defined $searchid) );
  # get right format
  print "[D] check_status: Converting variables.\n" if $o_verbose == 3;
  my $component = $components;
  chop $component;
  $components =~ s/_//g;
  print "[D] check_status: Converted variable \$components: $components\n" if $o_verbose == 3;
  print "[D] check_status: Converted variable \$component: $component\n" if $o_verbose == 3;
  # REST-API call
  # e.g. /api/datacenters?search=%3D
  # or   /api/datacenters/
  # call search path only if input is given
  my $rref = undef;
  if ($search eq ""){
    $rref = rhev_connect("/$components/");
  }else{
    $rref = rhev_connect("/$components?search=name%3D$search");
  }
  my %result = %{$rref};
  print "[D] check_status: \%result: " if $o_verbose == 3; print Dumper(%result) if $o_verbose == 3;
  
  # loop through multiple results
  print "[D] check_status: Looping through \%result\n" if $o_verbose == 3;
  foreach my $key (keys %result){
    if (! $result{$component}{id} ){
      # multiple results
      print "[V] Status: Multiple hash entries found.\n" if $o_verbose >= 2;
      my @return;
      print "[D] check_status: Looping through second hash level.\n" if $o_verbose == 3;
      foreach my $value (keys %{ $result{$key} }){
	if (defined $id){
	  # check if vm status is needed for cluster or vmpool query
	  my $sub = "cluster";
	     $sub = "vmpool" if $searchid eq "vmpool";
	  print "[D] check_status: Variable \$sub: $sub.\n" if $o_verbose == 3;
	  if ($components eq "networks") { 
	    print "[V] Status: Value of $value: $result{$key}{$value}{status}{state}.\n" if $o_verbose >= 2;
	    push @return, $result{$key}{$value}{status}{state}; next; 
	  }
	  next unless defined $result{$key}{$value}{$sub}{id};
	  print "[V] Status: $sub-Value of $value: $result{$key}{$value}{status}{state}.\n" if $o_verbose >= 2;
	  push @return, $result{$key}{$value}{status}{state} if $result{$key}{$value}{$sub}{id} eq $id;
	}else{
	  print "[V] Status: Value of $value: $result{$key}{$value}{status}{state}.\n" if $o_verbose >= 2;
	  push @return, $result{$key}{$value}{status}{state};
	}
      }
      return \@return;

    }else{
      my @return;
      # single result
      print "[V] Status: single hash entry found.\n" if $o_verbose >= 2;
      if (defined $id){
	my $sub = "cluster";
	   $sub = "vmpool" if $searchid eq "vmpool";
	print "[D] check_status: Variable \$sub: $sub.\n" if $o_verbose == 3;
	if ($components eq "networks") { 
	  push @return, $result{$component}{status}{state}; 
	  print "[V] Status: Result: $result{$component}{status}{state}.\n" if $o_verbose >= 2;
	}
	else { 
	  next unless defined $result{$component}{$sub}{id};
	  print "[V] Status: Result: $result{$component}{status}{state}.\n" if $o_verbose >= 2;
	  print "[V] Status: $sub-ID: $result{$component}{$sub}{id}.\n" if $o_verbose >= 2;
	  push @return, $result{$component}{status}{state} if $result{$component}{$sub}{id} eq $id;
	}
      }else{
        print "[D] check_status: Converting variable \$components.\n" if $o_verbose == 3;
        chop $components;
        print "[D] check_status: Converted variable \$components: $components\n" if $o_verbose == 3;
        # storage domains with status active don't have <status><state>!
        if ( (! defined $result{$component}{status}{state}) && (! defined $result{$component}{id}) ){ 
          print_notfound(ucfirst($components), $search);
        }
        print "[V] Status: Result: $result{$component}{status}{state}\n" if $o_verbose >= 2;
	push @return, $result{$component}{status}{state};
      }
      return \@return;
    }
  }
  print "[V] Status: Search pattern $search not found.\n" if $o_verbose >= 2;
  print_notfound(ucfirst($components), $search);
}


#***************************************************#
#  Status check with ID search                      #
#---------------------------------------------------#
#  Check the status of storage domains, networks or #
#  host and vm nics.                                #
#  ARG1: component to check                         #
#  ARG2: search string                              #
#  ARG3: subcheck                                   #
#***************************************************#

sub check_istatus{
  print "[D] check_istatus: Called function check_istatus.\n" if $o_verbose == 3;
  print "[V] Status: Checking status of $_[0].\n" if $o_verbose >= 2;
  my $component = $_[0];
  my $search    = $_[1];
  my $subcheck  = $_[2];
  print "[D] check_istatus: Input parameter \$component: $component\n" if $o_verbose == 3;
  print "[D] check_istatus: Input parameter \$search: $search\n" if $o_verbose == 3;
  print "[D] check_istatus: Input parameter \$subcheck: $subcheck\n" if $o_verbose == 3;
  print "[D] check_istatus: Converting variables.\n" if $o_verbose == 3;
  my $url	= $component;
  $url =~ s/_//g;
  print "[D] check_istatus: Converted variable \$url: $url\n" if $o_verbose == 3;
  # get datacenter or cluster id
  my $iref = get_result("/$url?search=name%3D$search",$component,"id");
  my %id = %{ $iref };
  print "[D] check_istatus: \%id: " if $o_verbose == 3; print Dumper(%id) if $o_verbose == 3;

  my $size = 0;
  my $ok = 0;
  # for hosts the network status can be found under nics not under networks
  $subcheck = "nics" if $component eq "hosts";
  print "[D] check_istatus: Looping through \%id\n" if $o_verbose == 3;
  foreach my $key (keys %id){
    print "[V] Status: $key: $id{ $key }\n" if $o_verbose >= 2;
    # REST-API call - get network and storage status
    my $rref = rhev_connect("/$url/$id{ $key }/$subcheck");
    my %result = %{$rref};
    print "[D] check_istatus: \%result: " if $o_verbose == 3; print Dumper(%result) if $o_verbose == 3;
    print "[D] check_istatus: Looping through \%result\n" if $o_verbose == 3;
    foreach my $value (keys %result){
      if (! $result{$value}{id}){
	print "[V] Status: Multiple hash entries found.\n" if $o_verbose >= 2;
	print "[D] check_istatus: Looping through second hash level.\n" if $o_verbose == 3;
	foreach my $val (keys %{ $result{$value} }){
	  next unless defined( $result{$value}{$val}{status}{state} );	# don't count virtual nics
	  # only count specifed nics
	  my $match = 0;
	  if (scalar @o_nics > 0){
	    for (my $n=0;$n<=$#o_nics;$n++){
	      $match = 1 if $val =~ /$o_nics[$n]$/;
	    }
	    next unless $match == 1;
	  }
          $size++;
	  $ok++ if $result{$value}{$val}{status}{state} eq "active";		# storagedomain
	  $ok++ if $result{$value}{$val}{status}{state} eq "operational";	# network
	  $ok++ if $result{$value}{$val}{status}{state} eq "up";		# nics
	  print "[V] Status: Value of $val: $result{$value}{$val}{status}{state}.\n" if $o_verbose >= 2;
	}
      }else{
        print "[V] Status: single hash entry found.\n" if $o_verbose >= 2;
	next unless $result{$value}{status}{state};	# don't count virtual nics
	# only count specifed nics
	my $match = 0;
	if (scalar @o_nics > 0){
	  for (my $n=0;$n<=$#o_nics;$n++){
	    $match = 1 if $result{$value}{name} =~ /$o_nics[$n]/;
	  }
	  next unless $match == 1;
	}
        $size++;
	$ok++ if $result{$value}{status}{state} eq "active";		# storagedomain
	$ok++ if $result{$value}{status}{state} eq "operational";	# network
	$ok++ if $result{$value}{status}{state} eq "up";		# nics
	print "[V] Status: Value of $result{$value}{name}: $result{$value}{status}{state}\n" if $o_verbose >= 2;
      }
    }
    print "[V] Status: $ok/$size " . ucfirst($subcheck) . " in Cluster $key OK\n" if $o_verbose >= 2;
  }
  my $state = undef;
  if ($subcheck eq "networks"){	$state = "Operational"; }else{ $state = "Active"; }
  $o_warn = $size unless defined $o_warn;
  $o_crit = $size unless defined $o_crit;
  print "[D] check_istatus: Variable \$state: $state.\n" if $o_verbose == 3;
  print "[V] Eval Status: warning value: $o_warn.\n" if $o_verbose >= 2;
  print "[V] Eval Status: critical value: $o_crit.\n" if $o_verbose >= 2;
  
  my $perf = undef;
  if ($perfdata == 1){ 
    $perf = "|$subcheck=$ok;$o_warn;$o_crit;0;";
    print "[V] Eval Status: Performance data: $perf.\n" if $o_verbose >= 2;
  }else{ 
    $perf = ""; 
  }
  if ( ( ($ok == $size) && ($size != 0) ) || ( ($ok > $o_warn) && ($ok > $o_crit) ) ){
    exit_plugin('ok',ucfirst($subcheck),"$ok/$size " . ucfirst($subcheck) . " with state $state" . $perf);
  }elsif ($ok > $o_crit){
    exit_plugin('warning',ucfirst($subcheck),"$ok/$size " . ucfirst($subcheck) . " with state $state" . $perf);
  }else{
    exit_plugin('critical',ucfirst($subcheck),"$ok/$size " . ucfirst($subcheck) . " with state $state" . $perf);
  }
#  print_notfound("Storage", "???");
}


#***************************************************#
#  Performance statistics check                     #
#---------------------------------------------------#
#  Check performance statistics like load, memory,  #
#  traffic of datacenters, hosts, storage domains   #
#  and vms.                                         #
#  ARG1: component to check                         #
#  ARG2: search string                              #
#  ARG3: statistics                                 #
#***************************************************#

sub check_statistics{
  print "[D] check_statistics: Called function check_statistics.\n" if $o_verbose == 3;
  print "[V] Statistics: Checking statistics of $_[0].\n" if $o_verbose >= 2;
  my $component = $_[0];
  my $search    = $_[1];
  my $statistics  = $_[2];
  print "[D] check_statistics: Input parameter \$component: $component\n" if $o_verbose == 3;
  print "[D] check_statistics: Input parameter \$search: $search\n" if $o_verbose == 3;
  print "[D] check_statistics: Input parameter \$statistics: $statistics\n" if $o_verbose == 3;
  print "[D] check_statistics: Converting variables.\n" if $o_verbose == 3;
  my $url	= $component;
  $url =~ s/_//g;
  print "[D] check_statistics: Converted variable \$url: $url\n" if $o_verbose == 3;

  # get datacenter, host or vm id
  my $iref = get_result("/$url?search=name%3D$search",$component,"id");
  my %id = %{ $iref };
  print "[D] check_statistics: \%id: " if $o_verbose == 3; print Dumper(%id) if $o_verbose == 3;

  my $status = "unknown";
  my $output = undef;

  my %rethash;
  my $subcheck = "statistics"; 
     $subcheck = "nics" if $statistics eq "traffic";
     $subcheck = "nics" if $statistics eq "errors";
     $subcheck = ""     if $statistics eq "storage";
     $subcheck = "storagedomains" if $statistics eq "dcstorage";
     $statistics = "storage" if $statistics eq "dcstorage";	# we can use "normal" storage domain behavior now
  print "[D] check_statistics: Looping through \%id.\n" if $o_verbose == 3;
  foreach my $key (keys %id){
    print "[V] Statistics: $key: $id{ $key }.\n" if $o_verbose >= 2;

    # cpu, memory, load are located under /api/hosts|vms/id/statistics
    # nics, disks are located under /api/hosts|vms/id/nics|disks/id/statistics
    if ($statistics eq "traffic" || $statistics eq "errors"){
      # check nics and disks
      my $nref = get_result("/$url/$id{ $key }/$subcheck","nics","id");
      my %nics = %{ $nref };
      print "[D] check_statistics: \%nics: " if $o_verbose == 3; print Dumper(%nics) if $o_verbose == 3;
      foreach my $nic (keys %nics){
	# only count specifed nics
	my $match = 0;
	if (scalar @o_nics > 0){
	  for (my $n=0;$n<=$#o_nics;$n++){
	    $match = 1 if $nic =~ /$o_nics[$n]$/;
	  }
	  next unless $match == 1;
	}
	print "[D] check_statistics: $nic: $nics{$nic}\n" if $o_verbose == 3;
        my $iret = get_stats($component,$id{ $key },"nics/$nics{$nic}/statistics",$statistics,$key);
        my %temp = %{ $iret };
        $rethash{$key}{$nic} = $temp{$key};
        print "[D] check_statistics: \%rethash: " if $o_verbose == 3; print Dumper(%rethash) if $o_verbose == 3;
      }
      if (! %rethash){
	$output = "No nics found matching your search query!";
	$status = 'critical';
      }
    }else{
      # check cpu, load and memory
      my $iret = get_stats($component,$id{ $key },$subcheck,$statistics,$key);
      my %temp = %{ $iret };
      $rethash{$key} = $temp{$key};
      print "[D] check_statistics: \%rethash: " if $o_verbose == 3; print Dumper(%rethash) if $o_verbose == 3;
    }
  }

  # default values for warning and critical if missing
  if (! defined $o_warn){
    $o_warn = 60;
    $o_warn = 2   if $statistics eq "cpu.load.avg.5m";
    $o_warn = 500 if $statistics eq "traffic";
    $o_warn = 5   if $statistics eq "errors";
  }
  if (! defined $o_crit){
    $o_crit = 80;
    $o_crit = 4   if $statistics eq "cpu.load.avg.5m";
    $o_crit = 700 if $statistics eq "traffic";
    $o_crit = 10  if $statistics eq "errors";
  }
  print "[V] Statistics: warning value: $o_warn.\n" if $o_verbose >= 2;
  print "[V] Statistics: critical value: $o_crit.\n" if $o_verbose >= 2;

  my $perf   = "|";
  # use Bytes instead of Bites for performance data
  $o_warn = $o_warn / 8 if $statistics eq "traffic";
  $o_crit = $o_crit / 8 if $statistics eq "traffic";
  # go through hash
  foreach my $key (keys %rethash){
    print "[D] check_statistics: \%rethash: " if $o_verbose == 3; print Dumper(%rethash) if $o_verbose == 3;

    if ($statistics eq "traffic" || $statistics eq "errors"){
      # go through nic hash
      foreach my $nic (keys %{ $rethash{$key} } ){
	    my $uom = 'MB' if $statistics eq "traffic";
           $uom = 'c'  if $statistics eq "errors";
        my $used = "used" unless $statistics eq "cpu.load.avg.5m";
           $used = "" if $statistics eq "errors";
        if ($perfdata == 1){
          $perf .= $statistics . "_" . "$nic=$rethash{$key}{$nic}{usage}$uom;$o_warn;$o_crit;0; ";
          # loop through hash if stats are given
          foreach my $stat (keys %{ $rethash{ $key }{ $nic }{stats} }){
	        $perf .= $stat . "_" . "$nic=$rethash{$key}{$nic}{stats}{$stat};";
          }
          print "[V] Statistics: Performance data: $perf.\n" if $o_verbose >= 2;
        }else{
          $perf = "";
        }

        # process errors - we need a temp file for this as errors are an increasing value
        if ($statistics eq "errors"){
          my $errors = check_nic_errors($key, $nic, $rethash{$key}{$nic}{usage});
          # update %rethash with real errors
          $rethash{$key}{$nic}{usage} = $errors;
        }

        if ( ($rethash{$key}{$nic}{usage} < $o_warn) && ($rethash{$key}{$nic}{usage} < $o_crit) ){
          $status = "ok" unless ($status eq "warning" || $status eq "critical");
          print "[V] Statistics: Status: $status.\n" if $o_verbose >= 2;
        }elsif ($rethash{$key}{$nic}{usage} < $o_crit){
          $status = "warning" unless $status eq "critical";
        }else{
          $status = "critical";
        }
        # Display Mbit/s instead of MB
        $uom = " Mbit/s" if $uom eq "MB";
        $uom = " Errors" if $uom eq "c";
        $output .= "$nic: $rethash{$key}{$nic}{usage}$uom ";
        print "[V] Statistics: Output: $output\n" if $o_verbose >= 2;
      }
      $output .= "($key) ";
    }else{
      # go through memory, load and cpu hash
      my $uom = "";
         $uom = '%' unless $statistics eq "cpu.load.avg.5m";
      my $used = "";
         $used = "used" unless $statistics eq "cpu.load.avg.5m";
      if ($perfdata == 1){
        my $tmp = $statistics;
           $tmp .= "_" . $key if $statistics eq "storage";
           $perf .= "$tmp=$rethash{$key}{usage}$uom;";
        # always use warning and critical values in percentage for storagedomains to
        # avoid breaking existing pnp graphs
        if (defined $rethash{$key}{warnPercent}){
           $perf .= "$rethash{$key}{warnPercent};";
        }else{
           $perf .= "$o_warn;";
        }
        if (defined $rethash{$key}{critPercent}){
           $perf .= "$rethash{$key}{critPercent};";
        }else{
           $perf .= "$o_crit;";
        }
          $perf .= "0; ";
        # loop through hash if stats are given
        foreach my $stat (keys %{ $rethash{ $key }{stats} }){
	      $stat .= "_" . $key if $statistics eq "storage";
	      $perf .= "$stat=$rethash{$key}{stats}{$stat};;;0; ";
        }
        print "[V] Statistics: Performance data: $perf.\n" if $o_verbose >= 2;
      }else{
        $perf = "";
      }

      # storage domains don't provide correct values when not attached
      if ($rethash{$key}{usage} == -1){
	    $status = "critical";
	    $rethash{$key}{usage} = "?";
	    print "[V] Statistics: Status: $status.\n" if $o_verbose >= 2;
      }else{
      	my $warn_key = "usage";
      	my $crit_key = "usage";	
      	# are warning and critical values in bytes or %?
      	$warn_key = "usageBytes" if $o_warn > 100;
      	$crit_key = "usageBytes" if $o_crit > 100;
      	if ($o_warn > 100){
      	  if ($rethash{$key}{$warn_key} > $o_warn){
      	  	$status = "ok" unless ($status eq "warning" || $status eq "critical");
      	  }else{
      	  	$status = "warning" unless $status eq "critical";
      	  }
      	}else{
      	  if ($rethash{$key}{$warn_key} < $o_warn){
      	  	$status = "ok" unless ($status eq "warning" || $status eq "critical");
      	  }else{
      	  	$status = "warning" unless $status eq "critical";
      	  }
      	}
      	if ($o_crit > 100){
      	  if ($rethash{$key}{$crit_key} > $o_crit){
      	  	$status = "ok" unless ($status eq "warning" || $status eq "critical");
      	  }else{
      	  	$status = "critical";
      	  }
      	}else{
      	  if ($rethash{$key}{$crit_key} < $o_crit){
      	  	$status = "ok" unless ($status eq "warning" || $status eq "critical");
      	  }else{
      	  	$status = "critical";
      	  }
      	}
      }
      $output .= "$rethash{$key}{usage}$uom $used ($key) ";
      print "[V] Statistics: Output: $output\n" if $o_verbose >= 2;
    }
  }
  if (! defined $output || ! defined $perf){
  	exit_plugin("unknown",$statistics,"Performance data not found!");
  }else{
    exit_plugin($status,$statistics,$output.$perf);
  }
  
}


#***************************************************#
#  Function: get_stats                              #
#---------------------------------------------------#
#  Get performance statistics like load, memory,    #
#  traffic of datacenters, hosts, storage domains   #
#  and vms and return to get_statistics.            #
#  ARG1: component to check                         #
#  ARG2: ID                                         #
#  ARG2: search string                              #
#  ARG3: path to statistics                         #
#  ARG4: stats type (e.g. traffic)                  #
#  ARG5: key (e.g. hostname)                        #
#***************************************************#

sub get_stats {
  print "[D] get_stats: Called function get_stats.\n" if $o_verbose == 3;
  print "[V] Stats: Checking statistics of $_[0].\n" if $o_verbose >= 2;
  my %rethash;
  my $component = $_[0];
  my $statistics = $_[3];
  my $key = $_[4];
  print "[D] get_stats: Input parameter \$component: $component\n" if $o_verbose == 3;
  print "[D] get_stats: Input parameter \$_[1]: $_[1]\n" if $o_verbose == 3;
  print "[D] get_stats: Input parameter \$_[2]: $_[2]\n" if $o_verbose == 3;
  print "[D] get_stats: Input parameter \$statistics: $statistics\n" if $o_verbose == 3;
  print "[D] get_stats: Input parameter \$key: $key\n" if $o_verbose == 3;
  print "[D] get_stats: Converting variables.\n" if $o_verbose == 3;
  my $url	= $component;
  $url =~ s/_//g;
  print "[D] get_stats: Converted variable \$url: $url\n" if $o_verbose == 3;
  # REST API-Call -> e.g. /hosts/41df3b5e-c9de-11e1-92a7-0025907587a8/statistics
  #                       /hosts/41df3b5e-c9de-11e1-92a7-0025907587a8/nics/5cc1b27e-d51b-44aa-96e6-fa89ecd7c9e8/statistics
  my $rref = rhev_connect("/$url/$_[1]/$_[2]");
  my %result = %{$rref};
  print "[D] get_stats: \%result: "if $o_verbose == 3; print Dumper(%result) if $o_verbose ==3;
  print "[D] get_stats: Looping through \%result.\n" if $o_verbose == 3;

  # deal with empty results (e.g. datacenters without storage domains attached)
  exit_plugin('critical',$statistics,"No $statistics found!") if (! %result);

  foreach my $value (keys %result){
    if ($statistics eq "cpu.load.avg.5m"){
      print "[V] Statistics: Getting CPU Load.\n" if $o_verbose >= 2;
      $rethash{$key}{usage} = $result{statistic}{$statistics}{values}{value}{datum};
      print "[V] Statistics: CPU Load of $key: $result{statistic}{$statistics}{values}{value}{datum}.\n" if $o_verbose >= 2;
    }elsif ($statistics eq "cpu"){
      print "[V] Statistics: Getting CPU Usage.\n" if $o_verbose >= 2;
      # cpu is different for hosts and vms
      my $cpu_usage = undef;
      if ($component eq "hosts"){
	my $cpu_idle   = $result{statistic}{"cpu.current.idle"}{values}{value}{datum};
	my $cpu_system = $result{statistic}{"cpu.current.system"}{values}{value}{datum};
	my $cpu_user   = $result{statistic}{"cpu.current.user"}{values}{value}{datum};
	   $cpu_usage  = 100 - $cpu_idle;
	$rethash{$key}{stats}{"cpu.current.idle"} = $cpu_idle;
	$rethash{$key}{stats}{"cpu.current.system"} = $cpu_system;
	$rethash{$key}{stats}{"cpu.current.user"} = $cpu_user;
      }else{
	my $cpu_guest  = $result{statistic}{"cpu.current.guest"}{values}{value}{datum};
	my $cpu_hypervisor = $result{statistic}{"cpu.current.hypervisor"}{values}{value}{datum};
	   $cpu_usage  = $result{statistic}{"cpu.current.total"}{values}{value}{datum};
#	   $cpu_usage  = 100 - $cpu_total;
	$rethash{$key}{stats}{"cpu.current.guest"} = $cpu_guest;
	$rethash{$key}{stats}{"cpu.current.hypervisor"} = $cpu_hypervisor;
      }
      $rethash{$key}{usage} = $cpu_usage;
      print "[V] Statistics: CPU usage of $key: $cpu_usage.\n" if $o_verbose >= 2;
    }elsif ($statistics eq "ksm.cpu.current"){
      print "[V] Statistics: Getting KSM CPU Usage.\n" if $o_verbose >= 2;
      $rethash{$key}{usage} = $result{statistic}{$statistics}{values}{value}{datum};
      print "[V] Statistics: KSM CPU Usage of $key: $result{statistic}{$statistics}{values}{value}{datum}.\n" if $o_verbose >= 2;
    }elsif ($statistics eq "memory"){
      # memory is different for hosts and vms
      print "[V] Statistics: Getting Memory Usage.\n" if $o_verbose >= 2;
      my $memory_usage = undef;
      if ($component eq "hosts"){
	my $mem_used    = $result{statistic}{"memory.used"}{values}{value}{datum};
	my $mem_buffers = $result{statistic}{"memory.buffers"}{values}{value}{datum};
	my $mem_cached  = $result{statistic}{"memory.cached"}{values}{value}{datum};
	my $mem_free    = $result{statistic}{"memory.free"}{values}{value}{datum};
	my $mem_total   = $result{statistic}{"memory.total"}{values}{value}{datum};
	$memory_usage   = sprintf("%.2f", 100 - $mem_free / $mem_total * 100);
	$rethash{$key}{stats}{"memory.used"} = $mem_used;
	$rethash{$key}{stats}{"memory.buffers"} = $mem_buffers;
	$rethash{$key}{stats}{"memory.cached"} = $mem_cached;
      }else{
	my $mem_installed = $result{statistic}{"memory.installed"}{values}{value}{datum};
	my $mem_used      = $result{statistic}{"memory.used"}{values}{value}{datum};
	  # fix issue with negative memory usage
	  if ($mem_used < 0){
        $mem_used = $mem_installed + $mem_used;
	  }
  	   $memory_usage  = sprintf("%.2f", $mem_used / $mem_installed * 100);
      }
      $rethash{$key}{usage} = $memory_usage;
      print "[V] Statistics: Memory Usage of $key: $memory_usage.\n" if $o_verbose >= 2;
    }elsif ($statistics eq "swap"){
      print "[V] Statistics: Getting Swap Usage.\n" if $o_verbose >= 2;
      my $swap_used  = $result{statistic}{"swap.used"}{values}{value}{datum};
      my $swap_total = $result{statistic}{"swap.total"}{values}{value}{datum};
      my $swap_usage = sprintf("%.2f", $swap_used / $swap_total * 100);
      $rethash{$key}{usage} = $swap_usage;
      print "[V] Statistics: Swap Usage of $key: $swap_usage.\n" if $o_verbose >= 2;
    }elsif ($statistics eq "traffic" || $statistics eq "errors"){
      my $network = undef;
      if ($statistics eq "traffic"){
        print "[V] Statistics: Getting Network Traffic Usage.\n" if $o_verbose >= 2;
	    $network = "data.current";
      }else{
        print "[V] Statistics: Getting Network Errors.\n" if $o_verbose >= 2; 
	    $network = "errors.total";
      }
      # TODO: check this!
      # RHEV API documentation says that these values are in bytes/second but it seems as these are
      # Mbyte/second
      my $rx = $result{statistic}{"$network.rx"}{values}{value}{datum};
      my $tx = $result{statistic}{"$network.tx"}{values}{value}{datum};
      my $total = ($rx + $tx);
      # convert to Mbit/s
      $total = $total * 8 if $statistics eq "traffic";
      $rethash{$key}{usage} = $total;
      $rethash{$key}{rx} = $rx;
      $rethash{$key}{tx} = $tx;
      print "[V] Statistics: Traffic Usage of $key: $total.\n" if $o_verbose >= 2 && $statistics eq "traffic";
      print "[V] Statistics: Errors on $key: $total.\n" if $o_verbose >= 2 && $statistics eq "errors";
    }elsif ($statistics eq "storage"){
      print "[V] Statistics: Getting Storage Usage.\n" if $o_verbose >= 2;
      my ($storage_available,$storage_used) = undef;
      # storage attached to datacenter has different path to direct checked storagedomains
      if (! $result{id}){ 
	if (! $result{$value}{id}){
          # loop through storage domains
          foreach my $storage (keys %{ $result{ $value } }){
	    $storage_available  = $result{$value}{$storage}{available}  if defined $result{$value}{$storage}{available};
	    $storage_used       = $result{$value}{$storage}{used}       if defined $result{$value}{$storage}{used};
	  }
	}else{
	  $storage_available  = $result{$value}{available}  if defined $result{$value}{available};
	  $storage_used       = $result{$value}{used}       if defined $result{$value}{used};
	}
      }else{
        $storage_available = $result{available} if defined $result{available};
        $storage_used      = $result{used}      if defined $result{used};
      }
      my $storage_usage     = sprintf("%.2f", $storage_used / ($storage_used + $storage_available) * 100) if defined $storage_available;
         $storage_usage     = -1 if ! defined $storage_available;
      $rethash{$key}{usage} = $storage_usage;
      $rethash{$key}{usageBytes} = $storage_used;
      # set default values for warning and critical
      $o_warn = 60 unless defined $o_warn;
      $o_crit = 80 unless defined $o_crit;
      # also return warning and critical values in % to avoid breaking existing pnp graphs
      $rethash{$key}{warnPercent} = sprintf("%.2f", $o_warn / ($storage_used + $storage_available) *100) if $o_warn > 100;
      $rethash{$key}{critPercent} = sprintf("%.2f", $o_crit / ($storage_used + $storage_available) *100) if $o_crit > 100;
      print "[V] Statistics: Storage Usage of $key: $storage_usage.\n" if $o_verbose >= 2;
    }
  }
  return \%rethash;
}


#***************************************************#
#  Function print_unknown                           #
#---------------------------------------------------#
#  Prints an error message that the given check is  #
#  invalid and prints help page.                    #
#  ARG1: check                                      #
#***************************************************#

sub print_unknown{
  print "RHEV $status{'unknown'}: Unknown $_[0] check is given.\n";
  print_help;
  exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function exit_plugin                             #
#---------------------------------------------------#
#  Prints plugin output and exits with exit code.   #
#  ARG1: status code (ok|warning|cirtical|unknown)  #
#  ARG2: check                                      #
#  ARG3: additional information                     #
#***************************************************#

sub exit_plugin{
  print "RHEV $status{$_[0]}: $_[1] $_[0] - $_[2]\n";
  exit $ERRORS{$status{$_[0]}};
}


#***************************************************#
#  Function get_result                              #
#---------------------------------------------------#
#  Get the requestet information from API.          #
#  ARG1: API path                                   #
#  ARG2: XML component                              #
#  ARG3: result                                     #
#***************************************************#

sub get_result{
  print "[D] get_result: Called function get_result.\n" if $o_verbose == 3;
  my $xml = $_[1];
  my $search = $_[2];
  print "[D] get_result: Input parameter \$_[0]: $_[0]\n" if $o_verbose == 3;
  print "[D] get_result: Input parameter \$xml: $xml\n" if $o_verbose == 3;
  print "[D] get_result: Input parameter \$search: $search\n" if $o_verbose == 3;
  my $rref = rhev_connect($_[0]);
  my %result = %{$rref};
  print "[D] get_result: \%result: " if $o_verbose == 3; print Dumper(%result) if $o_verbose == 3;
  my %return;

  print "[D] get_result: Looping through \%result.\n" if $o_verbose == 3;
  foreach my $key (keys %result){
  chop $xml;
    if (! $result{$xml}{$search} ){
      # multiple results or RHEV 3.1 host nics
      next if $key eq 'actions';	# RHEV 3.1 host nic found!
      my $retval;
      # multiple results
      foreach my $value (keys %{ $result{$key} }){
	print "$value: $result{$key}{$value}{$search}\n" if $o_verbose >= 2;
	$return{$value} = $result{$key}{$value}{$search};
      }
    }else{
      print "$result{$xml}{name}: $result{$xml}{$search}\n" if $o_verbose >= 2;
      %return = ( $result{$xml}{name} => $result{$xml}{$search} );
    }
  }
  return \%return;
}


#***************************************************#
#  Function print_notfound                          #
#---------------------------------------------------#
#  Information that a component (data center, host  #
#  or cluster) was not found.                       #
#  ARG1: component                                  #
#  ARG2: name                                       #
#***************************************************#

sub print_notfound{
  print "[D] print_notfound: Called function print_notfound.\n" if $o_verbose == 3;
  print "[D] print_notfound: Input parameter: $_[0]\n" if $o_verbose == 3;
  print "[D] print_notfound: Input parameter: $_[1]\n" if $o_verbose == 3;
  print "RHEV $status{'unknown'}: $_[0] $_[1] not found.\n";
  exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function check_cstatus                           #
#---------------------------------------------------#
#  Call check_status and eval_status afterwards.    #
#  ARG1: component                                  #
#  ARG2: search string                              #
#***************************************************#

sub check_cstatus{
  print "[D] check_cstatus: Called function check_cstatus.\n" if $o_verbose == 3;
  my $component = $_[0];
  my $rref = check_status($component,$_[1]);
  print "[D] check_cstatus: Input parameter \$component: $component\n" if $o_verbose == 3;
  print "[D] check_cstatus: Input parameter: $_[1]\n" if $o_verbose == 3;
  print "[D] check_cstatus: Converting variable $component.\n" if $o_verbose == 3;
  $component =~ s/_//g;
  print "[D] check_cstatus: Converted variable \$component: $component\n" if $o_verbose == 3;
  eval_status(ucfirst($component),$rref);
}


#***************************************************#
#  Function check_nic_errors                        #
#---------------------------------------------------#
#  Check if nic errors increased since last run.    #
#  ARG1: host                                       #
#  ARG1: nic                                        #
#  ARG1: errors                                     #
#***************************************************#

sub check_nic_errors{
  print "[D] check_nic_errors: Called function check_nic_errors.\n" if $o_verbose == 3;
  my $host = $_[0];
  my $nic = $_[1];
  my $error = $_[2];
  print "[D] check_nic_errors: Input parameter \$host: $host\n" if $o_verbose == 3;
  print "[D] check_nic_errors: Input parameter \$nic: $nic\n" if $o_verbose == 3;
  print "[D] check_nic_errors: Input parameter \$error: $error\n" if $o_verbose == 3;
  
  my $return;
  # check if errors file exist
  if (! -d $cookie . "/" . $host){
   	if (! mkdir $cookie . "/" . $host){
   	  print "Can't create directory: $cookie/$host: $!";
   	  exit $ERRORS{$status{'unknown'}};
   	}
  }
  # process errors
  if (-e $cookie ."/" . $host . "/" . $nic){
   	if (! -r $cookie . "/" . $host . "/" . $nic){
   	  print "Interface errors file $cookie/$host/$nic isn't readable!\n";
   	  exit $ERRORS{$status{'unknown'}};
   	}
   	my $errors = `cat $cookie/$host/$nic`;
   	if ($errors !~ /^(\d)+$/){
   	  print "Interface errors in file $cookie/$host/$nic not a number: $errors\n";
        exit $ERRORS{$status{'unknown'}};
   	}
   	$return = $error - $errors;
   	# set counter to 0 if value is negative
   	# this can happen if counter is reseted on host (e.g. reboot)
   	$return = 0 if $return < 0;
  	write_errors_file($cookie . "/" . $host . "/" . $nic, $return);
  }else{
  	$return = $error;
  	write_errors_file($cookie . "/" . $host . "/" . $nic, $return);
  }
  
  return $return;
  
}

#***************************************************#
#  Function write_errors_file                       #
#---------------------------------------------------#
#  Write interface errors into a file.              #
#  ARG1: filename                                   #
#  ARG2: content                                    #
#***************************************************#

sub write_errors_file{
  print "[D] write_errors_file: Called function write_errors_file.\n" if $o_verbose == 3;
  print "[D] write_errors_file: Input parameter: $_[0]\n" if $o_verbose == 3;
  print "[D] write_errors_file: Input parameter: $_[1]\n" if $o_verbose == 3;
  if (! open ERRORS, ">$_[0]"){
  	print "RHEV $status{'unknown'}: Can't open file $_[0] for writing: $!\n";
	exit $ERRORS{'UNKNOWN'};
  }else{
	print ERRORS $_[1];
	close ERRORS;
	chmod (0600, $_[0]);
  }
}

#***************************************************#
#  Function eval_status                             #
#---------------------------------------------------#
#  Take the input array with status information and #
#  compare it with warning and critical values.     #
#  ARG1: component                                  #
#  ARG2: status array                               #
#***************************************************#

sub eval_status{
  print "[D] eval_status: Called function eval_status.\n" if $o_verbose == 3;
  my $component = $_[0];
  my @input = @{ $_[1] };
  print "[D] eval_status: Input parameter \$component: $component\n" if $o_verbose == 3;
  print "[D] eval_status: Input parameter \@input: @input\n" if $o_verbose == 3;
  my $size = $#input + 1;
  my $ok = 0;

  foreach (@input){
    print "[V] Eval Status: Status of $component: $_.\n" if $o_verbose >= 2;
    if ($component eq "Storagedomains"){
      $ok++ if ! $_;			# storage domain status - status ok if not available under /storagedomains - strange isn't it? ;)
      next;
    }
    $ok++ if $_ eq "up";		# datacenter, host and vm status
  }
  print "[V] Eval Status: $ok/$size $component OK\n" if $o_verbose >= 2;
  my $state = "UP";
  $o_warn = $size unless defined $o_warn;
  $o_crit = $size unless defined $o_crit;
  print "[V] Eval Status: warning value: $o_warn.\n" if $o_verbose >= 2;
  print "[V] Eval Status: critical value: $o_crit.\n" if $o_verbose >= 2;
  my $perf = undef;
  if ($perfdata == 1){ 
    $perf = "|$component=$ok;$o_warn;$o_crit;0;";
    print "[V] Eval Status: Performance data: $perf.\n" if $o_verbose >= 2;
  }else{ 
    $perf = ""; 
  }
  if ( ( ($ok == $size) && ($size != 0) ) || ( ($ok > $o_warn) && ($ok > $o_crit) ) ){
    exit_plugin('ok',$component,"$ok/$size " . ucfirst($component) . " with state $state" . $perf);
  }elsif ($ok > $o_crit){
    exit_plugin('warning',$component,"$ok/$size " . ucfirst($component) . " with state $state" . $perf);
  }else{
    exit_plugin('critical',$component,"$ok/$size " . ucfirst($component) . " with state $state" . $perf);
  }
}


#***************************************************#
#  Function: rhev_connect                           #
#---------------------------------------------------#
#  Connect to RHEV Manager via REST-API and get     #
#  values.                                          #
#  ARG1: API path                                   #
#***************************************************#

sub rhev_connect{
  print "[D] rhev_connect: Called function rhev_connect.\n" if $o_verbose == 3;
  print "[V] REST-API: Connecting to REST-API.\n" if $o_verbose >= 2;
  print "[D] rhev_connect: Input parameter: $_[0].\n" if $o_verbose == 3;

  # construct URL
  my $rhevm_url = "https://" . $o_rhevm_host . ":" . $rhevm_port . $rhevm_api . $_[0];
  print "[V] REST-API: RHEVM-API URL: $rhevm_url\n" if $o_verbose >= 2;
  print "[V] REST-API: RHEVM-API User: $rhevm_user\n" if $o_verbose >= 2;
  #print "[V] REST-API: RHEVM-API Password: $rhevm_pwd\n" if $o_verbose >= 2;

  # connect to REST-API
  my $ra = LWP::UserAgent->new();
  $ra->timeout($rhevm_timeout);

  # SSL certificate verification
  if (defined $o_ca_file){
    # check certificate
    $ra->ssl_opts(verfiy_hostname => 1, SSL_ca_file => $o_ca_file);
  }else{
    # disable SSL certificate verification
    if (LWP::UserAgent->VERSION >= 6.0){
      $ra->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);		# disable SSL cert verification
    }
  }

  my $rr = HTTP::Request->new(GET => $rhevm_url);

  # cookie authentication or basic auth
  my $cf = `echo "$o_rhevm_host-$rhevm_user" | base64`;
  chomp $cf;
  print "[V] REST-API: cookie filename: $cf\n" if $o_verbose >= 2;
  print "[D] rhev_connect: Trying cookie authentication.\n" if $o_verbose == 3;
  $rr->header('Prefer' => 'persistent-auth');
  my $re = undef;
  # check if cookie file exists
  if (-r $cookie . "/" . $cf){
  	# cookie based authentication
    my $jsessionid = `cat $cookie/$cf`;
    chomp $jsessionid;
    print "[D] rhev_connect: Using cookie: $jsessionid\n" if $o_verbose == 3;
    $rr->header('cookie' => $jsessionid);
    $re = $ra->request($rr);
    # fall back to username and password if cookie auth was not successful
    if (! $re->is_success){
      print "[V] REST-API: Cookie authentication failed - using username and password.\n" if $o_verbose >= 2;
      $rr->authorization_basic($rhevm_user,$rhevm_pwd);
      $re = rest_api_connect($rr, $ra, $cookie . "/" . $cf);
    }
    print "[V] REST-API: " . $re->headers_as_string if $o_verbose >= 2;
    print "[D] rhev_connect: " . $re->content if $o_verbose >= 3;
  }else{
  	# authentication with username and password
    print "[D] rhev_connect: No cookie file found - using username and password\n" if $o_verbose == 3;
    $rr->authorization_basic($rhevm_user,$rhevm_pwd);
    $re = rest_api_connect($rr, $ra, $cookie . "/" . $cf);
  }

  my $result = eval { XMLin($re->content) };
  print "RHEV $status{'critical'}: Error in XML returned from RHEVM - enable debug mode for details.\n" if $@;
  return $result;

}


#***************************************************#
#  Function: rest_api_connect                       #
#---------------------------------------------------#
#  Connect to RHEV Manager via REST-API             #
#  ARG1: HTTP::Request                              #
#  ARG2: LWP::Useragent                             #
#  ARG3: Cookie                                     #
#***************************************************#

sub rest_api_connect{
  print "[D] rest_api_connect: Called function rest_api_connect.\n" if $o_verbose == 3;
  print "[V] REST-API: Connecting to REST-API.\n" if $o_verbose >= 2;
  print "[D] rest_api_connect: Input parameter: $_[0].\n" if $o_verbose == 3;
  print "[D] rest_api_connect: Input parameter: $_[1].\n" if $o_verbose == 3;
  print "[D] rest_api_connect: Input parameter: $_[2].\n" if $o_verbose == 3;
  
  my $rr = $_[0];
  my $ra = $_[1];
  my $cookie = $_[2];
  
  my $re = $ra->request($rr);
  if (! $re->is_success){	
    print "RHEV $status{'unknown'}: Failed to connect to RHEVM-API or received invalid response.\n"; 
    if (-f $cookie){
      print "[D] rhev_connect: Deleting file $cookie\n" if $o_verbose == 3;
      unlink $cookie;
    }
    exit $ERRORS{'UNKNOWN'};	
  }
  print "[V] REST-API: " . $re->headers_as_string if $o_verbose >= 2;
  print "[D] rest_api_connect: " . $re->content if $o_verbose >= 3;

  # write cookie into file
  # Set-Cookie is only available when connecting with username and password
  if ($re->header('Set-Cookie')){
    my @jsessionid = split/ /,$re->header('Set-Cookie');
    chop $jsessionid[0];
    print "[V] REST_API: jsessionid: $jsessionid[0]\n" if $o_verbose >= 2;
    print "[D] rest_api_connect: Creating new cookie file $cookie.\n" if $o_verbose == 3;
    if (! open COOKIE, ">$cookie"){
  	  print "RHEV $status{'unknown'}: Can't open file $cookie for writing: $!\n";
	  exit $ERRORS{'UNKNOWN'};
    }else{
	  print COOKIE $jsessionid[0];
	  close COOKIE;
	  chmod (0600, $cookie);
    }
  }
  
  return $re;
  
}

exit $ERRORS{$status{'unknown'}};

