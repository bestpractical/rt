#jesse@fsck.com
#
# $Header$

package rt::ui::web;


sub FormQueueOptions{
    local($^W) = 0; # Lots of form fields that may or may not exist give bogus errors
    my @qs;
    

    print "<form action=\"$ScriptURL\" method=\"get\"";
    if ($frames){ 
        print "target=\"queue\"";
    }
    print ">
<center>
<table>
<td valign=\"top\">
<font size=\"-1\">
<b>Status</b>: <SELECT NAME=\"q_status\" Size=1>";
    print "<OPTION SELECTED> any" if ($rt::ui::web::FORM{'q_status'} eq "any");
    print "<OPTION> any" if ($rt::ui::web::FORM{'q_status'} ne "any");
    print "<OPTION SELECTED> open" if (($rt::ui::web::FORM{'q_status'} eq "open" ) or  (!$rt::ui::web::FORM{'q_status'}));
    print "<OPTION> open" if (! (($rt::ui::web::FORM{'q_status'} eq "open" ) or (!$rt::ui::web::FORM{'q_status'})) );
    print "<OPTION SELECTED> stalled" if ($rt::ui::web::FORM{'q_status'} eq "stalled");
    print "<OPTION> stalled" if ($rt::ui::web::FORM{'q_status'} ne "stalled");
    print "<OPTION SELECTED> resolved"  if ($rt::ui::web::FORM{'q_status'} eq "resolved");
    print "<OPTION> resolved" if ($rt::ui::web::FORM{'q_status'} ne "resolved");
    print "<OPTION SELECTED> dead" if ($rt::ui::web::FORM{'q_status'} eq "dead");
    print "<OPTION> dead" if ($rt::ui::web::FORM{'q_status'} ne "dead");
    print "</SELECT\n>";
 
    print "</td>
<td valign=\"top\">
<font size=\"-1\">
<b>Queue</b>: <select name=\"q_queue\">
<option value=\"\">Any\n";
    foreach $queue (sort keys %rt::queues) {
        if ($queue) {
        if (&rt::can_display_queue($queue, $current_user) == 1 ) {
	    push @qs, $queue;


            print "<option";
            if($queue eq $rt::ui::web::FORM{q_queue}) {  print " SELECTED";}
            print ">$queue\n";
        }
    }
    }
    print "
</select>\n<br>
</TD>
<td>
<font size=\"-1\">
<B>Subject:<B><input name=\"q_subject\" size=15 value=\"$rt::ui::web::FORM{'q_subject'}\">
</TD>
</TR>
<TR>
<td valign=\"top\">
<font size=\"-1\">
<b>Owner</b>: <INPUT TYPE=\"checkbox\" NAME=\"q_unowned\" VALUE=\"true\"";

    $rt::ui::web::FORM{'q_unowned'} = '' if ! defined $rt::ui::web::FORM{'q_unowned'};
    $rt::ui::web::FORM{'q_owned_by'} = '' if ! defined $rt::ui::web::FORM{'q_owned_by'};

    print "CHECKED" if $rt::ui::web::FORM{'q_unowned'};
    print "> None ";

    print "<INPUT TYPE=\"checkbox\" NAME=\"q_owned_by\" VALUE=\"true\"";
    print "CHECKED" if $rt::ui::web::FORM{'q_owned_by'};
 
  print "> <select name=\"q_owner\">";

	if (!  $rt::ui::web::FORM{'q_owner'}) {
    $rt::ui::web::FORM{'q_owner'} = $current_user;
}

    foreach $user_id (sort keys %rt::users ) {
	if( $rt::ui::web::FORM{q_queue} )
	{
		next if &rt::can_display_queue($rt::ui::web::FORM{q_queue},$user_id) != 1;
	}
else
	{
		$u = 1;
		foreach $queue ( @qs )
		{
			next if &rt::can_display_queue($queue, $user_id) != 1;
			$u = 0;
			last;
		}
		next if  ($u==1);
	}
	print "<option ";
	if  ($user_id eq $rt::ui::web::FORM{'q_owner'}) {
print "SELECTED";};
	print ">$user_id\n";	
    }
	print "</select>

</TD><td valign=\"top\">
<font size=\"-1\">
<b>Requestor</b>: <INPUT TYPE=\"radio\" NAME=\"q_user\" VALUE=\"\"";
 
   $rt::ui::web::FORM{'q_user'} = '' if ! defined $rt::ui::web::FORM{'q_user'};

   print "CHECKED" if (!$rt::ui::web::FORM{'q_user'}) || (!$rt::ui::web::FORM{'q_user_other'});
    print "> Any ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_user\" VALUE=\"other\"";
    print "CHECKED" if $rt::ui::web::FORM{'q_user_other'};
    print "> <INPUT SIZE=8 NAME=\"q_user_other\"";
    print "VALUE=\"$rt::ui::web::FORM{'q_user_other'}\"" if $rt::ui::web::FORM{'q_user_other'};
    print "> 
<br>
</font>
</td><td valign=\"top\">
<font size=\"-1\"><b>Refresh:</b><SELECT name=\"refresh\">
<OPTION VALUE=0 ";
	if ($rt::ui::web::FORM{'refresh'} == -1 ) { print "SELECTED ";}
        print "> Never";

	print "<OPTION VALUE=60 ";
        if ($rt::ui::web::FORM{'refresh'} == 60 ) { print "SELECTED " ;}
        print "> every 1 minute";


        print "<OPTION VALUE=180 ";
        if ($rt::ui::web::FORM{'refresh'} == 180 ) { print "SELECTED " ;}
        print "> every 3 minutes";


        print "<OPTION VALUE=300 ";
        if ($rt::ui::web::FORM{'refresh'} == 300 ) { print "SELECTED " ;}
        print "> every 5 minutes";
	
	print "<OPTION VALUE=600 ";
        if ($rt::ui::web::FORM{'refresh'} == 600 ) { print "SELECTED " ;}
        print "> every 10 minutes";

	print "<OPTION VALUE=1800 ";
        if ($rt::ui::web::FORM{'refresh'} == 1800 ) { print "SELECTED "; }
        print "> every 30 minutes";

	print "<OPTION VALUE=3600 ";
        if ($rt::ui::web::FORM{'refresh'} == 3600 ) { print "SELECTED "; }
        print "> every hour";

		

print"
</select>
</font>


</td></tr></table></center>
<B>
<center><input type=\"submit\" value =\"Update Queue Filters\"></center>
</B>

<input type=\"hidden\" name=\"display\" value=\"Queue\">
</form>
";

}  

sub FormShowNum{
    print "<form method=get action=\"$ScriptURL\"";
    if ($frames) {
	print "target =\"workspace\" ";
    }
    
    print">";
    if ($frames) {
	print "<input type=\"hidden\" name=\"display\" value=\"Request\">";
    }
    else {
	print "<input type=\"hidden\" name=\"display\" value=\"History\">";
    }
    print "<input type=\"submit\" value=\"Display request #\"><input size=6 name=\"serial_num\">

</form>";
}


sub FormSetUser{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set requestor to\">
<input type=\"hidden\" name=\"do_req_user\" value=\"true\">
<input size=20 name=\"recipient\" VALUE=\"$rt::req[$serial_num]{'requestors'}\">
</FORM>
";
}


sub FormSetGive{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Give to\"><select name=\"do_req_give_to\">
<option value=\"\">Nobody ";	
    foreach $user_id ( sort keys % {$rt::queues{$rt::req[$serial_num]{queue_id}}{acls}} ) {
	if (&rt::can_manipulate_queue ($rt::req[$serial_num]{queue_id}, $user_id)) {
	    print "<option ";
		print "SELECTED" if ($user_id eq $rt::req[$serial_num]{owner});
		print ">$user_id\n";
	    }
	}
    print "</select>
<input type=\"hidden\" name=\"do_req_give\" value=\"true\"></FORM>
";
}
sub FormSetArea{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set area to\"><select name=\"area\">
<option value=\"\">None ";	
    if (&rt::can_manipulate_queue ($rt::req[$serial_num]{queue_id}, $current_user)) {
       foreach $area ( sort keys % {$rt::queues{$rt::req[$serial_num]{queue_id}}{areas}} ) {
	    print "<option ";
		print "SELECTED" if ($area eq $rt::req[$serial_num]{area});
		print ">$area\n";
	    }
    }
    print "</select>
<input type=\"hidden\" name=\"do_req_area\" value=\"true\">
</FORM>
";
}

sub FormSetSubject{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set \#$serial_num\'s subject to\">
<font size=\"$MESSAGE_FONT\">
<input type=\"hidden\" name=\"do_req_subject\" value=\"true\">
<input size=25 name=\"subject\" VALUE=\"$rt::req[$serial_num]{'subject'}\">
</font>
</FORM>
";
}
sub FormSetKill{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" name=\"do_req_kill\" value =\"Kill \#$serial_num\">
<input type=\"submit\" name=\"dummy\" value=\"Abort\"></FORM>
";
}
sub FormSetSteal{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" name=\"do_req_steal\" value =\"Steal \#$serial_num\">
<input type=\"submit\" name=\"dummy\" value=\"Abort\"></FORM>
";
}

sub FormSetMerge{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"hidden\" name=\"do_req_merge\" value=\"true\">
<input type=\"submit\" value =\"Merge into #\"> <input size=5 name=\"req_merge_into\" ></FORM>
";
}
sub FormSetQueue{
    my ($queue, $value);
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set queue to\"> <select name=\"queue\">";
    foreach $queue (sort keys %rt::queues) {
	if (&rt::can_create_request($queue, $current_user)) {
	    print "<option";
	    if ($rt::req[$serial_num]{queue_id} eq $queue) {
		print " SELECTED";
	    }
	    print ">$queue\n";
	}
	}
    print "
</select>
<input type=\"hidden\" name=\"do_req_queue\" value=\"true\"> 
</FORM>
";
}
  



sub  FormSetDateDue{
    print "<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"do_req_date_due\" value=\"true\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set Date Due to\"> ";
    &rt::ui::web::select_a_date($rt::req[$serial_num]{date_due}, "due");
    print "</FORM>";
}  

sub  FormSetPrio{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"do_req_prio\" value=\"true\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set \#$serial_num\'s priority to\">";
    &rt::ui::web::select_an_int($rt::req[$serial_num]{priority}, "prio");
 
    print "</FORM>\n";
}  
sub  FormSetFinalPrio{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"do_req_final_prio\" value=\"true\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set \#$serial_num\'s final priority to\">";
    &rt::ui::web::select_an_int($rt::req[$serial_num]{final_priority}, "final_prio");
    print "</FORM>\n";
}  


sub  FormSetStatus{
    if ($rt::req[$serial_num]{status} eq 'dead') { 
	print "You can not reopen requests that have been killed";
	return();
    }
  
    print "<form action=\"$ScriptURL\" method=\"post\"";
   if ($frames) {
	print "target=\"summary\"";
    }
    print">";
    print "<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\">\n";
    print "<input type=\"submit\" value =\"Set \#$serial_num\'s status to\"> ";  
    print "<select name=\"do_req_status\">\n";
    print "<option value=\"open\" ";
    if ($rt::req[$serial_num]{status} eq 'open') { print "SELECTED";}
    print ">open\n";
    print "<option value=\"stall\" ";
    if ($rt::req[$serial_num]{status} eq 'stalled') { print "SELECTED";}
    print ">stalled\n";
    print "<option value=\"resolve\" ";
    if ($rt::req[$serial_num]{status} eq 'resolved') { print "SELECTED";}
    print ">resolved\n";
    print "<option value =\"kill\">dead\n";
    print "</select>\n";
  
    print "</FORM>\n";
}
sub FormReply{
    my ($reply_content);
 
    # if we were called with a transaction num, let's read its content and quote it
    if ($rt::ui::web::FORM{'transaction'}) {
	$reply_content= &rt::quote_content($rt::ui::web::FORM{'transaction'},$current_user);
    }


    print "<form action=\"$ScriptURL\" method=\"post\"";
    if ($frames) {
	print "target=\"summary\"";
    }
    print ">
<H1>
Enter your reply to the requestor below:
</H1>
<pre>
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\">
Status:<select name=\"do_req_status\">\n";
    print "<option value=\"open\" ";
    if ($rt::req[$serial_num]{status} eq 'open') { print "SELECTED";}
    print ">open\n";
    print "<option value=\"stall\" ";
    if ($rt::req[$serial_num]{status} eq 'stalled') { print "SELECTED";}
    print ">stalled\n";
    print "<option value=\"resolve\" ";
    if ($rt::req[$serial_num]{status} eq 'resolved') { print "SELECTED";}
    print ">resolved\n";
    print "
</select>

Give to:<select name=\"do_req_give_to\">
<option value=\"\">Nobody ";   
    foreach $user_id ( sort keys % {$rt::queues{$rt::req[$serial_num]{queue_id}}{acls}}) {
       if (&rt::can_manipulate_queue ($rt::req[$serial_num]{queue_id}, $user_id)) {
           print "<option ";
               print "SELECTED" if ($user_id eq $rt::req[$serial_num]{owner});
               print ">$user_id\n";
           }
       }
    print "</select>
<input type=\"hidden\" name=\"do_req_give\" value=\"true\">


To:       $rt::req[$serial_num]{requestors}
Cc:	  <input name=\"cc\">
Bcc:      <input name=\"bcc\">
From:     $rt::users{$current_user}{email}
Subject:  <input name=\"subject\" size=\"50\" value=\"$rt::req[$serial_num]{'subject'}\">
</pre>
<input type=\"hidden\" name=\"do_req_respond\" value=\"true\">
<font size=\"$MESSAGE_FONT\">
<br><textarea rows=15 cols=78 name=\"content\" WRAP=HARD>
$reply_content
</textarea>
</font>
<center><input type=\"submit\" value=\"Send Response\"></center></form>";
}

sub FormCreate{   
    print "<form action=\"$ScriptURL\" method=\"post\"";
    if ($frames) { 
	print "target=\"history\" ";
    }
    print ">
<input type=\"submit\" value=\"Create request in queue\"><select name=\"queue_id\">\n";
    foreach $queue (sort keys %rt::queues) {
	if (&rt::can_create_request($queue, $current_user)) {
	    print "<option>$queue\n";
	}
#	else {
#	print "<!-- $current_user can't make a req in $queue\n\n-->";    
#	}
}
    print"</select>
<input type=\"hidden\" name=\"display\" value=\"Create_Step2\">
</form>";
    
}
sub FormCreate_Step2 {   
    my ($template,$actions,$user_id, $value);
    my $queue_id;
    require rt::support::mail;

    $queue_id = $rt::ui::web::FORM{'queue_id'};
    
    print "<CENTER> <form action=\"$ScriptURL\" method=\"post\"";
    if ($frames) { print "target=\"summary\" ";
	       }
    print ">";
      print "<table>
<TR>
<TD align=\"right\">
Queue:
</TD>
<TD> $queue_id </TD>
<TD align=\"right\"> Created by:

</TD> 
<TD>
 $current_user
</TD>
\n";
    $template=&rt::template_read("web_create",$rt::ui::web::FORM{'queue_id'});
    $template=&rt::template_replace_tokens($template,0,0,"", $current_user);
    if ($current_user){

    print "
<TD align=\"right\">Area:
</TD>
<TD><select name=\"area\">
<option value=\"\">None ";	
    if (&rt::can_manipulate_queue ($queue_id, $current_user)) {
	foreach $area (sort keys % {$rt::queues{$queue_id}{areas}}) {
	    print "<option>$area\n";
	}
    }
    print "</select>
</TD>
</TR>
<TR>
<TD align=\"right\">Status:</TD>
<TD><select name=\"status\">
<option value=\"open\">open
<option value=\"stalled\">stalled
<option value=\"resolved\">resolved
</select></TD>
<TD align=\"right\">Owner:
</TD>
<TD>
<select name=\"owner\">
<option value=\"\">Nobody ";	
	foreach $user_id ( sort keys % {$rt::queues{$rt::ui::web::FORM{'queue_id'}}{acls}} ) {
	    if (&rt::can_manipulate_queue ($rt::ui::web::FORM{'queue_id'}, $user_id)) {
		print "<option>$user_id\n";
	    }
	}
	print "</select></TD></TR>\n";
    }	



    print"<TR><TD align=\"right\">Priority:</TD><TD>";
    
    &rt::ui::web::select_an_int($rt::queues{$queue_id}{default_prio}, "prio");
    print "
</TD><TD align=\"right\">
Final priority:
</TD>
<TD>";
    &rt::ui::web::select_an_int($rt::queues{$queue_id}{default_final_prio}, "final_prio");
    print "</TD></TR>
<TR><TD align=\"right\">Date Due:</TD><TD COLSPAN=5><input type=\"checkbox\" name=\"due\">";
    &rt::ui::web::select_a_date($rt::req[$serial_num]{date_due}, "due");
    print "</TD></TR>
<TR><TD align=\"right\">Requestor:</TD><TD COLSPAN=5><input name=\"requestors\" size=\"30\"";
    if ($current_user ne 'anonymous') {
	print "value=\"$rt::users{$current_user}{email}\"";
    }
    print "></TD></TR>
<TR><TD align=\"right\">Subject:</TD><TD COLSPAN=5>  <input name=\"subject\" size=\"50\">

</TD></TR>
<TR><TD valign=\"top\" align=\"right\">Content:</TD><TD COLSPAN=5>
<font size=\"-1\">
<textarea rows=15 cols=78 name=\"content\" WRAP=HARD>
$template
</textarea>
</TD></TR>
</TABLE>
</font>
<center>
<input type=\"submit\" value=\"Create request\">
</center>
<input type=\"hidden\" name=\"queue_id\" value=\"$rt::ui::web::FORM{'queue_id'}\">
<input type=\"hidden\" name=\"alias\" value=\"$rt::ui::web::FORM{'alias'}\">
<input type=\"hidden\" name=\"do_req_create\" value=\"true\">
</form>
</CENTER>";
    
}

sub FormComment{
    my ($reply_content);
  if ($rt::ui::web::FORM{'transaction'}) {
	$reply_content= &rt::quote_content($rt::ui::web::FORM{'transaction'},$current_user);
    }    
    print "
<form action=\"$ScriptURL\" method=\"post\" ";

if ($rt::ui::web::frames) { print " target=\"summary\"";}

print " >
<H1>
Enter your comments below:
</H1>
<pre>
Summary: <input name=\"subject\" size=\"50\" value=\"$rt::req[$serial_num]{'subject'}\">
Cc:	 <input name=\"cc\">
Bcc:	 <input name=\"bcc\"> 
</pre>
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\">
<input type=\"hidden\" name=\"do_req_comment\" value=\"true\">
<br><font size=\"$MESSAGE_FONT\">
<textarea rows=15 cols=78 name=\"content\" WRAP=HARD>
$reply_content
</textarea>
</font>
<center>
<input type=\"submit\" value=\"Submit Comments\">
</center>
</form>";
}

1;
