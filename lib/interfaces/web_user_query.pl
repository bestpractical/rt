#jesse@utopia.com
# 24 nov 96
#
#

{

package webrt;
require "/usr/local/rt/lib/routines/RT.pm";
require RT_UI_Web;
require Web_Auth;
use Time::Local;


$frames=&RT_UI_Web::frames();


&RT_UI_Web::cgi_vars_in();
&initialize_sn();
($value, $message)=&rt::initialize('web_not_authenticated_yet');
&CheckAuth();
#&WebAuth::Headers_Authenticated();
&InitDisplay();

&takeaction();
if ($serial_num > 0) {
    require RT_Database;
    &rt::req_in($serial_num,$current_user);
}

&DisplayForm();
exit 0;


### subroutines 
sub CheckAuth() {
    my ($name,$pass);

    require RT_ReadConf;	

    $AuthRealm="WebRT for $rt::rtname";
    if ($ENV{'QUERY_STRING'} eq 'Logout') {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0);
    }

    ($name, $pass)=&WebAuth::AuthCheck($AuthRealm);

    if (!(&rt::is_password($name, $pass))) {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0);
    }

    elsif ($name eq '') {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0)
    }
    else  {
	$current_user = $name;
	&WebAuth::Headers_Authenticated();
    }
}
sub InitDisplay {
  

    if ($RT_UI_Web::FORM{'display'} eq 'SetNotify') { # #this is an ugly hack, but to get the <select>
	$RT_UI_Web::FORM{'do_req_notify'}=1;          # working in the display intereface, I neeeded
	                                   # to do it.  hopefully, it will go away some day.
	
    }
    if (!($frames) && (!$RT_UI_Web::FORM{'display'})) {
	
	if ($serial_num > 0) {	
	    $RT_UI_Web::FORM{'display'} = "History";
	}
	else{
	 
            #display a default queue
	    #$RT_UI_Web::FORM{'q_unowned'}='true';
	    #$RT_UI_Web::FORM{'q_owned_by_me'}='true';
	    $RT_UI_Web::FORM{'q_status'}='open';
	    $RT_UI_Web::FORM{'q_by_date_due'}='true';
	    $RT_UI_Web::FORM{'display'} = "Queue";
	}
    }
    
    if ($frames) {
	
	if (!($ENV{'CONTENT_LENGTH'}) && !($ENV{'QUERY_STRING'})) {
	    &frame_display_queue();
	}
	elsif ($RT_UI_Web::FORM{'display_request'}) {
	    &frame_display_request();
	}
    }



}
sub DisplayForm {

    &RT_UI_Web::header();

    if (($frames) && (!$RT_UI_Web::FORM{'display'})) {
# for getting blank canvases on startup
    }
   #nice for debugging
    else {


        if ($RT_UI_Web::FORM{'display'} eq 'Credits') {
            &credits();
        }

        elsif ($RT_UI_Web::FORM{'display'} eq 'Queue') {
            &display_queue();
            if (!$frames) {
                $RT_UI_Web::FORM{'display'} = 'QueueOptions';
            }
        }

        elsif ($RT_UI_Web::FORM{'display'} eq 'ReqOptions') {
            &display_req_options();
        } 

	elsif ($RT_UI_Web::FORM{'display'} eq 'DumpEnv'){
	    &RT_UI_Web::dump_env();
	}    
	
        elsif ($RT_UI_Web::FORM{'display'} eq 'CreditCreate'){
            &ThingsToDo();

        }
        elsif ($RT_UI_Web::FORM{'display'} eq 'Message'){
            &RT_UI_Web::print_html($RT_UI_Web::FORM{'message'});
           if (($serial_num>0) and (!$frames)) {
                $RT_UI_Web::FORM{'display'} = 'History';
                print "<hr>";
            }
        }    

	if ($RT_UI_Web::FORM{'display'} eq 'FormCreate') {
	    &FormCreate();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'FormCreate_Step2') {
	    &FormCreate_Step2();
	}
	
	elsif ($RT_UI_Web::FORM{'display'} eq 'QueueOptions'){
	    &FormQueueOptions();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetReply') {
	    &FormReply();
	}

	if ($RT_UI_Web::FORM{'display'} eq 'History') {
	    if ($frames) {
		&display_summary($serial_num);
		print "<hr>";
		&display_history_tables($serial_num);
	    }
	    else {
		if (!$RT_UI_Web::FORM{'do_req_comment'} && !$RT_UI_Web::FORM{'do_req_create'} && !$RT_UI_Web::FORM{'do_req_reply'}) {	
		    &display_req_options;
		}
		
		&display_summary($serial_num);
		print "<hr>";
		&display_history_tables($serial_num);
		if (!$RT_UI_Web::FORM{'do_req_comment'} && !$RT_UI_Web::FORM{'do_req_create'} && !$RT_UI_Web::FORM{'do_req_reply'}) {
		    &display_req_options;  
		}
	    }
	}
    }
    
   if (!$frames) {
	&head_foot_options();
	}	
   &RT_UI_Web::footer(); 
}


sub frame_display_request {

    &RT_UI_Web::content_header();
    print "
<frameset rows=\"20,80\" name=\"body\" border=\"0\">\
<frameset cols=\"45,55\" name=\"reqtop\" border\"0\">
<frame src=\"$ScriptURL?display=ReqOptions&serial_num=$serial_num\"\" name=\"reqbuttons\" scrolling=\"no\">
<frame src=\"$ScriptURL?serial_num=$serial_num\" name=\"summary\">
</frameset>
<frame src=\"$ScriptURL?display=History&serial_num=$serial_num\" name=\"history\">
</frameset>
";
    &RT_UI_Web::content_footer;
    exit(0);
 }   
sub frame_display_queue {
    &RT_UI_Web::content_header();
    print "
<frameset rows=\"20,68,12\" border=\"1\">
<frame src=\"$ScriptURL?display=Queue\" name=\"queue\">
";
    if ($serial_num > 0) {
	&frame_display_request;
    }
    else{
	print "<frame src=\"$ScriptURL?display=Credits\" name=\"workspace\">\n";
    }
    print "
<frameset cols=\"15,85\">
<frame src=\"$ScriptURL?display=CreditCreate\" name=\"creditcreate\" scrolling=\"no\">
<frame src=\"$ScriptURL?display=QueueOptions\" name=\"queue_options\">
</frameset>
</frameset>
";
    &RT_UI_Web::content_footer();
    exit(0);
    
}
sub takeaction {
    local ($date_due);

    require RT_Manipulate;

    if ($RT_UI_Web::FORM{'do_req_create'}) {
	if ($RT_UI_Web::FORM{'due_mday'} and $RT_UI_Web::FORM{'due_month'} and $RT_UI_Web::FORM{'due_year'}) {
	    $date_due=timelocal(0,0,0,$RT_UI_Web::FORM{'due_mday'},$RT_UI_Web::FORM{'due_month'},$RT_UI_Web::FORM{'due_year'});
	}
	else { 
	    $due_date=0;
	}
	($serial_num,$transaction_num,$StatusMsg)=&rt::add_new_request($RT_UI_Web::FORM{'queue_id'},$RT_UI_Web::FORM{'area'},$RT_UI_Web::FORM{'requestors'},$RT_UI_Web::FORM{'alias'},$RT_UI_Web::FORM{'owner'},$RT_UI_Web::FORM{'subject'},"$RT_UI_Web::FORM{'final_prio_tens'}$RT_UI_Web::FORM{'final_prio_ones'}","$RT_UI_Web::FORM{'prio_tens'}$RT_UI_Web::FORM{'prio_ones'}",$RT_UI_Web::FORM{'status'},$rt::time,0,$date_due, $RT_UI_Web::FORM{'content'},$current_user); 
	&rt::req_in($serial_num,$current_user);
    }
    if ($current_user) {
	if ($RT_UI_Web::FORM{'do_req_respond'}){
	($trans,$StatusMsg)=&rt::add_correspondence($serial_num,$RT_UI_Web::FORM{'content'},$RT_UI_Web::FORM{'subject'},$current_user);
	}
	
	if ($StatusMsg) {
	    &DisplayMsgInFrame();
	    $RT_UI_Web::FORM{'message'}=$StatusMsg;
	}
    }	
}

sub DisplayMsgInFrame {
    $RT_UI_Web::FORM{'display'}="Message";
    
    # an ugly hack so we don't try to print in a frame that's been printed in.
}
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
<font size=\"-1\">
<b>Owner</b>: <INPUT TYPE=\"checkbox\" NAME=\"q_unowned\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_unowned'};
    print "> None <INPUT TYPE=\"checkbox\" NAME=\"q_owned_by_me\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_owned_by_me'};
    print ">  $current_user <INPUT TYPE=\"checkbox\" NAME=\"q_owned_by\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_owned_by'};
    print "> <input size=8 name=\"q_owner\" VALUE=\"$RT_UI_Web::FORM{'q_owner'}\" > </font><br>";

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
    print "<font size=\"-1\">";
    print "<b>Status</b>: ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_status\" VALUE=\"any\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_status'} eq "any");
    print "> Any  ";   
    print "<INPUT TYPE=\"radio\" NAME=\"q_status\" VALUE=\"open\"";
    print "CHECKED" if (($RT_UI_Web::FORM{'q_status'} eq "open" ) or  (!$RT_UI_Web::FORM{'q_status'}));
    print "> Open  ";
    print "<INPUT TYPE=\"radio\" NAME=\"q_status\" VALUE=\"stalled\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_status'} eq "stalled");
    print "> Stalled  ";
    print "<INPUT TYPE=\"radio\" NAME=\"q_status\" VALUE=\"resolved\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_status'} eq "resolved");
    print "> Resolved";
        print "<INPUT TYPE=\"radio\" NAME=\"q_status\" VALUE=\"dead\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_status'} eq "dead");
    print "> Dead  ";
    print "\n<br>"; 
    
    print "</font>";
    #print "</td>";
    print "<!-- COMMENTED OUT FOR NOW...IT DOESN'T WORK ANYWAY\n";
    print "<td valign=\"top\">";
    print "<font size=\"-1\">";
    print "<b>Priority</b>: ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_prio\" VALUE=\"\"";
    print "CHECKED" if (!$RT_UI_Web::FORM{'q_prio'});
    print "> Standard ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_prio\" VALUE=\"all\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_prio'} eq "all");
    print "> All ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_prio\" VALUE=\"low\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_prio'} eq "low");
    print "> Low ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_prio\" VALUE=\"normal\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_prio'} eq "normal");
    print "> Normal ";
    
    print "<INPUT TYPE=\"radio\" NAME=\"q_prio\" VALUE=\"high\"";
    print "CHECKED" if ($RT_UI_Web::FORM{'q_prio'} eq "high");
    print "> High";
    print "</font>";
        print "</td>";

    print "\n\n!!------ comment ends here -->\n";
    #print "<td valign=\"top\">";
    print "<font size=\"-1\">";
   print "<b>Queue</b>: <select name=\"q_queue\">";
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
    
    print "<b>Order by</b>: ";
    
    print"<INPUT TYPE=\"checkbox\" NAME=\"q_reverse\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_reverse'};
    print "> Reverse ";
    
    print "<INPUT TYPE=\"checkbox\" NAME=\"q_timestamp\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_timestamp'};
    print "> Timestamp ";
    
    print "<INPUT TYPE=\"checkbox\" NAME=\"q_by_date_due\" VALUE=\"true\"";
    print "CHECKED" if $RT_UI_Web::FORM{'q_by_date_due'};
    print "> Date Due ";
    print "</font>";
    print "</td></tr></table>";
    print "</td><td>";
     print "<center><input type=\"submit\" value =\"Refresh Queue\"></center>";
   
    print "</td></tr></table>";
    print "<input type=\"hidden\" name=\"display\" value=\"Queue\">";
   
    print "</form>\n";

}
sub display_queue{
    my ($owner_ops, $queue_ops, $status_ops, $prio_ops, $user_ops, $order_ops, $reverse, $query_string);
    local($^W) = 0; # Lots of form fields that may or may not exist give bogus errors

    require RT_Database;
    if ($RT_UI_Web::FORM{'q_owned_by'}) {
	if ($owner_ops){
	    $owner_ops .= " OR ";
	}
      
	$owner_ops .= " owner = \'" . $RT_UI_Web::FORM{'q_owner'} . "\'";
    }
    if ($RT_UI_Web::FORM{'q_owned_by_me'}) {
	if ($owner_ops){
	    $owner_ops .= " OR ";
	}
	$owner_ops .= " owner = \'" . $current_user . "\'";
    }
    
    if ($RT_UI_Web::FORM{'q_unowned'}){
	if ($owner_ops){
	    $owner_ops .= " OR ";
	}
	$owner_ops .= " owner =  \'\'" ;
    }  
    if ($RT_UI_Web::FORM{'q_queue'}){
	if ($queue_ops){
	    $queue_ops .= " OR ";
	}
	$queue_ops .= " queue_id =  \'$RT_UI_Web::FORM{'q_queue'}\'" ;
    }

    
    if (0){  #must implement sort by prio in webrt
	if ($ARGV[$i] eq '-priority'){
	       if ($prio_ops){
		   $prio_ops .= " AND ";
	       }
	       $prio_ops .= " prio $ARGV[++$i] $ARGV[++$i]";
	   }
    }   
    if ($RT_UI_Web::FORM{'q_status'}){
	if ($status_ops){
	    $status_ops .= " OR ";
	}
	if ($RT_UI_Web::FORM{'q_status'} ne "any") {

	  $status_ops .= " status =  \'" .$RT_UI_Web::FORM{'q_status'}."\'" ;
        }
        else {
	  $status_ops = " status <> \'dead\'";
	} 
    }   

 if ($RT_UI_Web::FORM{'q_user'} eq 'other') {
	if ($user_ops){
		$user_ops .= " OR ";
	    }
	$user_ops .= " requestors like \'%" . $RT_UI_Web::FORM{'q_user_other'} . "%\' ";
    }
    
    if ($RT_UI_Web::FORM{'q_user'} eq $current_user) {
	if ($user_ops){
	    $user_ops .= " OR ";
	}
	    $user_ops .= " requestors like \'%" . $current_user . "%\' ";
    }
    
    if ($RT_UI_Web::FORM{'q_orderby'}) {
	if ($order_ops){
		$order_ops .= ", ";
	    }
	$order_ops .= $RT_UI_Web::FORM{'q_orderby'}; 
    }
    if ($RT_UI_Web::FORM{'q_reverse'}) {
	$reverse = ' DESC'; 
	   }
    
    if ($RT_UI_Web::FORM{'q_by_date_due'}) {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "date_due"; 
    }
   if ($RT_UI_Web::FORM{'q_timestamp'}) {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "date_acted"; 
    }
    
    
    if ($queue_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$queue_ops";
    }
    
    if ($prio_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$prio_ops";
    }

    if ($status_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$status_ops";
    }

    
    if ($user_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$user_ops";
    }
    if ($owner_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$owner_ops";
    }
    if (!$query_string) {
	$query_string = "owner = \'$current_user\' or owner = \'\' and status = \'open\'";
    }


    if ($order_ops) {
	$query_string .= "ORDER BY $order_ops";
    }
    else {
	$query_string .= "ORDER BY serial_num";
    }
    if ($reverse) {
	$query_string .= " DESC";
    }
    

     $count=&rt::get_queue($query_string,$current_user);
    print "<!-- Query String 
$query_string
-->"; 
    print "<font size=\"-1\">\n";
    print "<pre>";
    print "Num   !  Owner   Age     Told    Due     Status   User    Subject\n";
    for ($temp=0;$temp<$count;$temp++){
	    print "<A href=\"$ScriptURL?serial_num=$rt::req[$temp]{'effective_sn'}";
	    if($frames) {
		print "&display_request=true\" target=\"workspace\"";
	    }
	    else {
		print "&display=History\"";
	    }
	    print ">";

	    $foo=pack("A6",$rt::req[$temp]{'serial_num'});
	    chop($foo);
	    &RT_UI_Web::print_html ("$foo");
	    $foo=pack("A3",$rt::req[$temp]{'priority'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");
	    $foo=pack("A8",$rt::req[$temp]{'owner'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");

	    $foo=pack("A8",$rt::req[$temp]{'age'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");

	    $foo=pack("A8",$rt::req[$temp]{'since_told'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");

	    $foo=pack("A8",$rt::req[$temp]{'till_due'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");

	    $foo=pack("A9",$rt::req[$temp]{'status'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");
	    $foo=pack("A8",$rt::req[$temp]{'requestors'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");
	    $foo=pack("A30",$rt::req[$temp]{'subject'});
	    chop($foo);
	    &RT_UI_Web::print_html (" $foo");
	    print "</a>\n";
#	    print "</tr>\n";
	    
	}
    print "</pre></font>";
    
}



sub display_history_tables {
    local ($in_serial_num)=@_;
    local ($temp, $total_transactions, $wday,$mon,$mday,$hour,$min,$sec,$TZ,$year);

    require RT_Database;
    $total_transactions=&rt::transaction_history_in($in_serial_num, $current_user);
    print "<font size=\"+1\">T</font>ransaction <font size=\"+1\">H</font>istory\n<br><hr>";
    print "<font size=\"-1\">";
    
    print "<table>";
    for ($temp=0; $temp < $total_transactions; $temp++){
	print "<tr><td valign=\"top\" align=\"right\">";
	($wday, $mon, $mday, $hour, $min, $sec, $TZ, $year)=&rt::parse_time($rt::transaction[$temp]{'time'});
	$date=sprintf ("%s, %s %s %4d", $wday, $mon, $mday, $year);

	$time=sprintf ("%.2d:%.2d:%.2d", $hour,$min,$sec);
	print "<font size=\"-2\">\n$date\n<br>\n$time\n</font>\n";
	print "</td><td>";
	print"$rt::transaction[$temp]{text}\n";
	if ($rt::transaction[$temp]{'content'}) {
	    print "\n<font size=\"-1\"><pre>$rt::transaction[$temp]{'content'}</pre></font>\n";
	}
	print "</tr>";
    }   
    print "</table></font>\n";
}



# Mini Forms for changing req params...

sub FormReply{
    print "<form action=\"$ScriptURL\" method=\"post\"";
    if ($frames) {
	print "target=\"summary\"";
    }
    print ">
<H1>Reply to Request $serial_num</H1>
<pre>
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\">
Make status: 
<select name=\"do_req_status\">\n";
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
<br><textarea rows=15 cols=70 name=\"content\"></textarea>
</font>
<center><input type=\"submit\" value=\"Send Response\"></center></form>";
}

sub FormCreate{   
    print "<form action=\"$ScriptURL\" method=\"post\"";
    if ($frames) { print "target=\"otherpage\" ";
	       }
    print ">";
    print "<H1>Webrt Creation Form </H1>\n";
    print "<pre>";
    if ($current_user){

  print "Status: <select name=\"status\">
<option value=\"open\">open
<option value=\"stalled\">stalled
<option value=\"resolved\">resolved
</select>
Created by:      $current_user
Priority: ";

	&RT_UI_Web::select_an_int($rt::req[$serial_num]{priority}, "prio");
	print "\nFinal priority:";
	&RT_UI_Web::select_an_int($rt::req[$serial_num]{final_priority}, "final_prio");
	print "\nDate Due: ";
	&RT_UI_Web::select_a_date($rt::req[$serial_num]{date_due}, "due");
	print "\n";
    }
    print "Queue:     <select name=\"queue_id\">\n";
    while(($queue, $value)= each %rt::queues) {
	if (&rt::can_create_request($queue, $current_user)) {
	    print "<option>$queue\n";
	}
    }
    print "</select>\nRequestor: <input name=\"requestors\" size=\"30\"";
    if ($current_user) {
	print "value=\"$rt::users{$current_user}{email}\"";
    }
    print ">
Summary:   <input name=\"subject\" size=\"50\">
</pre>
<input type=\"hidden\" name=\"display\" value=\"FormCreate_Step2\">
<center><input type=\"submit\" value=\"Continue to next screen\"></center></form>";
    
}
sub FormCreate_Step2 {   
    my ($template,$actions,$user_id, $value);
    print "<form action=\"$ScriptURL\" method=\"post\"";
    if ($frames) { print "target=\"summary\" ";
	       }
    print ">";
    print "<H1>Webrt Creation Form </H1>\n";
    print "<pre>";
    $template=&rt::template_read("web_create",$RT_UI_Web::FORM{'queue_id'});
    if ($current_user){

	print "Owner:             <select name=\"owner\">

<option value=\"\">Nobody ";	
	foreach $user_id ( keys % {$rt::queues{$RT_UI_Web::FORM{'queue_id'}}{acls}} ) {
	    if (&rt::can_manipulate_queue ($RT_UI_Web::FORM{'queue_id'}, $user_id)) {
		print "<option>$user_id\n";
	    }
	}
	print "</select>";
    }	
    print "
Priority:          $RT_UI_Web::FORM{'prio_tens'}$RT_UI_Web::FORM{'prio_ones'}
Final priority:    $RT_UI_Web::FORM{'final_prio_tens'}$RT_UI_Web::FORM{'final_prio_ones'}
Date Due:          $RT_UI_Web::FORM{'due_mday'}/$RT_UI_Web::FORM{'due_month'}/$RT_UI_Web::FORM{'due_year'}
Queue:             $RT_UI_Web::FORM{'queue_id'}
Status:            $RT_UI_Web::FORM{'status'}
Requestor:         $RT_UI_Web::FORM{'requestors'}
Summary:           $RT_UI_Web::FORM{'subject'}

<input type=\"hidden\" name=\"due_mday\" value=\"$RT_UI_Web::FORM{'due_mday'}\">	<input type=\"hidden\" name=\"due_month\" value=\"$RT_UI_Web::FORM{'due_month'}\"><input type=\"hidden\" name=\"due_year\" value=\"$RT_UI_Web::FORM{'due_year'}\"><input type=\"hidden\" name=\"queue_id\" value=\"$RT_UI_Web::FORM{'queue_id'}\"><input type=\"hidden\" name=\"requestors\" value=\"$RT_UI_Web::FORM{'requestors'}\"><input type=\"hidden\" name=\"alias\" value=\"$RT_UI_Web::FORM{'alias'}\"><input type=\"hidden\" name=\"status\" value=\"$RT_UI_Web::FORM{'status'}\"><input type=\"hidden\" name=\"subject\" value=\"$RT_UI_Web::FORM{'subject'}\"><input type=\"hidden\" name=\"final_prio_tens\" value=\"$RT_UI_Web::FORM{'final_prio_tens'}\"><input type=\"hidden\" name=\"final_prio_ones\" value=\"$RT_UI_Web::FORM{'final_prio_ones'}\"><input type=\"hidden\" name=\"prio_tens\" value=\"$RT_UI_Web::FORM{'prio_tens'}\"><input type=\"hidden\" name=\"prio_ones\" value=\"$RT_UI_Web::FORM{'prio_ones'}\"><input type=\"hidden\" name=\"due_mday\" value=\"$RT_UI_Web::FORM{'due_mday'}\"><input type=\"hidden\" name=\"do_req_create\" value=\"true\">

</pre>
<font size=\"-1\">
<br><textarea rows=15 cols=70 name=\"content\">
$template
</textarea>
</font>
<center>
<input type=\"submit\" value=\"Create Request\">
</center>
</form>";
    
}

sub FormComment{
    
    print "
<form action=\"$ScriptURL\" method=\"post\" target=\"summary\">
<H1>
Comment on request $serial_num 
</H1>
<pre>
Summary: <input name=\"subject\" size=\"50\" value=\"$rt::req[$serial_num]{'subject'}\">
</pre>
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\">
<input type=\"hidden\" name=\"do_req_comment\" value=\"true\">
<br><font size=\"-1\">
<textarea rows=15 cols=70 name=\"content\">
</textarea>
</font>
<center>
<input type=\"submit\" value=\"Submit Comments\">
</center>
</form>
";
}

sub display_summary {
    my ($in_serial_num)=@_;
    print "<table cellspacing=0 cellpadding=0>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>Serial Number</b>
</td>
<td bgcolor=\"#ccffff\">
$in_serial_num
</td>
</tr>    

<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>
Subject
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'subject'}
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>    
Queue
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'queue_id'}
</td>
</tr>
    
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\"><b>   
Requestors 
</b>
</td>
<td bgcolor=\"#ccffff\"> 
$rt::req[$in_serial_num]{'requestors'}
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>
Owner
</b></td><td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'owner'}
</td></tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>
Status
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'status'}
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\"><b>
Created
</b>
</td>
<td bgcolor=\"#ccffff\"> ";
    print &ctime($rt::req[$in_serial_num]{'date_created'});
print "
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\"><b>
Last Contact
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'since_told'}
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\"><b>
Last Action
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'since_acted'}
</td>
</tr>    
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>
Current Priority
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'priority'}
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>
Final Priority
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'final_priority'}
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>
Due
</b>
</td>
<td bgcolor=\"#ccffff\">
";
    if ($rt::req[$in_serial_num]{'date_due'}) {
	print &ctime($rt::req[$in_serial_num]{'date_due'});
    }
    else {
	print "No date assigned \n";
    }
    print "
</td>
</tr>
<tr valign=\"top\">
<td bgcolor=\"#ffccff\" align=\"right\">
<b>
Age
</b>
</td>
<td bgcolor=\"#ccffff\">
$rt::req[$in_serial_num]{'age'}
</td>
</tr>
</table>
";
}




#display req options munge url
#makes it easier to print out a url for fdro
sub fdro_murl {
    local ($custom_content, $target,$description) = @_;
    $url="<a href=\"$ScriptURL?serial_num=$serial_num&refresh_req=true&";
    $url .= $custom_content;
    $url .= "\"";
    $url .= "target=\"$target\"" if ($frames);
    $url .= ">";
    $url .= "$description</a>";
    return($url);
}
sub display_req_options {
    print "<center><font size=-2 >";
    print "<form action=\"$ScriptURL\" method=\"post\" ";
    print "target=\"summary\"" if ($frames);
    print ">";    
    print "<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\">";
    print &fdro_murl("display=SetComment","otherpage","<img src=\"/webrt/comment.gif\" alt=\"Comment\" border=\"0\"> ");
    
    print &fdro_murl("display=SetReply","otherpage","<img src=\"/webrt/respond.gif\" alt=\"Respond\" border=\"0\"> ");
    
    print &fdro_murl("do_req_give=true&do_req_give_to=$current_user","summary","<img src=\"/webrt/take.gif\" alt=\"Take\" border=\"0\"> ");
    
    print &fdro_murl("do_req_resolve=true","summary","<img src=\"/webrt/resolve.gif\" alt=\"Resolve\" border=\"0\"> ");
    
    print &fdro_murl("display=SetGive","summary","<img src=\"/webrt/give.gif\" alt=\"Owner\" border=\"0\"> ");
    print "<br>";

print "  <select name=\"display\">
    <option value=\"SetSubject\">Set Subject
    <option value=\"SetUser\">User  
    <option value=\"SetDateDue\">Date Due  
    <option value=\"SetMerge\">Merge
    <option value=\"SetPrio\">Priority
    <option value=\"SetFinalPrio\">Final Priority
    <option value=\"SetStatus\">Status
    <option value=\"SetQueue\">Queue
    <option value=\"SetSteal\">Steal 
    <option value=\"SetNotify\">Notify
	</select>
    <input type=\"submit\" value=\"Go\">
    </form>
    </font>
</center>
";
}





sub ThingsToDo {
    print "

<font size=\"-2\">
<pre>
<a href=\"$ScriptURL\" target=\"_top\">Restart</a>
<a href=\"$ScriptURL?display=FormCreate\" target=\"otherpage\">Create</a>
<a href=\"$ScriptURL?display=Credits\" target=\"workspace\">Look at #</a>
<a href=\"$ScriptURL?Logout\" target=\"_top\">Logout</a>
</pre>
</font>
";
}

sub head_foot_options {
    print "<center>";
    print "| <a href=\"$ScriptURL\"";
   	if ($frames) {
	    print "target=\"_top\"";
	}
    print ">View the Queue</a> ";
    if ($current_user) { 	#if we're authenticated
 	print "| <a href=\"$ScriptURL?display=FormCreate\"";
	if ($frames) {
	    print " target=\"otherpage\"";
	}
	print ">Create a Request</a> ";
    }
    print "| <a href=\"$ScriptURL?display=Credits\"";
	if ($frames) {
	    print "target=\"workspace\"";
	}
    print ">Display a specific request</a> |\n"; 
    print "<a href=\"$ScriptURL?Logout\" target=\"_top\">Logout of RT</a><br>\n"; 

    print "
<BR>
<FONT SIZE=\"-1\">
You are currently authenticated as $current_user.  
Be careful not to leave yourself authenticated from a public terminal
</FONT>
</CENTER>";
}


sub credits{
    print "
<center>
<img src=\"/webrt/rt.jpeg\">
<br>
<form method=get action=\"$ScriptURL\">
<input type=\"hidden\" name=\"display\" value=\"History\">
View a specific request: <input size=6 name=\"serial_num\">
<input type=\"submit\" value=\"Display\">
</form>
<font size=\"+1\">
Request Tracker's development was initially comissioned by <a href=\"http://www.utopia.com\">Utopia Inc</a>.  Further work has been funded by Utopia Inc. and <a href=\"http://www.wesleyan.edu\">Wesleyan University.</a>
<br>
This program is redistributable under the terms of the <b>GNU Public License.
</b>
</font>
<br>
Copyright &copy; 1996,1997
<a href=\"http://www.con.wesleyan.edu/~jesse/jesse.html\">Jesse Vincent</a>.
";
   
    print "</center>";
    if($frames) {
	&head_foot_options();
    }
}
sub initialize_sn {

    if ((!$RT_UI_Web::FORM{'serial_num'}) and (!$frames))
    {
	# If we don't have a serial_num, we assume the query string was just an int representing serial_num
	$RT_UI_Web::FORM{'serial_num'} = $ENV{'QUERY_STRING'};
   
    }
    $ScriptURL=$ENV{'SCRIPT_NAME'}.$ENV{'PATH_INFO'};
    
    if ($RT_UI_Web::FORM{'serial_num'}){
	$serial_num=int($RT_UI_Web::FORM{'serial_num'});
    }
    else {
	$serial_num = 0;
    }
}




}












