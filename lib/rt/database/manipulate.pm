# $Header$

package rt;

require rt::database;
require rt::support::mail;
require rt::support::utils;

sub add_correspondence {
    my  $in_serial_num = shift;
    my $in_content = shift;
    my $in_subject = shift;
    my $in_cc = shift;
    my $in_bcc = shift;
    my $in_status = shift; # if we want to make the status something, set it here
                           # otherwise leave it blank to not change anything;
    my $in_notify = shift; # if we want to update the "user notified" field
                           # make this a 1.oo
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
    } else {
      if ($in_cc || $in_bcc) {
	$tem=&rt::template_mail('correspondence-official', $queue_id, "", $in_cc, $in_bcc, 
				"$in_serial_num", "$transaction_num", "$in_subject", "$in_current_user",'');
      }
	if ($in_notify) {
	  &update_each_req($in_serial_num, 'date_told', $rt::time);
	}
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



sub kill {
    my  ($in_serial_num, $in_current_user) = @_;
    my ($transaction_count, $transaction_num);
 
 
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



sub link {
    my ($in_serial_num, $in_current_user, $otherdb, $foreign_id, $content) = @_;
    my $transaction_num;


    # ADD TRANSACTION AT THE OTHER REQUEST
    if ($rt::relship{$otherdb}{TYPE} eq 'dependency') {
	if (!$rt::relship{$otherdb}{URL}) {
	    $transaction_num=&add_transaction
		($in_serial_num, $in_current_user, 'link', 
		 "$otherdb/$foreign_id/$rt::relship{$otherdb}{TYPE}-",
		 "$content", $time, 1, $in_current_user)
		    or return (0, 'addtrans failed');
	} else {
	    die "Stub!! :( Link action has to be taken at foreign RT instance";
	}
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
	 "$otherdb/$foreign_id/$rt::relship{$otherdb}{TYPE}". 
	 (defined $rt::relship{$otherdb}{URL}) ? "/$rt::relship{$otherdb}{URL}" : "",
	 "$content", $time, 1, $in_current_user)
	    or return (0, 'addtrans failed');


    # DEPENDENCY
    # One more thing: If we add a dependency, the dependent should be
    # stalled:
    if ($rt::relship{$otherdb}{TYPE} eq 'dependency') {
	req_in($foreign_id);
	if ($rt::req[$foreign_id]{'status'} ne 'resolved') {
	    if (!$rt::relship{$otherdb}{URL}) {
		return stall($foreign_id, $in_current_user);
	    } else {
		die "Stub! :( The foreign RT instance has to be informed that the request should be stalled";
	    }
	}
    }

    return ($transaction_num, 'Link added');
 }

}

1;
