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
  
  
  if ($rt::ui::web::FORM{'display'} eq 'DumpEnv'){
    
    &dump_env();
    
  }    
  elsif ($rt::ui::web::FORM{'display'} eq 'Credits') {
    
    &credits();
    
  }
  
  elsif (($rt::ui::web::FORM{'display'} eq 'Create a User called') && ($rt::ui::web::FORM{'new_user_id'})){
    &FormModifyUser($rt::ui::web::FORM{'new_user_id'});
  }
  elsif ($rt::ui::web::FORM{'display'} eq 'Modify your RT Account') {
    &FormModifyUser($current_user);
  }
  elsif (($rt::ui::web::FORM{'display'} eq 'Create a Queue called') && ($rt::ui::web::FORM{'new_queue_id'})) {
    &FormModifyQueue($rt::ui::web::FORM{'new_queue_id'});
  }
  elsif (($rt::ui::web::FORM{'action'} eq "Update User") or ($rt::ui::web::FORM{'display'} eq 'Modify the User called')) {
    &FormModifyUser($rt::ui::web::FORM{'user_id'});
  }
  elsif (($rt::ui::web::FORM{action} eq "Update Queue") or ($rt::ui::web::FORM{'display'} =~ /(View|Modify) the Queue called/)){
    &FormModifyQueue($rt::ui::web::FORM{'queue_id'});
  }
  elsif ($rt::ui::web::FORM{'display'} eq 'Delete Queue'){
    &FormDeleteQueue($rt::ui::web::FORM{'queue_id'});
  }
  elsif ($rt::ui::web::FORM{'display'} eq 'Delete User'){
    &FormDeleteUser($rt::ui::web::FORM{'user_id'});
  }    
  else {
    &menu();
  } 
  
  
  &rt::ui::web::footer();
}


sub take_action {
    my ($queue_id,$acl,$acl_string,$user_id,$value);
    
    require rt::database::admin;    
    

    if ($rt::ui::web::FORM{action} eq "Update Queue") {
	
      ($flag, $message)=&rt::add_modify_queue_conf($rt::ui::web::FORM{queue_id}, $rt::ui::web::FORM{email}, &rt::booleanize($rt::ui::web::FORM{m_owner_trans}), &rt::booleanize($rt::ui::web::FORM{m_members_trans}), &rt::booleanize($rt::ui::web::FORM{m_user_trans}), &rt::booleanize($rt::ui::web::FORM{m_user_create}), &rt::booleanize($rt::ui::web::FORM{m_members_correspond}), &rt::booleanize($rt::ui::web::FORM{m_members_comment}), &rt::booleanize($rt::ui::web::FORM{allow_user_create}), "$rt::ui::web::FORM{'initial_prio_tens'}$rt::ui::web::FORM{'initial_prio_ones'}","$rt::ui::web::FORM{'final_prio_tens'}$rt::ui::web::FORM{'final_prio_ones'}",$current_user);


	foreach $user_id( sort keys %rt::users) {
	    
	    $acl_string="acl_" . $rt::ui::web::FORM{queue_id} . "_" . $user_id;
	    $acl=$rt::ui::web::FORM{"$acl_string"};
	    
	    
		print STDERR "ACL is $acl -- Aclstring is $acl_string\n";

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
	($flag, $message)=&rt::add_modify_user_info($rt::ui::web::FORM{user_id}, $rt::ui::web::FORM{real_name}, $rt::ui::web::FORM{password}, $rt::ui::web::FORM{email}, $rt::ui::web::FORM{phone}, $rt::ui::web::FORM{office},$rt::ui::web::FORM{comments}, &rt::booleanize($rt::ui::web::FORM{admin_rt}), $current_user);


	foreach $queue_id (sort keys %rt::queues) {

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


    &page_head("Main Menu");
    
    print "
<form action=\"$ScriptURL\" method=\"post\">

<table width=100%><TR VALIGN=TOP><TD VALIGN=TOP ALIGN=LEFT>

<H2>User Configuration</H2>\n";
    
		if ($rt::users{$current_user}{admin_rt}) {
		    
		    print "
<input type=Submit name=display value=\"Create a User called\"> <input size=15 name=\"new_user_id\">
<br>
<input type=submit name=display value=\"Modify the User called\"> <select name=\"user_id\">\n";
		    foreach $user_id (sort keys %rt::users) {
			print "<option value=\"$user_id\">$user_id\n";
			
		    }
		    print "</select>\n<br>\n";
	
		}
		print "
<input type=submit name=display value=\"Modify your RT Account\">

</TD>
<TD VALIGN=TOP ALIGN=RIGHT>

<H2>Queue Configuration</H2>";
    if ($rt::users{$current_user}{admin_rt}) {
	print "<input type=Submit name=display value=\"Create a Queue called\"> <input size=15 name=\"new_queue_id\">
<br>";
}
    my $q = 0;
    for( keys %rt::queues ) {
        next if ! &rt::can_admin_queue($_, $current_user);
	$q = 1;
	last;
    }
    if( ! $q && ! $rt::users{$current_user}{admin_rt} )
    {
        $q = 0;
	for( keys %rt::queues ) {
    	    next if ! &rt::can_manipulate_queue($_, $current_user);
	    $q = 1;
	    last;
	}
	if( ! $q )
	{
	    print "<BR>You're not allowed to view/modify queue configuration";
	    print "</TD></TR></TABLE>";
    	    print "</form>\n";
	    return;
	}
        print "<input type=submit name=display value=\"View the Queue called\"> <select name=\"queue_id\">";
	for( sort keys %rt::queues) {
	    if( &rt::can_manipulate_queue($_, $current_user)){
		print "<option value=\"$_\">$_";
	    }
	}
    }    	
    else
    {
        print "<input type=submit name=display value=\"Modify the Queue called\"> <select name=\"queue_id\">";
	for( sort keys %rt::queues) {
	    if( $rt::users{$current_user}{admin_rt} or &rt::can_admin_queue($_, $current_user)){
		print "<option value=\"$_\">$_";
	    }
	}
    }
    print "</select>\n";
	print "</TD></TR></TABLE>";
	    
    print "</form>\n";
    
}

sub FormModifyUser{
    my ($user_id) = @_;

      if (!&rt::is_a_user($user_id)) {
	&page_head("Create a new user called <b>$user_id</b>");
      }
    elsif  ($user_id eq $current_user){
      &page_head("Modify your own attributes");
      }
    else {
      &page_head("Modify the user <b>$user_id</b>");
    }
    
  
    print "
<TABLE WIDTH=100%>
 <TR>
  <TD VALIGN=TOP>


<H2>User Configuration</H2>

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
Real name:   
</td>
<td>
<input name=\"real_name\" size=30 value=\"$rt::users{$user_id}{real_name}\">
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
	print "</TD>
<TD ALIGN=RIGHT VALIGN=TOP>
<H2>Access Control</H2>
<br>\n";
		if ($rt::users{$current_user}{admin_rt}) {
		    print "RT Admin: <input type=\"checkbox\" name=\"admin_rt\" ";
		    print "checked" if ($rt::users{$user_id}{admin_rt});
		    print "><br><hr>\n";
		    foreach $queue_id ( sort keys %rt::queues) {
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
		    foreach $queue_id (sort keys %rt::queues) {
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
		    
		    print "<BR>\n";
			}
		}
	
	print "</TD></TR></TABLE>\n";	
    

    print "<TABLE WIDTH=100% BGCOLOR=\"#DDDDDD\" BORDER=0 CELLSPACING=0 CELLPADDING=3><TR><TD ALIGN=LEFT WIDTH=33%>
<input type=\"submit\" name=\"action\" value=\"Update User\">
</TD>\n";
    if ($rt::users{$current_user}{admin_rt}) {
	print "<TD ALIGN=CENTER WIDTH=33%>
	<input type=\"submit\" name=\"display\" value=\"Delete User\">\n
</TD>";
    }

    print "<TD ALIGN=RIGHT>
<input type=\"submit\" name=\"display\" value=\"Main Menu\">
</TD></TR></TABLE>
";


print "</FORM>";
}


sub FormModifyQueue{
    my ($queue_id) = @_;
    if (!&rt::is_a_queue($queue_id)) {
	&page_head("Create a new queue called <b>$queue_id</b>");

	}
    else {
	&page_head("View\/Modify the queue <b>$queue_id</b>");
    }


    print "
<TABLE WIDTH=\"100%\" border=0 cellspacing=5>

<TR>
<TD ALIGN=LEFT VALIGN=TOP>

<H2>
Queue Configuration
</H2>

<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"queue_id\" value=\"$queue_id\" >

<table>
<tr><td>Queue name:</td><td>$queue_id</td></tr>
<tr><td>mail alias:</td><td><input name=\"email\" size=30 value=\"$rt::queues{$queue_id}{mail_alias}\"></td></tr>
<tr><td>Initial priority:</td><td> ";
    &rt::ui::web::select_an_int($rt::queues{$queue_id}{default_prio},"initial_prio");
    print "</td></tr>
<tr><td>Final priority:</td><td>";
    &rt::ui::web::select_an_int($rt::queues{$queue_id}{default_final_prio},"final_prio");
    print "</td></tr></table>\n<BR>\n";

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
    
    print "<br>Add an area called <input size=\"15\" name=\"add_area\"><br>
</TD>


<TD ALIGN=RIGHT VALIGN=TOP>
<H2>
Access Control
</H2>

";
    foreach $user_id (sort keys %rt::users) {
      print "<A HREF=\"$ScriptURL?display=Modify+the+User+called&user_id=$user_id\">$user_id</a>:";

	&select_queue_acls($user_id, $queue_id);
    }
    print "</TD></TR></TABLE>";


    print "<TABLE WIDTH=100% BGCOLOR=\"#DDDDDD\" BORDER=0 CELLSPACING=0 CELLPADDING=>";

    if (&rt::can_admin_queue($queue_id, $current_user)){

      print "
<TR>
<TD ALIGN=LEFT WIDTH=33%>
<input type=\"submit\" name=\"action\" value=\"Update Queue\">
</TD>
<TD ALIGN=CENTER>
<input type=\"submit\" name=\"display\" value=\"Delete Queue\">
</TD>";
    }
    
    
    print "<TD ALIGN=RIGHT WIDTH=33%>
<input type=\"submit\" name=\"display\" value=\"Main Menu\">
</TD>
</TR>
</TABLE>
</FORM>\n";

}



sub FormDeleteUser {
    my ($user_id) = @_;
    &page_head("Confirm Deletion of user <b>$user_id</b>");
    print "

<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"user_id\" value=\"$user_id\" >
<input type=\"hidden\" name=\"action\" value=\"delete_user\">
<center>
<input type=\"submit\" value=\"Delete User\">
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
    
    &page_head("Confirm deletion of queue $queue_id");

    print "
<form action=\"$ScriptURL\" method=\"post\">
<input type=\"hidden\" name=\"queue_id\" value=\"$queue_id\" >
<input type=\"hidden\" name=\"action\" value=\"delete_queue\">
<center>
<input type=\"submit\" value=\"Delete Queue\">
<br><center></form>
<form action=\"$ScriptURL\" method=\"post\">
<center>
<input type=\"submit\" value =\"Abort. Do not delete this queue\">
</center>
</FORM>
 ";
}




sub page_head {
my $page_title = shift; 

print <<EOF;
<table width=100% cellpadding=5 cellspacing=0 border=0>
<tr bgcolor=\"#dddddd\">
<td align=left valign=center>
<FONT SIZE=+2><A HREF="$ScriptURL">RT Web Administrator</A></FONT>
</td>
<td align=right valign=center>
<FONT SIZE=+2>$page_title</FONT></td></tr></table>
EOF
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
    my $flag = 0;

	print "<select name=\"acl_". $queue_id . "_" .$user_id. "\">\n";

	print "<option value=\"admin\"";
	if ((&rt::can_admin_queue($queue_id,$user_id))== 1){
	    print "SELECTED";
	    $flag = 1;
	}
	print">Admin\n";

	print "<option value=\"manip\"";
	if (! $flag && (&rt::can_manipulate_queue($queue_id,$user_id))==1){
	    print "SELECTED";
	    $flag = 1;
	}
	print">Manipulate\n";
	print "<option value=\"disp\"";
	if (! $flag && (&rt::can_display_queue($queue_id,$user_id))==1){
	    print "SELECTED";
	}
	print">Display\n";	
	print "<option value=\"none\"";
	if (! $flag && !&rt::can_display_queue($queue_id,$user_id)){
	    print "SELECTED";
	}
	print ">No Access\n";

    print "</select><br>\n";
}

1;

