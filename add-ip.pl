#!/usr/bin/perl -w

sub condense_ifcfg {
	#
	# Bomb out if running Hostware or Plesk
	#
	if ( -d "/hsphere" ) { print "Hostware detected!\nDon't use this with Hostware, use the EManager in the Control Panel!\n"; exit 1;}
	#
	# Be smart, always make backups before you do anything stupid...
	#
	print "Backing-up ifcfg files to /tmp/ifcfg-backukp.tar.gz...";
	system "tar -zcvf /tmp/ifcfg-backup.tar.gz /etc/sysconfig/network-scripts/ifcfg-* 1>/dev/null 2>/dev/null";
	print "done!\n";
	print "Condensing ifcfg files\n";
	print "-----------------------------\n";	
	$startif = 0;
	#
	# Grab just the directory portion of the path to the files
	#
	@pathonly = split('/',$tmp[0]);
	$pathonly[4] = '';
	$pathonly = join('/',@pathonly);
	#
	# Iterate through the list of existing files
	#
	foreach $cfgfile ( @tmp ) {
		@fileonly=split('/',$cfgfile);
		$_ = $fileonly[4];
		#
		# Only match interfaces with a ":" in them
		#
		if ( /(ifcfg-(eth0:[0-9]+))/ ) {
			$oldfile=$1;
			$olddev=$2;
			$newfile="ifcfg-eth0:$startif";
			$newdev="eth0:$startif";
			#
			# If the existing ifcfg list is not condensed
			# already, then do some work
			#
			if ( $olddev ne $newdev) {
				print "Bringing down $olddev, ";	
				system "/sbin/ifconfig $olddev down 1>/dev/null 2>/dev/null";
				print "condensing $olddev -> $newdev, ";
				#
				# Open the old file, read all the lines
				#
				open(OLDFILE, "<$pathonly$oldfile");
				@lines = <OLDFILE>;
				close(OLDFILE);
				#
				# Then drop the old file
				#
				unlink("$pathonly$oldfile");
				
				#
				# Print to the new ifcfg file, doing search- 
				# replace of the old interface with the new
				#
				open(NEWFILE, ">$pathonly$newfile");	
				foreach $_ ( @lines ) {
					s/$olddev/$newdev/g;
					print NEWFILE $_;
				}
				close(NEWFILE);
				print "Bringing up $newdev\n";	
				system "/sbin/ifup $newdev 1>/dev/null 2>/dev/null";
				
			}
		$startif=$startif+1;
		}
	}
	print "-----------------------------\n";
	print "Condensing ifcfgs complete!\n\n";
}


$system=`/bin/uname`;
chop $system;

#
# Make sure it's Linux, else DIE
#
if ($system eq Linux){

#
# Do some system startup stuff, set some initial variables, 
# and do some footwork applicable to all sections of the 
# script to prevent as much duplication as possible.
#
  $ARGCOUNT=@ARGV;
  print "\nRunning on: $system\n";
  $ifcfg_dir = "/etc/sysconfig/network-scripts/"; # Directory of the Network Config Files
  $ipfile_base = "ifcfg-eth0:"; # Base filename for IP Config Files
  $devname = "eth0:"; # Base device name for configure IP's
  $filelist = $ifcfg_dir . "ifcfg-eth0" . " " . $ifcfg_dir . "ifcfg-eth0:*";
  # 
  # Get the list of all interfaces in /etc/sysconfig/network-scripts
  # and sort it numerically
  #
  @tmp= `ls $filelist 2> /dev/null| sort -t : -k 2 -n 2> /dev/null`;
  $num_exist_ip = @tmp;
  $netmask = '255.255.255.255'; 
#
# Bork if they don't already have a primary ip (shouldn't happen, but CYA)
#
  if ($num_exist_ip == 0){
	print " Error: No Primary IP has been configured on this Box!\n";
	print " Exiting Now...\n";
	exit 1;
  }
#
# List how many ip's they currently have on the primary interface
#
  print "Existing IPs: ",$num_exist_ip, "\n\n";

#
# If we have been passed a parameter, expect the parameter
# to be a filename containing ips/netmasks copied from CORE.
# 
if ($ARGCOUNT>0) {
	if ( -r $ARGV[0] ){
		open(COREFILE, "<$ARGV[0]");
		@iplines = <COREFILE>;
		close(COREFILE);
		condense_ifcfg();
		$tot_ip = @iplines-1;
		$num_ip = 0;
		print "Number of IP's to configure: ", $tot_ip, "\n";
		print "-----------------------------\n";
		foreach $ipline ( @iplines ) {
			#
			# Clean up the format from CORE
			#
			$_ = $ipline;
			$_ =~ s/\s*\/\s*/|/g;
			#
			# Break the ip/netmask into variables using () groups
			#
			if (/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\|([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/) {
				$ip = $1;
				$netmask = $2;	

				#
				# Play games to generate a good path
				# and ifcfg-eth0:* filename
				#
				$filename = ($num_exist_ip-1)+$num_ip;
				$device_name = ($devname . $filename);
				$filename = ($ipfile_base . $filename);
				$filename = ($ifcfg_dir . $filename);
				print "Configuring $device_name => $ip/$netmask, ";	
				#
				# Open the filename generated above and 
				# write the information to the file
				#
				open(OUTFILE, ">$filename");
				print OUTFILE "DEVICE=$device_name\n";
				print OUTFILE "IPADDR=$ip\n";
				print OUTFILE "NETMASK=$netmask\n";
				print OUTFILE "ONBOOT=yes\n";
				close(OUTFILE);
				print "Bringing up $device_name\n";	
				system "/sbin/ifup $device_name 1>/dev/null 2>/dev/null";
				$num_ip = $num_ip+1;
			}	
		}
		print "-----------------------------\n";
		exit 1;
	}	
	else { 
		#
		# Error out if the parameter passed by the user 
		# isn't a file that is readable
		#
		print "$ARGV[0] does not exist or is not readable.\n\n";
		print "Proper usage: add-ip.pl <path to file containing ip/mask pairs from CORE>\n\n";
		exit 1;
	}

}
else {
#
# If we don't have a file from CORE, and have a block of consecutive 
# IP's then we can just generate the ip list.  
#

  condense_ifcfg();
  print "This program will automaticly configure blocks of IP's for the remote box. \n";
	print "Please only enter 1 block at a time.\n \n";
	print "Please enter the Starting IP: ";
	$start_ip = <>; # Starting IP Address for the block
	chop($start_ip);
	#
	# Break the provided ip into octets and sanity check them
	#
	@ip = split(/\./, $start_ip); 
	for ($i=0;$i<4;$i++){
		if ((0<=$ip[$i])&&($ip[$i]<=255)){}
		else{
			print "An IP consists of four numbers between 0 and 255 seperated \n";
			print "by periods. You have not entered a valid IP \n";
			print "Exiting Now....\n\n";
			exit 1; 
		} 
	}
	print "Please enter the Last IP: ";
	$last_ip = <>; # Last IP Address for the block
	chop($last_ip);
	#
	# Sanity check again
	#
	@ip = split(/\./, $last_ip);
	for ($i=0;$i<4;$i++){
		if ((0<=$ip[$i])&&($ip[$i]<=255)){}
		else{
			print "An IP consists of four numbers between 0 and 255 seperated \n";
			print "by periods. You have not entered a valid IP \n";
			print "Exiting Now....\n\n";
			exit 1; 
		} 
	}
	print "\nStarting IP: ", $start_ip;
	print "\nLast IP: ", $last_ip, "\n";
	@ip_start = split(/\./, $start_ip); # First IP Address in a list
	@ip_stop = split(/\./, $last_ip); # Last IP in a list
	for ($i=0;$i<3;$i++){
		if ($ip_start[$i]!=$ip_stop[$i]){
			#
			# For simplicity's sake, we require the ip's to share
			# the same first 3 octets, to prevent lots of IP
			# addressing math (maybe later I'll do it)
			#
			print "This program requires both IP's to share the same first three octets. \n";
			print "Exiting Now....\n\n";
			exit 1;
		}
	}
	$num_ip = ($ip_stop[3]-$ip_start[3])+1; # Number of IP's to configure
	@ip_octets=@ip_start;
	print "Number of IP's to configure: ", $num_ip, "\n";
	print "-----------------------------\n";
	for ($i=0;$i<$num_ip;$i++){
		#
		# Play games to generate a good path
		# and ifcfg-eth0:* filename
		#
		$filename = ($num_exist_ip-1)+$i;
		$device_name = ($devname . $filename);
		$filename = ($ipfile_base . $filename);
		$filename = ($ifcfg_dir . $filename);
		$ip_octets[3] = $ip_start[3]+$i;
		$ip = join("\.", @ip_octets);
		print "Configuring $device_name => $ip/$netmask, ";	

		#
		# Open the filename generated above and 
		# write the information to the file
		#
		open(OUTFILE, ">$filename");
		print OUTFILE "DEVICE=$device_name \n";
		print OUTFILE "IPADDR=$ip \n";
		print OUTFILE "NETMASK=$netmask\n";
		print OUTFILE "ONBOOT=yes\n";
		close(OUTFILE);
		print "Bringing up $device_name\n";	
		system "/sbin/ifup $device_name 1>/dev/null 2>/dev/null";
	}
	print "-----------------------------\n";
}
} else { print "\nThis script is only for Linux!\n\nRunning it on BSD or (God-forbid) Windows can cause naught be bad things.\n\n"; } 
