#$Header$
package rt::ui::cli::admin;


sub activate {
($current_user,$tmp)=getpwuid($<);
($value, $message)=&rt::initialize($current_user);
print "$message\n";
if ($value == 0) {
	return(0);
} 
&parse_args;
}

sub parse_args {
    for ($i=0;$i<=$#ARGV;$i++) {
	if ($ARGV[$i] =~ 'q') {
	    $action=$ARGV[++$i];
	    if (($action eq "-modify") or ($action eq "-create")) {
		$queue_id=$ARGV[++$i];
		if (!$queue_id) {
			print "You must specify a queue.\n";
			exit(0);
			}

		&cli_create_modify_queue($queue_id);
	    }
	    elsif ($action eq "-delete")	{
		$queue_id=$ARGV[++$i];
            if (!$queue_id) {
                        print "You must specify a queue.\n";
                        exit(0);
                        }

		&cli_delete_queue($queue_id);
	    }

	    elsif ($action eq "-acl")	{
		$queue_id=$ARGV[++$i];
	                if (!$queue_id) {
                        print "You must specify a queue.\n";
                        exit(0);
                        }


		&cli_acl_queue($queue_id);
	    }	
	    
	    elsif ($action eq "-area")	{
		$area_action=$ARGV[++$i];
		$area_name=$ARGV[++$i];
		$queue_id=$ARGV[++$i];
		if ($area_action =~ 'a') {
		    ($flag, $message)=&rt::add_queue_area($queue_id, $area_name, $current_user);
		    print "$message\n"
		    }
		elsif ($area_action =~  'd') {
		    ($flag, $message)=&rt::delete_queue_area($queue_id, $area_name, $current_user);
		    print "$message\n"
		    }	
	    }
	}

	elsif ($ARGV[$i] =~ 'u') {
	    $action=$ARGV[++$i];
	    if (($action eq "-modify") or ($action eq "-create")) {
		$user_id=$ARGV[++$i];
	                if (!$user_id) {
                        print "You must specify a user.\n";
                        exit(0);
                        }


		&cli_create_modify_user($user_id);
	    } elsif ($action eq "-getpwent") {
		$passwd=$ARGV[++$i];
		$admin=$ARGV[++$i];
		if (!defined($admin)) {
		    print "Usage: user -getpwent <password> <administrator> [<users>...]\n";
		    exit(0);
		}
		if (defined($ARGV[i+1])) {
		   while (my $login=$ARGV[++$i]) {
		      ($login, $domain) = split('@', $login);
                      $domain || ($domain = $host);
                      &add_pwent($domain, getpwnam($login), $current_user);		  
		   }
	       } else { 
		   #Sometimes it really had been useful beeing able to combine while with
		   #else..  
		   
                     &setpwent;
                     while (&add_pwent($host, getpwent, $current_user))
                          {;}
                     &endpwent;
	       }
   
	    }
	    elsif ($action eq "-delete")	{
		$user_id=$ARGV[++$i];

                        if (!$user_id) {
                        print "You must specify a user.\n";
                        exit(0);
                        }

		&cli_delete_user($user_id);
	    }	
	    
	}
	elsif ($ARGV[$i] =~ 'a')	{
	    $user_id=$ARGV[++$i];
	    $queue_id=$ARGV[++$i];
	    $privs=$ARGV[++$i];
	    &cli_user_acl($user_id,$queue_id,$privs);
	}	
	
	else{
	    &cli_help_rt_admin();
	    exit(0);
	}
    }
}
   

# Add/Modify users by pwent:
# This code by tobix...
sub add_pwent {
  if (!@_) {return undef;}
  my ($domain, $name,$pass,$uid,$gid,
      $quota,$comment,$gcos,$dir,$shell,$whoami) = @_;
  my ($realname,$office,$phone)=split(/,/,$gcos);

  my ($result, $msg)=&rt::add_modify_user_info
      ($name,$realname,$passwd,"$name\@$domain",$phone,$office,$comment,
       ($name eq $whoami ? 1 : $admin),$whoami);

  # Report to STDOUT:
  print "$msg\n" if ($msg);

  return $result;
}


sub cli_acl_queue {
    my ($queue_id)=@_;

    print "ACLs for queue \"$queue_id\"\n";
    while (($user_id,$value)= each %rt::users) {
	print "$user_id:";
	&cli_print_acl($user_id,$queue_id);
    }
}
 sub cli_create_modify_user{
    my ($user_id)=@_;
    if (($current_user eq $user_id) or ($rt::users{$current_user}{admin_rt})) {
	$email=&rt::ui::cli::question_string("User's email alias (ex: somebody\@somewhere.com)" ,$rt::users{$user_id}{email});
	$real_name=&rt::ui::cli::question_string("Real Name",$rt::users{$user_id}{'real_name'});
	$password=&rt::ui::cli::question_string("RT Password (will echo)",$rt::users{$user_id}{password});
	$phone=&rt::ui::cli::question_string("Phone Number",$rt::users{$user_id}{phone});
	$office=&rt::ui::cli::question_string("Office Location",$rt::users{$user_id}{office});
	$comments=&rt::ui::cli::question_string("Misc info about this user",$rt::users{$user_id}{comments});
	if ($rt::users{$current_user}{admin_rt}) {
	    $admin_rt=&rt::ui::cli::question_yes_no("Is this user the RT administrator",$rt::users{$user_id}{admin_rt});
	}
	else {
	    $admin_rt=0;
	}
	if(&rt::ui::cli::question_yes_no("Are you satisfied with your answers",0)){
	    ($flag, $message)=&rt::add_modify_user_info($user_id, $real_name, $password, $email, $phone, $office,$comments, $admin_rt, $current_user);
	    print "$message\n";
	}
	else {
	    print "User modifications aborted.\n";
	}
    }
    else {
	print "\nYou do not have privileges to modify that user's info\n";
    }
}



sub cli_create_modify_queue {
    my ($queue_id)=@_;
    my ($mail_alias, $m_owner_trans, $m_members_trans, $m_user_trans,$m_members_correspond, $m_user_create, $m_members_comment, $allow_user_create,$default_prio, $default_final_prio);
    $mail_alias=&rt::ui::cli::question_string("Queue email alias (ex: support\@somewhere.com)" ,$rt::queues{$queue_id}{mail_alias});
    $m_owner_trans=&rt::ui::cli::question_yes_no("Mail request owner on transaction",$rt::queues{$queue_id}{m_owner_trans});
    
    $m_members_trans=&rt::ui::cli::question_yes_no("Mail queue members on transaction",$rt::queues{$queue_id}{m_members_trans});
    $m_user_trans=&rt::ui::cli::question_yes_no("Mail requestors on transaction",$rt::queues{$queue_id}{m_user_trans});

    $m_user_create=&rt::ui::cli::question_yes_no("Autoreply to requestor on creation",$rt::queues{$queue_id}{m_user_create});
    $m_members_correspond=&rt::ui::cli::question_yes_no("Mail correspondence to queue members",$rt::queues{$queue_id}{m_members_correspond});
    $m_members_comment=&rt::ui::cli::question_yes_no("Mail queue members on comment",$rt::queues{$queue_id}{m_members_comment});
    $allow_user_create=&rt::ui::cli::question_yes_no("Allow non-queue members to create requests",$rt::queues{$queue_id}{allow_user_create});
    $default_prio=&rt::ui::cli::question_int("Default request priority (1-100)",$rt::queues{$queue_id}{default_prio});
    $default_final_prio=&rt::ui::cli::question_int("Default final request priority (1-100)",$rt::queues{$queue_id}{default_final_prio});
    
    if(&rt::ui::cli::question_yes_no("Are you satisfied with your answers",0)){
	($flag, $message)=&rt::add_modify_queue_conf($queue_id, $mail_alias, $m_owner_trans, $m_members_trans, $m_user_trans, $m_user_create, $m_members_correspond, $m_members_comment, $allow_user_create, $default_prio, $default_final_prio, $current_user);
	print "$message\n";
  }
    else {
	print "Queue modifications aborted.\n";
    }
}

sub cli_delete_queue {
    my ($queue_id)=@_;
    # this function needs to ask about moving all requests into some other queue
    if(&rt::ui::cli::question_yes_no("Really DELETE queue $queue_id",0)){
	($flag, $message)=&rt::delete_queue($queue_id, $current_user);
	print "$message\n";
    }
    else {
	print "Queue deletion aborted.\n";
    }
}

sub cli_delete_user {
    my ($user_id)=@_;
    if(&rt::ui::cli::question_yes_no("Really DELETE user $user_id",0)){
	($flag, $message)=&rt::delete_user($user_id, $current_user);
	print "$message\n";
    }
    else {
	print "User deletion aborted.\n";
    }
}





sub cli_user_acl {
    my ($user_id,$queue_id,$privs) =@_;
    my ($display, $manipulate, $admin, $message);
    if (!$user_id) {
	print "You must specify a user.\n";
	return(0);
    }
    elsif (!&rt::is_a_user($user_id)){
	print "That user does not exist.\n";
	return(0);
    }

    elsif (!$queue_id){
	print "$user_id\'s ACL\n";
	while (($queue_id,$value)= each %rt::queues) {
	    print "$queue_id: ";
	    &cli_print_acl($user_id,$queue_id);
	}
	return(0);
	
    }
    elsif (!(&rt::is_a_queue($queue_id))){
	print "That queue does not exist.\n";
        return(0);
    }
    
    elsif (!$in_privs) {
	$display=&rt::ui::cli::question_yes_no("Can this user access this queue",$rt::queues{$queue_id}{acls}{$user_id}{display});
	if ($display) {
	    $manipulate=&rt::ui::cli::question_yes_no("Can this user manipulate requests in this queue",$rt::queues{$queue_id}{acls}{$user_id}{manipulate});
	    if ($manipulate) {
		$admin=&rt::ui::cli::question_yes_no("Is this user the administrator for this queue",$rt::queues{$queue_id}{acls}{$user_id}{admin});
	    }
	    else {
		$admin=0;
	    }
	}
	else {
	    $manipulate=0;
	    $admin=0;
	}

	if (&rt::ui::cli::question_yes_no("Are you satisfied with your answers",0)) {
	    ($result,$message)=&rt::add_modify_queue_acl($queue_id, $user_id, $display, $manipulate, $admin, $current_user);
	    print "$message\n";
	}
	else {
	    print "User ACL modifications aborted\n";
	}
	
    }
    else {
	print "command line privilege parsing not yet implemented\n";
    }
    return(1);
}


sub cli_print_acl {
    my ($user_id, $queue_id) = @_;
    
    if (!&rt::is_a_queue($queue_id)){
	print "$queue_id: That queue does not exist. (You should never see this error)\n";
        return(0);
    }
   #print "Queue: $queue_id \n";
    if (&rt::can_display_queue($queue_id,$user_id)){
	print " Display";
    }
    else {
	print "        ";
    }
    if (&rt::can_manipulate_queue($queue_id,$user_id)){
	print "   Manipulate";
    }
    else {
	print "             ";
    }
    if (&rt::can_admin_queue($queue_id,$user_id)){
	print "   Admin\n";
    }
    else {
	print "         \n";
    }
    
    
}
sub cli_help_rt_admin{
    print "
user
      -create <user> create a RT account for <user>
      -modify <user> modify user info for <user>
      -delete <user> delete <user>'s RT account
      -getpwent <password> <admin> [<users>]  Creates user(s) from the
                    data in the /etc/passwd file. If no users are 
		    specified, ALL of /etc/passwd will be processed.

acl <user> <queue> set user <user>'s privileges for queue <queue>
                   if <queue> is ommitted, list user <user>'s ACLs

queue -create <queue>              create a new queue called <queue>
      -modify <queue>              modify <queue>'s settings
      -delete <queue>              completely wipe out <queue>
      -area add <area> <queue>     adds <area> to <queue>
      -area delete <area> <queue>  remove <area> from <queue>
";
}
1;
