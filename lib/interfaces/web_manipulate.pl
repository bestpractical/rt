#
# (c) 1997 Jesse Vincent
# jesse@fsck.com
#

{

package webrt;
require "/usr/local/rt/lib/routines/RT.pm";
require RT_UI_Web;
require Web_Auth;
use Time::Local;

$QUEUE_FONT="-1";
$MESSAGE_FONT="-1";
$frames=&RT_UI_Web::frames();
&RT_UI_Web::cgi_vars_in();

&initialize_sn();

($value, $message)=&rt::initialize('web_not_authenticated_yet');
#	print "Content-type: text/plain\n\n";
#	&RT_UI_Web::dump_env();

&CheckAuth();

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


    ($name, $pass)=&WebAuth::AuthCheck($AuthRealm);

    #if the user's password is bad
    if (!(&rt::is_password($name, $pass))) {

	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0);
    }

    #if the user isn't eve authenticating
    elsif ($name eq '') {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0)
	}
    
    #if the user is trying to log out
    if ($RT_UI_Web::FORM{'display'} eq 'Logout') {
	&WebAuth::AuthForceLogin($AuthRealm);
	exit(0);
    }
    else {
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
	
	if ((!($ENV{'CONTENT_LENGTH'}) && !($ENV{'QUERY_STRING'}) )) {
	    &frame_display_queue();
	}

    }



}
sub DisplayForm {

	
    if ($RT_UI_Web::FORM{'display'} eq 'Request') {
	&frame_display_request();
	exit(0);
    }
    
    
    
    &RT_UI_Web::header();
    
    if (($frames) && (!$RT_UI_Web::FORM{'display'})) {
	# for getting blank canvases on startup
	print "\n";
	return();
	}
    
    else {   
	
        if ($RT_UI_Web::FORM{'display'} eq 'Credits') {
            &credits();
	    return();
        }
	
	
        elsif ($RT_UI_Web::FORM{'display'} eq 'ReqOptions') {
            &display_commands();
	    return();
        } 
	
	#easy debugging tool
	elsif ($RT_UI_Web::FORM{'display'} eq 'DumpEnv'){
	    &RT_UI_Web::dump_env();
	    return();
	}    
	
	elsif ($RT_UI_Web::FORM{'display'} eq 'Message') {
	    if ($RT_UI_Web::FORM{'message'}) {
		print "$R_UI_Web::FORM{'message'}\n\n";
		if (($serial_num>0) and (!$frames)) {
		    $RT_UI_Web::FORM{'display'} = 'History';
		    print "<hr>";
		}
	    }
	}
	if ($RT_UI_Web::FORM{'display'} ne 'History') {
	    require RT_WebForms;
	}
	
	if (($RT_UI_Web::FORM{'display'} !~ 'Create') and 
	    ($RT_UI_Web::FORM{'display'} ne 'Queue') and 
	    ($RT_UI_Web::FORM{'display'} ne 'ReqOptions') and 
	    ($RT_UI_Web::FORM{'display'} ne 'DumpEnv') and 
	    ($RT_UI_Web::FORM{'display'} ne 'Credits')) {
#	    print "<h1>Request Number $serial_num</h1>\n";
	    if ($RT_UI_Web::FORM{'message'}) {
		print "$RT_UI_Web::FORM{'message'}<br>\n";
	    }
	}
	if ($RT_UI_Web::FORM{'display'} eq 'Queue') {
            &display_queue();
	    &FormQueueOptions();
	    
        }
	
	elsif ($RT_UI_Web::FORM{'display'} eq 'Create') {
	    &FormCreate();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'Create_Step2') {
	    &FormCreate_Step2();
	}
	

	elsif ($RT_UI_Web::FORM{'display'} eq 'ShowNum') {
	    
	    &FormShowNum();
	}	
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetFinalPrio'){
	    &FormSetFinalPrio();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetPrio'){
	    &FormSetPrio();

	}
	elsif  ($RT_UI_Web::FORM{'display'} eq 'SetSubject'){
	    &FormSetSubject();
	}
	elsif  ($RT_UI_Web::FORM{'display'} eq 'SetUser'){
	    &FormSetUser();
	}
	elsif  ($RT_UI_Web::FORM{'display'} eq 'SetMerge'){
	    &FormSetMerge();
	}
	elsif  ($RT_UI_Web::FORM{'display'} eq 'SetGive'){
	    &FormSetGive();
	}
	
	elsif  ($RT_UI_Web::FORM{'display'} eq 'SetComment'){
	    &FormComment();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetReply') {
	    &FormReply();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetKill') {
	    &FormSetKill();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetSteal') {
	    &FormSetSteal();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetStatus') {
	    &FormSetStatus();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetQueue') {
	    &FormSetQueue();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetArea') {
	    &FormSetArea();
	}
	elsif ($RT_UI_Web::FORM{'display'} eq 'SetDateDue') {
	    &FormSetDateDue();
	}
    }
    
    if ($RT_UI_Web::FORM{'display'} eq 'History') {
	
	&display_summary($serial_num);
	print "<hr>";
	&display_history_tables($serial_num);
	
    }
    

    
   if (!$frames) {
       &display_commands();
   }	
    &RT_UI_Web::footer(); 
}


sub frame_display_request {
    
    &RT_UI_Web::content_header();
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
    &RT_UI_Web::content_footer();
    
}   
sub frame_display_queue {
    &RT_UI_Web::content_header();
    print "
<frameset rows=\"20,80\" border=\"1\">
<frame src=\"$ScriptURL?display=Queue\" name=\"queue\">
<frame src=\"$ScriptURL?display=Request\" name=\"workspace\">
</frameset>";
    
    
}


sub takeaction {
    local ($date_due);

    require RT_Manipulate;

    if ($RT_UI_Web::FORM{'do_req_create'}) {
	

	if ($RT_UI_Web::FORM{'due'} and $RT_UI_Web::FORM{'due_mday'} and $RT_UI_Web::FORM{'due_month'} and $RT_UI_Web::FORM{'due_year'}) {
	    $date_due=timelocal(0,0,0,$RT_UI_Web::FORM{'due_mday'},$RT_UI_Web::FORM{'due_month'},$RT_UI_Web::FORM{'due_year'});
	}
	else { 
	    $due_date=0;
	}
	($serial_num,$transaction_num,$StatusMsg)=&rt::add_new_request($RT_UI_Web::FORM{'queue_id'},$RT_UI_Web::FORM{'area'},$RT_UI_Web::FORM{'requestors'},$RT_UI_Web::FORM{'alias'},$RT_UI_Web::FORM{'owner'},$RT_UI_Web::FORM{'subject'},"$RT_UI_Web::FORM{'final_prio_tens'}$RT_UI_Web::FORM{'final_prio_ones'}","$RT_UI_Web::FORM{'prio_tens'}$RT_UI_Web::FORM{'prio_ones'}",$RT_UI_Web::FORM{'status'},$rt::time,0,$date_due, $RT_UI_Web::FORM{'content'},$current_user); 
	&rt::req_in($serial_num,$current_user);
    }
    if ($current_user) {
	if ($RT_UI_Web::FORM{'do_req_prio'}){
	    ($trans, $StatusMsg)=&rt::change_priority ($serial_num, "$RT_UI_Web::FORM{'prio_tens'}$RT_UI_Web::FORM{'prio_ones'}",$current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_final_prio'}){
	    ($trans, $StatusMsg)=&rt::change_final_priority ($serial_num, "$RT_UI_Web::FORM{'final_prio_tens'}$RT_UI_Web::FORM{'final_prio_ones'}",$current_user);
	}
	
	if ($RT_UI_Web::FORM{'do_req_status'}){
	    if ($RT_UI_Web::FORM{'do_req_status'} eq 'stall') {
		($trans, $StatusMsg)=&rt::stall ($serial_num, $current_user);
	    }
	    if ($RT_UI_Web::FORM{'do_req_status'} eq 'open') {
		($trans, $StatusMsg)=&rt::open ($serial_num, $current_user);
	    }
	    if ($RT_UI_Web::FORM{'do_req_status'} eq 'resolve') {
		($trans, $StatusMsg)=&rt::resolve ($serial_num, $current_user);
	    }
	    if ($RT_UI_Web::FORM{'do_req_status'} eq 'kill') {
		$RT_UI_Web::FORM{'display'} = "SetKill";
	    }
	}


	if ($RT_UI_Web::FORM{'do_req_stall'}){
	    ($trans, $StatusMsg)=&rt::stall ($serial_num, $current_user);
	    
	}
	if ($RT_UI_Web::FORM{'do_req_steal'}){
	    ($trans, $StatusMsg)=&rt::steal($serial_num, $current_user);
	}    

	
	if ($RT_UI_Web::FORM{'do_req_notify'}) {
	    ($trans, $StatusMsg)=&rt::notify($serial_num,$rt::time,$current_user);
	}
	
	if ($RT_UI_Web::FORM{'do_req_open'}){
	    ($trans, $StatusMsg)=&rt::open($serial_num, $current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_user'}) {
	    ($trans, $StatusMsg)=&rt::change_requestors($serial_num, $RT_UI_Web::FORM{recipient}, $current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_merge'}) {
	    ($trans, $StatusMsg)=&rt::merge($serial_num,$RT_UI_Web::FORM{'req_merge_into'},$current_user);
	}
	
	if ($RT_UI_Web::FORM{'do_req_kill'}){
	    ($trans, $StatusMsg)=&rt::kill($serial_num, $current_user);
	}

	if ($RT_UI_Web::FORM{'do_req_give'}){
	    ($trans, $StatusMsg)=&rt::give($serial_num, $RT_UI_Web::FORM{'do_req_give_to'}, $current_user);
	    if (($trans == 0 ) and ($RT_UI_Web::FORM{'do_req_give_to'} eq $current_user)) {
		$RT_UI_Web::FORM{'display'} = 'SetSteal';
	    }

	}
	
	if ($RT_UI_Web::FORM{'do_req_resolve'}){
	    ($trans, $StatusMsg)=&rt::resolve ($serial_num,$current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_subject'}){
	    ($trans, $StatusMsg)=&rt::change_subject ($serial_num, $RT_UI_Web::FORM{'subject'}, $current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_area'}){
	    ($trans, $StatusMsg)=&rt::change_area ($serial_num, $RT_UI_Web::FORM{'area'}, $current_user);
	}
	
	if ($RT_UI_Web::FORM{'do_req_comment'}){
	    ($trans, $StatusMsg)=&rt::comment($serial_num, $RT_UI_Web::FORM{'content'},$RT_UI_Web::FORM{'subject'}, $current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_respond'}){
	    ($trans,$StatusMsg)=&rt::add_correspondence($serial_num,$RT_UI_Web::FORM{'content'},$RT_UI_Web::FORM{'subject'},$current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_date_due'}){
	    $date_due=timelocal(0,0,0,$RT_UI_Web::FORM{'due_mday'},$RT_UI_Web::FORM{'due_month'},$RT_UI_Web::FORM{'due_year'});

	    ($trans,$StatusMsg)=&rt::change_date_due($serial_num,$date_due,$current_user);
	}
	if ($RT_UI_Web::FORM{'do_req_queue'}){
	    ($trans, $StatusMsg)=&rt::change_queue ($serial_num, $RT_UI_Web::FORM{'queue'}, $current_user);
	}

	
	if ($StatusMsg) {
	    $RT_UI_Web::FORM{'message'}=$StatusMsg;
	    if ($RT_UI_Web::FORM{'display'} eq '') {

		$RT_UI_Web::FORM{'display'}="Message";
	    }
	    
	}
    }	
}

sub display_queue{
    my ($owner_ops, $subject_ops, $queue_ops, $status_ops, $prio_ops, $user_ops, $order_ops, $reverse, $query_string);
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

     if ($RT_UI_Web::FORM{'q_subject'} ) {
        if ($subject_ops){
                $subject_ops .= " OR ";
            }
        $subject_ops .= " subject like \'%" . $RT_UI_Web::FORM{'q_subject'} . "%\' ";
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
    
    if ($RT_UI_Web::FORM{'q_sort'} eq "Date Due") {
        if ($order_ops){
            $order_ops .= ", ";
            }
        $order_ops .= "date_due";
    }
    if ($RT_UI_Web::FORM{'q_sort'} eq "Timestamp") {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "date_acted"; 
    }
    if ($RT_UI_Web::FORM{'q_sort'} eq "Ticket Number") {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "serial_num"; 
    }
    if ($RT_UI_Web::FORM{'q_sort'} eq "Priority") {       
	if ($order_ops){
	    $order_ops .= ", ";
	    }
	$order_ops .= "priority"; 
    }
    if ($RT_UI_Web::FORM{'q_sort'} eq "User") {       
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
	&RT_UI_Web::new_table("cellpadding=4 border=1 width=100% bgcolor=\"\#bbbbbb\""); {
    for ($temp=0;$temp<$count;$temp++){



	    &RT_UI_Web::new_row; {
		&RT_UI_Web::new_col("rowspan=2 valign=center bgcolor=\"#bbbbbb\" align=center"); {
		    
		    print "
<A href=\"$ScriptURL?serial_num=$rt::req[$temp]{'effective_sn'}";
		    if($frames) {
			print "&display=Request\" target=\"workspace\"";
		    }
		    else {
			print "&display=History\"";
		    }
		    print "><font size=+3>$rt::req[$temp]{'serial_num'}</font></a>";
		} &RT_UI_Web::end_col;

		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Queue");
		    print "$rt::req[$temp]{'queue_id'}";
		} &RT_UI_Web::end_col;
		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Area");
		    print "$rt::req[$temp]{'area'}";
		} &RT_UI_Web::end_col;
		
		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Owner");
		    print "$rt::req[$temp]{'owner'}";
		} &RT_UI_Web::end_col;

		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Age");
		    print "$rt::req[$temp]{'age'}";
		} &RT_UI_Web::end_col;
		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Sub");
		    print "$rt::req[$temp]{'subject'}";
		} &RT_UI_Web::end_col;
	    } &RT_UI_Web::end_row;
	    &RT_UI_Web::new_row("bgcolor=\"#ffffff\""); {
		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Status");
		    print "$rt::req[$temp]{'status'}";
		} &RT_UI_Web::end_col;
		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Told");
		    print "$rt::req[$temp]{'since_told'}";
		} &RT_UI_Web::end_col;
		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Priority");
		    print "$rt::req[$temp]{'priority'}";
		} &RT_UI_Web::end_col;
		&RT_UI_Web::new_col;{
		    &RT_UI_Web::table_label("Due");
		    print "$rt::req[$temp]{'till_due'}";
		} &RT_UI_Web::end_col;
		&RT_UI_Web::new_col; {
		    &RT_UI_Web::table_label("Requestor");
		    print "$rt::req[$temp]{'requestors'}";
		} &RT_UI_Web::end_col;
	    } &RT_UI_Web::end_row;
	    


	    if ($false) {
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
}	    print "</a>\n";
#	    print "</tr>\n";
	    
	}
    } &RT_UI_Web::end_table;
    print "</font><HR>";
    
}




sub display_history_tables {
    local ($in_serial_num)=@_;
    local ($temp, $total_transactions, $wday,$mon,$mday,$hour,$min,$sec,$TZ,$year);
    
    require RT_Database;
    $total_transactions=&rt::transaction_history_in($in_serial_num, $current_user);
    print "
<font size=\"+1\">T</font>ransaction <font size=\"+1\">H</font>istory\n<br>
<font size=\"-1\">";
    &RT_UI_Web::new_table("width=\"100%\""); {
	
	
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
	    
	    &RT_UI_Web::new_row("bgcolor=\"$bgcolor\""); {
		&RT_UI_Web::new_col("valign=\"top\" align=\"left\" width=\"15%\""); {
		    
		
		    print "
<font color=\"\#ffffff\" size=\"-1\">
$date
<br>
$time
</font>";
		} &RT_UI_Web::end_col();
		&RT_UI_Web::new_col("align=\"left\" width=\"85%\""); {
		    
		    print "<font color=\"\#ffffff\">
<b>$rt::req[$serial_num]{'trans'}[$temp]{text}</b>
</font>";
		} &RT_UI_Web::end_col(); 
	    } &RT_UI_Web::end_row();
	    
	    if ($rt::req[$serial_num]{'trans'}[$temp]{'content'}) {
		&RT_UI_Web::new_row(); {
		    &RT_UI_Web::new_col("valign=\"top\""); {
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
			
		    } &RT_UI_Web::end_col();
		    &RT_UI_Web::new_col ("bgcolor=\"\#EEEEEE\""); {
			print "<font size=\"$MESSAGE_FONT\">";
			&RT_UI_Web::print_transaction('all','received',$rt::req[$serial_num]{'trans'}[$temp]{'content'});
			print "
</font>
<hr>
";
			
			
		    } &RT_UI_Web::end_col();
		    
		}&RT_UI_Web::end_row();
	    }
	}   
    } &RT_UI_Web::end_table();
    print "</font>\n";
}




sub display_summary {
    my ($in_serial_num)=@_;
    my ($bg_color, $fg_color);
    
    $fg_color="#FFFFFF";
    $bg_color="#EEEEEE";
    
    if ($frames) {
	$target = "target=\"summary\"";
    }
    else {
	$target="";
    }
    print "<font color=\"\$fg_color\">";
    &RT_UI_Web::new_table("cellspacing=0 cellpadding=0 width=\"100%\""); {
	&RT_UI_Web::new_row("valign=\"top\""); {
	    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		
		print "<A href=\"$ScriptURL?display=SetMerge&serial_num=$in_serial_num\" $target $color><b>Serial Number</b></a>";
	    } &RT_UI_Web::end_col(); 
	    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
		print "$in_serial_num";
	    }&RT_UI_Web::end_col();
	} &RT_UI_Web::end_row(); 
	
	
	&RT_UI_Web::new_row("valign=\"top\""); {
	    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		
		print "<b><a href=\"$ScriptURL?display=SetSubject&serial_num=$in_serial_num\" $target>Subject</a></b>";
		
		
	    } &RT_UI_Web::end_col();
	    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
		if ($rt::req[$in_serial_num]{'subject'}) {
		    print "$rt::req[$in_serial_num]{'subject'}";
		}
		else {
		    print "<i>none</i>";
		}
	    } &RT_UI_Web::end_col();
	} &RT_UI_Web::end_row(); 
	&RT_UI_Web::new_row("valign=\"top\""); {
	    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		print "<b><a href=\"$ScriptURL?display=SetArea&serial_num=$in_serial_num\" $target>Area</a></b>";
	    } &RT_UI_Web::end_col();
	    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
		if ($rt::req[$in_serial_num]{'area'}) {
		    print "$rt::req[$in_serial_num]{'area'}";
		}
		else {
		    print "<i>none</i>";
		}
	    } &RT_UI_Web::end_col();
	    
	    
	    &RT_UI_Web::new_row("valign=\"top\""); {
		&RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		    print "<b><a href=\"$ScriptURL?display=SetQueue&serial_num=$in_serial_num\" $target>Queue</a></b>";
		    
		} &RT_UI_Web::end_col();
		&RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
		    print "$rt::req[$in_serial_num]{'queue_id'} ";
		} &RT_UI_Web::end_col();
		
	    } &RT_UI_Web::end_row(); 
	    
	    &RT_UI_Web::new_row("valign=\"top\""); {
		&RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		    print "<b><a href=\"$ScriptURL?display=SetUser&serial_num=$in_serial_num\" $target>Requestors</a></b>";
		} &RT_UI_Web::end_col();
		&RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
		    print "$rt::req[$in_serial_num]{'requestors'}";
		} &RT_UI_Web::end_col();
	    } &RT_UI_Web::end_row(); 
	    &RT_UI_Web::new_row("valign=\"top\""); {
		&RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
		    
			print "<b><a href=\"$ScriptURL?display=SetGive&serial_num=$in_serial_num\" $target>Owner</a></b>";
	 	    } &RT_UI_Web::end_col();
		}
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
			
			if ($rt::req[$in_serial_num]{'owner'}) {
			    print "$rt::req[$in_serial_num]{'owner'}";
			}
			else {
			    print "<i>none</i>";
			}
		    } &RT_UI_Web::end_col();
		} &RT_UI_Web::end_row(); 
     	 	&RT_UI_Web::new_row("valign=\"top\""); {
		    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b><a href=\"$ScriptURL?display=SetStatus&serial_num=$in_serial_num\" $target>Status</a></b>";
		    } &RT_UI_Web::end_col();
		    
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
			
			
			print "$rt::req[$in_serial_num]{'status'}";
			
		    } &RT_UI_Web::end_col();
		} &RT_UI_Web::end_row(); 
     	 	&RT_UI_Web::new_row("valign=\"top\""); {
		    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b><a href=\"$ScriptURL?display=SetNotify&serial_num=$in_serial_num\" $target>Last User Contact</a></b>";
		    } &RT_UI_Web::end_col();
		    
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
			
			if ($rt::req[$in_serial_num]{'date_told'}) {
			    print &ctime($rt::req[$in_serial_num]{'date_told'});
			    print "($rt::req[$in_serial_num]{'since_told'} ago)";
			}
			else {
			    print "<i>Never contacted</i>";
			}
		    } &RT_UI_Web::end_col();
		} &RT_UI_Web::end_row(); 
     	 	&RT_UI_Web::new_row("valign=\"top\""); {
		    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			
			
			print "<b><a href=\"$ScriptURL?display=SetPrio&serial_num=$in_serial_num\" $target>Current Priority</a></b>";
		    } &RT_UI_Web::end_col();
		    
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
			
			
			print "$rt::req[$in_serial_num]{'priority'}";
			
		    } &RT_UI_Web::end_col();
 		} &RT_UI_Web::end_row(); 
     	 	&RT_UI_Web::new_row("valign=\"top\""); {
		    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			
			
			print "<b><a href=\"$ScriptURL?display=SetFinalPrio&serial_num=$in_serial_num\" $target>Final Priority</a></b>";
		    } &RT_UI_Web::end_col();
		    
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
			print "$rt::req[$in_serial_num]{'final_priority'}";
		    } &RT_UI_Web::end_col();
	 	} &RT_UI_Web::end_row(); 
		&RT_UI_Web::new_row("valign=\"top\""); {
		    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b><a href=\"$ScriptURL?display=SetDateDue&serial_num=$in_serial_num\" $target>Due</a></b>";
		    } &RT_UI_Web::end_col();
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {		

			if ($rt::req[$in_serial_num]{'date_due'}) {
			    print &ctime($rt::req[$in_serial_num]{'date_due'});
			    print "(in $rt::req[$in_serial_num]{'till_due'})";
			}
			else {
			    print "<i>No date assigned</i>";
			}
			
		    } &RT_UI_Web::end_col();
		} &RT_UI_Web::end_row(); 
     	 	&RT_UI_Web::new_row("valign=\"top\""); {
		    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			
			print "<b>Last Action</b>";
		    } &RT_UI_Web::end_col();
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
			print &ctime($rt::req[$in_serial_num]{'date_acted'});
			print "($rt::req[$in_serial_num]{'since_acted'} ago)";
		    } &RT_UI_Web::end_col();
		} &RT_UI_Web::end_row(); 
     	 	&RT_UI_Web::new_row("valign=\"top\""); {
		    &RT_UI_Web::new_col("$bgcolor=\"$bg_color\" align=\"right\""); {
			print "<b>Created</b>";
		    } &RT_UI_Web::end_col();
		    
		    &RT_UI_Web::new_col("bgcolor=\"$bg_color\""); {
			
			print &ctime($rt::req[$in_serial_num]{'date_created'});
			print "($rt::req[$in_serial_num]{'age'} ago)";
		    } &RT_UI_Web::end_col();
		} &RT_UI_Web::end_row();
    } &RT_UI_Web::end_table();
    
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
