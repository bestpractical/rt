# $Header$

package rt;

require rt::database;
require rt::support::mail;
require rt::support::utils;


sub add_new_request {
    my  $in_queue_id = shift;
    my $in_area = shift;
    my $in_requestors = shift;
    my $in_alias  = shift;
    my $in_owner = shift;
    my $in_subject  = shift;
    my $in_final_priority  = shift;
    my $in_priority  = shift;
    my $in_status  = shift;
    my $in_date_created  = shift;
    my $in_date_told  = shift;
    my $in_date_due  = shift;
    my $in_content = shift;
    my $in_current_user = shift;
    my $in_cc = shift;
    my $in_bcc= shift;

    my $msg;
        
    my ($transaction_num, $serial_num);
    
    if (!&can_create_request($in_queue_id, $in_current_user)) {
	return (0,0,"You don't have permission to create requests in this queue");
    }
    
    ($in_requestors,$msg) = &norm_requestors($in_requestors);
    return (0,0,$msg) if $msg;
    
    # This should be handled better.
    if ($in_cc) {
      $content="Cc: $in_cc\n$content";
    }
    
    #add the fact to each_req    
    $serial_num=&add_request($in_queue_id, $in_area, $in_requestors, $in_alias, $in_owner, $in_subject, 
			     $in_final_priority, $in_priority, $in_status, $in_date_created, 
			     $in_date_told, $in_date_due, $in_current_user);
    
    # note the creation in the transaction log
    $transaction_num=&add_transaction($serial_num, $in_current_user, 'create','',$in_content,$time,1,$in_current_user);

    if ($queues{$in_queue_id}{m_members_correspond}) {
      &rt::template_mail ('correspondence',$in_queue_id,"$queues{$in_queue_id}{dist_list}",
			  "$in_cc","$in_bcc", "$serial_num" ,"$transaction_num","$in_subject", 
			  "$in_current_user",'');
    } elsif ($in_cc || $in_bcc) {
      &rt::template_mail ('correspondence',$in_queue_id,"","$in_cc","$in_bcc", "$serial_num" ,"$transaction_num","$in_subject", "$in_current_user",'');
    }
    
    if ( $queues{$in_queue_id}{m_user_create}) {
	&rt::template_mail ('autoreply',$in_queue_id,"$in_requestors","","","$serial_num",
			    "$transaction_num","$in_subject","_rt_system",'');
    }

    if( $in_owner )
    {
	&rt::template_mail('give',$in_queue_id,$rt::users{$in_owner}{email},"","", "$serial_num" ,
			   "$transaction_num","$in_subject","$in_current_user",'');

    }

    return ($serial_num,$transaction_num,"Request #$serial_num created.");
    }

#to be used for importing requests from other inferior ticket systems
sub import_request {
    #what queue is the fact in
    my $in_queue_id = shift;

    # what is the fact's serial num
    my $in_serial_num = shift;

    #what area is it in
    my $in_area = shift;
    
    #who requested it
    my $in_requestors = shift;

    #does it have an alias
    my $in_alias  = shift;

    #who's the owner
    my $in_owner = shift;

    #what's the subject
    my $in_subject  = shift;

    #what's the final priority
    my $in_final_priority  = shift;

    #what's the priority
    my $in_priority  = shift;

    #what's the status
    my $in_status  = shift;

    #when was it created (unixtime)
    my $in_date_created  = shift;

    #when was the user last told (unixtime)
    my $in_date_told  = shift;

    #when is it due (unixtime)
    my $in_date_due  = shift;

    #text of the transaction content
    my $in_content = shift;

    #who's doing the acting
    my $in_current_user = shift;
    
    
    my ($transaction_num, $serial_num);
    
    if (!&can_create_request($in_queue_id, $in_current_user)) {
	return (0,0,"You don't have permission to create requests in this queue");
    }
    

    #add the fact to each_req    
    $serial_num=&add_request($in_queue_id, $in_area, $in_requestors, $in_alias, $in_owner, 
			     $in_subject, $in_final_priority, $in_priority, $in_status, $in_date_created, 
			     $in_date_told, $in_date_due, $in_current_user, $in_serial_num);
    
    # note the creation in the transaction log
    $transaction_num=&add_transaction($serial_num, $in_current_user, 'import','',$in_content,$time,1,$in_current_user);

    
    return ($serial_num,$transaction_num,"Request #$serial_num created.");
    }

sub add_correspondence {
    my  $in_serial_num = shift;
    my $in_content = shift;
    my $in_subject = shift;
    my $in_cc = shift;
    my $in_bcc = shift;
    my $in_status = shift; # if we want to make the status something, set it here
                           # otherwise leave it blank to not change anything;
    my $in_notify = shift; # if we want to update the "user notified" field
                           # make this a 1.
    my $in_current_user = shift;
    my ($transaction_num,$requestors,$isnotrequestor);
    
    &req_in($in_serial_num, '_rt_system');
    
    $isnotrequestor=&is_not_a_requestor($in_current_user,$in_serial_num);

    # Those RT comments that are inserted into the content should also
    # have been handled more elegant.
    # Everybody can comment things, but only the support personell should send official replies:
    if ($isnotrequestor && !&can_manipulate_request($in_serial_num,$in_current_user)) { 

	my ($resc, $ress)=&comment
	    ( $in_serial_num, 
	     "(Reply NOT sent to requestor due to access restrictions)\n\n$in_content", 
	     $in_subject, $in_cc, $in_bcc, $in_current_user);

	# If you want to bounce back an error, then replace $resc to 1
	# below. Be warned this will also bounce to requestors if they
	# changes their email during the progress.
	return 
	    (
	     $resc,
"No permission to reply to \#$in_serial_num - your mail is recorded as a comment.\n$ress"
	     );
    }
    if (!$isnotrequestor) {
	$in_content = "(inbound)\n\n$in_content";
    }

    $requestors=$rt::req[$in_serial_num]{'requestors'};
    
    $queue_id=$rt::req[$in_serial_num]{'queue_id'};

    $transaction_num=&add_transaction($in_serial_num, $in_current_user, 'correspond',
				      '',$in_content,$time,0,$in_current_user);
    
    # read again as add_transaction overwrites it depending on user's privileges
    &req_in($in_serial_num, '_rt_system');
    
    if (($in_status ne '') and ($rt::req[$in_serial_num]{'status'} ne $in_status)) {
      $opentrans=&rt::update_request($in_serial_num,'status',"$in_status", "_rt_system");
    }
    
    #if it's coming from somebody other than the user, send them a copy
    if ($isnotrequestor) {
	&update_each_req($in_serial_num, 'date_told', $rt::time);
	$tem=&rt::template_mail('correspondence-official', $queue_id, "$requestors", $in_cc, $in_bcc, 
			 "$in_serial_num", "$transaction_num", "$in_subject", "$in_current_user",'');
    } elsif ($in_cc || $in_bcc) {
	$tem=&rt::template_mail('correspondence-official', $queue_id, "", $in_cc, $in_bcc, 
			 "$in_serial_num", "$transaction_num", "$in_subject", "$in_current_user",'');
    }

    my $dist_list=&rt::dist_list('correspond', $queue_id, $in_serial_num);
    if ($dist_list) {
	&rt::template_mail ('correspondence', $queue_id, $dist_list, "", "", 
			    $in_serial_num, $transaction_num, $in_subject, $in_current_user);
    }
    
    $effective_sn=&normalize_sn($in_serial_num);
    &update_each_req($effective_sn, 'date_acted', $time); #make now the last acted time
    
    
    return ($transaction_num,"This correspondence has been recorded.");
  }


sub import_correspondence {
  my  ($in_serial_num, $in_content, $in_subject, $in_current_user) = @_;
  my ($transaction_num,$requestors);
  
  &req_in($in_serial_num, '_rt_system');
  
  $transaction_num=&add_transaction($in_serial_num, $in_current_user, 'correspond',
				    '',$in_content,$time,1,$in_current_user);
  
  ($notifytrans,$notifymsg)=&rt::update_request($in_serial_num,'date_told', $rt::time, $in_current_user);
  return ($transaction_num,"This correspondence on request ($in_serial_num) has been recorded.");
}

sub comment {
    my  ( $in_serial_num, $in_content, $in_subject, $in_cc, $in_bcc, $in_current_user) = @_;
    my ($transaction_num,$queue_id);
 
    #Todo: this may or may not be broken. ideally we should have the headers and body in seperate places. 
    if ($in_cc) {
      $in_content = "Cc: $in_cc\n\n$in_content";
    }
    &req_in($in_serial_num, '_rt_system');
    $queue_id=$rt::req[$in_serial_num]{'queue_id'}; 

    if ($in_subject !~ /\[(\s*)comment(\s*)\]/i) {
	$in_subject .= ' [comment]';
    }
    
    $transaction_num=&add_transaction($in_serial_num, $in_current_user, 'comments',
				      '',$in_content,$time, 0,$in_current_user);
  
    my $dist_list=&rt::dist_list('comment', $queue_id, $in_serial_num);
    if ($dist_list || $in_cc || $in_bcc) {
       &template_mail('comment', $queue_id, "$dist_list", $in_cc, $in_bcc, $in_serial_num, 
		      $transaction_num, "$in_subject", $in_current_user, $in_content);
    }
     
    $effective_sn=&normalize_sn($in_serial_num);
    &update_each_req($effective_sn, 'date_acted', $time); #make now the last acted time
    
    return ($transaction_num,"Your comments have been recorded.");
}

sub resolve {
    my  ($in_serial_num, $in_current_user) = @_;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You ($in_current_user) don't have permission to modify request \#$in_serial_num");
    }
 
    $transaction_num=&update_request($in_serial_num,'status', 'resolved', $in_current_user);
    &open_parents($in_serial_num, $in_current_user) || $transaction_num=0;
    return ($transaction_num,"Request #$in_serial_num has been resolved.");
}

#
#change request's status to open
sub open {
    my  ($in_serial_num, $in_current_user) = @_;
    my ($transaction_num);
 
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    
    $transaction_num=&update_request($in_serial_num,'status','open', $in_current_user);
    return ($transaction_num,"Request #$in_serial_num has been opened.");
}

sub stall {
    my  ($in_serial_num, $in_current_user) = @_;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to stall request \#$in_serial_num");
    }
  
    $transaction_num=&update_request($in_serial_num,'status','stalled', $in_current_user);
    return ($transaction_num,"Request #$in_serial_num has been stalled.");
}

sub kill {
    my  ($in_serial_num, $in_current_user) = @_;
    my ($transaction_count, $transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
 
    ($transaction_count)=&transaction_history_in($in_serial_num,$in_current_user);

    # This is not working at my place. Perhaps it would be smarter to
    # use 'localtime' than 'parse_time' below? I'm commenting it out
    # even though - I think it's stupid deleting the transactions
    # without deleting from each_req
    
    if (0) { 
	for ($counter=0;$counter<$transaction_count;$counter++) {
	    ($weekday, $month, $monthday, $hour, $min, $sec, $TZ, $year)=&parse_time($rt::req[$in_serial_num]{'trans'}[$counter]{'time'});
	    $filename="$transaction_dir/$year/$month/$monthday/$in_serial_num.$transaction[$counter]{'id'}";
	    
	    if (-f $filename) {
		unlink($filename);
	    }
	}
    }

# I would consider deleting the DB content without deleting the files
# as a bug, so I've commented out those. Perhaps some
# "trash-can"-functionality to clear up deleted requests (files +
# each_req + transactions) had been smart. It would be sort of cool
# with some 'tmpwatch' functionality in crontab, where all dead
# requests that hasn't been accessed for one month gets killed. Or
# what do you think?
# 	$sth = $dbh->prepare($query_string) or warn "prepare had some problem: $DBI::errstr\n";
# 	$rv = $sth->execute or warn "execute had some problem: $DBI::errstr\n";
	
    $transaction_num=&update_request($in_serial_num,'status','dead', $in_current_user);    
    return ($transaction_num,"Request #$in_serial_num has been killed.");

}


sub merge {
    my  ($in_serial_num, $in_merge_into, $in_current_user) = @_;
    my ($new_requestors, $old_requestors, @requestors_list, $user); 
    my ($transaction_num);
    my %requestors;
    if (!(&can_manipulate_request($in_serial_num,$in_current_user)) or (!(&can_manipulate_request($in_merge_into,$in_current_user)))) {
      return (0,"You don't have permission to modify both requests you wish to merge");
    }
    #&req_in($in_serial_num,$in_current_user);
    #&req_in($in_merge_into,$in_current_user);
    if ( $req[$in_merge_into]{'date_created'} == 0) {
	return (0,"That request doesn't exist\n");
      }
    
    $old_requestors=$req[$in_serial_num]{'requestors'};
    $new_requestors=$req[$in_merge_into]{'requestors'};
    @requestors_list=split(/,/ , $old_requestors . ", $new_requestors");
    foreach $user (@requestors_list) {
	$user =~ s/\s//g;
	$user .= "\@$rt::domain" if ! ($user =~ /\@/);
	$requestors{$user} = 1;
    }
    $new_requestors = join(",",sort keys %requestors);
    
    &update_each_req($in_merge_into,'requestors',$new_requestors);

  if ($req[$in_merge_into]{'date_created'} > $req[$in_serial_num]{'date_created'}) {
	&update_each_req($in_merge_into,'date_created',$req[$in_serial_num]{'date_created'});
    }
    if (($req[$in_merge_into]{'date_told'} < $req[$in_serial_num]{'date_told'}) && ($req[$in_serial_num]{'date_told'} > 0)) {
	&update_each_req($in_merge_into,'date_told',$req[$in_serial_num]{'date_told'});
    }

    if (($req[$in_merge_into]{'date_due'} < $req[$in_serial_num]{'date_due'}) && ($req[$in_serial_num]{'date_due'} > 0)) {
	&update_each_req($in_merge_into,'date_due',$req[$in_serial_num]{'date_due'});
    }    
    

    $transaction_num=&update_request($in_serial_num,'effective_sn',$in_merge_into, $in_current_user);    

	$query_string = "UPDATE transactions SET effective_sn = $in_merge_into WHERE effective_sn = $in_serial_num";
	$sth = $dbh->prepare($query_string) or warn "prepare had some problem: $DBI::errstr\n";
	$rv = $sth->execute  or warn "execute had some problem: $DBI::errstr\n";

    &req_in($in_merge_into,$in_current_user);
    return ($transaction_num,"Request #$in_serial_num has been merged into request #$in_merge_into.");

}

sub change_queue {
    my  ($in_serial_num, $in_queue, $in_current_user) = @_;
    my ($transaction_num);
    
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    elsif (!&is_a_queue($in_queue)) {
	return (0, "\'$in_queue\' is not a valid queue.");
    }
    elsif (!(&can_create_request($in_queue, $in_current_user))){
	return (0, "You may only requeue a request into a queue you have privileges to create requests in");
    }
    if (!(&is_an_area($rt::req[$in_serial_num]{queue_id}, $in_area))){ 

	&update_request($in_serial_num,'area','',$in_current_user);
    }
	$transaction_num=&update_request($in_serial_num,'queue_id',$in_queue, $in_current_user);
    if (! $transaction_num) {
      return (0,"Specify a different queue.");
    }
	#if the owner isn't able to manipulate reqs in the new queue
     if(!can_manipulate_queue($in_queue, $rt::req[$in_serial_num]{'owner'})) { 
       &update_request($in_serial_num,'owner','','_rt_system');
	}
	return ($transaction_num,"Request #$in_serial_num moved to queue $in_queue.");
}

#change the ownership of a request
sub give {
    my  ($in_serial_num, $in_owner, $in_current_user) = @_;
    my ($transaction_num);
    my $qid;
    my $requestors;
    
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You do not have access to modify request \#$in_serial_num");
    }

    if (($req[$in_serial_num]{owner} ne '') and ($req[$in_serial_num]{owner} ne $in_current_user))
    {
	return (0, "$req[$in_serial_num]{owner} owns request \#$in_serial_num.  You can not reassign it without 'stealing' it.");
    }

    if ($in_owner eq $req[$in_serial_num]{owner}) {
	return(0,"$in_owner already owns request \#$in_serial_num.");
    }
    
    $qid = $req[$in_serial_num]{queue_id};
    $requestors = $req[$in_serial_num]{requestors};
    $in_subject = $req[$in_serial_num]{subject};
    if ($in_owner eq '') {
	if ($req[$in_serial_num]{'owner'} eq $in_current_user){	 

	    $transaction_num=&update_request($in_serial_num,'owner','', $in_current_user);
	    return ($transaction_num, "Request #$in_serial_num untaken.");
	    }
	else {
	    return (0,"You must own request \#$in_serial_num before you can untake it.");
	}
    }
    
    if ($req[$in_serial_num]{'owner'} eq '') {
	if ($in_owner eq $in_current_user) {	 
	    $transaction_num=&update_request($in_serial_num,'owner',$in_current_user, $in_current_user);

	    return ($transaction_num, "Request #$in_serial_num taken.");
	    }
    }
    
    if (!(&can_manipulate_request($in_serial_num,$in_owner))) {
	return (0,"$in_owner does not have access to modify requests in this queue");
    }    
    if (($req[$in_serial_num]{'owner'} eq $in_current_user) or ($req[$serial_num]{'owner'} eq ''))
    {
	$transaction_num=&update_request($in_serial_num,'owner',$in_owner, $in_current_user);
	&rt::template_mail('give',$qid,$rt::users{$in_owner}{email},"","", "$in_serial_num" ,
			   "$transaction_num","$in_subject","$in_current_user",'');

    	return ($transaction_num, "Request #$in_serial_num given to $in_owner.");
    }
    else {
	
	return(0, "You can not change the ownership of a request  owned by somebody else.");
    }
}
sub untake {
    my  ($in_serial_num, $in_current_user) = @_;
    return(&give ($in_serial_num, "", $in_current_user));
}
sub take {
    my  ($in_serial_num, $in_current_user) = @_;
    return(&give ($in_serial_num, $in_current_user, $in_current_user));
}

sub steal {
    my  ($in_serial_num, $in_current_user) = @_;
    my $old_owner;
    my $qid;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    #we don't need to read the req in because can_manipulate_req calls req_in
    #&req_in($in_serial_num,$in_current_user);
    $old_owner=$req[$in_serial_num]{'owner'};
    $qid = $req[$in_serial_num]{'queue_id'};

    if (($old_owner ne $in_current_user) and ($old_owner ne '')) {
	$transaction_num=&update_request($in_serial_num,'owner',$in_current_user, $in_current_user);
	&rt::template_mail('steal',$qid,$rt::users{$old_owner}{email},"","", "$in_serial_num" ,
			   "$transaction_num",$rt::req[$in_serial_num]{subject}, "$in_current_user",'');

	return ($transaction_num, "Request \#$in_serial_num stolen.");
    }
    else {
	return (0,"You can only steal requests owned by someone else.");
    }
}

sub change_requestors {
    my  ($in_serial_num, $in_user, $in_current_user) = @_;
    my ($transaction_num);
    my $msg;
    
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }

    ($in_user,$msg) = &norm_requestors($in_user);
    return (0,$msg) if $msg;

    $transaction_num=&update_request($in_serial_num,'requestors',$in_user,$in_current_user);
    return ($transaction_num);
}

sub change_area {
    my  ($in_serial_num, $in_area, $in_current_user) = @_;
    my ($transaction_num);

    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    if ((!(&is_an_area($rt::req[$in_serial_num]{queue_id}, $in_area))) and ($in_area ne '')){ 
	return (0, "Queue \'$rt::req[$in_serial_num]{queue_id}\' doesn't have an area called \'$in_area\'");
    }

    $transaction_num=&update_request($in_serial_num,'area',$in_area,$in_current_user);
    return ($transaction_num);
}

sub change_priority {
    my  ($in_serial_num, $in_priority, $in_current_user) = @_;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    $transaction_num=&update_request($in_serial_num,'priority',$in_priority, $in_current_user);
    return ($transaction_num, "Request $in_serial_num [$rt::req[$in_serial_num]{subject}] set to priority $in_priority");
}


sub change_date_due {
    my  ($in_serial_num, $in_due_date, $in_current_user) = @_;
    my ($transaction_num,$text_time);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }

    $transaction_num=&update_request($in_serial_num,'date_due',$in_due_date,$in_current_user);
    ($wday, $mon, $mday, $hour, $min, $sec, $TZ, $year)=&parse_time($in_due_date);
    $text_time = sprintf ("%s, %s %s %4d %.2d:%.2d:%.2d", $wday, $mon, $mday, $year,$hour,$min,$sec);
    return ($transaction_num, "Date due changed to $text_time");
}
sub change_alias {
    # we need to do error checking here
    # only one req can have a given alias
    # aliases can only be of certain characters

    my  ($in_serial_num, $in_alias, $in_current_user) = @_;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }

    $transaction_num=&update_request($in_serial_num,'alias',$in_alias,$in_current_user);
    return ($transaction_num);
}

sub change_final_priority {
    my  ($in_serial_num, $in_final_prio, $in_current_user) = @_;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    $transaction_num=&update_request($in_serial_num,'final_priority',$in_final_prio,$in_current_user);
    return ($transaction_num,"Final priority changed");
}



sub change_subject {
    my  ($in_serial_num, $in_subject, $in_current_user) = @_;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    
    $transaction_num=&update_request($in_serial_num,'subject',$in_subject, $in_current_user);
    return ($transaction_num,"Request \#$in_serial_num\'s subject has been changed to \"$in_subject\".");
}

sub notify {
    my  ($in_serial_num, $in_notified, $in_current_user) = @_;
    my ($transaction_num);
    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }
    $transaction_num=&update_request($in_serial_num,'date_told',$in_notified, $in_current_user);
    return ($transaction_num, 'Notification Noted.');
}

sub link {
    my ($in_serial_num, $in_current_user, $otherdb, $foreign_id, $content) = @_;
    my $transaction_num;

    if (!(&can_manipulate_request($in_serial_num,$in_current_user))) {
	return (0,"You don't have permission to modify request \#$in_serial_num");
    }

    # ADD TRANSACTION AT THE OTHER REQUEST
    if ($rt::relship{$otherdb}{TYPE} eq 'dependency') {
	$transaction_num=&add_transaction
	    ($in_serial_num, $in_current_user, 'link', 
	     "$otherdb/$foreign_id/$rt::relship{$otherdb}{type}-",
	     "$content", $time, 1, $in_current_user)
		or return (0, 'addtrans failed');
    } else {
	# Maybe we need some kind of PlugIn system here? Hm. What about
	# loading all available modules in a certain subdirectory. All
	# those modules add references to subs in a hash table,
	# i.e. PlugIns::subs. The Knowledge DB should certainly be
	# represented here through such a PlugIn system, forcing this link
	# sub to insert a link from the KB to RT as well.
    }

    # ADD THE ACTUAL LINK:
    &add_link($in_serial_num, $in_current_user,
	      $otherdb, $foreign_id);

    # ADD TRANSACTION:
    $transaction_num=&add_transaction
	($in_serial_num, $in_current_user, 'link', 
	 "$otherdb/$foreign_id/$rt::relship{$otherdb}{type}",
	 "$content", $time, 1, $in_current_user)
	    or return (0, 'addtrans failed');


}

1;

