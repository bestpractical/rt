# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#
package rt::ui::cli::admin;

# {{{ sub activate 
sub activate  {
  my ($current_user);
  
  require RT::CurrentUser;  
  ($current_user,undef)=getpwuid($<);
  $CurrentUser = new RT::CurrentUser($current_user);
  if (!$CurrentUser) {
    print "You have no RT access.\n";
    return();
  }
  
  &ParseArgs();
  return(0);
  

}
# }}}

# {{{ sub ParseArgs 

sub ParseArgs  {

  for ($i=0;$i<=$#ARGV;$i++) {
    if ($ARGV[$i] =~ 'q') {
      $action=$ARGV[++$i];
      
      if ($action eq "-list") {
	&cli_list_queues();
      }
      
      if ($action eq "-create") {
	$queue_id=$ARGV[++$i];
	if (!$queue_id) {
	  print "You must specify a queue.\n";
	  return(0);
	}
	&cli_create_queue($queue_id);
      }
      
      elsif ($action eq "-modify") {
	$queue_id=$ARGV[++$i];
	if (!$queue_id) {
	  print "You must specify a queue.\n";
	  return(0);
	}
	&cli_modify_queue($queue_id);
      }
      
      elsif ( ($ARGV[$i] =~ "-cc") ||	($ARGV[$i] =~ "-admincc") ) {
	my $type = $ARGV[$i];
	my $queue_id = $ARGV[++$i];
	my $arg = $ARGV[++$i];
	my $Queue = &LoadQueue($queue_id);
	
	if ($type eq '-cc') {
	  $watcher_type = "Cc";
	}
	elsif ($type eq '-admincc') {
	  $watcher_type = "AdminCc";
	}
	
	else {
	  #we've just covered all our bases
	  die "This else never reached. Ever. or you broke the cli\n";
	}
	
	if ($arg =~ /^(.)(.*)/) {
	  $action = $1;
	  $email = $2;
	}
	if ($action eq "+") {
	  $Message .= $Queue->AddWatcher(Email => "$email",
					 Type => "$watcher_type");
	  
	}
	elsif ($action eq "-") {
	  $Message .= $Queue->DeleteWatcher("$email");
	}
	else {
	  $Message .= "$type expects an argument of the form +<email address> or -<email address>\n";
	}
      }
      
    }
    
    
    
    elsif ($action eq "-delete") {
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
	return(0);
      }
      &cli_acl_queue($queue_id);
    }	
    
    
    
    elsif ($ARGV[$i] =~ 'u') {
      require RT::User;
      
      $action=$ARGV[++$i];
      
    if ($action eq "-modify") {
      $user_id=$ARGV[++$i];
      if (!$user_id) {
	print "You must specify a user.\n";
	return(0);
	}
      &cli_modify_user($user_id);
    } 
    
    elsif  ($action eq "-create") {
      $user_id=$ARGV[++$i];
      if (!$user_id) {
	print "You must specify a user.\n";
	return(0);
      }
      &cli_create_user($user_id);
    } 
    
    elsif ($action eq "-getpwent") {
      $passwd=$ARGV[++$i];
      $admin=$ARGV[++$i];
      
      print "Getpwent is not currently supported. A patch would be appreciated\n";
      exit(0);
      
      if (!defined($admin)) {
	print "Usage: user -getpwent <password> <administrator> [<users>...]\n";
	exit(0);
      }
      if (defined($ARGV[$i++])) {
	while (my $login=$ARGV[++$i]) {
	  ($login, $domain) = split('@', $login);
	  $domain || ($domain = $host);
	  &add_pwent($domain, getpwnam($login), $CurrentUser);		  
	}
      } else { 
	#Sometimes it really had been useful beeing able to combine while with
	  #else..  
	
	&setpwent;
	while (&add_pwent($host, getpwent, $CurrentUser))
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

# }}}

# Add/Modify users by pwent:
# This code by tobix...
# {{{ sub add_pwent 
sub add_pwent  {
  if (!@_) {return undef;}
  my ($domain, $name,$pass,$uid,$gid,
      $quota,$comment,$gcos,$dir,$shell,$whoami) = @_;
  my ($realname,$office,$phone)=split(/,/,$gcos);
  
  #TODO replace this with an object call  
  #  my ($result, $msg)=&rt::add_modify_user_info ($name,$realname,$passwd,"$name\@$domain",$phone,$office,$comment,
  #						($name eq $whoami ? 1 : $admin),$whoami);
  
  # Report to STDOUT:
  print "$msg\n" if ($msg);
  
  return $result;
}
# }}}

# {{{ sub cli_acl_queue 
sub cli_acl_queue  {
    my ($queue_id)=@_;

    print "ACLs for queue \"$queue_id\"\n";
    while (($user_id,$value)= each %rt::users) {
	print "$user_id:";
	&cli_print_acl($user_id,$queue_id);
    }
}
# }}}

# {{{ sub cli_modify_user
sub cli_modify_user {
  my $user_id = shift;
  my $User;
  
  $User = new RT::User($CurrentUser);
   if (!$User->Load($user_id)){
     print "That user does not exist.\n";
     return(0);
   }
  
  &cli_modify_user_helper($User);
}
# }}} 

# {{{ sub cli_modify_user_helper 
sub cli_modify_user_helper  {
  my $User = shift;


   my ($email, $real_name, $password, $phone, $office, $admin_rt, $comments, $message);
   
   if (($CurrentUser->Id eq $User->Id) or 
       ($CurrentUser->IsAdministrator)) {
     
     $email=&rt::ui::cli::question_string("User's email alias (ex: somebody\@somewhere.com)" ,
					  $User->EmailAddress);
     $real_name=&rt::ui::cli::question_string("Real Name",
					      $User->RealName);
     
     
     $password=&rt::ui::cli::question_string("RT Password (will echo)",
					     undef);
     $homephone=&rt::ui::cli::question_string("Home Phone Number",
					      $User->HomePhone);
     $workphone=&rt::ui::cli::question_string("Work Phone Number",
					      $User->WorkPhone);
     

     
     $address1=&rt::ui::cli::question_string("Address Line 1",
					 $User->Address1);
     $address2=&rt::ui::cli::question_string("Address Line 2",
					 $User->Address2);
    
    $city=&rt::ui::cli::question_string("City",
					 $User->City);
    
    $state=&rt::ui::cli::question_string("State",
				      $User->State);
    
    $zip=&rt::ui::cli::question_string("ZIP/Postal Code",
				      $User->Zip);
    $country=&rt::ui::cli::question_string("Country",
					 $User->Country);
    
      if ($CurrentUser->IsAdministrator) {
   
        $gecos=&rt::ui::cli::question_string("UNIX Username",
					      $User->Gecos);
	$externalid=&rt::ui::cli::question_string("External ID",
						 $User->ExternalId);	
	$admin_rt=&rt::ui::cli::question_yes_no("Is this user the RT administrator",
						$User->IsAdministrator);
	$comments=&rt::ui::cli::question_string("Misc info about this user",
						$User->Comments);
      }
     
     if(&rt::ui::cli::question_yes_no("Are you satisfied with your answers",0)){
       $message = $User->SetEmailAddress($email);
       $message .= $User->SetRealName($real_name);
       $message .= $User->SetPassword($password);
       $message .= $User->SetHomePhone($homephone);
       $message .= $User->SetWorkPhone($workphone);
       $message .= $User->SetAddress1($address1);
       $message .= $User->SetAddress2($address2);
       $message .= $User->SetCity($city);
       $message .= $User->SetState($state);
       $message .= $User->SetZip($zip);
       $message .= $User->SetCountry($country);
       
       if ($CurrentUser->IsAdministrator()) {
	 $message .= $User->SetExternalId($externalid);
	 $message .= $User->SetComments($comments);
	 $message .= $User->SetIsAdministrator($admin_rt);
	 $message .= $User->SetGecos($gecos);
       }

      print "$message\n";
    }
    else {
      print "User modifications aborted.\n";
    }
  }
  else {
    print "You do not have privileges to modify that user's info\n";
  }
}
# }}}
 
# {{{ sub cli_create_user 
sub cli_create_user  {
  my $user_id = shift;
  my $User = RT::User->new($CurrentUser);
  (my $result, $message)= $User->Create(UserId => $user_id);
  if (!$result) {
    print $message;
    return()
  }
  
  #TODO. this is wasteful. we should just be passing around a queue object
  &cli_modify_user_helper($User);
}
# }}}

# {{{ sub cli_create_queue 
sub cli_create_queue  {
  my $queue_id = shift;

  use RT::Queue;
  my $Queue = new RT::Queue($CurrentUser);
  $Queue->Create($queue_id);
  #TODO. this is wasteful. we should just be passing around a queue object
  &cli_modify_queue_helper($Queue);
}
# }}}

# {{{ sub cli_modify_queue 
sub cli_modify_queue  {
  my $queue_id = shift;
  my $Queue = &LoadQueue($queue_id);
  &cli_modify_queue_helper($Queue);
}
# }}}

# {{{ sub cli_modify_queue_helper 
sub cli_modify_queue_helper  {
  my $Queue = shift;
  my ($mail_alias, $m_owner_trans, $m_members_trans, $m_user_trans, $m_members_correspond, 
      $m_user_create, $m_members_comment, $allow_user_create,$default_prio, 
 	$default_final_prio, $comment_alias);
  
  
  $mail_alias=&rt::ui::cli::question_string("Queue email alias (ex: support\@somewhere.com)" , 
					    $Queue->CorrespondAddress);
  $comment_alias=&rt::ui::cli::question_string("Queue comments alias (ex: support\@somewhere.com)" ,
					       $Queue->CommentAddress);
  
  $m_owner_trans=&rt::ui::cli::question_yes_no("Mail request owner on transaction",
					       $Queue->MailOwnerOnTransaction);
  
  $m_members_trans=&rt::ui::cli::question_yes_no("Mail queue members on transaction",
						 $Queue->MailMembersOnTransaction);
  $m_user_trans=&rt::ui::cli::question_yes_no("Mail requestors on transaction",
					      $Queue->MailRequestorOnTransaction);
  
  $m_user_create=&rt::ui::cli::question_yes_no("Autoreply to requestor on creation",
					       $Queue->MailRequestorOnCreation);
  $m_members_correspond=&rt::ui::cli::question_yes_no("Mail correspondence to queue members",
						      $Queue->MailMembersOnCorrespondence);
  
  $m_members_comment=&rt::ui::cli::question_yes_no("Mail queue members on comment",
						   $Queue->MailMembersOnComment);
  $allow_user_create=&rt::ui::cli::question_yes_no("Allow non-queue members to create requests",
						   $Queue->PermitNonmemberCreate);
  $default_prio=&rt::ui::cli::question_int("Default request priority (1-100)",
					   $Queue->InitialPriority);
  $default_final_prio=&rt::ui::cli::question_int("Default final request priority (1-100)",
						 $Queue->FinalPriority);
  
  if(&rt::ui::cli::question_yes_no("Are you satisfied with your answers",0)){
    $message = $Queue->SetCorrespondAddress($mail_alias);
    $message .= $Queue->SetCommentAddress($comment_alias);
    $message .= $Queue->SetMailOwnerOnTransaction($m_owner_trans);
    $message .= $Queue->SetMailMembersOnTransaction($m_members_trans);
    $message .= $Queue->SetMailRequestorOnTransaction($m_user_trans);
    $message .= $Queue->SetMailRequestorOnCreation($m_user_create);
    $message .= $Queue->SetMailMembersOnCorrespondence($m_members_correspond);
    $message .= $Queue->SetMailMembersOnComment($m_members_comment);
    $message .= $Queue->SetPermitNonmemberCreate($allow_user_create);
    $message .= $Queue->SetInitialPriority($default_prio);
    $message .= $Queue->SetFinalPriority($default_final_prio);
    print "$message\n";
  }
  else {
    print "Queue modifications aborted.\n";
  }
}
# }}}

# {{{ sub cli_delete_queue 
sub cli_delete_queue  {
  my  $queue_id = shift;
  # this function needs to ask about moving all requests into some other queue
    if(&rt::ui::cli::question_yes_no("Really DELETE queue $queue_id",0)){
      my $Queue = new RT::Queue($CurrentUser);
      $Queue->Load($queue_id);
      $message = $Queue->Delete();
      print "$message\n";
    }
  else {
    print "Queue deletion aborted.\n";
  }
}
# }}}

# {{{ sub cli_delete_user 
sub cli_delete_user  {
  my  $user_id = shift;
  if(&rt::ui::cli::question_yes_no("Really DELETE user $user_id",0)){
    my $User = new RT::User($CurrentUser);
    $User->Load($user_id);
    $message = $User->Delete();
    print "$message\n";
  }
  else {
    print "User deletion aborted.\n";
  }
}
# }}}

# {{{ sub cli_user_acl 
sub cli_user_acl  {
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
	    ($result,$message)=&rt::add_modify_queue_acl($queue_id, $user_id, $display, $manipulate, $admin, $CurrentUser);
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
# }}}

# {{{ sub cli_list_queues 
sub cli_list_queues  {
  use RT::Queues;
  my ($Queues, $Queue);
  $Queues = new RT::Queues($CurrentUser);
  $Queues->Limit (FIELD=> 'id',
		  OPERATOR => '>',
		  VALUE => '0');
  while ($Queue = $Queues->Next) {
    print $Queue->QueueId,"\t", $Queue->CorrespondAddress, "\t", $Queue->CommentAddress,"\n"; 
  }
}
# }}}

# {{{ sub cli_print_acl 
sub cli_print_acl  {
  my  $user_id =  shift;
  my  $queue_id  = shift;
  
  my $ACE = new RT::ACE($CurrentUser);
  
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
# }}}

# {{{ sub cli_help_rt_admin
sub cli_help_rt_admin {
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
# }}}

# {{{ sub LoadQueue 
sub LoadQueue {
  my $queue_id = shift;

  my ($Queue);
  # get a new queue object and fill it.
  use RT::Queue;
  $Queue = new RT::Queue($CurrentUser);
  $Queue->Load($queue_id) || die "Couldn't load the queue called $queue_id";
  return ($Queue);
}
# }}}
1;
