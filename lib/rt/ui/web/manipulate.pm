# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#
{
 
 package rt::ui::web;
 
 sub activate {
   
   use Time::Local;
   
   $QUEUE_FONT="-1";
   $MESSAGE_FONT="-1";
   $frames=&rt::ui::web::frames();
   &rt::ui::web::cgi_vars_in();
   &rt::ui::web::GetSerial();
   ($value, $message)=&rt::initialize('web_not_authenticated_yet');
   &rt::ui::web::check_auth();
   &InitDisplay();
   &takeaction();
   
   
   if ($serial_num > 0) {
     require rt::database;
     $effective_sn = &rt::normalize_sn($serial_num);
     &rt::req_in($effective_sn,$current_user);
   }
   
   &DisplayForm();
   return(0);
 }
 
 
 sub InitDisplay {
   
   if (!($frames) && (!$rt::ui::web::FORM{'display'})) {
     
     if ($serial_num > 0 || $rt::ui::web::FORM{'do_req_create'}) {	
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
     if (!($rt::ui::web::FORM{'display'}) and 
	 !($rt::ui::web::FORM{'serial_num'} ) and
	 !($rt::ui::web::FORM{'queue_id'}) ) {      
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
     if ($rt::ui::web::FORM{'display'} eq 'ReqOptions') {
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
	 ($rt::ui::web::FORM{'display'} ne 'DumpEnv')) {
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
     elsif ($rt::ui::web::FORM{'display'} eq 'Blank') {
       exit(0);
     }
     
   }
   
   if ($rt::ui::web::FORM{'display'} eq 'History') {
     
     
     
     &display_summary($serial_num);
     
     &do_bar();
     print "<hr>";
     
     if (!$frames) {
       &display_commands();
     }
     
     &display_history_tables($serial_num);
     &do_bar($serial_num);
     
     
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
<frameset cols=\"45,55\" name=\"reqtop\" border=\"0\">
<frame src=\"$ScriptURL?display=ReqOptions&amp;serial_num=$serial_num\" name=\"req_buttons\" scrolling=\"no\">
<frame src=\"$ScriptURL?display=Blank&serial_num=$serial_num\" name=\"summary\">
</frameset>";
   if ($serial_num) {
     print "<frame src=\"$ScriptURL?display=History&amp;serial_num=$serial_num\" name=\"history\">";
   }
   else {
     print "<frame src=\"$ScriptURL?display=Blank\" name=\"history\">\n";  
   }
   print "</frameset>
";
   &rt::ui::web::content_footer();
   
 }   
 sub frame_display_queue {
   &rt::ui::web::content_header();
   print "
<frameset rows=\"35,65\" border=\"1\">
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
     
     if( (! $serial_num) && (! $transaction_num) )
       {
	 $rt::ui::web::FORM{'display'} = '';
       }
     else {
       &rt::req_in($serial_num,$current_user);
     }
   }
   if ($current_user) {
     if ($rt::ui::web::FORM{'do_req_prio'}){
       ($trans, $StatusMsg)=&rt::change_priority ($serial_num, "$rt::ui::web::FORM{'prio_tens'}$rt::ui::web::FORM{'prio_ones'}",$current_user);
     }
     if ($rt::ui::web::FORM{'do_req_final_prio'}){
       ($trans, $StatusMsg)=&rt::change_final_priority ($serial_num, "$rt::ui::web::FORM{'final_prio_tens'}$rt::ui::web::FORM{'final_prio_ones'}",$current_user);
     }
     
     if (( my $status =$rt::ui::web::FORM{'do_req_status'}) and
	 ($status ne $rt::req[$serial_num]{'status'})) {
       if ($status eq 'stall') {
	 ($trans, $StatusMsg)=&rt::stall ($serial_num, $current_user);
       } elsif ($status eq 'open') {
	 ($trans, $StatusMsg)=&rt::open ($serial_num, $current_user);
       } elsif ($status eq 'resolve') {
	 ($trans, $StatusMsg)=&rt::resolve ($serial_num, $current_user);
       } elsif ($status eq 'kill') {
	 $rt::ui::web::FORM{'display'} = "SetKill";
       }
     }
   }
   
   
   if ($rt::ui::web::FORM{'do_req_steal'}){
     ($trans, $StatusMsg)=&rt::steal($serial_num, $current_user);
   }    
   
   
   if ($rt::ui::web::FORM{'do_req_notify'}) {
     ($trans, $StatusMsg)=&rt::notify($serial_num,$rt::time,$current_user);
   }
   
   if ($rt::ui::web::FORM{'do_req_user'}) {
     ($trans, $StatusMsg)=&rt::change_requestors($serial_num, $rt::ui::web::FORM{'recipient'}, $current_user);
   }
   if ($rt::ui::web::FORM{'do_req_merge'}) {
     ($trans, $StatusMsg)=&rt::merge($serial_num,$rt::ui::web::FORM{'req_merge_into'},$current_user);
     $serial_num = $rt::ui::web::FORM{'req_merge_into'} if $trans;
   }
   
   if ($rt::ui::web::FORM{'do_req_kill'}){
     ($trans, $StatusMsg)=&rt::kill($serial_num, $current_user);
   }
   
   if ($rt::ui::web::FORM{'do_req_give'}){
     ($trans, $StatusMsg)=&rt::give($serial_num, $rt::ui::web::FORM{'do_req_give_to'}, $current_user);
     
     if (($trans == 0 ) and 
	 ($rt::ui::web::FORM{'do_req_give_to'} eq $current_user) and 
	 ($rt::req[$serial_num]{'owner'} !~ $current_user) ) {
       $rt::ui::web::FORM{'display'} = 'SetSteal';
     }
     
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
     ($trans,$StatusMsg)=&rt::add_correspondence($serial_num,$rt::ui::web::FORM{'content'},$rt::ui::web::FORM{'subject'}, $rt::ui::web::FORM{'cc'}, $rt::ui::web::FORM{'bcc'},$rt::ui::web::FORM{'status'},1, $current_user);
   }
   if ($rt::ui::web::FORM{'do_req_date_due'}){
     $date_due=timelocal(0,0,0,$rt::ui::web::FORM{'due_mday'},$rt::ui::web::FORM{'due_month'},$rt::ui::web::FORM{'due_year'});
     
     ($trans,$StatusMsg)=&rt::change_date_due($serial_num,$date_due,$current_user);
   }
   if ($rt::ui::web::FORM{'do_req_queue'}){
     ($trans, $StatusMsg)=&rt::change_queue ($serial_num, $rt::ui::web::FORM{'queue'}, $current_user);
     if( $trans && ! &rt::can_display_queue($rt::ui::web::FORM{'queue'},$current_user) )
       {
	 $rt::ui::web::FORM{'display'} = 'Queue';
       }
   }
   
   
   if ($StatusMsg) {
     $rt::ui::web::FORM{'message'}=$StatusMsg;
     if ($rt::ui::web::FORM{'display'} eq '') {
       
       $rt::ui::web::FORM{'display'}="Message";
     }
     
   }
 }
 
 sub display_queue {
   my ($owner_ops, $subject_ops, $queue_ops, $status_ops, $prio_ops, $user_ops, $order_ops, $reverse, $query_string);
   local($^W) = 0;		# Lots of form fields that may or may not exist give bogus errors
   
   
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
   
   if ($rt::ui::web::FORM{'q_area'} && $rt::ui::web::FORM{'q_area'} ne "Any") {
     $area_ops .= " area like \'%" . $rt::ui::web::FORM{'q_area'} . "%\' ";
   }
   if ($rt::ui::web::FORM{'q_area'} eq "None") {
     $area_ops = !$area_ops;
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
   
   if ($rt::ui::web::FORM{'q_sort'} eq "date_due") {
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "date_due";
   }
   if ($rt::ui::web::FORM{'q_sort'} eq "timestamp") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "date_told"; 
   }
   if ($rt::ui::web::FORM{'q_sort'} eq "number") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "serial_num"; 
   }
   if ($rt::ui::web::FORM{'q_sort'} eq "priority") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "priority"; 
   }
   
   if ($rt::ui::web::FORM{'q_sort'} eq "owner") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "owner"; 
   }
   if ($rt::ui::web::FORM{'q_sort'} eq "status") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "status"; 
   }
   if ($rt::ui::web::FORM{'q_sort'} eq "age") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "date_created"; 
   } 
   if ($rt::ui::web::FORM{'q_sort'} eq "last") {
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "date_acted";
   }
   
   if ($rt::ui::web::FORM{'q_sort'} eq "subject") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "subject"; 
   } 
   if ($rt::ui::web::FORM{'q_sort'} eq "queue") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "queue_id"; 
   } 
   if ($rt::ui::web::FORM{'q_sort'} eq "area") {       
     if ($order_ops){
       $order_ops .= ", ";
     }
     $order_ops .= "area"; 
   } 
   if ($rt::ui::web::FORM{'q_sort'} eq "user") {       
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
   if ($area_ops) {
     if ($query_string) {$query_string .= " AND ";}
     $query_string .= "( $area_ops )";
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
   
   if ($rt::ui::web::FORM{'q_limit'}) {
     if ($rt::ui::web::FORM{'q_range'}) {
       $start = $rt::ui::web::FORM{'q_range'};
     }
     else {
       $start = 0;
     }
     $query_string .= " LIMIT $start,$rt::ui::web::FORM{'q_limit'}";
   }
   
   
   $count=&rt::get_queue($query_string,$current_user);
   
   #if we've got a refresh rate > 0, then let's set how often we refresh
   if ($rt::ui::web::FORM{'refresh'} > 0) {
     print "<META HTTP-EQUIV=\"REFRESH\" CONTENT=\"". $rt::ui::web::FORM{'refresh'}."\">";
   }
   $query = $ENV{'QUERY_STRING'};
   $query =~ s/q_sort=(.*?)\&//;
   $query =~ s/q_reverse=(.*?)\&//;
   $query =~ s/&&//g;
   print "<!-- Query String 
$query_string
-->
<font size=\"$QUEUE_FONT\">
<TABLE cellpadding=4 border=1 width=\"100%\" bgcolor=\"\#bbbbbb\">

<TR>";
   
   print &queue_header('number',"Ser");
   print &queue_header('queue',"Queue");
   print &queue_header('owner',"Owner");
   print &queue_header('priority',"Pri");
   print &queue_header('status',"Status");
   print &queue_header('timestamp',"Told");
   print &queue_header('area',"Area");
   print &queue_header('age',"Age");
   print &queue_header('last',"Last");
   print &queue_header('date_due',"Due");
   print &queue_header('user',"Requestor");
   print &queue_header('subject',"Subject");
   
   print "</TR>";
   
   for ($temp=0;$temp<$count;$temp++){
     
     my $wrapped_requestors = $rt::req[$temp]{'requestors'};
     $wrapped_requestors =~ s/,/, /g; 
     if ($temp % 2) {
       &rt::ui::web::new_row("bgcolor=\"ffffff\"");
     } else {
       &rt::ui::web::new_row("bgcolor=\"dddddd\"");
     }
     
     
     
     print "<TD NOWRAP>
<font size=-1>
<A href=\"$ScriptURL?serial_num=$rt::req[$temp]{'effective_sn'}";     
     
     
     if($frames) {
       print "&amp;display=Request\" target=\"workspace\"";
     }
     else {
       print "&amp;display=History\"";
     }
     print ">$rt::req[$temp]{'serial_num'}</a></font>

</TD>
<TD NOWRAP>
<font size=-1>$rt::req[$temp]{'queue_id'}</font>
</TD>

<TD NOWRAP>
<font size=-1><b>$rt::req[$temp]{'owner'}</b>&nbsp;</font>
</TD>

<TD NOWRAP>
<font size=-1>$rt::req[$temp]{'priority'}</font>
</TD>   

<TD NOWRAP>
<font size=-1>$rt::req[$temp]{'status'}</font>
</TD>

<TD NOWRAP>
<font size=-1>$rt::req[$temp]{'since_told'}</font>
</TD>

<TD NOWRAP>
<font size=-1>$rt::req[$temp]{'area'}&nbsp;</font>
</TD>
	 
<TD NOWRAP>
<font size=-1>$rt::req[$temp]{'age'}</font>
</TD>

<TD NOWRAP>
<font size=-1>$rt::req[$temp]{'since_acted'}</font>
</TD>
              
<TD NOWRAP>";
     
     
     $due = $rt::req[$temp]{'till_due'};
     
     if (substr($due,0,1) eq '-') {
       $attr = "color=#ff0000";
     } 
     else { 
       $attr = ""; 
     }
     
     print "
<font size=-1 $attr>$due&nbsp;</font>
</TD>

               
<TD>
<font size=-1>$wrapped_requestors&nbsp;</font>
</TD>

<TD>
<font size=-1>$rt::req[$temp]{'subject'}&nbsp;</font>
</TD>";
   }
   print "
</TR>
</TABLE>
</font>
<HR>
";
 }
 
 sub display_history_tables {
   local ($in_serial_num)=@_;
   local ($temp, $total_transactions, $wday,$mon,$mday,$hour,$min,$sec,$TZ,$year);
   
   require rt::database;
   $total_transactions=&rt::transaction_history_in($in_serial_num, $current_user);
   print "
<font size=\"+1\">T</font>ransaction <font size=\"+1\">H</font>istory\n<br>
<font size=\"-1\">
<TABLE WIDTH=\"100%\" cellpadding=0 cellspacing=0 border=0>


";
   
   
   
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
     
     print "
<TR BGCOLOR=\"$bgcolor\">
<TD WIDTH=5 BGCOLOR=\"$bgcolor\">&nbsp;</TD>
<TD align=\"left\" valign=\"middle\" width=\"15%\">
<font color=\"\#ffffff\" size=\"-1\">
$date
$time
</font>
</TD>
<TD>
&nbsp;&nbsp;
</TD>
<TD align=\"left\">
<font color=\"\#ffffff\">
<b>$rt::req[$serial_num]{'trans'}[$temp]{text}</b>";
     
     if ($rt::req[$serial_num]{'trans'}[$temp]{'effective_sn'} != 
	 $rt::req[$serial_num]{'trans'}[$temp]{'serial_num'} ) {
       
       print " (as #$rt::req[$serial_num]{'trans'}[$temp]{'serial_num'})";
     }
     print "
</font>
</TD>
<TD ALIGN=\"RIGHT\" VALIGN=\"MIDDLE\"><FONT color=\"\#ffffff\">&nbsp;";
     
     if (&rt::can_manipulate_request($serial_num, $current_user)) {
       
       
       if (($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'correspond') or
	   ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'comments') or
	   ($rt::req[$serial_num]{'trans'}[$temp]{'type'} eq 'create')) {
	 print &fdro_murl("display=SetComment","history","<img border=0 src=\"$rt::WebrtImagePath/comment.gif\" alt=\"[Comment on this message]\">",
			  $rt::req[$serial_num]{'trans'}[$temp]{'id'} );
	 
	 print &fdro_murl("display=SetReply","history","<img border=0 src=\"$rt::WebrtImagePath/respond.gif\" alt=\"[Reply to this message]\">",
			  $rt::req[$serial_num]{'trans'}[$temp]{'id'});
	 
	 # "FAQ-reply", "Spawn" and "notify"-links should be in here..
       }
     }
     
     print "</FONT></TD>
<TD width=4 bgcolor=\"		#ffffff\"><IMG SRC=\"$rt::WebrtImagePath/srs.gif\" width=4 height=\"28\" alt=\"\"></TD>
</TR>
<TR>
<TD COLSPAN=5><img src=\"$rt::WebrtImagePath/sbs.gif\" width=100% height=4 alt=\"\"></TD>
<TD><img src=\"$rt::WebrtImagePath/sbc.gif\"  width=4 alt=\"\" height=4></TD></TR>";
     
     if ($rt::req[$serial_num]{'trans'}[$temp]{'content'}) {
       print "

<TR><TD BGCOLOR=\"		#FFFFFF\" colspan=5>
<TABLE CELLPADDING=20 width=\"100%\"><TR><TD BGCOLOR=\"\#EEEEEE\">
<font size=\"$MESSAGE_FONT\">";
       
       &rt::ui::web::print_transaction('all','received',$rt::req[$serial_num]{'trans'}[$temp]{'content'});
       
       print "</font></TD></TR></TABLE></TD></TR>";
     }
     
   }
   
   print "</TABLE></font>\n";
 }
 
 
 sub do_bar {
   my $serial_num = shift;
   my $temp;
   
   print "
     <DIV ALIGN=\"CENTER\"> ".
       &fdro_murl("display=SetComment","history","Comment",0). " | " .
	 &fdro_murl("display=SetReply","history","Reply",0);
   
   
   if ($rt::req[$serial_num]{'owner'} eq '') {
     print " | ". 
       &fdro_murl("do_req_give=true&do_req_give_to=$current_user","summary","Take",0) ;
   }
   if ($rt::req[$serial_num]{'status'} ne 'resolved') {
     
     print " | ". 
       &fdro_murl("do_req_status=resolve","summary","Resolve",0);
   }
   if ($rt::req[$serial_num]{'status'} ne 'open') {
     
     print " | " . 
       &fdro_murl("do_req_status=open","summary","Open",0);
   }
   print " | <A HREF=\"$ScriptURL?display=History&serial_num=" .
     ($serial_num + 1) . "\">Next</A>";
   
   print "</DIV>";
 }
 
 sub display_summary {
   my $in_serial_num = shift;
   my ($bg_color, $fg_color);
   
   
   use Time::Local;
   
   $bg_color="#FFFFFF";
   $fg_color="#000000";
   
   if ($frames) {
     $target = "target=\"summary\"";
   }
   else {
     $target="";
   }
   $qtarget="target=\"queue\"";
   
   print "<hr>
<font size=\"-1\">
<form action=\"$ScriptURL\" method=\"post\">
<font color=\"$fg_color\">
<input type=\"hidden\" name=\"serial_num\" value=\"$serial_num\" >
<CENTER>
<TABLE>
<TR><TD COLSPAN=3 BGCOLOR=\"	#CCCCCC\" WIDTH=100%>
<font size=+2>$rt::rtname	#$in_serial_num </font>($rt::req[$in_serial_num]{'subject'})
</TD></TR>
<TR VALIGN=\"TOP\">
<TD COLSPAN=3> 
" .&Summary_Subject . "

</TD>

</TR>
<TR VALIGN=\"TOP\">

<TD>". &Summary_Queue. "</TD>
<TD></TD>
<TD>" . &Summary_Area . "</TD>
<TD>" .&Summary_Merge . "</TD>
</TR>

<TR VALIGN=\"TOP\">


<TD>" .&Summary_Status. " </TD>
<TD>" .&Summary_Owner. "</TD>
<TD>" .&Summary_Requestors . "</TD>

</TR>

<TR VALIGN=\"TOP\">
<TD> ". &Summary_Priority . "</TD>
<TD> ". &Summary_Final_Priority . "</TD>
<TD> " .&Summary_Due_Date . "</TD>
</TR>

<TR VALIGN=TOP>
<TD> ".  &Summary_Last_Action . "</TD>
<TD> " . &Summary_Created . "</TD>
<TD> " . &Summary_Last_Contact. "</TD>
</TR>


<TR>
<TD COLSPAN=3 ALIGN=RIGHT>

  <input type=\"reset\" value=\"Reset form\"> <input type=\"submit\" value=\"Update ticket\">
</TD></TR>
</TABLE>
</CENTER>
    </font>



<input type=\"checkbox\" name=\"do_req_date_due\" value=\"true\">Set new due date!


<input type=\"checkbox\" name=\"do_req_final_prio\" value=\"true\">Set final priority!

<input type=\"checkbox\" name=\"do_req_prio\" value=\"true\">Set priority!

<input type=\"checkbox\" name=\"do_req_notify\" value=\"1\">Requestor has been touched!

<input type=\"checkbox\" name=\"do_req_give\" value=\"true\">Set owner!

<input type=\"checkbox\" name=\"do_req_user\">Change requestor!

<input type=\"checkbox\" name=\"do_req_merge\">Merge requests!

<input type=\"checkbox\" name=\"do_req_queue\" value=\"true\">Change queue!

<input type=\"checkbox\" name=\"do_req_subject\">Change subject!

<input type=\"checkbox\" name=\"do_req_area\">Change area!
    </form>
    ";
   
 }
 
 #display a column header for the queue
 
 sub queue_header {
   my $col = shift;
   my $name = shift;
   my ($header);
   $header = "<TH>
<TABLE CELLPADDING=0 CELLSPACING=0>
<TR WIDTH=\"100%\"><TD COLSPAN=2 ALIGN=\"CENTER\">
<FONT SIZE=\"-1\">$name</FONT></TD></TR>
<TR><TD ALIGN=\"LEFT\">
<a href=\"$ScriptURL?q_sort=$col\&$query\"><img src=\"$rt::WebrtImagePath/up.gif\" alt=\"+\" border=0></a></TD>
<TD ALIGN=\"RIGHT\"><a href=\"$ScriptURL?q_sort=$col\&q_reverse=1&$query\"><img src=\"$rt::WebrtImagePath/down.gif\" alt=\"-\" border=0></a></TD></TR></TABLE></TH>";
   return ($header);
 }
 
 #display req options munge url
 #makes it easier to print out a url for fdro
 sub fdro_murl {
   my $custom_content = shift;
   my $target = shift;
   my $description = shift;
   my $trans = shift;
   
   $url="<a href=\"$ScriptURL?serial_num=$serial_num&refresh_req=true&transaction=$trans&$custom_content\"";
   $url .= " target=\"$target\"" if ($frames);
   $url .= " > $description</a>";
   return($url);
 }

sub GetSerial {
  if ((!$rt::ui::web::FORM{'serial_num'}) and (!$frames)) {
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

 sub display_commands {
   
   if (!$frames) {
     require rt::ui::web::forms;
     print "<hr>
    <TABLE WIDTH=\"100%\" BGCOLOR=\" #ffffff\" CELLSPACING=0 BORDER=0><TR><TD ALIGN=CENTER VALIGN=\"MIDDLE\">
<A HREF=\"$ScriptURL\">Display Queue</A></TD><TD ALIGN=CENTER VALIGN=\"MIDDLE\">";
     &FormCreate;
     print "</TD><TD ALIGN=CENTER VALIGN=\"MIDDLE\">";
     &FormShowNum;
     print "</TD><TD ALIGN=CENTER VALIGN=\"MIDDLE\"><A HREF=\"$ScriptURL?display=Logout\" target=\"_top\">Logout</A></TD></TR></TABLE>";
     
     
     
   }
   else {
     
     print "<center>
<font size=\"-1\" >
<A HREF=\"$ScriptURL?display=Create\" target = \"summary\">Create a request</A>
<br>";
     
     if ($serial_num != 0){
       print " <A HREF=\"$ScriptURL?display=Request&amp;serial_num=$serial_num\" target=\"_parent\">Refresh Request \#$serial_num</a><br>";
       
     }
     
     
     print "<A HREF=\"$ScriptURL?display=ShowNum\"";
     
     print " target=\"summary\"" if ($frames);
     
     print ">View Specific Request</A> 


<br>
<A HREF=\"$ScriptURL?display=Logout\" target=\"_top\">Logout</A>
</font>
</center>";
   }
 }
 
 
 
 sub Summary_Owner {
   my $Form;
   $Form = &Summary_Col_Header("Owner");
   if (&rt::can_manipulate_request($serial_num, $current_user)) {
     $Form .= "
<select name=\"do_req_give_to\">
<option value=\"\">Nobody ";	
     foreach $user_id ( sort keys % {$rt::queues{$rt::req[$serial_num]{queue_id}}{acls}} ) {
       if (&rt::can_manipulate_queue ($rt::req[$serial_num]{queue_id}, $user_id)) {
	 
	 if ($user_id eq $rt::req[$serial_num]{owner}) {
	   $Form
 .=  "<option SELECTED> $user_id\n";
	 }
	 else {
	   $Form .= "<option> $user_id\n";
	 }
       }
     
       }
     $Form .= "</select>";
     
   }
   else {
     $Form .=  $rt::req[$serial_num]{owner};
   }
   return ($Form);
 }
 
 sub Summary_Requestors {
   my $Form;
   $Form .= &Summary_Col_Header("Requestors");
   
   if (&rt::can_manipulate_request($serial_num, $current_user)) {
     $Form .= "<input size=20 name=\"recipient\" VALUE=\"$rt::req[$serial_num]{'requestors'}\">
<br>
<div align=right><font size=-1>
( <a href=\"$ScriptURL?display=Queue&amp;q_user=other&amp;q_user_other=$rt::req[$in_serial_num]{requestors}\" $qtarget>
  This user's requests.</a>
)
</font>
</div>"; 
}
else {
  $Form .= $rt::req[$serial_num]{'requestors'};
 }
return ($Form);
}


sub Summary_Subject {
  my $Form;
  $Form = &Summary_Col_Header("Summary");
  if (&rt::can_manipulate_request($serial_num, $current_user)) {
    $Form .= "<input size=60 MAXSIZE=80 name=\"subject\" value=\"$rt::req[$in_serial_num]{'subject'}\">
";
  }
  else {
    $Form .= $rt::req[$in_serial_num]{'subject'};
  }
  return ($Form);
}

sub Summary_Created {
  my $Form;
  $Form = &Summary_Col_Header("Created");
  
  $Form .= scalar localtime($rt::req[$in_serial_num]{'date_created'}) . "
<br><i><font size=-1>($rt::req[$in_serial_num]{'age'} ago)</font></i>";
  
  
}
sub Summary_Last_Action {
  my $Form;
  $Form =  &Summary_Col_Header("Last Action");
  
  $Form .=  scalar localtime($rt::req[$in_serial_num]{'date_acted'}) . 
    "<br><i><font size=-1>($rt::req[$in_serial_num]{'since_acted'} ago)</font></i>";
  return ($Form);
}
sub Summary_Last_Contact {
  my $Form;
  $Form = &Summary_Col_Header("Last Contact");
  if ($rt::req[$in_serial_num]{'date_told'}) {
    $Form .= scalar localtime($rt::req[$in_serial_num]{'date_told'});
    $Form .= "<br><i>($rt::req[$in_serial_num]{'since_told'} ago)</i>";
  }
  else {
    $Form .= "<i>Never contacted</i>";
  }
  return ($Form);
}


sub Summary_Queue {
  my $Form;
  $Form .= &Summary_Col_Header("Queue");
  
  if (&rt::can_manipulate_request($serial_num, $current_user)) {
    $Form .= "<select name=\"queue\">";
    foreach $queue (sort keys %rt::queues) {
      if (&rt::can_create_request($queue, $current_user)) {
	if ($rt::req[$serial_num]{queue_id} eq $queue) {
	  $Form .= "<option SELECTED> $queue";
	}
	else {
	  $Form .=  "<option> $queue\n";
	}
      }
      $Form .= "</select>";
    }
  }
  else {
    $Form .= "$rt::req[$serial_num]{queue_id}";
  }
  
  return ($Form);
}

sub Summary_Area {
  my ($Form, $area);
  $Form = &Summary_Col_Header("Area");
  if (&rt::can_manipulate_request($serial_num, $current_user)) {
    $Form .= "<select name=\"area\"><option value=\"\">None ";
    foreach $area ( sort keys % {$rt::queues{$rt::req[$serial_num]{queue_id}}{areas}} ) {
      if ($area eq $rt::req[$serial_num]{area}) {
	print "<option SELECTED>$area\n";
      }
      else {
	$Form .= "<option>$area\n";
      }
    }
    $Form .= "</select>";
  }
  else {
    $Form .= $rt::req[$serial_num]{'area'};
  }
  return ($Form);
}



sub Summary_Merge {
  my $Form;
  if (&rt::can_manipulate_request($serial_num, $current_user)) {
    $Form =  &Summary_Col_Header("Merge Into");
    $Form .=  "<input size=5 name=\"req_merge_into\" value=\"$in_serial_num\">";
  }
  return ($Form);
}


sub Summary_Status {
  my $Form;
  $Form =  &Summary_Col_Header("Status");
  if (&rt::can_manipulate_request($serial_num, $current_user)) {
    
    if ($rt::req[$serial_num]{status} eq 'dead') { 
      $Form .=  "<i>Dead</i>";
    } 
    else {
      $Form .=  "<select name=\"do_req_status\">\n";
      $Form .=  "<option value=\"open\" ";
      if ($rt::req[$serial_num]{status} eq 'open') { $Form .=  "SELECTED";}
      $Form .= ">open\n";
      $Form .= "<option value=\"stall\" ";
      if ($rt::req[$serial_num]{status} eq 'stalled') { $Form .=  "SELECTED";}
      $Form .=  ">stalled\n";
      $Form .=  "<option value=\"resolve\" ";
      if ($rt::req[$serial_num]{status} eq 'resolved') { $Form .=  "SELECTED";}
      $Form .=  ">resolved\n";
      $Form .=  "<option value =\"kill\">dead\n";
      $Form .=  "</select>\n";
    }
  }
  else {
    $Form .= $rt::req[$serial_num]{'status'};
  }
  return ($Form);
}

sub Summary_Due_Date {
  my $Form;
  $Form = &Summary_Col_Header("Due Date:");
    
  if ($rt::req[$in_serial_num]{'date_due'}) {
    $Form .= &rt::ui::web::select_a_date($rt::req[$serial_num]{'date_due'}, "due");
    $Form .= " <br><i><font size=-1>(in $rt::req[$in_serial_num]{'till_due'})</font></i>";
  } 
  else {
    $Form .= &rt::ui::web::select_a_date(-1, "due");
    
  }
}

sub Summary_Priority {
  my ($Form);
  $Form = &Summary_Col_Header("Priority");
  if (&rt::can_manipulate_request($serial_num, $current_user)) {
    $Form .= &rt::ui::web::select_an_int($rt::req[$serial_num]{priority}, "prio");
  }
  else {
    $Form .= $rt::req[$serial_num]{'priority'};
  }
  return ($Form);
}

sub Summary_Final_Priority {
  my $Form;
  $Form = &Summary_Col_Header("Final Priority");
  
  if (&rt::can_manipulate_request($serial_num, $current_user)) {
    $Form .= &rt::ui::web::select_an_int($rt::req[$serial_num]{final_priority}, "final_prio");
  }
  else {
    $Form .= $rt::req[$serial_num]{final_priority};
  }
  return ($Form);
}
sub Summary_Col_Header {
  my $val = shift;
  return ("<FONT SIZE=-2>$val:</FONT><BR>");
}



}

1;
