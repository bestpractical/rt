package rt::ui::web;

sub activate { 
use Time::Local;
require rt::ui::web::auth;

&rt::ui::web::cgi_vars_in();
$ScriptURL=$ENV{'SCRIPT_NAME'}.$ENV{'PATH_INFO'};
($value, $message)=&rt::initialize('web_not_authenticated_yet');
if ($value) {
    $message="";
}
&CheckAuth();
&WebAuth::Headers_Authenticated();

$result=&take_action();
&DisplayForm();
return(0);
}

### subroutines 
sub CheckAuth() {
    local ($name,$pass);
    
	require rt::database::config;
    $AuthRealm="WebRT for $rt::rtname";
    if ($ENV{'QUERY_STRING'} eq 'display=Logout') {
	&WebAuth::AuthForceLogout($AuthRealm);
	exit(0);
    }
    
    ($name, $pass)=&WebAuth::AuthCheck($AuthRealm);
    
    if (!(&rt::is_password($name, $pass))) {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0);    }
    
    elsif ($name eq '') {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0)
	}
    else  {
	$current_user = $name;
	&WebAuth::Headers_Authenticated();
    }
}
sub DisplayForm {

    &rt::ui::web::header();
#    print "<h1>WebRT Administrator</h1>";
    
    if ($result ne '') {
	print "$result<hr>";
    }
    
    if ((!$rt::ui::web::FORM{'display'}) or ($rt::ui::web::FORM{'display'} eq 'Return to Admin Menu')){
	
	
	&menu();

    }

    #nice for debugging 
    else {
	if ($rt::ui::web::FORM{'display'} eq 'DumpEnv'){

	    &dump_env();

	}    
	elsif ($rt::ui::web::FORM{'display'} eq 'Credits') {

	    &credits();

	}
	
	elsif ($rt::ui::web::FORM{'display'} eq 'Create a User called') {
	    &FormModifyUser($rt::ui::web::FORM{'new_user_id'});
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'Modify your RT Account') {
	    &FormModifyUser($current_user);
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'Create a Queue called') {
	    &FormModifyQueue($rt::ui::web::FORM{'new_queue_id'});
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'Modify the User called'){
       	    &FormModifyUser($rt::ui::web::FORM{'user_id'});
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'Modify the Queue called'){
	    &FormModifyQueue($rt::ui::web::FORM{'queue_id'});
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'Delete this Queue'){
	    &FormDeleteQueue($rt::ui::web::FORM{'queue_id'});
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'Delete this User'){
	    &FormDeleteUser($rt::ui::web::FORM{'user_id'});
	}    }
   
   &rt::ui::web::footer();
}

sub take_action {
    my ($queue_id,$acl,$acl_string,$user_id,$value);
    
    require rt::database::admin;    
    

    if ($rt::ui::web::FORM{action} eq "Update Queue") {
	
      ($flag, $message)=&rt::add_modify_queue_conf($rt::ui::web::FORM{queue_id}, $rt::ui::web::FORM{email}, &rt::booleanize($rt::ui::web::FORM{m_owner_trans}), &rt::booleanize($rt::ui::web::FORM{m_members_trans}), &rt::booleanize($rt::ui::web::FORM{m_user_trans}), &rt::booleanize($rt::ui::web::FORM{m_user_create}), &rt::booleanize($rt::ui::web::FORM{m_members_correspond}), &rt::booleanize($rt::ui::web::FORM{m_members_comment}), &rt::booleanize($rt::ui::web::FORM{allow_user_create}), "$rt::ui::web::FORM{'initial_prio_tens'}$rt::ui::web::FORM{'initial_prio_ones'}","$rt::ui::web::FORM{'final_prio_tens'}$rt::ui::web::FORM{'final_prio_ones'}", $current_user);


	while (($user_id,$value)= each %rt::users) {
	    $acl_string="acl_" . $rt::ui::web::FORM{queue_id} . "_" . $user_id;
	    $acl=$rt::ui::web::FORM{$acl_string};
	    if ($acl eq 'admin') {
		&rt::add_modify_queue_acl($rt::ui::web::FORM{queue_id},$user_id,1,1,1,$current_user);
	    }
	    if ($acl eq 'manip') {
		&rt::add_modify_queue_acl($rt::ui::web::FORM{queue_id},$user_id,1,1,0,$current_user);
	    }
	    if ($acl eq 'disp') {
		&rt::add_modify_queue_acl($rt::ui::web::FORM{queue_id},$user_id,1,0,0,$current_user);
	    }
	    if ($acl eq 'none') {
		&rt::add_modify_queue_acl($rt::ui::web::FORM{queue_id},$user_id,0,0,0,$current_user);
	    }

	}
    }

    if ($rt::ui::web::FORM{action} eq "delete_user") {
	($flag, $message)=&rt::delete_user($rt::ui::web::FORM{user_id}, $current_user);
	
	}
    if ($rt::ui::web::FORM{action} eq "delete_queue") {
        ($flag, $message)=&rt::delete_queue($rt::ui::web::FORM{queue_id}, $current_user);

        }       
    if ($rt::ui::web::FORM{action} eq "Update User") {

	
	($flag, $message)=&rt::add_modify_user_info($rt::ui::web::FORM{user_id}, $rt::ui::web::FORM{password}, $rt::ui::web::FORM{email}, $rt::ui::web::FORM{phone}, $rt::ui::web::FORM{office},$rt::ui::web::FORM{comments}, &rt::booleanize($rt::ui::web::FORM{admin_rt}), $current_user);
	while (($queue_id,$value)= each %rt::queues) {

	    $acl_string="acl_" . $queue_id . "_" . $rt::ui::web::FORM{user_id};
	    $acl=$rt::ui::web::FORM{$acl_string};
	    
	    if ($acl eq 'admin') {

		&rt::add_modify_queue_acl($queue_id,$rt::ui::web::FORM{user_id},1,1,1,$current_user);
	    }
	    if ($acl eq 'manip') {

		&rt::add_modify_queue_acl($queue_id,$rt::ui::web::FORM{user_id},1,1,0,$current_user);
	    }
	    if ($acl eq 'disp') {

		&rt::add_modify_queue_acl($queue_id,$rt::ui::web::FORM{user_id},1,0,0,$current_user);
	    }
	    if ($acl eq 'none') {
		&rt::add_modify_queue_acl($queue_id,$rt::ui::web::FORM{user_id},0,0,0,$current_user);
	    }

	}
    }
    if ($rt::ui::web::FORM{delete_area} ) {
	($flag, $message)=&rt::delete_queue_area($rt::ui::web::FORM{queue_id}, $rt::ui::web::FORM{delete_area}, $current_user);
    }
    if ($rt::ui::web::FORM{add_area} ) {
	($flag, $message)=&rt::add_queue_area($rt::ui::web::FORM{queue_id}, $rt::ui::web::FORM{add_area}, $current_user);
    }
	return "$message<br>$total_result";	    
    
}	



sub menu () {
    my ($queue_id,$user_id,$value);


    print "<table width=100%>
<tr>
<td align=left>
<H2>RT Web Administrator</H2>
</td>
<td align=right><H2>Main Menu</H2></td></tr>
</TABLE>
";
   
    print "<form action=\"$ScriptURL\" method=\"post\">";
    
    &rt::ui::web::new_table("width=100%"); {
	&rt::ui::web::new_row("valign=top"); {
	    &rt::ui::web::new_col("valign=top align=left"); {
		print "\n<H2>User Configuration</H2>\n";
		
		if ($rt::users{$current_user}{admin_rt}) {
		    
		    print "
<input type=Submit name=display value=\"Create a User called\"> <input size=15 name=\"new_user_id\">
<br>
<input type=submit name=display value=\"Modify the User called\"> <select name=\"user_id\">\n";
		    while (($user_id,$value)= each %rt::users) {
			print "<option value=\"$user_id\">$user_id\n";
			
		    }
		    print "</select>\n<br>\n";
	
		}
		print "\n<input type=submit name=display value=\"Modify your RT Account\">";
	    } &rt::ui::web::end_col();
	    &rt::ui::web::new_col("valign=top align=right"); {
	    print "\n<H2>Queue Configuration</H2>";
    if ($rt::users{$current_user}{admin_rt}) {
	print "<input type=Submit name=display value=\"Create a Queue called\"> <input size=15 name=\"new_queue_id\">
<br>";
}
    print "<input type=submit name=display value=\"Modify the Queue called\"> <select name=\"queue_id\">";
    while (($queue_id,$value)= each %rt::queues) {
	#if (&rt::can_admin_queue($queue_id, $current_user)){
	    print "<option value=\"$queue_id\">$queue_id";
	#}
    }
    print "</select>\n";
	} &rt::ui::web::end_col();
	} &rt::ui::web::end_row();
    } &rt::ui::web::end_table();
	    
    print "</form>\n";
    
}





sub FormModifyUser{
    my ($user_id) = @_;

    print "<table width=100%><tr><td align=left><H2>RT Web Administrator</H2></td><td align=right>";
   
    if (!&rt::is_a_user($user_id)) {
	print "<h2>Create a new user called <b>$user_id</b></h2>\n"
	}
    elsif  ($user_id eq $current_user){
	print "<h2>Modify your own attributes</h2>\n";
    }
    
    
    else {
	print "<h2>Modify the user <b>$user_id</b></h2>";
    }
    
    print "</td></tr></table>\n<hr>\n";

    &rt::ui::web::new_table("width=100%"); {
	&rt::ui::web::new_row(); {
	    &rt::ui::web::new_col("valign=top"); {


		print "
<TABLE BGCOLOR=black width=100% cellpadding=5><TR><TD><FONT COLOR=white><H1>User Configuration</H!></FONT></TD></TR></TABLE>
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"user_id\" value=\"$user_id\" >
<table>
<tr>
<td>
Username:
</td>
<td>
$user_id
</td>
</tr>
<tr>
<td>
email:   
</td>
<td>
<input name=\"email\" size=30 value=\"$rt::users{$user_id}{email}\">
</td>
</tr>
<tr>
<td>
password:
</td>
<td>
<input type=\"password\" name=\"password\" size=15><font size=\"-2\">(leave blank unless you want to change)</font>
</td>
</tr>
<tr>
<td>
phone:
</td>
<td>
<input name=\"phone\" size=30 value=\"$rt::users{$user_id}{phone}\">
</td>
</tr>
<tr>
<td>
office:
</td>
<td>
<input name=\"office\" size=30 value=\"$rt::users{$user_id}{office}\">
</td>
</tr>
<tr>
<td>
misc:
</td>
<td>
<input name=\"comments\" size=30 value=\"$rt::users{$user_id}{comments}\">
</td>
</tr>
</table>
";

	    } &rt::ui::web::end_col();
	    &rt::ui::web::new_col("align=right valign=top"); {
		print "<TABLE BGCOLOR=black width=100% cellpadding=5><TR><TD align=right><FONT COLOR=white><H1>Access Control</H!></FONT></TD></TR></TABLE>\n<br>\n";
		if ($rt::users{$current_user}{admin_rt}) {
		    print "RT Admin: <input type=\"checkbox\" name=\"admin_rt\" ";
		    print "checked" if ($rt::users{$user_id}{admin_rt});
		    print "><br><hr>\n";
		    while (($queue_id,$value)= each %rt::queues) {
			print "<b><A HREF=\"$ScriptURL?display=Modify+the+Queue+called&queue_id=$queue_id\">$queue_id</a>:</b>\n";
			
			if (!&rt::is_a_queue($queue_id)){
			    print "$queue_id: That queue does not exist. (You should never see this error)\n";
			    return(0);
			}
			&select_queue_acls($user_id, $queue_id);
		    }
		}
		
		else {
		    if ($rt::users{user_id}{admin_rt}) {
			print "<b>This user is an RT administrator</b><br>\n";
		    }
		    while (($queue_id,$value)= each %rt::queues) {
			print "<b>$queue_id:</b>\n";
			if (!&rt::can_display_queue($queue_id,$user_id)){
			    print "No Access\n";
			}
			elsif ((&rt::can_admin_queue($queue_id,$user_id))== 1){
			    print "Admin\n";
			}
			elsif ((&rt::can_manipulate_queue($queue_id,$user_id))==1){
			    print "Manipulate\n";
			}
			elsif ((&rt::can_display_queue($queue_id,$user_id))==1){
			    print "Display\n";	
			}
			else {
			    print "This should never appear (NO ACLS!)\n";
			}
		    }
		}
		
	    } &rt::ui::web::end_col();
	} &rt::ui::web::end_row();
    } &rt::ui::web::end_table();
    
    &rt::ui::web::new_table("width=100%");
    &rt::ui::web::new_row();
    &rt::ui::web::new_col("align=left");
    print "<input type=\"submit\" name=\"action\" value=\"Update User\">\n";
    &rt::ui::web::end_col();
    if ($rt::users{$current_user}{admin_rt}) {
	&rt::ui::web::new_col("align=center");
	print "<input type=\"submit\" name=\"display\" value=\"Delete this User\">\n";
	&rt::ui::web::end_col();
    }
    &rt::ui::web::new_col("align=right");
    print "<input type=\"submit\" name=\"display\" value=\"Return to Admin Menu\">\n";
    &rt::ui::web::end_col();
    &rt::ui::web::end_row();
    &rt::ui::web::end_table();



print "</FORM>";
}


sub FormModifyQueue{
    my ($queue_id) = @_;
    print "<table width=100%>
<tr>
<td align=left>
<H2>RT Web Administrator</H2>
</td>
<td align=right>
";    
    if (!&rt::is_a_queue($queue_id)) {
	print "<h2>Create a new queue called <b>$queue_id</b></h2>\n"

	}
    else {
	print "<h2>Modify the queue <b>$queue_id</b></h2>\n";
    }
    print "</td></tr>
</TABLE>";
    &rt::ui::web::new_table("width=100%"); {
	&rt::ui::web::new_row(); {
	    &rt::ui::web::new_col("valign=top"); {
    print "
<TABLE BGCOLOR=black width=100% cellpadding=5><TR><TD><FONT COLOR=white><H1>Queue Configuration</H!></FONT></TD></TR></TABLE>
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"queue_id\" value=\"$queue_id\" >

<table>
<tr>
<td>
Queue name:
</td>
<td>
$queue_id
</td>
</tr>
<tr>
<td>
mail alias:
</td>
<td>
<input name=\"email\" size=30 value=\"$rt::queues{$queue_id}{mail_alias}\">
</td>
</tr>
<tr>
<td>
Initial priority:
</td>
<td> ";
    &rt::ui::web::select_an_int($rt::queues{$queue_id}{default_prio},"initial_prio");
    print "</td>
</tr>
<tr>
<td>
Final priority:
</td>
<td>";
    &rt::ui::web::select_an_int($rt::queues{$queue_id}{default_final_prio},"final_prio");
    print "</td></tr></table>\n";

    print "<input type=\"checkbox\" name=\"m_owner_trans\" ";
    print "CHECKED" if ($rt::queues{$queue_id}{m_owner_trans});
    print "> Mail request owner on transaction<br>\n";
     
    print "<input type=\"checkbox\" name=\"m_members_trans\" ";
    print "CHECKED" if ($rt::queues{$queue_id}{m_members_trans});
    print "> Mail request queue members on transaction<br>\n";
    
    print "<input type=\"checkbox\" name=\"m_user_trans\" ";
    print "CHECKED" if ($rt::queues{$queue_id}{m_user_trans});
    print "> Mail requestors on transaction<br>\n";
    
    print "<input type=\"checkbox\" name=\"m_user_create\" ";
    print "CHECKED" if ($rt::queues{$queue_id}{m_user_create});
    print "> Autoreply to requestors on creation<br>\n";
    
    print "<input type=\"checkbox\" name=\"m_members_correspond\" ";
    print "CHECKED" if ($rt::queues{$queue_id}{m_members_correspond});
    print "> Mail correspondence to queue members<br>\n";
    
    print "<input type=\"checkbox\" name=\"m_members_comment\" ";
    print "CHECKED" if ($rt::queues{$queue_id}{m_members_comment});
    print "> Mail comments to queue members<br>\n";
    
    print "<input type=\"checkbox\" name=\"allow_user_create\" ";
    print "CHECKED" if ($rt::queues{$queue_id}{allow_user_create});
    print "> Allow non-members to create requests<br>\n";

 
    print "Delete the area <select name=\"delete_area\">
<option value=\"\">None ";	
    foreach $area ( keys % {$rt::queues{$queue_id}{areas}} ) {
	print "<option>$area\n";
    }
    print "</select>\n";
    
    print "<br>Add an area called <input size=\"15\" name=\"add_area\"><br>\n";
    
    } &rt::ui::web::end_col();
    &rt::ui::web::new_col("align=right valign=top"); {
	print "<TABLE BGCOLOR=black width=100% cellpadding=5><TR><TD align=right><FONT COLOR=white><H1>Access Control</H!></FONT></TD></TR></TABLE>\n";
    while (($user_id,$value)= each %rt::users) {
      print "<A HREF=\"$ScriptURL?display=Modify+the+User+called&user_id=$user_id\">$user_id</a>:";

	&select_queue_acls($user_id, $queue_id);
    }
    } &rt::ui::web::end_col();
    } &rt::ui::web::end_row();
    } &rt::ui::web::end_table();


    &rt::ui::web::new_table("width=100%");
    if (&rt::can_admin_queue($queue_id, $current_user)){
	&rt::ui::web::new_row();
	&rt::ui::web::new_col("align=left");
	print "<input type=\"submit\" name=\"action\" value=\"Update Queue\">\n";
	&rt::ui::web::end_col();
	&rt::ui::web::new_col("align=center");
	print "<input type=\"submit\" name=\"display\" value=\"Delete this Queue\">\n";
	&rt::ui::web::end_col();
    }
    &rt::ui::web::new_col("align=right");
    print "<input type=\"submit\" name=\"display\" value=\"Return to Admin Menu\">\n";
    &rt::ui::web::end_col();
    &rt::ui::web::end_row();
    &rt::ui::web::end_table();
    print"</FORM>\n";
}



sub FormDeleteUser {
    my ($user_id) = @_;
    
    print "<table width=100%>
<tr>
<td align=left>
<H2>RT Web Administrator</H2>
</td>
<td align=right>
<H2>Confirm Deletion of  user <b>$user_id</b></h2></TD></TR></TABLE>
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"user_id\" value=\"$user_id\" >
<input type=\"hidden\" name=\"action\" value=\"delete_user\">
<center>
<input type=\"submit\" value=\"Delete this user\">
<br><center></form>
<form action=\"$ScriptURL\" method=\"post\">
<center>
<input type=\"submit\" value =\"Abort. Do not delete this user\">
</center>
</FORM>
 ";
}

sub FormDeleteQueue{
    my ($queue_id) = @_;
    
    print "<table width=100%>
<tr>
<td align=left>
<H2>RT Web Administrator</H2>
</td>
<td align=right>
<H2>Confirm Deletion of queue $queue_id</H2></td></tr></table>
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"queue_id\" value=\"$queue_id\" >
<input type=\"hidden\" name=\"action\" value=\"delete_queue\">
<center>
<input type=\"submit\" value=\"Delete this queue\">
<br><center></form>
<form action=\"$ScriptURL\" method=\"post\">
<center>
<input type=\"submit\" value =\"Abort. Do not delete this queue\">
</center>
</FORM>
 ";
}







sub things_to_do {
    print "
<hr>
<center>
<font size=\"-1\">
<a href=\"$ScriptURL\">Restart</a> | <a href=\"$ScriptURL?display=Credits\">About</a> | <a href=\"$ScriptURL?display=Logout\">Logout</a>
<br>
</font>
</CENTER>
";
}

sub head_foot_options {
    &things_to_do();
    print "
<BR>
<FONT SIZE=\"-1\">
You are currently authenticated as $current_user.  
Be careful not to leave yourself authenticated from a public terminal
</FONT>
</CENTER>";
}




sub select_queue_acls {
    my ($user_id, $queue_id) = @_;
	print "<select name=\"acl_". $queue_id . "_" .$user_id. "\">\n";
	print "<option value=\"none\"";
	if (!&rt::can_display_queue($queue_id,$user_id)){
	    print "SELECTED";
	}
	print ">No Access\n";

	print "<option value=\"admin\"";
	if ((&rt::can_admin_queue($queue_id,$user_id))== 1){
	    print "SELECTED";
	}
	print">Admin\n";

	print "<option value=\"manip\"";
	if ((&rt::can_manipulate_queue($queue_id,$user_id))==1){
	    print "SELECTED";
	}
	print">Manipulate\n";
	print "<option value=\"disp\"";
	if ((&rt::can_display_queue($queue_id,$user_id))==1){
	    print "SELECTED";
	}
	print">Display\n";	
    print "</select><br>\n";
}

1;
