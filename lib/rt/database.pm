# $Header$
# 
#
# Request Tracker is Copyright 1997 Jesse Reed Vincent <jesse@fsck.com>
# RT is distributed under the terms of the GNU Public License

package rt;
use Mysql;

&connectdb();

require rt::support::utils;   
require rt::database::config;
&rt::read_config();

sub connectdb {
   if (!($dbh = Mysql->Connect($host, $dbname, $rtpass, $rtuser,))){
           die "[connectdb] Database connect failed: $Mysql::db_errstr\n";
         }
  }


#
# Database routines for loading/storing transactions and requests
#

sub add_request {
    my $in_queue_id = shift;
    my $in_area = shift;
    my $in_requestors = shift;
    my $in_alias = shift;
    my $in_owner = shift;
    my $in_subject = shift;
    my $in_final_priority = shift;
    my $in_priority = shift;
    my $in_status = shift;
    my $in_date_created = shift;
    my $in_date_told = shift;
    my $in_date_due = shift;
    my $in_current_user = shift;
    my ($query_string, $serial_num);
    
    
    # if we aren't passed the serial num, get a new one.
    # this is only here for importing
    if (!($serial_num = shift)) {
        $serial_num="NULL";
    }


    $in_queue_id = $rt::dbh->quote($in_queue_id);
    $in_area = $rt::dbh->quote($in_area);
    $in_requestors = $rt::dbh->quote($in_requestors);
    $in_alias = $rt::dbh->quote($in_alias);
    $in_owner = $rt::dbh->quote($in_owner);
    $in_subject = $rt::dbh->quote($in_subject);
    $in_status = $rt::dbh->quote($in_status);
    $in_current_user = $rt::dbh->quote($in_current_user);

    $query_string="INSERT INTO each_req (serial_num, effective_sn, queue_id, area, alias,requestors, owner, subject, initial_priority, final_priority, priority, status, date_created, date_told, date_acted, date_due)  VALUES ($serial_num, $serial_num, $in_queue_id, $in_area, $in_alias, $in_requestors, $in_owner, $in_subject," . int($in_priority) .", ". int($in_final_priority).", ".int($in_priority) . ", $in_status, " . int($in_date_created).", ".int($in_date_told) .", ". int($in_date_created).", ". int($in_date_due).")";
    
    $sth = $dbh->Query($query_string) 
	or warn "[add_request] Query had some problem: $Mysql::db_errstr\n$query_string\n";
   
  # if we just assigned the fact a serial number, get it and then set effective serial_num 
  # to the same number
  if ($serial_num eq 'NULL') {
      $serial_num = $sth->insert_id;   
    	$query_string="UPDATE each_req set effective_sn = $serial_num WHERE serial_num = $serial_num";
	$sth = $dbh->Query($query_string) 
		or warn "[add_request] Query had some problem: $Mysql::db_errstr\n$query_string\n";
	}
    return ($serial_num);
}


sub add_transaction {
    my ($in_serial_num, $in_actor, $in_type, $in_data,$in_content, $in_time,$in_do_mail,$in_current_user) = @_;
    my ($transaction_num, $query_string, $queue_id, $owner, $requestors);

    
    $in_actor = $rt::dbh->quote($in_actor);
    $in_type = $rt::dbh->quote($in_type);
    $in_data = $rt::dbh->quote($in_data);
    

    &req_in($in_serial_num, '_rt_system');
    $queue_id=$rt::req[$in_serial_num]{queue_id};
    $requestors=$rt::req[$in_serial_num]{requestors};
    $owner=$rt::req[$in_serial_num]{owner};
    &req_in($in_serial_num, $in_current_user);

    $query_string = "INSERT INTO transactions (id, effective_sn, serial_num, actor, type, trans_data, trans_date)  VALUES (NULL, $req[$in_serial_num]{'effective_sn'}, $in_serial_num, $in_actor, $in_type, $in_data, $in_time)";
     $sth = $dbh->Query($query_string) or warn "[add transaction] Query had some problem: $Mysql::db_errstr\nQuery: $query_string\n";
    $transaction_num = $sth->insert_id;       

    
    #if we've got content, mail it away
    if ($in_content) {
	require rt::database::content;
        $content_file=&write_content($time,$in_serial_num,$transaction_num,$in_content);
    }


    if ($in_do_mail) {
      if (!&is_owner($in_serial_num,$in_current_user) and ($owner ne "") and ($queues{$queue_id}{m_owner_trans})){
	&rt::template_mail ('transaction',$queue_id,$rt::users{$owner}{email},"","", "$in_serial_num" ,"$transaction_num","Transaction ($in_current_user)", "$in_current_user",'');
      }
      if ($queues{$queue_id}{m_members_trans}){
	&rt::template_mail ('transaction',$queue_id,$queues{$queue_id}{dist_list},"","", "$in_serial_num" ,"$transaction_num","Transaction ($in_current_user)", "$in_current_user",'');
    }
	if ($queues{queue_id}{m_user_trans}){
	  &rt::template_mail ('transaction',$queue_id,$requestors,"","", "$in_serial_num" ,"$transaction_num","Transaction ($in_current_user)", "$in_current_user",'');
    }
      
      
}
    return ($transaction_num);
}

sub update_each_req {
    my ($in_serial_num, $in_field, $in_new_value) = @_;
    my $query_string;
    
   

 # DANGER, WILL ROBINSON!  
 # the following code works great right now, but if we modify the fields in the schema, 
 # we'll need to update the if below.  I'd rather just rewrite scrub to be intelligent about 
 # how to scrub...but to do that, we'd have to read the field type for each field...which 
 # we don't do yet
 #
    
    $in_new_value =~ s/\'/\\\'/g; #we'd do this with scrub, but $in_field might be an int.
    $in_new_value =~ s/\\/\\\\/g; #that would cause it to puke
                                  #so for now, we've got to resort to this EVIL hack

    # this if really means "single quote it if the field is not an int field....but
    # it's terribly non-obvious.
    if (($in_field !~ /date/) and ($in_field !~ /time/) and ($in_field !~ /effective_sn/) and ($in_field !~ /priority/)) {
    	$in_new_value = "\'$in_new_value\'";
    }
	$query_string="UPDATE each_req SET $in_field= $in_new_value WHERE effective_sn = $in_serial_num";
    #print "update_each_req: $query_string\n\n";
    $dbh->Query($query_string) or warn "[update_each_req] Query had some problem: $Msql::db_errstr\nQuery: $query_string\n";
}

sub update_request
{
    my $in_serial_num = shift;
    my $in_variable = shift;
    my $in_new_value = shift;
    my $in_current_user = shift;

    $effective_sn=&normalize_sn($in_serial_num);
    if (($in_current_user eq '_rt_system') or (&can_manipulate_queue($req[$effective_sn]{queue_id},$in_current_user))) {
	&update_each_req($effective_sn, $in_variable, $in_new_value);
	&update_each_req($effective_sn, 'date_acted', $time);        #make now the last acted time
	$transaction_num=&add_transaction($effective_sn, $in_current_user, $in_variable,$in_new_value,'',$time,1,$in_current_user);
	return ($transaction_num);
      }
    else {
	return(0);
    }
}



sub transaction_history_in
{
    my ($in_serial_num,$in_current_user) = @_;
    my ($counter);
    
    #print "reading trans history\n";
    $effective_sn=&normalize_sn($in_serial_num);
    $sth = $dbh->Query("SELECT id, actor, type, trans_data, trans_date, serial_num, effective_sn from transactions WHERE effective_sn = $effective_sn ORDER BY id") or warn "Query had some problem: $Msql::db_errstr\n";
    while (@row=$sth->FetchRow) {
	&parse_transaction_row($counter, $in_current_user, @row);
	$counter++;
    }
    return ($counter);
}

sub transaction_in {
    my ($trans, $in_current_user) = @_;
    my ($query_string);

    $query_string = "SELECT id, actor, type, trans_data, trans_date, serial_num, effective_sn from transactions WHERE id = $trans ORDER BY id";
    $sth = $dbh->Query($query_string) or return( "Query had some problem: $Mysql::db_errstr\nThe query was $query_string");
    
    while (@row=$sth->FetchRow) {
	&parse_transaction_row($trans, $in_current_user, @row);
    }
    return ($trans);
}

sub parse_transaction_row {
    my ($in_id, $in_current_user, @row) = @_;
    my ($success,$content,$wday, $mon, $mday, $hour, $min, $sec, $TZ, $year);
    $serial_num=$row[6];

    $rt::req[$serial_num]{'trans'}[$in_id]{'id'}	       	=	$row[0];
    $rt::req[$serial_num]{'trans'}[$in_id]{'serial_num'}		=	$row[5];
    $rt::req[$serial_num]{'trans'}[$in_id]{'effective_sn'}	=	$row[6];
    if ((&can_display_queue( "$rt::req[$serial_num]{'queue_id'}",$in_current_user)) or ($in_current_user eq '_rt_system')){

	$rt::req[$serial_num]{'trans'}[$in_id]{'actor'}	       	=	$row[1];
	$rt::req[$serial_num]{'trans'}[$in_id]{'type'}	       	=	$row[2];
	$rt::req[$serial_num]{'trans'}[$in_id]{'data'} 	       	=	$row[3];	
	$rt::req[$serial_num]{'trans'}[$in_id]{'time'}	       	=	$row[4];   
	($wday, $mon, $mday, $hour, $min, $sec, $TZ, $year)=&parse_time($rt::req[$serial_num]{'trans'}[$in_id]{'time'});

	$rt::req[$serial_num]{'trans'}[$in_id]{'text_time'}         = sprintf ("%s, %s %s %4d %.2d:%.2d:%.2d", $wday, $mon, $mday, $year,$hour,$min,$sec);
	
	require rt::database::content;
	($success, $content)= &read_content($rt::req[$serial_num]{'trans'}[$in_id]{'time'},$rt::req[$serial_num]{'trans'}[$in_id]{'serial_num'}, $rt::req[$serial_num]{'trans'}[$in_id]{'id'});


       

	if ($success) {
	    $rt::req[$serial_num]{'trans'}[$in_id]{'content'} = $content;
	}
	$rt::req[$serial_num]{'trans'}[$in_id]{'text'}=&transaction_text($serial_num, $in_id);

    }
    
    else {
	$rt::req[$serial_num]{'trans'}[$in_id]{'actor'}	       	="";
	$rt::req[$serial_num]{'trans'}[$in_id]{'type'}	       	=	"";
	$rt::req[$serial_num]{'trans'}[$in_id]{'data'} 	       	=	"";
	$rt::req[$serial_num]{'trans'}[$in_id]{'time'}	       	=	"";
	$rt::req[$serial_num]{'trans'}[$in_id]{'text_time'}         = "";
	$rt::req[$serial_num]{'trans'}[$in_id]{'content'} = "";
	$rt::req[$serial_num]{'trans'}[$in_id]{'text'}="";
    }
}


sub transaction_text {
    my ($serial_num,$index) =@_;
    my ($text_time, $wday, $mon, $mday, $hour, $min, $sec, $TZ, $year);
    if ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'create'){
	return( "Request created by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'correspond')    {
	return( "Mail sent by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'comments')  {
	return( "Comments added by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }

    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'area')  {
	return( "Area changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'status'){
	if ($rt::req[$serial_num]{'trans'}[$index]{'data'} eq 'dead') {
	    return ("Request killed by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
	}
	else {
	    return( "Status changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
	}
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'queue_id'){
	return( "Queue changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'owner'){
	if ($rt::req[$serial_num]{'trans'}[$index]{'data'} eq $rt::req[$serial_num]{'trans'}[$index]{'actor'}){
	    return( "Taken by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
	}
	elsif ($rt::req[$serial_num]{'trans'}[$index]{'data'} eq ''){
	    return( "Untaken by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
	}
	
	else{
	    return( "Owner changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
	}
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'requestors'){
	return( "User changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'priority')
    {
	return( "Priority changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'final_priority')
    {
	return( "Final Priority changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'date_due')
    {  
    ($wday, $mon, $mday, $hour, $min, $sec, $TZ, $year)=&parse_time($rt::req[$serial_num]{'trans'}[$index]{'data'});
    $text_time = sprintf ("%s, %s %s %4d %.2d:%.2d:%.2d", $wday, $mon, $mday, $year,$hour,$min,$sec);
	return( "Date Due changed to $text_time by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'subject')
    {
	return( "Subject changed to $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'date_told')
    {
	return( "User notified by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    elsif ($rt::req[$serial_num]{'trans'}[$index]{'type'} eq 'effective_sn')
    {
	return( "Request $rt::req[$serial_num]{'trans'}[$index]{'serial_num'} merged into $rt::req[$serial_num]{'trans'}[$index]{'data'} by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
    }
    else {
	return("$rt::req[$serial_num]{'trans'}[$index]{'type'} modified.  RT Should be more explicit about this!");
    }
    
    
}

sub get_effective_sn {
    my ($in_serial_num) =@_;
    my ($effective_sn);
       #gotta do this damn query to deal w/ merged requests
    $sth = $dbh->Query("select effective_sn from each_req WHERE serial_num = ". int($in_serial_num))
	or warn "Query had some problem: $Msql::db_errstr\n";
    while (@row=$sth->FetchRow) {
	$effective_sn	       	=	$row[0];
    }
    return ($effective_sn);
}

sub req_in
{
    my ($in_serial_num, $in_current_user) = @_;
    my ($effective_sn);

    $effective_sn = &normalize_sn($in_serial_num);

    
    $query_string = "SELECT serial_num, effective_sn,  queue_id,  area, alias,  requestors,  owner,  subject,  initial_priority,  final_priority,  priority,  status,  date_created,  date_told,  date_acted,  date_due FROM each_req WHERE serial_num = $effective_sn";
    $sth = $dbh->Query($query_string)  
	or warn "Query had some problem: $Msql::db_errstr\nQuery String = $query_string\n";
    while (@row=$sth->FetchRow) {
	&parse_req_row($in_serial_num, $in_current_user, @row);
    }
}


sub get_queue {
    my ($in_criteria,$in_current_user) =@_;
    my $temp=0;
    
    $query_string = "SELECT serial_num, effective_sn,  queue_id, area,  alias,  requestors,  owner,  subject,  initial_priority,  final_priority,  priority,  status,  date_created,  date_told,  date_acted,  date_due FROM each_req WHERE $in_criteria";
    $sth = $dbh->Query($query_string)
	or warn "Query had some problem: $Msql::db_errstr\n$query_string\n";

    while (@row=$sth->FetchRow) {
	# we don\'t want to include reqs that have been merged.
	if ($row[0]==$row[1]) { 
	    &parse_req_row($temp, $in_current_user, @row);
	    if ($req[$temp]{status}){
		$temp++;
	    }
	}
	
    }
    return ($temp);
}

sub parse_req_row {
    # $in_serial_num is a misnomer....it could just be an arbitrary ID #..but we'd like to 
    # discourage that.
    my ($in_serial_num,$in_current_user,@row) =@_;
    

    $req[$in_serial_num]{'serial_num'} = $row[0];
    $req[$in_serial_num]{'effective_sn'}	       	=	$row[1];
    $req[$in_serial_num]{'queue_id'}	       	=	$row[2];

    $req[$in_serial_num]{'alias'} 	       	=	$row[4];	
    if ((&can_display_queue( $req[$in_serial_num]{'queue_id'},$in_current_user)) or ($row[6] eq $in_current_user) or ($in_current_user eq '_rt_system')) {
	$req[$in_serial_num]{'area'}                =       $row[3];	
	$req[$in_serial_num]{'requestors'}	       	=	$row[5];		
	$req[$in_serial_num]{'owner'}	=	$row[6];
	$req[$in_serial_num]{'subject'}	       	= 	$row[7];
	$req[$in_serial_num]{'initial_priority'}    		= 	$row[8];
	$req[$in_serial_num]{'final_priority'}      	=	$row[9];
	$req[$in_serial_num]{'priority'}	        =	$row[10];
	$req[$in_serial_num]{'status'}	       	=	$row[11];
	$req[$in_serial_num]{'date_created'}		=	$row[12];
	$req[$in_serial_num]{'date_told'}      	=	$row[13];
	$req[$in_serial_num]{'date_acted'}	        =	$row[14];
	$req[$in_serial_num]{'date_due'}	       	=	$row[15];
	$req[$in_serial_num]{'age'}=date_diff($req[$in_serial_num]{'date_created'}, $time);
	if ($req[$in_serial_num]{'date_told'} > 0) {
	    $req[$in_serial_num]{'since_told'}=date_diff($req[$in_serial_num]{'date_told'}, $time);	
	}
	else {
	    $req[$in_serial_num]{'since_told'}="never";
	}
	if ($req[$in_serial_num]{'date_acted'} > 0) {
	    $req[$in_serial_num]{'since_acted'}=date_diff($req[$in_serial_num]{'date_acted'}, $time);	
	}
	if ($req[$in_serial_num]{'date_due'} > 0) {
	    $req[$in_serial_num]{'till_due'}=date_diff($time, $req[$in_serial_num]{'date_due'});
	}
	else {
	    $req[$in_serial_num]{'till_due'}="";
	}
    }
    else {
	$req[$in_serial_num]{'requestors'}	       	=	"";		
	$req[$in_serial_num]{'owner'}	=	"";
	$req[$in_serial_num]{'area'}    =       "";
	$req[$in_serial_num]{'subject'}	       	= "";
	$req[$in_serial_num]{'initial_priority'}    	="";
	$req[$in_serial_num]{'final_priority'}      	=	"";
	$req[$in_serial_num]{'priority'}	        ="";
	$req[$in_serial_num]{'status'}	       	=	"";
	$req[$in_serial_num]{'date_created'}		="";
	$req[$in_serial_num]{'date_told'}      	=	"";
	$req[$in_serial_num]{'date_acted'}	        ="";
	$req[$in_serial_num]{'date_due'}	       	="";
	$req[$in_serial_num]{'age'}= "";
	$req[$in_serial_num]{'since_told'}="";
	$req[$in_serial_num]{'since_acted'}="";
    }

}

1;
    
  
