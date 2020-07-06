#!c:/perl/bin/perl
######################################
# WonderSweeper V1
#
# written by Adam McCormack
# with derived code from previous sweeper iterations
#
# Now supports channels and FTP scheduling, and multiple processes
######################################
use strict;
use File::Copy;
use DBI;
use Net::FTP;
use Date::Manip;
use Digest::MD5;
use IBC::MainConfig;
#increase "size" to the maximum number of ftp processes desired
use Proc::Queue size => 5, debug => 0;


use vars qw($dsn $duser $dpass $datanode $data_drive);

my $process_on_off;
my $xfer_method;
my $dbh;
my $fileinfo;
my $channelinfo;
my $fullname;
my $filename;
my $file;
my $pid = -1;
&Date_Init("TZ=-0000");
my $dts = UnixDate("today","%Y%m%d%H%M%S");
#20080205094345
my $dts_year  = substr($dts, 0, 4);
my $dts_month = substr($dts, 4, 2);
my $dts_date  = substr($dts, 6, 2);
my $dts_hour  = substr($dts, 8, 2);
my $dts_min   = substr($dts, 10,2);
my $dts_sec   = substr($dts, 12,2);
my $dts_day_of_week = Date_DayOfWeek($dts_month, $dts_date, $dts_year);


my $error_called_script;
my $error_ftp;
my $error_missing_handle;
my $error_missing_channel;
my $error_sweeper_abort;
my $error_dups;

my $path;
my $proc_path;
my $error_path;
my $notfound_path;

my @pids;

#my $dbl_channel_admin = "mccormack_adam\@interstatebrands.com;king_susan\@interstatebrands.com";
#my $dbl_channel_admin = "mccormack_adam\@interstatebrands.com";
my $dbl_channel_admin = "DBL_ECPORTAL_ERROR\@interstatebrands.com";

sub running {
  if (-e "sweeper.lck") {
  	return 1;
  } else {
  	return 0;
  }
}

sub create_lock {
############################
# Create a lock file so that sweeper knows its running
############################
	open (FILEH,"> sweeper.lck");
	close (FILEH);
}

sub delete_lock {
############################
# All done so delete the lock file
############################
  unlink ("sweeper.lck");
}

sub send_error_emails {
		#print "DEBUG: in sub send_error_emails\n";
		#$error_called_script;  
		#$error_missing_handle; 
		#$error_missing_channel;
		#$error_ftp;            
		#$error_sweeper_abort;  
		#$error_dups;           

		
		my $err_body;
		my $err_subject ="Wonder Sweeper had problems with its run on $node";
		my $err_flag = 0;
		
		if (length($error_called_script)  >0) {
			$err_flag++;
			$err_body .= "Aborted scripts:\n". $error_called_script ."\n\n"; 
									 
		}
		if (length($error_missing_handle) >0) {
			$err_flag++;
			$err_body .= "File handle not found:\n". $error_missing_handle ."\n\n"; 
			
		}
		if (length($error_missing_channel)>0) {
			$err_flag++;
			$err_body .=  "Channel not found:\n". $error_missing_channel ."\n\n";
		}
		if (length($error_ftp)            >0) {
			$err_flag++;
			$err_body .=  "FTP Error:\n". $error_ftp ."\n\n";
		}
		if (length($error_sweeper_abort)  >0) {
			$err_flag++;
			$err_body .=  "Sweeper Error:\n". $error_sweeper_abort ."\n\n";
		}
		if (length($error_dups)           >0) {
			$err_flag++;
			$err_body .= "Sweeper tried to process the following Duplicate Files:\n". $error_dups ."\n\n";
		}

  	if ($err_flag > 0) 
  	{
	  	my $email_data = {
	      'recips'	=>	$dbl_channel_admin,
	      'subject'	=>	$err_subject,
	      'body'	  =>	$err_body,
	  	};
	  	SendEmail($email_data);
  	}
}


sub send_ftp_error_emails {
		#print "DEBUG: in sub send_error_emails\n";
		#$error_called_script;  
		#$error_missing_handle; 
		#$error_missing_channel;
		#$error_ftp;            
		#$error_sweeper_abort;  
		#$error_dups;           

		
		my $err_body;
		my $err_subject ="Wonder Sweeper had problems with its' run on $node";
		my $err_flag = 0;

		if (length($error_ftp)            >0) {
			$err_flag++;
			$err_body .=  "FTP Error:\n". $error_ftp ."\n\n";
		}

  	if ($err_flag > 0) 
  	{
	  	my $email_data = {
	      'recips'	=>	$dbl_channel_admin,
	      'subject'	=>	$err_subject,
	      'body'	  =>	$err_body,
	  	};
	  	SendEmail($email_data);
  	}
}

sub get_file_info {
#################################
#  Get file information from database
#
#  loads global variable $fileinfo with database record in hash
#  returns: 1 if the window is open 
#			0 if the time is outside the window 
#		-1 if the handle is not found
#    
#################################
  #print "DEBUG: in get_file_info\n";
  my $in_file_name = shift;
  my $has_day;
  my $has_date;
  my $has_hour;
  my $matches_day;
  my $matches_date;
  my $matches_hour;
  my $has_total = 0;
  my $matches_total = 0;

  my $sql = "select * ";
  $sql .= "from sweeper.file_handle ";
  $sql .= "where in_file_name = ? ";

  my $sth = $dbh->prepare($sql) or die "Could not prepare statement:\n\t$sql\n\t\t$in_file_name" ;
  $sth->execute($in_file_name) or die "Could not execute statement: " . $sth->errstr;
  $fileinfo = $sth->fetchrow_hashref();
  $sth->finish;
  
  $has_date  = $fileinfo->{cron_date_of_month}   ;
  $has_day   = $fileinfo->{cron_day_of_week}     ;
  $has_hour  = $fileinfo->{cron_hour}            ;
  if (length($has_date  )>0) {$has_total++;}
  if (length($has_day   )>0) {$has_total++;}
  if (length($has_hour  )>0) {$has_total++;}
  $matches_day   = is_in_cron($has_day  , $dts_day_of_week);
  $matches_date  = is_in_cron($has_date , $dts_date);       
  $matches_hour  = is_in_cron($has_hour , $dts_hour);       
  $matches_total = $matches_day + $matches_date + $matches_hour;
  
  #still needs to react on the window.
  sleep 1;
  #print "DEBUG: fileinfo->{on_off}= $fileinfo->{on_off}\n";
  #print "DEBUG: \tdate \tday \thour\n";
  #print "DEBUG: has \t$has_date \t$has_day \t$has_hour\n";
  #print "DEBUG: is \t$dts_date \t$dts_day_of_week \t$dts_hour\n";  
  #print "DEBUG: match \t$matches_day \t$matches_date \t$matches_hour\n";
  
  if (length($fileinfo->{in_file_name})>0)
  {
    if ($fileinfo->{on_off} eq "ON") {
      if ($matches_total == $has_total) {
        $process_on_off = 1;
        #print "DEBUG: in cron window: $matches_total = $has_total\n";
        return 1;
  	  } elsif ($fileinfo->{cron_override} eq "ON") {
        $process_on_off = 1;
        print "cron window closed, but cron override == ON\n";
        return 1;
  	  } else {
        $process_on_off = 0;
        print "cron window closed, no override\n";
        return 0;
  	  }
    } else {
      $process_on_off = 0;
      print "file processing is turned off\n";
      return 0;
    }
  } else { #handle not found
    $error_missing_handle .= "Sweeper attempted to process a file named: $filename.\nHowever no entry was found for it in sweeper.file_handle.\n\n";
  	return (-1);
  }
}

sub is_in_cron {
###############################
#  generically checks the DTS field to see if it is in the cron formatted string
#
#  example: dts_str = 10
#  matches: "10"
#			"8,10,12"
#			"8-10"
#  NULLs are handled elsewhere  
#################################
	#print "DEBUG: in is_in_cron\n";
	my $cron_str = shift;
	my $dts_str  = shift;
	if ($dts_str eq $cron_str)
	{	return 1;	}
	
	if ($cron_str =~ /$dts_str/)
	{	return 1;	}
	if ($cron_str =~ /-/) 
	{
		my $cstart;
		my $cend;
		$_ = $cron_str;
		($cstart, $cend) = /^(\d+)-(\d+)$/;
		if (($cstart <= $dts_str)  && ($dts_str <= $cend))
		{	return 1;	}
	}
	return 0;
}

sub get_channel_info {
###############################
#  Get channel information from database
#
#  loads global variable $channelinfo with database record in hash
#  return 1 if the channel is open, 0 otherwise, emails $dbl_channel_admin if channel not found
#################################
  #print "DEBUG: get_channel_info\n";
  my $outChannelName = shift;
  #flags indicating that there are values for the time
  my $has_year  ;
  my $has_month ;
  my $has_day   ;
  my $has_date  ;
  my $has_hour  ;
  my $matches_year;
  my $matches_month;
  my $matches_day ;
  my $matches_date;
  my $matches_hour;
  undef $channelinfo;
  my $sql_channel  = "select * from sweeper.com_channel "
  	 . "where server_name = ?";
  my $sth_channel = $dbh->prepare($sql_channel);
  $sth_channel->execute($outChannelName) or die "Could not execute statement: $sql_channel" . $sth_channel->errstr;
  if ($channelinfo = $sth_channel->fetchrow_hashref()) {
  	$sth_channel->finish;
  } else {
  	$sth_channel->finish;
  	$error_missing_channel .= "Sweeper attempted to move a file named: $filename.\nHowever no entry was found for it in sweeper.com_channel that matched the channel specified in sweeper.file_handle.";
  	return (-1);
  }
    
  if ($channelinfo->{on_off} ne "ON")
  {	return 0;	}
  my $sql_blackout = "select * from sweeper.channel_blackout "
     . "where server_name = ?";
  my $sth_blackout = $dbh->prepare($sql_blackout);
  #print "\nDEBUG: $outChannelName\n";
  $sth_blackout->execute($outChannelName) or die "Could not execute statement: sql_blackout" . $sth_blackout->errstr;
  while (my $blackout_hash = $sth_blackout->fetchrow_hashref) {
	 	my $has_total     = 0;
	 	my $matches_total = 0;
	  	$has_year  = $blackout_hash->{cron_year}            ;
		$has_month = $blackout_hash->{cron_month}           ;
		$has_date  = $blackout_hash->{cron_date_of_month}   ;
		$has_day   = $blackout_hash->{cron_day_of_week}     ;
		$has_hour  = $blackout_hash->{cron_hour}            ;
		if (length($has_year  )>0) {$has_total++}
		if (length($has_month )>0) {$has_total++}
		if (length($has_date  )>0) {$has_total++}
		if (length($has_day   )>0) {$has_total++}
		if (length($has_hour  )>0) {$has_total++}
		$matches_year  = is_in_cron($has_year , $dts_year );      
		$matches_month = is_in_cron($has_month, $dts_month);      
		$matches_day   = is_in_cron($has_day  , $dts_day_of_week);
		$matches_date  = is_in_cron($has_date , $dts_date);       
		$matches_hour  = is_in_cron($has_hour , $dts_hour);       
		$matches_total = $matches_year + $matches_month + $matches_day + $matches_date + $matches_hour;
		#print "DEBUG: $has_year\t$has_month\t$has_date\t$has_day\t$has_hour\n";	
		#print "DEBUG: $matches_year\t$matches_month\t$matches_date\t$matches_day\t$matches_hour\n";
		#print "DEBUG: --------------------------------- $has_total - $matches_total\n\n";
		# if there are the same number of matches as hases then all entered fields 
		# are matched, so there is a blackout, therefor return zero
		if ($has_total == $matches_total) {
			$sth_blackout->finish;
			return 0;
		}
  }
  $sth_blackout->finish;
  return 1;
}

sub check_for_plant {
  $file = shift;
  my $len = length($file);
  my $dash = substr($file,$len-3,1);
  
  if ($dash eq '-') {
  	my $plt = substr($file,$len-2,2);
  	if ($plt =~ /^[0-9]+$/ ) {
  		$file = substr($file,0,$len-3);
  	}
  }

  return($file);	  
}

sub insert_log_thread {
  #print "DEBUG: in insert_log thread\n";
  #uses the MD5 hash as a flag of if the transmission was successfull, if NULL it has not been sent/processed due to 
  #blackout/processing windows
  #
  # The decidion to pass NULL for the MD5 is made outside this function
  # returns 1 if an insert was performed, 0 if it was an update
  my $io = shift;
  my $handle = shift;
  my $log_filename = shift;
  my $file_MD5 = shift;
  my $stat7 = shift;
  my $error = shift;
  my $dbh_thread = shift;
  my $log_id;
  
  
  
  my $sql_check_log = "select * from sweeper.file_log where file_full_name = ?";
  my $sth_check_log = $dbh_thread->prepare($sql_check_log);
  $sth_check_log->execute($log_filename) or print "Could not execute statement: sth_check_log" . $sth_check_log->errstr;
  if (($error ne "Duplicate File") && (my ($log_id, $log_handle, $log_file_name, $log_md5, $log_bytes, $log_direction, 
          $log_processed, $log_error) = $sth_check_log->fetchrow_array())) {
    #print "DEBUG: attempting to update an entry in file_log\n";      	
    my $sql_update_log = "update sweeper.file_log set file_MD5 = ?, date_processed=NOW(), ".
                         "error_message = ? where log_id = ?";
    my $sth_update_log = $dbh_thread->prepare($sql_update_log);	
    $sth_update_log->execute($file_MD5, $error, $log_id);
    $sth_check_log->finish;
    $sth_update_log->finish;  	
    return 0;
  } else {
    #print "DEBUG: Attempting to insert a record in file_log\n";
    my $sql_insert_log = "insert into sweeper.file_log values ( ";
    $sql_insert_log .= "NULL, '$handle', '$log_filename', '$file_MD5', $stat7, '$io', NOW(), '$error')";
    my $sth_insert_log = $dbh_thread->prepare($sql_insert_log);
    $sth_insert_log->execute() or die "Could not execute statement: " . $sth_insert_log->errstr;
    $sth_check_log->finish;
    $sth_insert_log->finish;
    return 1;
  }
}


sub insert_log2 {
  #uses the MD5 hash as a flag of if the transmission was successfull, if NULL it has not been sent/processed due to 
  #blackout/processing windows
  #
  # The decidion to pass NULL for the MD5 is made outside this function
  # returns 1 if an insert was performed, 0 if it was an update
  #print "DEBUG: in insert_log2\n";
  my $io = shift;
  my $handle = shift;
  my $log_filename = shift;
  my $file_MD5 = shift;
  my $stat7 = shift;
  my $error = shift;
  my $log_id;
  
  
  my $sql_check_log = "select * from sweeper.file_log where file_full_name = ?";
  my $sth_check_log = $dbh->prepare($sql_check_log);
  $sth_check_log->execute($log_filename) or die "Could not execute statement: sth_check_log" . $sth_check_log->errstr;
  if (($error ne "Duplicate File") && (my ($log_id, $log_handle, $log_file_name, $log_md5, $log_bytes, $log_direction, 
          $log_processed, $log_error) = $sth_check_log->fetchrow_array())) {
    #print "DEBUG: attempting to update an entry in file_log\n";      	
    my $sql_update_log = "update sweeper.file_log set file_MD5 = ?, date_processed=NOW(), ".
                         "error_message = ? where log_id = ?";
    my $sth_update_log = $dbh->prepare($sql_update_log);	
    $sth_update_log->execute($file_MD5, $error, $log_id);
    $sth_check_log->finish;
    $sth_update_log->finish;  	
    return 0;
  } else {
    #print "DEBUG: Attempting to insert a record in file_log\n";
    my $sql_insert_log = "insert into sweeper.file_log values ( ";
    $sql_insert_log .= "NULL, ?, ?, ?, ?, ?, NOW(), ?)";
    my $sth_insert_log = $dbh->prepare($sql_insert_log);
    $sth_insert_log->execute($handle, $log_filename, $file_MD5, $stat7, $io, $error) or die "Could not execute statement: " . $sth_insert_log->errstr;
    $sth_check_log->finish;
    $sth_insert_log->finish;
    return 1;
  }
}



sub check_dup {
  #print "DEBUG: check_dup\n";
  my $fHandle = shift;
  my $io = shift;
  my $file_MD5 = shift;
  my $sql = "select * from sweeper.file_log  ";
  $sql .= "where file_MD5 = '$file_MD5' ";
  $sql .= "and file_handle = '$fHandle' ";
  $sql .= "and file_direction = '$io' ";
  
  #print "DEBUG: dup check sql = $sql\n";
  my $sth = $dbh->prepare($sql);
  $sth->execute() or die "Could not execute statement: " . $sth->errstr;
  my $data = $sth->fetchrow_hashref;
  $sth->finish;
  
  if ($data) {
  	print "The file is a dup\n";
  	return 1;
  } else {
  	print "the file is not a dup\n";
  	return 0;
  }
}

sub handle_inbound_file {
# replace srcipt_parm variables with acutual information
 	#print "DEBUG: in handle_inbound_file()\n";
 	my $in_out    = shift;
  my $handle    = shift;
  my $filename  = shift;
  my $file_MD5  = shift;
  my $file_size = shift;
  my $processed_pathfile = "$proc_path$filename";
  my $error_pathfile = "$error_path$filename";
  
 	my $output;
 	my $result;
 	my $err_lines=0;
 	$fileinfo->{script_parms} =~ s/\@FILE\@/$fullname/g;
 	
 	print LOGFILE "c:\\scripts\\$fileinfo->{script} $fileinfo->{script_parms} \n";
 	$result = open(EXECUTION, "perl c:\\scripts\\$fileinfo->{script} $fileinfo->{script_parms}  2>&1 1>NULL|");
 	while (<EXECUTION>)
 	{
 		$err_lines++;
 		$output .= $_;
 	}
	print LOGFILE "DEBUG: \$script = $fileinfo->{script} \n";
	print LOGFILE "DEBUG: \$output = $output \n";
	print LOGFILE "DEBUG: \$result = $result \n";
 	
 	if ($err_lines > 0)
 	{
 		#report called script error
 		$error_called_script .= "Sweeper tried to run \"c:\\scripts\\$fileinfo->{script} $fileinfo->{script_parms}\" but it crashed.\n".
 														"The error was: $output\n";
 		insert_log2($in_out, $handle, $filename, $file_MD5, $file_size, $output); 
		move($fullname,$error_pathfile);
 	}
 	else
 	{
 		insert_log2($in_out, $handle, $filename, $file_MD5, $file_size, ""); 
		move($fullname,$processed_pathfile);
 	}
 	
}

sub handle_outbound_file {
##################################
# Spawn FTP thread
###################################
  
  my $in_out    = shift;
  my $handle    = shift;
  my $filename  = shift;
  my $file_MD5  = shift;
  my $file_size = shift;
  my $cron_override = shift;
  my $channel_status;  
  my $processed_pathfile = "$proc_path$filename";
  
  if ($cron_override eq "ON")
  {	
  	print "cron override is on\n";
  	get_channel_info($fileinfo->{channel});
  	$channel_status = 1;	
  }
  else
  {	$channel_status = get_channel_info($fileinfo->{channel});	}
  #print "DEBUG: in handle_outbound_file: $channel_status\n";
  
  if ($channel_status == 1)
  {
    $pid = fork();
    if (not defined $pid) {
			print "fork resources not avilable.\n";
			$error_ftp .= "Sweeper was unable to spawn the FTP process - FORK error\n";
		}
		elsif ($pid == 0) {
			#my $thr = threads->new(\&ftp_thread, $in_out, $handle, $filename, $file_MD5, $file_size, $processed_pathfile, $dbh);	
			#ftp_thread($in_out, $handle, $filename, $file_MD5, $file_size, $processed_pathfile, $dbh);	
			#print "DEBUG: \t\t\t\tFORKING! - $filename\n";
			ftp_thread($in_out, $handle, $filename, $file_MD5, $file_size, $processed_pathfile);	
  	  push(@pids,$pid);
  	  exit;
  	} 
  	#else - it is the parent process
  }	elsif ($channel_status == 0) {
  	insert_log2($in_out, $handle, $filename, undef, $file_size, "the \"$fileinfo->{channel}\" channel is off");
  } elsif ($channel_status == -1) {
  	insert_log2($in_out, $handle, $filename, undef, $file_size, "the \"$fileinfo->{channel}\" channel could not be found.");
  }
  
  return $channel_status;
}

sub ftp_thread {
##################################
# perform actual FTP
#
# log success or failure
###################################
	#print "DEBUG: in ftp_thread \n";
	my $in_out    = shift;
	my $handle    = shift;
	my $filename  = shift;
	my $file_MD5  = shift;
	my $file_size = shift;
	my $processed_pathfile = shift;
	#my $dbh_thread_junk = shift;
	
	my $dbh_thread = DBI->connect ($dsn, $duser, $dpass, { RaiseError => 1});
	
	my $fail_message = "";
	
	print LOGFILE "moving file to $channelinfo->{destination_path}/$filename \n";
	#print "DEBUG: \tchannel: $channelinfo->{server_name}\n\t$channelinfo->{login_name},\t$channelinfo->{login_password}\n";
	my $ftp = Net::FTP->new($channelinfo->{server_name}, Debug => 0);
	$ftp->login($channelinfo->{login_name},$channelinfo->{login_password}) or $fail_message .= $ftp->message;
	$ftp->cwd($channelinfo->{destination_path}) or $fail_message .= $ftp->message;
	if ($fileinfo->{trans_type} eq 'B')
	{	print "transmitting binary\n";
		$ftp->binary;	
	}
	else
	{	print "transmitting ASCII - \n$fullname\n";
		$ftp->ascii;
	}
	if ($channelinfo->{server_name} eq "gisprod")
	{
		#no .rename 
		print "transmitting without the .\n";
		$ftp->put($fullname, "$filename") or $fail_message.= $ftp->message;
	}
	else
	{
		#still use the .rename
		$ftp->put($fullname, "\.$filename") or $fail_message.= $ftp->message;
		print "renaming to remove the .\n";
		$ftp->rename("\.$filename","$filename") or $fail_message .= $ftp->message;
	}
	
	$ftp->quit;
	#print "DEBUG: FTP complete\t".length($fail_message) ."\t$fail_message\n";
	print "DEBUG: FTP complete\t$filename\t$fail_message\n";
	if (length($fail_message)==0)
	{	
		insert_log_thread($in_out, $handle, $filename, $file_MD5, $file_size, "", $dbh_thread); 
		move($fullname,$processed_pathfile);
	}
	else
	{	
		my $ftp_log_result = insert_log_thread($in_out, $handle, $filename, undef, $file_size, $fail_message, $dbh_thread); 
		if ($ftp_log_result)
		{		
			$error_ftp .= "Sweeper attempted to ftp a file named: $filename.  However an FTP error occured:\n$fail_message.";
		}
	}	
	$dbh_thread->disconnect;
	send_ftp_error_emails();
}

sub handle_dir {
##################################
# Handle each file in a directory
#
# $node is the system to look in (e.g corpipp06 if directory will be in /intf/corpipp06/)
#
# $in_out needs to be either 'inb' or 'outb'
#
# path will be built as /intf/$node/$in_out/pending/
###################################
	#print "DEBUG: in handle_dir\n";
  my $node = shift;
  my $in_out = shift;
  my $drive = shift;
	
  $path = $drive.':/intf/' . $node . '/' . $in_out . '/pending/';
  $proc_path = $drive.':/intf/' . $node . '/' . $in_out . '/processed/';
  $error_path = $drive.':/intf/' . $node . '/' . $in_out . '/error/';
  $notfound_path = $drive.':/intf/' . $node . '/' . $in_out . '/not_found/';
  
  opendir(THISDIR, "$path");
  my @allfiles = grep !/^\./, readdir THISDIR;
  closedir THISDIR;
  foreach my $a_filename(@allfiles) {
  	$filename = $a_filename;
  	my ($handle, $trash) = split("_",$filename); # get the file name before the underscore
  	$fullname = $path . $filename;
  	print LOGFILE "$handle = $path$filename \n";

    open(FILE, $fullname) or die "Can't open '$file':\nPath=$path\nfilename=$filename $!";
    binmode(FILE);
    my $file_MD5 = Digest::MD5->new->addfile(*FILE)->hexdigest;  	
    close(FILE);
  	
  	my @stat = stat($fullname);
  	print "\nchecking for $fullname\n";

  	$handle = check_for_plant($handle);
  	
  	my $file_found = get_file_info($handle);
  	
  	my $error = '';
  	my $processed;
  	#print "DEBUG: file_found=$file_found\n";
  	if ($file_found == 1) {
  		if ($stat[7]) { # stat[7] is the EOF, if it contains a value then there is data
  			if (check_dup($handle,$in_out,$file_MD5)) {
  				
  				$error_dups .= $fullname ."\n";
  				insert_log2($in_out, $handle, $filename, $file_MD5, $stat[7], "Duplicate File");
  				move("$path$filename","$proc_path$filename");
  			} else {
      			if ($in_out eq 'inb') {
      				handle_inbound_file($in_out, $handle, $filename, $file_MD5, $stat[7]);
  	    		} elsif ($in_out eq 'outb') {
  		    		handle_outbound_file($in_out, $handle, $filename, $file_MD5, $stat[7], 
  		    			$fileinfo->{cron_override});
  	  	  	}
  	  		}
  	  }
  	  else #empty file, just move to processed.
  	  {	move("$path$filename","$proc_path$filename");	}
    } elsif ($file_found == -1) {
    	move("$path$filename","$notfound_path$filename");
    }
    
     
  }
}


sub handle_dots {
##################################
# Handle each file with a leading . in a directory
#
# $node is the system to look in (e.g corpipp04 if directory will be in /intf/corpipp04/)
#
# $in_out needs to be either 'inb' or 'outb'
#
# path will be built as /intf/$node/$in_out/pending/
#
# will rename the files without the . if they have a modify time stamp that is 
#   older than 2 hours.
###################################
	#print "DEBUG: handle_dots\n";
	my $node = shift;
	my $in_out = shift;
	
  my $path = '/intf/' . $node . '/' . $in_out . '/pending/';
    
  opendir(THISDIR, "$path");
  my @allfiles = grep /^\.\w+/, readdir THISDIR;
  closedir THISDIR;
  foreach $filename(@allfiles) {
  	my ($handle, $trash) = split("_",$filename); # get the file name before the underscore
  	my $oldname = $path . $filename;
  	my $newname =  $path . substr($filename, 1);
  	#print "\$newname = $newname\n";
  	#print "\$oldname = $oldname\n";
  	 	
 	my @stat = stat($fullname);
 	@stat = stat($oldname);
 	my $error = '';
 	my $modTimeEpoc = $stat[9]; #seconds since epoc
 	my $curTimeEpoc = time();
 	my $deltaTime = $curTimeEpoc - $modTimeEpoc;
 	
	if ($deltaTime > 600)   #7200 seconds in two hours.
	{
		my $mins = $deltaTime / 60;
		print "the file modification time for $filename is over two hoursago, so renaming to be processed next run\n";
		print LOGFILE  "the file modification time for $filename is over two hoursago, so renaming to be processed next run\n";
		move($oldname,$newname); 
	}
  }
}

#############################################
#    Main Script
#############################################

open (LOGFILE, '>> sweeper.log');

$dbh = DBI->connect ($dsn, $duser, $dpass, { RaiseError => 1});
if (!running()) {
  create_lock();
  #my $one = 1;
  #my $zero = 0;
  #my $blowtopieces;
  eval
  {
  	#$blowtopieces = $one / $zero;
  	handle_dir($datanode,'inb',$data_drive);
  	handle_dir($datanode,'outb',$data_drive);

  	foreach my $pid (@pids) {
    	waitpid($pid,0)
		}
  	handle_dots($datanode,'inb');
	};
	if ($@)
	{	
		$error_sweeper_abort .= $@;	
		delete_lock();	
	}
	
  delete_lock();
  send_error_emails();
} else {
	print "Already Running!!! \n";
}
#print "DEBUG: \$pid=$pid\n";
if ($pid != 0)
{
	#not in the child process
	print "cleaning up for exit (not in child process)\n";
	close (LOGFILE);
	$dbh->disconnect;
}
else
{	print "\tchild process ending\n";	}

