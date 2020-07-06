#!c:\perl\bin
#############################################
#	ftp_over_ssl.pl external FTP pver SSL script for invocation 
#			either via sweeper or command line
#
#	REQUIRED parms: <file to transfer> <server to send to> <user> <port> <destination path>
#
#	Command line invocation example:
#  C:\scripts\sftp-extern>ftp_over_ssl_moveit.pl c:/scripts/sftp-extern/locations.txt westgis01 99 ftpusr /westgis01/inb/pending
#
#	v1 - 2009-02-19 - Adam McCormack
#############################################
use strict;
use IBC::MainConfig;

my $in_file_name = $ARGV[0];
my $dest_server = $ARGV[1];		#westgis01
my $portnumber = $ARGV[2];		#22 or 10022
my $dest_user = $ARGV[3];			#ftpusr
#my $dest_pass = $ARGV[4];
my $dest_path = $ARGV[4];			#/intf/westgis01/inb/pending

my $file_only = $in_file_name;
#clean out unix formatted pathing
$file_only =~ s/^.+\///;
#clean out windows formatted pathing
$file_only =~ s/^.+\\//;

my $err_lines;
my $output;
my $result;


#my $exeString = "vcp -accepthostkeys -q -i \"c:\\keys\\identity\" $in_file_name $dest_user\@$dest_server#$portnumber:$dest_path";
my $exeString = "vcp -accepthostkeys -i \"C:\\Program Files\\VanDyke Software\\VShell\\hostkey.pub\" $in_file_name $dest_user\@$dest_server#$portnumber:$dest_path 2>&1 1>NULL|";
print "\n\$exeString = $exeString\n";

$result = open(EXECUTION, $exeString);
 	while (<EXECUTION>)
 	{
 		$err_lines++;
 		$output .= $_;
 	}

print "result = $result\n";

if ($err_lines > 0)
{
	print "\n\$exeString = $exeString\n";
	print "\$output = $output\n\n";
}

#unlink "$file_only.TXT";
exit;