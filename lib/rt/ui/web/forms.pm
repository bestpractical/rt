#jesse@fsck.com
#


package webrt;


sub FormQueueOptions{
    local($^W) = 0; # Lots of form fields that may or may not exist give bogus errors
    print "<form action=\"$ScriptURL";
    print "\" method=\"post\"";
    if ($frames){
        print "target=\"queue\"";
    }
    print ">
<table><tr><td>
<table>
<tr><td valign=\"top\">
<font size=\"-1\">";
    print "<b>Order by</b>:<BR> "; 

    print "<SELECT NAME=\"q_sort\" Size=1>";
    
    
    print "<OPTION";
    print " selected" if ($RT_UI_Web::FORM{'q_sort'} eq "Ticket Number");
    print ">Ticket Number";

    print "<OPTION";
    print " selected" if ($RT_UI_Web::FORM{'q_sort'} eq "Ticket Number");
    print ">Ticket Number";

    print "<OPTION";
    print " selected" if ($RT_UI_Web::FORM{'q_sort'} eq "Timestamp");
    print ">Timestamp";

    print "<OPTION";
    print " selected" if ($RT_UI_Web::FORM{'q_sort'} eq "User");
    print ">User";
   print "<OPTION";
    print " selected" if ($RT_UI_Web::FORM{'q_sort'} eq "Priority");
    print ">Priority";
   print "<OPTION";
    print " selected" if ($RT_UI_Web::FORM{'q_sort'} eq "Date Due");
    print ">Date Due";

    print "</SELECT>";
    
    print "</TD><td valign=\"top\">";
    print "<font size=\"-1\">";
    print "<b>Status</b>: <BR>";

    print "<SELECT NAME=\"q_status\" Size=1>";
    print "<OPTION SELECTED> any" if ($RT_UI_Web::FORM{'q_status'} eq "any");
    print "<OPTION> any" if ($RT_UI_Web::FORM{'q_status'} ne "any");
    print "<OPTION SELECTED> open" if (($RT_UI_Web::FORM{'q_status'} eq "open" ) or  (!$RT_UI_Web::FORM{'q_status'}));
    print "<OPTION> open" if (! (($RT_UI_Web::FORM{'q_status'} eq "open" ) or (!$RT_UI_Web::FORM{'q_status'})) );
    print "<OPTION SELECTED> stalled" if ($RT_UI_Web::FORM{'q_status'} eq "stalled");
    print "<OPTION> stalled" if ($RT_UI_Web::FORM{'q_status'} ne "stalled");
    print "<OPTION SELECTED> resolved"  if ($RT_UI_Web::FORM{'q_status'} eq "resolved");
    print "<OPTION> resolved" if ($RT_UI_Web::FORM{'q_status'} ne "resolved");
    print "<OPTION SELECTED> dead" if ($RT_UI_Web::FORM{'q_status'} eq "dead");
    print "<OPTION> dead" if ($RT_UI_Web::FORM{'q_status'} ne "dead");
    print "</SELECT>";
 
    print "</td>";
    print "<td valign=\"top\">";
    print "<font size=\"-1\">";
   print "<b>Queue</b>: <BR><select name=\"q_queue\">";
    print "<option value=\"\">Any\n";
    while(($queue, $value)= each %rt::queues) {
        if ($queue) {
        if (&rt::can_display_queue($queue, $current_user)) {
            print "<option";
            if($queue eq $RT_UI_Web::FORM{q_queue}) {  print " SELECTED";}
            print ">$queue\n";
        }
    }
    }
    print "</select>\n<br>";


    print "</TD></TR><TR><td valign=\"top\">";
    print "<font size=\"-1\">";
    print"<BR><INPUT TYPE=\"checkbox\" NAME=\"q_reverse\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_reverse'};
    print "> Reverse Order ";

    print "</td><td>";
    print "<font size=\"-1\">";
    print "<B>Subject:<B><input name=\"q_subject\" size=15 value=\"$RT_UI_Web::FORM{'q_subject'}\">";

    print "</TD></TR><TR><td valign=\"top\">";
    print "<font size=\"-1\">";
    print "<b>Owner</b>: <INPUT TYPE=\"checkbox\" NAME=\"q_unowned\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_unowned'};
    print "> None <INPUT TYPE=\"checkbox\" NAME=\"q_owned_by_me\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_owned_by_me'};
    print ">  $current_user <INPUT TYPE=\"checkbox\" NAME=\"q_owned_by\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_owned_by'};
    print "> <select name=\"q_owner\">
	<option value=\"\">Nobody ";	
    
    while  (($user_id,$value) = each %rt::users ) {
	
	print "<option ";
	if ($FORM{'q_owner'} eq $user_id) {
	    print "SELECTED";
	}
	    print ">$user_id\n";
	
    }
	print "</select>\n";
    	
    print "\n<br>";
    print "</TD><td valign=\"top\">";
    print "<font size=\"-1\">";
    print "<b>User</b>: ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_user\" VALUE=\"\"";
    print "CHECKED" if (!$RT_UI_Web::FORM{'q_user'});
    print "> Any ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_user\" VALUE=\"$current_user\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_user'} eq "$current_user");
    print "> $current_user ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_user\" VALUE=\"other\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_user_other'};
    print "> <INPUT SIZE=8 NAME=\"q_user_other\"";
    print "VALUE=\"$RT_UI_Web::FORM{'q_user_other'}\"" if $RT_UI_Web::FORM{'q_user_other'};
    print "> ";

    print "\n<br>";
    print "</font>";
    print "</td><td valign=\"top\">";
    print "</td></tr></table>";
    print "</td><td><B>";
     print "<center><input type=\"submit\" value =\"Refresh Queue\"></center>";

    print "</B></td></tr>";
        print "</td></tr></table>";
    print "<input type=\"hidden\" name=\"display\" value=\"Queue\">";

    print "</form>\n";

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
    print "<input type=\"submit\" value=\"Display Request #\"><input size=6 name=\"serial_num\">

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
    foreach $user_id ( keys % {$rt::queues{$rt::req[$serial_num]{queue_id}}{acls}} ) {
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
    foreach $area ( keys % {$rt::queues{$rt::req[$serial_num]{queue_id}}{areas}} ) {
	if (&rt::can_manipulate_queue ($rt::req[$serial_num]{queue_id}, $current_user)) {
	    print "<option ";
		print "SELECTED" if ($user_id eq $rt::req[$serial_num]{area});
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
<font size=\"-1\">
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
    while(($queue, $value)= each %rt::queues) {
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
    &RT_UI_Web::select_a_date($rt::req[$serial_num]{date_due}, "due");
    print "</FORM>";
}  

sub  FormSetPrio{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"do_req_prio\" value=\"true\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set \#$serial_num\'s priority to\">";
    &RT_UI_Web::select_an_int($rt::req[$serial_num]{priority}, "prio");
 
    print "</FORM>\n";
}  
sub  FormSetFinalPrio{
    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"do_req_final_prio\" value=\"true\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<input type=\"submit\" value =\"Set \#$serial_num\'s final priority to\">";
    &RT_UI_Web::select_an_int($rt::req[$serial_num]{final_priority}, "final_prio");
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
    if ($RT_UI_Web::FORM{'transaction'}) {
	$reply_content= &rt::quote_content($RT_UI_Web::FORM{'transaction'},$current_user);
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
To:       $rt::req[$serial_num]{requestors}
From:     $rt::users{$current_user}{email}
Subject:  <input name=\"subject\" size=\"50\" value=\"$rt::req[$serial_num]{'subject'}\">
</pre>
<input type=\"hidden\" name=\"do_req_respond\" value=\"true\">
<font size=\"-1\">
<br><textarea rows=15 cols=70 name=\"content\" wrap>
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
    while(($queue, $value)= each %rt::queues) {
	if (&rt::can_create_request($queue, $current_user)) {
	    print "<option>$queue\n";
	}
    }
    print"</select>
<input type=\"hidden\" name=\"display\" value=\"Create_Step2\">
</form>";
    
}
sub FormCreate_Step2 {   
    my ($template,$actions,$user_id, $value);
    print "<form action=\"$ScriptURL\" method=\"post\"";
    if ($frames) { print "target=\"summary\" ";
	       }
    print ">";
      print "<pre>
Queue: $RT_UI_Web::FORM{'queue_id'} * Created by: $current_user\n";
    $template=&rt::template_read("web_create",$RT_UI_Web::FORM{'queue_id'});
    if ($current_user){

    print "Area:<select name=\"area\">
<option value=\"\">None ";	
    if (&rt::can_manipulate_queue ($rt::req[$serial_num]{queue_id}, $current_user)) {
	foreach $area ( keys % {$rt::queues{$RT_UI_Web::FORM{queue_id}}{areas}} ) {
	    
	    print "<option>$area\n";
	}
    }
    print "</select>";

print " * Status:<select name=\"status\">
<option value=\"open\">open
<option value=\"stalled\">stalled
<option value=\"resolved\">resolved
</select>";
    
print " * Owner:<select name=\"owner\">
<option value=\"\">Nobody ";	
	foreach $user_id ( keys % {$rt::queues{$RT_UI_Web::FORM{'queue_id'}}{acls}} ) {
	    if (&rt::can_manipulate_queue ($RT_UI_Web::FORM{'queue_id'}, $user_id)) {
		print "<option>$user_id\n";
	    }
	}
	print "</select>\n";
    }	



    print"Priority:";
    
    &RT_UI_Web::select_an_int($rt::req[$serial_num]{priority}, "prio");
    print " * Final priority:";
    &RT_UI_Web::select_an_int($rt::req[$serial_num]{final_priority}, "final_prio");
    print "\n<input type=\"checkbox\" name=\"due\"> Set Date Due:";
    &RT_UI_Web::select_a_date($rt::req[$serial_num]{date_due}, "due");
    print "
Requestor:<input name=\"requestors\" size=\"30\"";
    if ($current_user ne 'anonymous') {
	print "value=\"$rt::users{$current_user}{email}\"";
    }
    print ">
Summary:  <input name=\"subject\" size=\"50\">
</pre>
<font size=\"-1\">
<br><textarea rows=15 cols=70 name=\"content\" wrap>
$template
</textarea>
</font>
<center>
<input type=\"submit\" value=\"Create Request\">
</center>
<input type=\"hidden\" name=\"queue_id\" value=\"$RT_UI_Web::FORM{'queue_id'}\">
<input type=\"hidden\" name=\"alias\" value=\"$RT_UI_Web::FORM{'alias'}\">
<input type=\"hidden\" name=\"do_req_create\" value=\"true\">
</form>";
    
}

sub FormComment{
    my ($reply_content);
  if ($RT_UI_Web::FORM{'transaction'}) {
	$reply_content= &rt::quote_content($RT_UI_Web::FORM{'transaction'},$current_user);
    }    
    print "
<form action=\"$ScriptURL\" method=\"post\" target=\"summary\">
<H1>
Enter your comments below:
</H1>
<pre>
Summary: <input name=\"subject\" size=\"50\" value=\"$rt::req[$serial_num]{'subject'}\">
</pre>
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\">
<input type=\"hidden\" name=\"do_req_comment\" value=\"true\">
<br><font size=\"-1\">
<textarea rows=15 cols=70 name=\"content\" wrap>
$reply_content
</textarea>
</font>
<center>
<input type=\"submit\" value=\"Submit Comments\">
</center>
</form>";
}


1;
