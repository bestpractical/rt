
#
# (c) 1997 Jesse Vincent
# jesse@fsck.com
#


package rt::ui::web;

sub activate {

use Time::Local;

$QUEUE_FONT="-1";
$MESSAGE_FONT="-1";
$frames=&rt::ui::web::frames();
&rt::ui::web::cgi_vars_in();
&initialize_sn();
($value, $message)=&rt::initialize('web_not_authenticated_yet');
&CheckAuth();
&InitDisplay();
&takeaction();


if ($serial_num > 0) {
    require rt::database;

    &rt::req_in($serial_num,$current_user);
}

&DisplayForm();
return(0);
}

sub CheckAuth() {
    my ($name,$pass);
    
    require rt::database::config;	
    
    $AuthRealm="WebRT for $rt::rtname";


    ($name, $pass)=&WebAuth::AuthCheck($AuthRealm);

    #if the user's password is bad
    if (!(&rt::is_password($name, $pass))) {

	&WebAuth::AuthForceLogout($AuthRealm);
	exit(0);
    }

    #if the user isn't even authenticating
    elsif ($name eq '') {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0)
	}
    
    #if the user is trying to log out
    if ($rt::ui::web::FORM{'display'} eq 'Logout') {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0);
    }
    else {
	$current_user = $name;
	&WebAuth::Headers_Authenticated();
    }
    

}
sub InitDisplay {
  
    if ($rt::ui::web::FORM{'display'} eq 'SetNotify') { # #this is an ugly hack, but to get the <select>
	$rt::ui::web::FORM{'do_req_notify'}=1;          # working in the display intereface, I neeeded
	                                   # to do it.  hopefully, it will go away some day.
	
    }
    if (!($frames) && (!$rt::ui::web::FORM{'display'})) {
	
	if ($serial_num > 0) {	
	    $rt::ui::web::FORM{'display'} = "History";
	}
	else{
	 
            #display a default queue
	    #$rt::ui::web::FORM{'q_unowned'}='true';
	    #$rt::ui::web::FORM{'q_owned_by_me'}='true';
	    $rt::ui::web::FORM{'q_status'}='open';
	    $rt::ui::web::FORM{'q_by_date_due'}='true';
	    $rt::ui::web::FORM{'display'} = "Queue";
	}
    }
    
    if ($frames) {
	
	if ((!($ENV{'CONTENT_LENGTH'}) && !($ENV{'QUERY_STRING'}) )) {
	    &frame_display_queue();
	}

    }



}
sub DisplayForm {

	
    if ($rt::ui::web::FORM{'display'} eq 'Request') {
	&frame_display_request();
	exit(0);
    }
    
    
    
    &rt::ui::web::header();
    
    if (($frames) && (!$rt::ui::web::FORM{'display'})) {
	# for getting blank canvases on startup
	print "\n";
	return();
	}
    
    else {   
	
        if ($rt::ui::web::FORM{'display'} eq 'Credits') {
            &credits();
	    return();
        }
	
	
        elsif ($rt::ui::web::FORM{'display'} eq 'ReqOptions') {
            &display_commands();
	    return();
        } 
	
	#easy debugging tool
	elsif ($rt::ui::web::FORM{'display'} eq 'DumpEnv'){
	    &rt::ui::web::dump_env();
	    return();
	}    
	
	elsif ($rt::ui::web::FORM{'display'} eq 'Message') {
	    if ($rt::ui::web::FORM{'message'}) {
		print "$R_UI_Web::FORM{'message'}\n\n";
		if (($serial_num>0) and (!$frames)) {
		    $rt::ui::web::FORM{'display'} = 'History';
		    print "<hr>";
		}
	    }
	}
	if ($rt::ui::web::FORM{'display'} ne 'History') {
	    require rt::ui::web::forms;
	}
	
	if (($rt::ui::web::FORM{'display'} !~ 'Create') and 
	    ($rt::ui::web::FORM{'display'} ne 'Queue') and 
	    ($rt::ui::web::FORM{'display'} ne 'ReqOptions') and 
	    ($rt::ui::web::FORM{'display'} ne 'DumpEnv') and 
	    ($rt::ui::web::FORM{'display'} ne 'Credits')) {
#	    print "<h1>Request Number $serial_num</h1>\n";
	    if ($rt::ui::web::FORM{'message'}) {
		print "$rt::ui::web::FORM{'message'}<br>\n";
	    }
	}
	if ($rt::ui::web::FORM{'display'} eq 'Queue') {
            &display_queue();
	    &FormQueueOptions();
	    
        }
	
	elsif ($rt::ui::web::FORM{'display'} eq 'Create') {
	    &FormCreate();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'Create_Step2') {
	    &FormCreate_Step2();
	}
	

	elsif ($rt::ui::web::FORM{'display'} eq 'ShowNum') {
	    
	    &FormShowNum();
	}	
	elsif ($rt::ui::web::FORM{'display'} eq 'SetFinalPrio'){
	    &FormSetFinalPrio();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetPrio'){
	    &FormSetPrio();

	}
	elsif  ($rt::ui::web::FORM{'display'} eq 'SetSubject'){
	    &FormSetSubject();
	}
	elsif  ($rt::ui::web::FORM{'display'} eq 'SetUser'){
	    &FormSetUser();
	}
	elsif  ($rt::ui::web::FORM{'display'} eq 'SetMerge'){
	    &FormSetMerge();
	}
	elsif  ($rt::ui::web::FORM{'display'} eq 'SetGive'){
	    &FormSetGive();
	}
	
	elsif  ($rt::ui::web::FORM{'display'} eq 'SetComment'){
	    &FormComment();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetReply') {
	    &FormReply();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetKill') {
	    &FormSetKill();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetSteal') {
	    &FormSetSteal();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetStatus') {
	    &FormSetStatus();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetQueue') {
	    &FormSetQueue();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetArea') {
	    &FormSetArea();
	}
	elsif ($rt::ui::web::FORM{'display'} eq 'SetDateDue') {
	    &FormSetDateDue();
	}
    }
    
    if ($rt::ui::web::FORM{'display'} eq 'History') {
	
	&display_summary($serial_num);
	print "<hr>";
	&display_history_tables($serial_num);
	
    }
    

    
   if (!$frames) {
       &display_commands();
   }	
    &rt::ui::web::footer(); 
}


sub frame_display_request {
    
    &rt::ui::web::content_header();
    print "
<frameset rows=\"20,80\" name=\"body\" border=\"0\">
<frameset cols=\"45,55\" name=\"reqtop\" border\"0\">
<frame src=\"$ScriptURL?display=ReqOptions&serial_num=$serial_num\" name=\"req_buttons\" scrolling=\"no\">
<frame src=\"$ScriptURL?serial_num=$serial_num\" name=\"summary\">
</frameset>";
    if ($serial_num) {
	print "<frame src=\"$ScriptURL?display=History&serial_num=$serial_num\" name=\"history\">";
    }
    else {
	print "<frame src=\"$ScriptURL?display=Credits\" name=\"history\">\n";  
    }
    print "</frameset>
";
    &rt::ui::web::content_footer();
    
}   
sub frame_display_queue {
    &rt::ui::web::content_header();
    print "
<frameset rows=\"20,80\" border=\"1\">
<frame src=\"$ScriptURL?display=Queue\" name=\"queue\">
<frame src=\"$ScriptURL?display=Request\" name=\"workspace\">
</frameset>";
    
    
}


sub takeaction {
    local ($date_due);

    require rt::database::manipulate;

    if ($rt::ui::web::FORM{'do_req_create'}) {
	

	if ($rt::ui::web::FORM{'due'} and $rt::ui::web::FORM{'due_mday'} and $rt::ui::web::FORM{'due_month'} and $rt::ui::web::FORM{'due_year'}) {
	    $date_due=timelocal(0,0,0,$rt::ui::web::FORM{'due_mday'},$rt::ui::web::FORM{'due_month'},$rt::ui::web::FORM{'due_year'});
	}
	else { 
	    $due_date=0;
	}
	($serial_num,$transaction_num,$StatusMsg)=&rt::add_new_request($rt::ui::web::FORM{'queue_id'},$rt::ui::web::FORM{'area'},$rt::ui::web::FORM{'requestors'},$rt::ui::web::FORM{'alias'},$rt::ui::web::FORM{'owner'},$rt::ui::web::FORM{'subject'},"$rt::ui::web::FORM{'final_prio_tens'}$rt::ui::web::FORM{'final_prio_ones'}","$rt::ui::web::FORM{'prio_tens'}$rt::ui::web::FORM{'prio_ones'}",$rt::ui::web::FORM{'status'},$rt::time,0,$date_due, $rt::ui::web::FORM{'content'},$current_user); 
	&rt::req_in($serial_num,$current_user);
    }
    if ($current_user) {
	if ($rt::ui::web::FORM{'do_req_prio'}){
	    ($trans, $StatusMsg)=&rt::change_priority ($serial_num, "$rt::ui::web::FORM{'prio_tens'}$rt::ui::web::FORM{'prio_ones'}",$current_user);
	}
	if ($rt::ui::web::FORM{'do_req_final_prio'}){
	    ($trans, $StatusMsg)=&rt::change_final_priority ($serial_num, "$rt::ui::web::FORM{'final_prio_tens'}$rt::ui::web::FORM{'final_prio_ones'}",$current_user);
	}
	
	if ($rt::ui::web::FORM{'do_req_status'}){
	    if ($rt::ui::web::FORM{'do_req_status'} eq 'stall') {
		($trans, $StatusMsg)=&rt::stall ($serial_num, $current_user);
	    }
	    if ($rt::ui::web::FORM{'do_req_status'} eq 'open') {
		($trans, $StatusMsg)=&rt::open ($serial_num, $current_user);
	    }
	    if ($rt::ui::web::FORM{'do_req_status'} eq 'resolve') {
		($trans, $StatusMsg)=&rt::resolve ($serial_num, $current_user);
	    }
	    if ($rt::ui::web::FORM{'do_req_status'} eq 'kill') {
		$rt::ui::web::FORM{'display'} = "SetKill";
	    }
	}


	if ($rt::ui::web::FORM{'do_req_stall'}){
	    ($trans, $StatusMsg)=&rt::stall ($serial_num, $current_user);
	    
	}
	if ($rt::ui::web::FORM{'do_req_steal'}){
	    ($trans, $StatusMsg)=&rt::steal($serial_num, $current_user);
	}    

	
	if ($rt::ui::web::FORM{'do_req_notify'}) {
	    ($trans, $StatusMsg)=&rt::notify($serial_num,$rt::time,$current_user);
	}
	
	if ($rt::ui::web::FORM{'do_req_open'}){
	    ($trans, $StatusMsg)=&rt::open($serial_num, $current_user);
	}
	if ($rt::ui::web::FORM{'do_req_user'}) {
	    ($trans, $StatusMsg)=&rt::change_requestors($serial_num, $rt::ui::web::FORM{recipient}, $current_user);
	}
	if ($rt::ui::web::FORM{'do_req_merge'}) {
	    ($trans, $StatusMsg)=&rt::merge($serial_num,$rt::ui::web::FORM{'req_merge_into'},$current_user);
	}
	
	if ($rt::ui::web::FORM{'do_req_kill'}){
	    ($trans, $StatusMsg)=&rt::kill($serial_num, $current_user);
	}

	if ($rt::ui::web::FORM{'do_req_give'}){
	    ($trans, $StatusMsg)=&rt::give($serial_num, $rt::ui::web::FORM{'do_req_give_to'}, $current_user);
	    if (($trans == 0 ) and ($rt::ui::web::FORM{'do_req_give_to'} eq $current_user)) {
		$rt::ui::web::FORM{'display'} = 'SetSteal';
	    }

	}
	
	if ($rt::ui::web::FORM{'do_req_resolve'}){
	    ($trans, $StatusMsg)=&rt::resolve ($serial_num,$current_user);
	}
	if ($rt::ui::web::FORM{'do_req_subject'}){
	    ($trans, $StatusMsg)=&rt::change_subject ($serial_num, $rt::ui::web::FORM{'subject'}, $current_user);
	}
	if ($rt::ui::web::FORM{'do_req_area'}){
	    ($trans, $StatusMsg)=&rt::change_area ($serial_num, $rt::ui::web::FORM{'area'}, $current_user);
	}
	
	if ($rt::ui::web::FORM{'do_req_comment'}){
	    ($trans, $StatusMsg)=&rt::comment($serial_num, $rt::ui::web::FORM{'content'},$rt::ui::web::FORM{'subject'}, $rt::ui::web::FORM{'cc'} , $rt::ui::web::FORM{'bcc'}, $current_user);
	}
	if ($rt::ui::web::FORM{'do_req_respond'}){
	    ($trans,$StatusMsg)=&rt::add_correspondence($serial_num,$rt::ui::web::FORM{'content'},$rt::ui::web::FORM{'subject'}, $rt::ui::web::FORM{'cc'}, $rt::ui::web::FORM{'bcc'}, $current_user);
	}
	if ($rt::ui::web::FORM{'do_req_date_due'}){
	    $date_due=timelocal(0,0,0,$rt::ui::web::FORM{'due_mday'},$rt::ui::web::FORM{'due_month'},$rt::ui::web::FORM{'due_year'});

	    ($trans,$StatusMsg)=&rt::change_date_due($serial_num,$date_due,$current_user);
	}
	if ($rt::ui::web::FORM{'do_req_queue'}){
	    ($trans, $StatusMsg)=&rt::change_queue ($serial_num, $rt::ui::web::FORM{'queue'}, $current_user);
	}

	
	if ($StatusMsg) {
	    $rt::ui::web::FORM{'message'}=$StatusMsg;
	    if ($rt::ui::web::FORM{'display'} eq '') {

		$rt::ui::web::FORM{'display'}="Message";
	    }
	    
	}
    }	
}

sub display_queue{
    my ($owner_ops, $subject_ops, $queue_ops, $status_ops, $prio_ops, $user_ops, $order_ops, $reverse, $query_string);
    local($^W) = 0; # Lots of form fields that may or may not exist give bogus errors

    require rt::database;
    if ($rt::ui::web::FORM{'q_owned_by'}) {
	if ($owner_ops){
	    $owner_ops .= " OR ";
	}
      
	$owner_ops .= " owner = \'" . $rt::ui::web::FORM{'q_owner'} . "\'";
    }
    if ($rt::ui::web::FORM{'q_owned_by_me'}) {
	if ($owner_ops){
	    $owner_ops .= " OR ";
	}
	$owner_ops .= " owner = \'" . $current_user . "\'";
    }
    
    if ($rt::ui::web::FORM{'q_unowned'}){
	if ($owner_ops){
	    $owner_ops .= " OR ";
	}
	$owner_ops .= " owner =  \'\'" ;
    }  
    if ($rt::ui::web::FORM{'q_queue'}){
	if ($queue_ops){
	    $queue_ops .= " OR ";
	}
	$queue_ops .= " queue_id =  \'$rt::ui::web::FORM{'q_queue'}\'" ;
    }

    
    if ($rt::ui::web::FORM{'q_status'}){
	if ($status_ops){
	    $status_ops .= " OR ";
	}
	if ($rt::ui::web::FORM{'q_status'} ne "any") {

	  $status_ops .= " status =  \'" .$rt::ui::web::FORM{'q_status'}."\'" ;
        }
        else {
	  $status_ops = " status <> \'dead\'";
	} 
    }   

 if ($rt::ui::web::FORM{'q_user'} eq 'other') {
	if ($user_ops){
		$user_ops .= " OR ";
	    }
	$user_ops .= " requestors like \'%" . $rt::ui::web::FORM{'q_user_other'} . "%\' ";
    }

     if ($rt::ui::web::FORM{'q_subject'} ) {
        if ($subject_ops){
                $subject_ops .= " OR ";
            }
        $subject_ops .= " subject like \'%" . $rt::ui::web::FORM{'q_subject'} . "%\' ";
    }    

    if ($rt::ui::web::FORM{'q_user'} eq $current_user) {
	if ($user_ops){
	    $user_ops .= " OR ";
	}
	    $user_ops .= " requestors like \'%" . $current_user . "%\' ";
    }
    
    if ($rt::ui::web::FORM{'q_orderby'}) {
	if ($order_ops){
		$order_ops .= ", ";
	    }
	$order_ops .= $rt::ui::web::FORM{'q_orderby'}; 
    }
    if ($rt::ui::web::FORM{'q_reverse'}) {
	$reverse = ' DESC'; 
	   }
    
    if ($rt::ui::web::FORM{'q_sort'} eq "Date Due") {
        if ($order_ops){
            $order_ops .= ", ";
            }
        $order_ops .= "date_due";
    }
    if ($rt::ui::web::FORM{'q_sort'} eq "Timestamp") {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "date_acted"; 
    }
    if ($rt::ui::web::FORM{'q_sort'} eq "Ticket Number") {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "serial_num"; 
    }
    if ($rt::ui::web::FORM{'q_sort'} eq "Priority") {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "priority"; 
    }
    if ($rt::ui::web::FORM{'q_sort'} eq "User") {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "requestors"; 
    }
    
    
  if ($subject_ops) {
        if ($query_string) {$query_string .= " AND ";}
        $query_string .= "($subject_ops)";
    }        
   if ($queue_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "($queue_ops)";
    }
    
    if ($prio_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "($prio_ops)";
    }

    if ($status_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "( $status_ops )";
    }

    
    if ($user_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "( $user_ops )";
    }
    if ($owner_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "( $owner_ops )";
    }
    if (!$query_string) {
	$query_string = "(owner = \'$current_user\' or owner = \'\' ) and status = \'open\' ";
    }


    if ($order_ops) {
	$query_string .= "ORDER BY $order_ops ";
    }
    else {
	$query_string .= "ORDER BY serial_num ";
    }
    if ($reverse) {
	$query_string .= " DESC";
    }
    

     $count=&rt::get_queue($query_string,$current_user);
    print "<!-- Query String 
$query_string
-->"; 
    print "<font size=$QUEUE_FONT>\n";
#    print "<pre>";
#    print "Num   !  Owner   Age     Told    Due     Status   User    Subject\n";
#    print "<HR SIZE=1>";
	&rt::ui::web::new_table("cellpadding=4 border=1 width=100% bgcolor=\"\#bbbbbb\""); {
   print " 
<TR>
       <TH><FONT SIZE=-1>Ser</FONT></TH>
       <TH><FONT SIZE=-1>Queue</FONT></TH>
       <TH><FONT SIZE=-1>Owner</FONT></TH>
       <TH><FONT SIZE=-1>Pri</FONT></TH>
       <TH><FONT SIZE=-1>Status</FONT></TH>
       <TH><FONT SIZE=-1>Told</FONT></TH>
       <TH><FONT SIZE=-1>Area</FONT></TH>
       <TH><FONT SIZE=-1>Age</FONT></TH>
       <TH><FONT SIZE=-1>Due</FONT></TH>
       <TH><FONT SIZE=-1>Requestor</FONT></TH>
       <TH><FONT SIZE=-1>Subject</FONT></TH>
 </TR>
";

    for ($temp=0;$temp<$count;$temp++){



       if ($temp % 2) {
               &rt::ui::web::new_row("bgcolor=\"ffffff\"");
       } else {
               &rt::ui::web::new_row("bgcolor=\"dddddd\"");
       }
       {
               &rt::ui::web::new_col("nowrap"); {

                   print "<font size=-1>
 <A href=\"$ScriptURL?serial_num=$rt::req[$temp]{'effective_sn'}";     
	

                    if($frames) {
                        print "&display=Request\" target=\"workspace\"";
                    }
                    else {
                        print "&display=History\"";
                    }
                    print ">$rt::req[$temp]{'serial_num'}</a></font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
                    #&rt::ui::web::table_label("Queue");
                    print "<font size=-1>$rt::req[$temp]{'queue_id'}</font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
#                   &rt::ui::web::table_label("Owner");
                    print "<font size=-1><b>$rt::req[$temp]{'owner'}</b></font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
#                   &rt::ui::web::table_label("Priority");
                    print "<font size=-1>$rt::req[$temp]{'priority'}</font>";
                } &rt::ui::web::end_col;   


                &rt::ui::web::new_col("nowrap"); {
                        print "<font size=-1>$rt::req[$temp]{'status'}</font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
#                   &rt::ui::web::table_label("Told");
                    print "<font size=-1>$rt::req[$temp]{'since_told'}</font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
#                   &rt::ui::web::table_label("Area");
                    print "<font size=-1>$rt::req[$temp]{'area'}&nbsp;</font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
#                   &rt::ui::web::table_label("Age");
                    print "<font size=-1>$rt::req[$temp]{'age'}</font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap");{
#                   &rt::ui::web::table_label("Due");        


 $due = $rt::req[$temp]{'till_due'};

                        if (substr($due,0,1) eq '-') {
                                $attr = "color=#ff0000";
                        } else { $attr = ""; }

                    print "<font size=-1 $attr>$due&nbsp;</font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
#                   &rt::ui::web::table_label("Requestor");
                    print "<font size=-1>$rt::req[$temp]{'requestors'}&nbsp;</font>";
                } &rt::ui::web::end_col;

                &rt::ui::web::new_col("nowrap"); {
#                   &rt::ui::web::table_label("Sub");
                    print "<font size=-1>$rt::req[$temp]{'subject'}</font>";
                } &rt::ui::web::end_col;
            } &rt::ui::web::end_row;

	}
    } &rt::ui::web::end_table;
    print "</font><HR>";
    
}




sub display_history_tables {
    local ($in_serial_num)=@_;
    local ($temp, $total_transactions, $wday,$mon,$mday,$hour,$min,$sec,$TZ,$year);
    
    require rt::database;
    $total_transactions=&rt::transaction_history_in($in_serial_num, $current_user);
    print "
<font size=\"+1\">T</font>ransaction <font size=\"+1\">H</font>istory\n<br>
<font size=\"-1\">";
    &rt::ui::web::new_table("width=\"100%\""); {
	
	
	for ($temp=0; $temp < $total_transactions; $temp++){
	    ($wday, $mon, $mday, $hour, $min, $sec, $TZ, $year)=&rt::parse_time($rt::req[$serial_num]{'trans'}[$temp]{'time'});
	    $date=sprintf ("%s, %s %s %4d", $wday, $mon, $mday, $year);
	    $time=sprintf ("%.2d:%.2d:%.2d", $hour,$min,$sec);
	    
	    $bgcolor="\#000000";
	    
	    $bgcolor="\#000077" if ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'correspond');
	    $bgcolor="\#0000CC" if ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'comments');
	    $bgcolor="\#0000AA" if ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'create');
	    $bgcolor="\#004400" if ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'status');
	    $bgcolor="\#330000" if ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'owner');	
	    $bgcolor="\#AA0000" if ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'date_due');	
	    
	    &rt::ui::web::new_row("bgcolor=\"$bgcolor\""); {
		&rt::ui::web::new_col("valign=\"top\" align=\"left\" width=\"15%\""); {
		    
		
		    print "
<font color=\"\#ffffff\" size=\"-1\">
$date
<br>
$time
</font>";
		} &rt::ui::web::end_col();
		&rt::ui::web::new_col("align=\"left\" width=\"85%\""); {
		    
		    print "<font color=\"\#ffffff\">
<b>$rt::req[$serial_num]{'trans'}[$temp]{text}</b>
</font>";
		} &rt::ui::web::end_col(); 
	    } &rt::ui::web::end_row();
	    
	    if ($rt::req[$serial_num]{'trans'}[$temp]{'content'}) {
		&rt::ui::web::new_row(); {
		    &rt::ui::web::new_col("valign=\"top\""); {
			if (($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'correspond') or
			    ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'comments') or
			    ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'create')) {	
			    print &fdro_murl("display=SetComment","history","Comment");
			    print "<br>\n";
			}
			if (($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'correspond') or
			    ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'create')) {
			    print &fdro_murl("display=SetReply","history","Reply");
			    print "<br>\n";
			}
			
			
			if ($rt::req[$serial_num]{'owner'} eq '') {
			    print &fdro_murl("do_req_give=true&do_req_give_to=$current_user","summary","Take");
			    print "<br>\n";
			}
			if ($rt::req[$serial_num]{'status'} ne 'resolved') {
			    print &fdro_murl("do_req_resolve=true","summary","Resolve");
			    print "<br>\n";
			}
			if ($rt::req[$serial_num]{'status'} ne 'open') {
			    print &fdro_murl("do_req_open=true","summary","Open");
			    print "<br>\n";
			}
			
		    } &rt::ui::web::end_col();
		    &rt::ui::web::new_col ("bgcolor=\"\#EEEEEE\""); {
			print "<font size=\"$MESSAGE_FONT\">";
			&rt::ui::web::print_transaction('all','received',$rt::req[$serial_num]{'trans'}[$temp]{'content'});
			print "
</font>
<hr>
";
			
			
		    } &rt::ui::web::end_col();
		    
		}&rt::ui::web::end_row();
	    }
	}   
    } &rt::ui::web::end_table();
    print "</font>\n";
}




sub display_summary {
    my ($in_serial_num)=@_;
    my ($bg_color, $fg_color);
    

    use Time::Local;
    
    $fg_color="#FFFFFF";
    $bg_color="#EEEEEE";
    
    if ($frames) {
	$target = "target=\"summary\"";
    }
    else {
	$target="";
    }
    print "<font color=\"\$fg_color\">";
    &rt::ui::web::new_table("cellspacing=0 cellpadding=0 width=\"100%\""); {
	&rt::ui::web::new_row("valign=\"top\""); {
	    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		
		print "<A href=\"$ScriptURL?display=SetMerge&serial_num=$in_serial_num\" $target $color><b>Serial Number</b></a>";
	    } &rt::ui::web::end_col(); 
	    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
		print "$in_serial_num";
	    }&rt::ui::web::end_col();
	} &rt::ui::web::end_row(); 
	
	
	&rt::ui::web::new_row("valign=\"top\""); {
	    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		
		print "<b><a href=\"$ScriptURL?display=SetSubject&serial_num=$in_serial_num\" $target>Subject</a></b>";
		
		
	    } &rt::ui::web::end_col();
	    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
		if ($rt::req[$in_serial_num]{'subject'}) {
		    print "$rt::req[$in_serial_num]{'subject'}";
		}
		else {
		    print "<i>none</i>";
		}
	    } &rt::ui::web::end_col();
	} &rt::ui::web::end_row(); 
	&rt::ui::web::new_row("valign=\"top\""); {
	    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		print "<b><a href=\"$ScriptURL?display=SetArea&serial_num=$in_serial_num\" $target>Area</a></b>";
	    } &rt::ui::web::end_col();
	    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
		if ($rt::req[$in_serial_num]{'area'}) {
		    print "$rt::req[$in_serial_num]{'area'}";
		}
		else {
		    print "<i>none</i>";
		}
	    } &rt::ui::web::end_col();
	    
	    
	    &rt::ui::web::new_row("valign=\"top\""); {
		&rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		    print "<b><a href=\"$ScriptURL?display=SetQueue&serial_num=$in_serial_num\" $target>Queue</a></b>";
		    
		} &rt::ui::web::end_col();
		&rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
		    print "$rt::req[$in_serial_num]{'queue_id'} ";
		} &rt::ui::web::end_col();
		
	    } &rt::ui::web::end_row(); 
	    
	    &rt::ui::web::new_row("valign=\"top\""); {
		&rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		    print "<b><a href=\"$ScriptURL?display=SetUser&serial_num=$in_serial_num\" $target>Requestors</a></b>";
		} &rt::ui::web::end_col();
		&rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
		    print "$rt::req[$in_serial_num]{'requestors'}";
		} &rt::ui::web::end_col();
	    } &rt::ui::web::end_row(); 
	    &rt::ui::web::new_row("valign=\"top\""); {
		&rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		    
			print "<b><a href=\"$ScriptURL?display=SetGive&serial_num=$in_serial_num\" $target>Owner</a></b>";
	 	    } &rt::ui::web::end_col();
		}
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
			
			if ($rt::req[$in_serial_num]{'owner'}) {
			    print "$rt::req[$in_serial_num]{'owner'}";
			}
			else {
			    print "<i>none</i>";
			}
		    } &rt::ui::web::end_col();
		} &rt::ui::web::end_row(); 
     	 	&rt::ui::web::new_row("valign=\"top\""); {
		    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b><a href=\"$ScriptURL?display=SetStatus&serial_num=$in_serial_num\" $target>Status</a></b>";
		    } &rt::ui::web::end_col();
		    
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
			
			
			print "$rt::req[$in_serial_num]{'status'}";
			
		    } &rt::ui::web::end_col();
		} &rt::ui::web::end_row(); 
     	 	&rt::ui::web::new_row("valign=\"top\""); {
		    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b><a href=\"$ScriptURL?display=SetNotify&serial_num=$in_serial_num\" $target>Last User Contact</a></b>";
		    } &rt::ui::web::end_col();
		    
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
			
			if ($rt::req[$in_serial_num]{'date_told'}) {
			    print localtime($rt::req[$in_serial_num]{'date_told'});
			    print " ($rt::req[$in_serial_num]{'since_told'} ago)";
			}
			else {
			    print "<i>Never contacted</i>";
			}
		    } &rt::ui::web::end_col();
		} &rt::ui::web::end_row(); 
     	 	&rt::ui::web::new_row("valign=\"top\""); {
		    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			
			
			print "<b><a href=\"$ScriptURL?display=SetPrio&serial_num=$in_serial_num\" $target>Current Priority</a></b>";
		    } &rt::ui::web::end_col();
		    
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
			
			
			print "$rt::req[$in_serial_num]{'priority'}";
			
		    } &rt::ui::web::end_col();
 		} &rt::ui::web::end_row(); 
     	 	&rt::ui::web::new_row("valign=\"top\""); {
		    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			
			
			print "<b><a href=\"$ScriptURL?display=SetFinalPrio&serial_num=$in_serial_num\" $target>Final Priority</a></b>";
		    } &rt::ui::web::end_col();
		    
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
			print "$rt::req[$in_serial_num]{'final_priority'}";
		    } &rt::ui::web::end_col();
	 	} &rt::ui::web::end_row(); 
		&rt::ui::web::new_row("valign=\"top\""); {
		    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b><a href=\"$ScriptURL?display=SetDateDue&serial_num=$in_serial_num\" $target>Due</a></b>";
		    } &rt::ui::web::end_col();
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {		

			if ($rt::req[$in_serial_num]{'date_due'}) {
			    print localtime($rt::req[$in_serial_num]{'date_due'});
			    print " (in $rt::req[$in_serial_num]{'till_due'})";
			}
			else {
			    print "<i>No date assigned</i>";
			}
			
		    } &rt::ui::web::end_col();
		} &rt::ui::web::end_row(); 
     	 	&rt::ui::web::new_row("valign=\"top\""); {
		    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			
			print "<b>Last Action</b>";
		    } &rt::ui::web::end_col();
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
			print localtime($rt::req[$in_serial_num]{'date_acted'});
			print " ($rt::req[$in_serial_num]{'since_acted'} ago)";

		    } &rt::ui::web::end_col();
		} &rt::ui::web::end_row(); 
     	 	&rt::ui::web::new_row("valign=\"top\""); {
		    &rt::ui::web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b>Created</b>";
		    } &rt::ui::web::end_col();
		    
		    &rt::ui::web::new_col("bgcolor=\"$bg_color\""); {
			
			print localtime($rt::req[$in_serial_num]{'date_created'});
			print " ($rt::req[$in_serial_num]{'age'} ago)";
		    } &rt::ui::web::end_col();
		} &rt::ui::web::end_row();
    } &rt::ui::web::end_table();
    
    print "</font>";
}




#display req options munge url
#makes it easier to print out a url for fdro
sub fdro_murl {
    local ($custom_content, $target,$description) = @_;
    $url="<a href=\"$ScriptURL?serial_num=$serial_num&refresh_req=true&transaction=$rt::req[$serial_num]{'trans'}[$temp]{'id'}&";
    $url .= $custom_content;
    $url .= "\"";
    $url .= "target=\"$target\"" if ($frames);

    $url .= ">";
    $url .= "$description</a>";
    return($url);
}
sub display_commands {
    print "<center>
<font size=\"-1\" >";
    
    
    if (!$frames) {
	print "<A HREF=\"$ScriptURL\">Display Queue</A> | ";
    }
    
    print "<A HREF=\"$ScriptURL?display=Create\"";
    print "target = \"summary\"" if ($frames);
    print ">Create a request</A>";
    if ($frames) {
	print "<br>";
    }
    else {
	print " | ";
    }
    
    if (($serial_num != 0) and ($frames)){
	print " <A HREF=\"$ScriptURL?display=Request&serial_num=$serial_num\" target=\"_parent\">Refresh Request \#$serial_num</a><br>";


	}
    
    
    print "<A HREF=\"$ScriptURL?display=ShowNum\"";
    
    print " target=\"summary\"" if ($frames);
    
    print ">View Specific Request</A> ";
    print "<br>" if ($frames);
    print " | " if (!$frames); 
    
    print "<A HREF=\"$ScriptURL?display=Logout\" target=\"_top\">Logout</A>

</font>
</center>";
     
    
}





sub credits{
    print "
<center>
<img src=\"/webrt/rt.jpeg\">
<br>

<font size=\"+1\">
Request Tracker's development was initially comissioned by <a href=\"http://www.utopia.com\">Utopia Inc</a>.  Further work has been funded by <a href=\"http://www.leftbank.com\">The Leftbank Operation</a>. and <a href=\"http://www.wesleyan.edu\">Wesleyan University.</a>
<br>
This program is redistributable under the terms of the <b>GNU Public License.</b>
</font>
<br>
Copyright &copy; 1996,1997
<a href=\"http://www.con.wesleyan.edu/~jesse/jesse.html\">Jesse Vincent</a>.
";
   
    print "</center>";
}
sub initialize_sn {
    
    if ((!$rt::ui::web::FORM{'serial_num'}) and (!$frames))
    {
	# If we don't have a serial_num, we assume the query string was just an int representing serial_num
	$rt::ui::web::FORM{'serial_num'} = $ENV{'QUERY_STRING'};
   
    }
    $ScriptURL=$ENV{'SCRIPT_NAME'}.$ENV{'PATH_INFO'};
    
    if ($rt::ui::web::FORM{'serial_num'}){
	$serial_num=int($rt::ui::web::FORM{'serial_num'});
    }
    else {
	$serial_num = 0;
    }
}



1;
