# $Header$
# 
#
# Request Tracker is Copyright 1997 Jesse Reed Vincent <jesse@fsck.com>
# RT is distributed under the terms of the GNU Public License

package rt;
use DBI;

&connectdb();

require rt::support::utils;   
require rt::database::config;
&rt::read_config();


sub connectdb {
	# Gets the RDBMS and database from the config.
	$data_source="dbi:$rt_db:dbname=$dbname";

	if (!($dbh = DBI->connect($data_source, $rtuser, $rtpass)))
	{
		die "[connectdb] Database connect failed: $DBI::errstr\n";
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
    my ($query_string, $serial_num, $queue_id, $area, $requestors, $alias, $owner, $subject, $status, $current_user);
    
    
    # if we aren't passed the serial num, get a new one.
    # this is only here for importing
    if (!($serial_num = shift)) {
        $serial_num="NULL";
    }


    $queue_id = &rt::quote_wrapper($in_queue_id);
    $area = &rt::quote_wrapper($in_area);
    $requestors = &rt::quote_wrapper($in_requestors);
    $alias = &rt::quote_wrapper($in_alias);
    $owner = &rt::quote_wrapper($in_owner);
    $subject = &rt::quote_wrapper($in_subject);
    $status = &rt::quote_wrapper($in_status);
    $current_user = &rt::quote_wrapper($in_current_user);

	if ($serial_num eq 'NULL')
	{   
		$query_string="INSERT INTO each_req (effective_sn, queue_id, area, alias,requestors, owner, subject, initial_priority, final_priority, priority, status, date_created, date_told, date_acted, date_due)  VALUES ($serial_num, $queue_id, $area, $alias, $requestors, $owner, $subject," . int($in_priority) .", ". int($in_final_priority).", ".int($in_priority) . ", $status, " . int($in_date_created).", ".int($in_date_told) .", ". int($in_date_created).", ". int($in_date_due).")";
	}
	else
	{
		$query_string="INSERT INTO each_req (serial_num, effective_sn, queue_id, area, alias,requestors, owner, subject, initial_priority, final_priority, priority, status, date_created, date_told, date_acted, date_due)  VALUES ($serial_num, $serial_num, $queue_id, $area, $alias, $requestors, $owner, $subject," . int($in_priority) .", ". int($in_final_priority).", ".int($in_priority) . ", $status, " . int($in_date_created).", ".int($in_date_told) .", ". int($in_date_created).", ". int($in_date_due).")";
	}

	$sth = $dbh->prepare($query_string) or warn "[add_request] prepare had some problem: $DBI::errstr\n$query_string\n";
	$rv = $sth->execute or warn "[add_request] execute had some problem: $DBI::errstr\n$query_string\n"; 

  # if we just assigned the fact a serial number, get it and then set effective serial_num 
  # to the same number
  if ($serial_num eq 'NULL') {

	$serial_num = &get_last_each_req_serial_num($sth);

    	$query_string="UPDATE each_req set effective_sn = $serial_num WHERE serial_num = $serial_num";
	$sth = $dbh->prepare($query_string) or warn "[add_request] prepare had some problem: $DBI::errstr\n$query_string\n";
	$rv = $sth->execute  or warn "[add_request] execute had some problem: $DBI::errstr\n$query_string\n";
	}
    return ($serial_num);
}

sub get_last_each_req_serial_num
{
        my $sth=shift;
	my($serial_num);

	# I like this one - unfortunately it's MySQL specific:
	if ($rt::rt_db eq 'mysql') { return $sth->{insertid}; }

	# Pull the last inserted sequence value for the each_req table.
    	$query_string="select last_value from each_req_serial_num_seq";
	$sth = $dbh->prepare($query_string) or warn "[add_request] prepare had some problem: $DBI::errstr\n$query_string\n";
	$rv = $sth->execute  or warn "[add_request] execute had some problem: $DBI::errstr\n$query_string\n";

	@row = $sth->fetchrow_array;
	$serial_num = $row[0];

	return($serial_num);
}

sub get_last_transactions_id
{
        my ($sth)=shift;
	my($transaction_num);

	# I like this one - unfortunately it's MySQL specific:
	if ($rt_db eq 'mysql') { return $sth->{insertid}; }

	# Pull the last inserted sequence value for the transactions table.
    	$query_string="select last_value from transactions_id_seq";
	$sth = $dbh->prepare($query_string) or warn "[add_request] prepare had some problem: $DBI::errstr\n$query_string\n";
	$rv = $sth->execute  or warn "[add_request] execute had some problem: $DBI::errstr\n$query_string\n";

	@row = $sth->fetchrow_array;
	$transaction_num = $row[0];

	return($transaction_num);
}

sub add_transaction {
  
  my $in_serial_num = shift;
  my $in_actor = shift;
  my $in_type = shift;
  my $in_data = shift;
  my $in_content  = shift;
  my $in_time = shift;
  my $in_do_mail = shift;
  my $in_current_user = shift;
  
  my ($actor, $type, $data, $transaction_num, $query_string, $queue_id, $owner, $requestors);
  
    
    $actor = &rt::quote_wrapper($in_actor);
    $type = &rt::quote_wrapper($in_type);
    $data = &rt::quote_wrapper($in_data);
    

    &req_in($in_serial_num, '_rt_system');
    $queue_id=$rt::req[$in_serial_num]{queue_id};
    $requestors=$rt::req[$in_serial_num]{requestors};
    $owner=$rt::req[$in_serial_num]{owner};
    &req_in($in_serial_num, $in_current_user);

#	$query_string = "INSERT INTO transactions (id, effective_sn, serial_num, actor, type, trans_data, trans_date)  VALUES ('', $req[$in_serial_num]{'effective_sn'}, $in_serial_num, $actor, $type, $data, $in_time)";
	$query_string = "INSERT INTO transactions (effective_sn, serial_num, actor, type, trans_data, trans_date)  VALUES ($req[$in_serial_num]{'effective_sn'}, $in_serial_num, $actor, $type, $data, $in_time)";
	$sth = $dbh->prepare($query_string) or warn "[add transaction] prepare had some problem: $DBI::errstr\nQuery: $query_string\n";
	$rv = $sth->execute  or warn "[add transaction] execute had some problem: $DBI::errstr\nQuery: $query_string\n";

	# MySQL specific, need more general way of getting the last sequence value.
	#    $transaction_num = $sth->insert_id;       

	$transaction_num = &get_last_transactions_id($sth);

   
    #if we've got content, write to transaction file
    if ($in_content) {
	require rt::database::content;
        $content_file=&write_content($in_time,$in_serial_num,$transaction_num,$in_content);
    }

    #if we've got content, mail it away
    if ($in_do_mail) {
      if (!&is_owner($in_serial_num,$in_current_user) and ($owner ne "") and ($queues{$queue_id}{m_owner_trans})){
	&rt::template_mail ('transaction',$queue_id,$rt::users{$owner}{email},"","", "$in_serial_num" ,"$transaction_num","Transaction ($in_current_user)", "$in_current_user",'');
      }
      if ($queues{$queue_id}{m_members_trans}){
	&rt::template_mail ('transaction',$queue_id,$queues{$queue_id}{dist_list},"","", "$in_serial_num" ,"$transaction_num","Transaction ($in_current_user)", "$in_current_user",'');
      }
      if ($queues{$queue_id}{m_user_trans}){

       #We don't want to mail the requestor on comment
       if ($in_type ne 'comments') {
	  &rt::template_mail ('transaction',$queue_id,$requestors,"","", "$in_serial_num" ,"$transaction_num","Transaction ($in_current_user)", "$in_current_user",'');

	}
      }

    }

    return ($transaction_num);
}

sub update_each_req {
    my ($in_serial_num, $in_field, $in_new_value) = @_;
    my ($query_string, $new_value);
    
	
    # if we're not actually changing the field, just abort 
    return 0 if $rt::req[$in_serial_num]{$in_field} eq $in_new_value;
    #quote the string before we update


    $new_value = &rt::quote_wrapper($in_new_value); 
    
    #set the field in the database
    $query_string="UPDATE each_req SET $in_field = $new_value WHERE effective_sn = $in_serial_num";
    #print "update_each_req: $query_string\n\n";
    $sth = $dbh->prepare($query_string) or warn "[update_each_req] prepare had some problem: $DBI::errstr\nQuery: $query_string\n";
	$rv = $sth->execute or warn "[update_each_req] execute had some problem: $DBI::errstr\nQuery: $query_string\n";	
    return 1;
}

sub update_request
{
    my $in_serial_num = shift;
    my $in_variable = shift;
    my $in_new_value = shift;
    my $in_current_user = shift;

    $effective_sn=&normalize_sn($in_serial_num);
    if (($in_current_user eq '_rt_system') or (&can_manipulate_queue($req[$effective_sn]{queue_id},$in_current_user))) {
	if( $in_variable eq 'effective_sn' )
	{
		&update_each_req($effective_sn, 'date_acted', time);        #make now the last acted time
		$transaction_num=&add_transaction($effective_sn, $in_current_user, $in_variable,$in_new_value,'',time,1,$in_current_user);
		return 0 if ! &update_each_req($effective_sn, $in_variable, $in_new_value);
		return ($transaction_num);
	}
	return 0 if ! &update_each_req($effective_sn, $in_variable, $in_new_value);
	&update_each_req($effective_sn, 'date_acted', time);        #make now the last acted time
	$transaction_num=&add_transaction($effective_sn, $in_current_user, $in_variable,$in_new_value,'',time,1,$in_current_user);
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
    $sth = $dbh->prepare("SELECT id, actor, type, trans_data, trans_date, serial_num, effective_sn from transactions WHERE effective_sn = $effective_sn ORDER BY id") or warn "prepare had some problem: $DBI::errstr\n";
	$rv = $sth->execute  or warn "prepare had some problem: $DBI::errstr\n";
    while (@row=$sth->fetchrow_array) {
	&parse_transaction_row($counter, $in_current_user, @row);
	$counter++;
    }
    return ($counter);
}

sub transaction_in {
    my ($trans, $in_current_user) = @_;
    my ($query_string);

    $query_string = "SELECT id, actor, type, trans_data, trans_date, serial_num, effective_sn from transactions WHERE id = $trans ORDER BY id";
    $sth = $dbh->prepare($query_string) or return( "prepare had some problem: $DBI::errstr\nThe query was $query_string");
	$rv = $sth->execute or return( "prepare had some problem: $DBI::errstr\nThe query was $query_string");
    
    while (@row=$sth->fetchrow_array) {
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
	my $to = $rt::req[$serial_num]{'trans'}[$index]{'data'};
	$to = 'none' if ! $to;
	return( "Area changed to $to by $rt::req[$serial_num]{'trans'}[$index]{'actor'}");
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
    $sth = $dbh->prepare("select effective_sn from each_req WHERE serial_num = ". int($in_serial_num)) or warn "prepare had some problem: $DBI::errstr\n";
	$rv = $sth->execute or warn "execute had some problem: $DBI::errstr\n";
    while (@row=$sth->fetchrow_array) {
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
    $sth = $dbh->prepare($query_string) or warn "prepare had some problem: $DBI::errstr\nQuery String = $query_string\n";
	$rv = $sth->execute or warn "execute had some problem: $DBI::errstr\nQuery String = $query_string\n";

    while (@row=$sth->fetchrow_array) {
	&parse_req_row($in_serial_num, $in_current_user, @row);
    }
}


sub get_queue {
    my ($in_criteria,$in_current_user) =@_;
    my $temp=0;
    
    $query_string = "SELECT serial_num, effective_sn,  queue_id, area,  alias,  requestors,  owner,  subject,  initial_priority,  final_priority,  priority,  status,  date_created,  date_told,  date_acted,  date_due FROM each_req WHERE $in_criteria";
    $sth = $dbh->prepare($query_string) or warn "prepare had some problem: $DBI::errstr\n$query_string\n";
	$rv = $sth->execute or warn "execute had some problem: $DBI::errstr\n$query_string\n";

    while (@row=$sth->fetchrow_array) {
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
	$req[$in_serial_num]{'age'}=date_diff($req[$in_serial_num]{'date_created'}, time);
	if ($req[$in_serial_num]{'date_told'} > 0) {
	    $req[$in_serial_num]{'since_told'}=date_diff($req[$in_serial_num]{'date_told'}, time);	
	}
	else {
	    $req[$in_serial_num]{'since_told'}="never";
	}
	if ($req[$in_serial_num]{'date_acted'} > 0) {
	    $req[$in_serial_num]{'since_acted'}=date_diff($req[$in_serial_num]{'date_acted'}, time);	
	}
	if ($req[$in_serial_num]{'date_due'} > 0) {
	    $req[$in_serial_num]{'till_due'}=date_diff(time, $req[$in_serial_num]{'date_due'});
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

sub quote_wrapper {
  my $in_val = shift;
  my ($out_val);
  if (!$in_val) {
    return ("''");
    
  }
  else {
    $out_val = $rt::dbh->quote($in_val);
    
  }
  return("$out_val");
  

}

1;
    
  
