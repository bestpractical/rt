# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#
package rt::ui::cli::admin;
use RT::User;
use RT::Queue;


# {{{ sub activate 
sub activate  {
  my ($current_user);
  
  use RT::CurrentUser;  
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
	if ($ARGV[$i] =~ /listacl/i) {
		my $type = $ARGV[++$i];
		if ($type =~ /us/i) {
			my $user = $ARGV[++$i];
			&UserACLList($user);
		}
		elsif ($type =~ /q/i) {
			my $queue = $ARGV[++$i];
			&QueueACLList($queue);
		}
	}
	
    elsif ($ARGV[$i] =~ 'q') {
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
     
      if ($action =~ /-disable/) {
	my $userid = $ARGV[++$i];
	&DisableUser($userid);
      }
      if ($action =~ /-enable/) {
	my $userid = $ARGV[++$i];
	&EnableUser($userid);
	}
  	
 
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
    
    elsif ($action eq "-delete")	{
      $user_id=$ARGV[++$i];
      if (!$user_id) {
	print "You must specify a user.\n";
	exit(0);
      }
      
      &cli_delete_user($user_id);
    }	
    
    }
  
    else{
      &cli_help_rt_admin();
      exit(0);
    }
  }
}

# }}}

# {{{ sub DisableUser

=head2 DisableUser

This routine takes a userid as its argument and tries to disable it.
If the user's already disabled, it tells the user. If it's not,
it checks that the currentuser can modify user records. if so, it
does what it needs

=cut

sub DisableUser {
	my $userid = shift;
        use RT::User;
	my $User = new RT::User($CurrentUser);
	
	#TODO: Error check the load
	my $res = $User->Load($userid);	
	if (!$res) {
		print "Couldn't load user $userid\n";
		exit(-1);
	}
	unless ($CurrentUser->HasSystemRight('AdminUsers')) {
		print "Permission denied";
	}
	my $result = $User->Disable();
	if ($result) {
		print "User ".$User->UserId."(".$User->Id.") disabled.\n";
		return;
	}
	else {
		print "There's been an error\n";
	}
}

# }}}	
# {{{ sub EnableUser

=head2 EnableUser

This routine takes a userid as its argument and tries to enable it.

=cut

sub EnableUser {
        my $userid = shift;
        use RT::User;
        my $User = new RT::User($CurrentUser);

        #TODO: Error check the load
        my $res = $User->Load($userid);
        if (!$res) {
                print "Couldn't load user $userid\n";
                exit(-1);
        }
        unless ($CurrentUser->HasSystemRight('AdminUsers')) {
                print "Permission denied";
		exit(-1);
        }
        my $result = $User->Enable();
        if ($result) {
                print "User ".$User->UserId."(".$User->Id.") enabled.\n";
                return;
        }
        else {
                print "There's been an error\n";
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
# {{{ sub UserACLList
sub UserACLList {
	my $userid = shift;

                require RT::ACL;
                my $ACLObj = new RT::ACL($CurrentUser);


	# If they're looking for rights that apply to all users.
	if ($userid eq '-global') {
		$ACLObj->LimitPrincipalsToUser(0);
	}
	else {
		my $UserObj = new RT::User($CurrentUser);
		$UserObj->Load($userid);
		$ACLObj->LimitPrincipalsToUser($UserObj->Id());
	}	
	while (my $ACEObj = $ACLObj->Next()) {
		print $ACEObj->Scope . "/".$ACEObj->AppliesTo . ": ".$ACEObj->Right."\n";
	}
}

# }}}
# {{{ sub QueueACLList
sub QueueACLList {
        my $queueid = shift;
	my ($ACLObj, $QueueObj, $ACEObj);
	# if they're looking for things that apply to 'all queues'
        if ($queueid eq '-global') {
                require RT::ACL;
                $ACLObj = new RT::ACL($CurrentUser);
		$ACLObj->LimitScopeToQueue(0);
        }
        else {
        	$QueueObj = new RT::Queue($CurrentUser);
       		$QueueObj->Load($queueid);
		$ACLObj =$QueueObj->ACL;	
	}
        while ($ACEObj = $ACLObj->Next()) {
                print $ACEObj->PrincipalType. " ".$ACEObj->PrincipalId . " ".
		      $ACEObj->Scope . "/".$ACEObj->AppliesTo . ": ".
		      $ACEObj->Right."\n";
        }
}

# }}}
# {{{ sub ACLAdd
sub ACLAdd {
  my $action = shift;
  my $princtype = shift;
  my $princid = shift;
  my $right = shift;
  my $scope = shift;
  my $object = shift;

  if ($action =~ /add/) {
    use RT::ACE;
    my $ACE = new RT::ACE($CurrentUser);
    $ACE->Create( PrincipalType => $princtype,
		  PrincipalId => $princid,
		  Right => $right,
		  Scope => $scope,
		  AppliesTo => $object);

  }

  elsif ($action =~ /del/) {
  
  }
  else {
    print "$action not a valid action\n";
    return();
  }
} 
# }}}
# {{{ sub cli_help_rt_admin
sub cli_help_rt_admin {
  print "
user	
      -enable <user>
      -disable <user>

	To implement:
      -create <user> create a RT account for <user>
      -modify <user> modify user info for <user>

listacl 
	-queue <queueid>/-global
	-user <userid>/-global



queue  to implement:
      -create <queue>              create a new queue called <queue>
      -modify <queue>              modify <queue>'s settings
      -delete <queue>              completely wipe out <queue>
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
  my $Status = $Queue->Load($queue_id);
  if (!$status) {
	$RT::Logger->debug( "Couldn\'t load the queue called $queue_id");
	exit (-1);
	}
  return ($Queue);
}
# }}}
1;
