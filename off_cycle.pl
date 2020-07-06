#!C:\Perl\bin\perl.exe
#################################################
# Author: 	Eric Dillon
# Created:	01/2007
# 	Copyright 2007 Interstate Brands Corporation
#
#
#################################################
use strict;
use DBI;
use CGI;
use Win32;
use IBC::OCycle::Common;
#################################################
my $cgi = new CGI;
# Define environment parameters
$cgi->{'script'} = "off_cycle.pl";
$cgi->{'header'} = "IBC Off Cycle";
my $node = Win32::NodeName();
my $function = $cgi->param('function');
unless (defined $function) {
	$function = 'displayinput';
}
# Verify that they are authorized to be using this app.
if ($function eq "authenticate") {
	my $mssg = AuthorizeUser($cgi);
	if ($mssg =~ /\w+/) {
		IBC::OCycle::Common::LoginForm($cgi,$mssg);
	} else {
		$function = "displayinput";
	}
} elsif ($function eq "login") {
	IBC::OCycle::Common::LoginForm($cgi);
} else {
	ValidateUser($cgi);
}
# Define database connection parameters
my $dbhost = "kronprod_dsn";
my $dbh = DBConnect($dbhost);
# Lets get started. Run sub based on function
my %routine = (
		'displayinput'	=> \&DisplayInputForm,
		'search'		=> \&SearchReturn,
		'updatedb' 	=> \&UpdateDb,
		'release'		=> \&UpdateDb,
              );
$routine{$function}->($cgi);

$dbh->disconnect();
exit;
1;

########################
#
########################
sub FetchList {
	my $search_params = shift;
	# Seems to be the norm around here for people to use '*' for wildcard searches. Since we default to wildcard, remove asterisks...
	$search_params =~ s/\*//g;
	my $holder;
	my $sql = "select lastnm,firstnm,personnum from VP_EMPLOYEEV42 where employmentstatus != 'Terminated' and personnum not in (select personnum from TKCSOWNER.KNX_OFFCYCLEPERSON)";
	my $sth = $dbh->prepare($sql);
	if ($search_params =~ /.+/) {
		$search_params = uc $search_params;
		$sql .= " and UPPER(lastnm) like '$search_params%'";
	}
	$sql .= " order by lastnm,firstnm";
	my $sth = $dbh->prepare($sql) || HandleError("Error: $!",$dbh);
	$sth->execute() || HandleError("Error: $!",$dbh);
	while ( my ($lastnm,$firstnm,$personid) = $sth->fetchrow_array() ) {
		my $maskedid = $personid;
		if ($maskedid =~ /^\d{9}$/) {
			$maskedid =~ s/^(\d{5})\d{4}$/$1xxxx/;
		}
		$holder .= "$lastnm, $firstnm - $maskedid!$personid|";
	}
	$sth->finish();
	return $holder;
}

########################
#
########################
sub UpdateDb {
	my $uids = $cgi->param('list2');
	my (@uids) = split /\|/, $uids;
	my $cnt=0;
	unless ($function eq "release") {
		# delete all records except for the PLACEHOLDER record
		my $del_sql = "delete from TKCSOWNER.KNX_OFFCYCLEPERSON where personnum != 'PLACEHOLDER'";
		my $del_sth = $dbh->prepare($del_sql) || HandleError("Cannot prepare delete statement;".$dbh->errstr,$dbh);
		$del_sth->execute() || HandleError("Cannot execute delete statement;".$dbh->errstr,$dbh);
		$del_sth->finish();
		my $insert_sql = "insert into TKCSOWNER.KNX_OFFCYCLEPERSON (personnum) VALUES(?)";
		my $insert_sth = $dbh->prepare($insert_sql) || HandleError("Cannot prepare statement;".$dbh->errstr,$dbh);
		foreach my $uid (@uids) {
			unless ($uid eq "") {
				$insert_sth->execute($uid) || HandleError("Cannot execute statement;".$dbh->errstr,$dbh);
				$cnt++;
			}
		}
		$insert_sth->finish();
	}

	my $message = "The employee list has been updated successfully ($cnt entries added).";

	if ($function eq "release") {
		# create trigger file to run external program
		open(FILE, '> E:\\SAP Interfaces\\TRIGGER FILES\\kronos2sapoffcycle.done') || HandleError("Trouble opening file: $!",$dbh);
		print FILE "Run E:\SAP Interfaces\OFFCYCLE\KRONOS2SAPOFFCYCLE.KNI \n";
		close FILE;
		$message = "The application 'KRONOS2SAPOFFCYCLE.KNI' has been instructed to run.";
	}

	print $cgi->header();
	print $message;
#	my $release_mssg = "Your changes have been completed and your session has ended.";
#
#	print qq~<html>
#<head>
#  <title>$cgi->{'header'} Check Employee Selection</title>
#</body>
#<p>&nbsp;</p>
#<center>
#<h4>Thank You</h4>
#$release_mssg
#<hr size=1>
#<a href="$cgi->{'script'}">Add more people to the $cgi->{'header'} database</a>
#</center>
#<p>&nbsp;</p>
#</body>
#</html>~;
	return;
}

########################
#
########################
sub SearchReturn {
	my $results = FetchList($cgi->param('srch'));
	print $cgi->header();
	print $results;
	return;
}

########################
#
########################
sub DisplayInputForm {
	my $cgi = shift;
	my ($right_list);
#	# prepare main query
	my $sql = qq~select KNX_OFFCYCLEPERSON.personnum,VP_EMPLOYEEV42.lastnm,VP_EMPLOYEEV42.firstnm
				from TKCSOWNER.KNX_OFFCYCLEPERSON,TKCSOWNER.VP_EMPLOYEEV42
				where VP_EMPLOYEEV42.personnum = KNX_OFFCYCLEPERSON.personnum
				order by VP_EMPLOYEEV42.lastnm,VP_EMPLOYEEV42.firstnm~;
	my $sth = $dbh->prepare($sql) || HandleError("Cannot prepare statement;".$dbh->errstr,$dbh);
	$sth->execute() || HandleError("Cannot execute statement;".$dbh->errstr,$dbh);
	while (my ($personnum,$lastnm,$firstnm) = $sth->fetchrow_array() ) {
		my $maskedid = $personnum;
		if ($maskedid =~ /^\d{9}$/) {
			$maskedid =~ s/^(\d{5})\d{4}$/$1xxxx/;
		}
		$right_list .= "\t\t\t\t<option value='$personnum'>$lastnm, $firstnm - $maskedid</option>\n";
	}
	$sth->finish();
	unless ($right_list) {
		$right_list = "\t\t\t\t<option>No results found!</option>\n";
	}
	print $cgi->header();
	print qq~<html>
<head>
	<title>$cgi->{'header'} Check Employee Selection</title>
	<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
	<META HTTP-EQUIV="CACHE-CONTROL" CONTENT="NO-CACHE">
	<style type="text/css">
		body {font-family: arial}
	</style>
	<script language="JavaScript">
	<!-- Cloak
		var request = false;
		try {
			request = new XMLHttpRequest();
		} catch (trymicrosoft) {
			try {
			  request = new ActiveXObject("Msxml2.XMLHTTP");
			} catch (othermicrosoft) {
			  try {
			    request = new ActiveXObject("Microsoft.XMLHTTP");
			  } catch (failed) {
			    request = false;
			  }
			}
		}
		function AjaxSearch(srch) {
			var tag = srch.value;
			if (tag==null||tag=="") {
				alert('You must enter at least one character in the field provided.');
				return false;
			}
			document.form1.list1.options.length = 1;
			document.form1.list1.options[0].value = "";
			document.form1.list1.options[0].text = "Searching...";
			var url = "$cgi->{'script'}?function=search&srch=" + escape(tag);
			request.open("GET", url, true);
			request.onreadystatechange = updatePage;
			request.send(null);
		}
		function updatePage() {
			if (request.readyState == 4) {
				var box = document.form1.list1;
				var response = request.responseText.split("|");
				if ((response[0]) && (response[0] != 'null')) {
					var list2 = document.form1.list2;
					var i;
					box.options.length = response.length;
					for (i = 0; i < response.length; i++) {
						var unique = response[i].split("!");
						var mark=0;
						var q;
						for (q = 0; q < list2.length; q++) {
							var tempval = list2.options[q].value;
							if (unique[1] == tempval) {
								mark++;
							}
						}
						box.options[i].value = unique[1];
						box.options[i].text = unique[0];
						if (mark > 0) {
							box.options[i] = null;
							response.splice(i,1);
							i--;
						}
					}
					box.options.length -= 1;
				} else {
					box.options.length = 1;
					box.options[0].value = "";
					box.options[0].text = "No results found!";
				}
				if (box.options.length <= 0) {
					box.options.length = 1;
					box.options[0].value = "";
					box.options[0].text = "No results found!";
				}
			}
		}
		function AjaxUpdate(button,funkshion) {
			//button.value = "Processing...";
			selectList2();
			var list = document.form1.list2;
			/*if ((list.options.length == 0) && (funkshion != 'release')) {
				alert('Please select at least one entry.');
				button.value = "Update List";
				return false;
			}*/
			var uids;
			var i;
			for (i = 0; i < list.options.length; i++) {
				uids += list.options[i].value + '|';
			}
			var uidstring = new String(uids);
			uids = uidstring.replace("undefined",'')
			uids = uids.substring(0,uids.length-1);
			var url = "$cgi->{'script'}?function="+funkshion+"&list2=" + uids;
			/* start test
			alert(url);
			return false;
			// end test */
			request.open("GET", url, true);
			request.onreadystatechange = updateDb;
			request.send(null);
			if (funkshion == 'release') {
				button.value = "Run OffCycle Payroll";
			} else {
				//button.value = "Update List";
			}
			//list.options.length = 0;
		}
		function updateDb() {
			if (request.readyState == 4) {
				var box = document.form1.list1;
				var response = request.responseText.split("|");
				if ((response[0]) && (response[0] != 'null')) {
					alert(response[0]);
				} else {
					alert("There has been an unspecified issue. The list was not updated.");
				}
			}
		}
		// Logic enabling selection(s) to be moved from one list to another
		function move(fbox, tbox) {
			var arrFbox = new Array();
			var arrTbox = new Array();
			var arrLookup = new Array();
			var i;
			if (tbox.options.length > 0) {
				if (tbox.options[0].text == 'No results found!') {
					tbox.options[0] = null;
				}
			}
			for (i = 0; i < tbox.options.length; i++) {
				arrLookup[tbox.options[i].text] = tbox.options[i].value;
				arrTbox[i] = tbox.options[i].text;
			}
			var fLength = 0;
			var tLength = arrTbox.length;
			for(i = 0; i < fbox.options.length; i++) {
				arrLookup[fbox.options[i].text] = fbox.options[i].value;
				if (fbox.options[i].selected && fbox.options[i].value != "") {
					arrTbox[tLength] = fbox.options[i].text;
					tLength++;
				} else {
					arrFbox[fLength] = fbox.options[i].text;
					fLength++;
				}
			}
			arrFbox.sort();
			arrTbox.sort();
			fbox.length = 0;
			tbox.length = 0;
			var c;
			for(c = 0; c < arrFbox.length; c++) {
				var no = new Option();
				no.value = arrLookup[arrFbox[c]];
				no.text = arrFbox[c];
				fbox[c] = no;
			}
			for(c = 0; c < arrTbox.length; c++) {
				var no = new Option();
				no.value = arrLookup[arrTbox[c]];
				no.text = arrTbox[c];
				tbox[c] = no;
			}
		}
		function selectList2() {
			var x;
			var list = document.form1.list2;
			for (x = 0; x < list.length; x++) {
				list.options[x].selected = true;
			}
			return true;
		}
		function selectNone() {
			var x;
			var list1 = document.form1.list1;
			var list2 = document.form1.list2;
			for (x = 0; x < list1.length; x++) {
				list1.options[x].selected = false;
			}
			for (x = 0; x < list2.length; x++) {
				list2.options[x].selected = false;
			}
			return true;
		}
		function confirmation() {
			var answer = confirm("Are you sure you want to run OffCycle Payroll?")
			if (answer){
				//location.href='$cgi->{script}?function=release';
				AjaxUpdate(document.forms[0].run,'release');
			}
		}
		function checkCR(evt) {
			var evt  = (evt) ? evt : ((event) ? event : null);
			var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
			if ((evt.keyCode == 13) && (node.type=="text")) {return false;}
		}
		document.onkeypress = checkCR;
	// de-cloak -->
	</script>
</head>
<body onLoad="document.form1.srch.focus();">
<p>&nbsp;</p>
<form action="$cgi->{'script'}" method=POST name="form1" onSubmit="selectList2();">
<center>
<table border=0 cellpadding=4 cellspacing=0 width="575" bgcolor="#0066CC">
  <tr align="center">
    <td>
	  <font color="white"><b>$cgi->{'header'} Check Employee Selection</b></font>
	  	<table border=0 cellpadding=4 cellspacing=0 width="100%" bgcolor="white">
		  <tr>
		    <td>
			&nbsp;<font size="-1">Enter at least the first character of the last name</font><br>
			&nbsp;
			<input type="text" name="srch" size="15" maxlength="25" autocomplete="off" value="">
			<input type="button" value="Filter" onClick="AjaxSearch(this.form.srch)">
		    </td>
		  </tr>
		</table>
	</td>
  </tr>
  <tr>
    <td>
		<table border=0 cellpadding=4 cellspacing=2 width="100%">
		  <tr align="center">
		    <td bgcolor="white">
			<br>&nbsp;
			<select multiple size="17" name="list1" style="width:300" onDblClick="move(this.form.list1,this.form.list2)">
			<option>No results found!</option>
			</select>
			<br>&nbsp;
		    </td>
		    <td bgcolor="white" valign="middle">
			<input type="button" onClick="move(this.form.list1,this.form.list2)" value=" --> ">
			<p>&nbsp;</p>
			<input type="button" value="CLEAR" onClick="selectNone();">
			<p>&nbsp;</p>
			<input type="button" onClick="move(this.form.list2,this.form.list1)" value=" <-- ">
		    </td>
		    <td bgcolor="white">
			<br>&nbsp;
			<select multiple size="17" name="list2" style="width:300" onDblClick="move(this.form.list2,this.form.list1)">
			$right_list
			</select>
			<br>&nbsp;
		    </td>
		  </tr>
		 </table>
	</td>
  </tr>
  <tr bgcolor="white">
    <td align="right">
    	<input type="hidden" name="function" value="updatedb">
    	<input type="button" name="run" value="Run OffCycle Payroll" onClick="this.value='Processing...';confirmation();this.value='Run OffCycle Payroll'"> &nbsp;&nbsp;&nbsp;
    	<input type="button" name="update_list" value="Update List" onClick="this.value='Processing...';AjaxUpdate(this,'updatedb');this.value='Update List'"> &nbsp;
    </td>
  </tr>
</table>
</center>
</form>

</body>
</html>
~;
	return;
}

####################################

1;
