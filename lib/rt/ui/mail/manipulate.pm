# $Header$
package rt::ui::mail::manipulate;

sub activate {
  
  #uncomment for a debugging version
  $debug = 0;
  
  $area = ""; #TODO: we may want to be able to set the area on the command line
  


  if ($ARGV[0] eq '--help') {
    print "

RT Mailgate works in two modes. 'Traditional' and 'Extended Sytax'

Traditional mode:

rt-mailgate <queue> <action>

<queue> is the full name of one of your RT queues. if it's got any 
spaces in it, it should be quoted.

<action> is one of 'comment', 'correspond' and 'action'

comment means that any mail sent through this gateway will be logged 
as private comments

correspond means that any mail sent through this gateway will be 
treateded as mail to or from the requestor. If you want tickets to be 
autocreated through this interface, correspond is the right choice.

action is for rt's mail action mode.


Extended syntax mode can be invoked by using the flag --extended-syntax as 
the _first_ argument passed to rt-mailgate. after that, you can order 
the arguments however you want.

-v or --verbose will print a single line to STDOUT about what was done to 
incoming mail if the alias is a comment or correspond alias.

-t or --ticketid will print the integer ticket id to STDOUT if the alias is a 
comment or correspond alias.

-d or --debug will give you some running commentary about what rt-mailgate is 
doing

-a <action> or --action <action> determines whether this is a comment, 
correspond or action alias (see above)

-q <queue> or --queue <queue> will instruct rt-mailgate that incoming new 
tickets should be put in queue <queue> (only makes sense on correspond 
aliases)

-r <area> or --area <area> determines what area to plunk this ticket into 
if it's a new ticket (only makes sense on correspond aliases)

";
    exit(0);
  }
  
  if ($ARGV[0] eq '--extended-syntax') {
    while (my $flag = shift @ARGV) {
      if (($flag eq '-v') or ($flag eq '--verbose')) {
	$verbose = 1;
      }
      if (($flag eq '-t') or ($flag eq '--ticketid')) {
	$return_tid = 1;
      }

      if (($flag eq '-d') or ($flag eq '--debug')) {
	$debug = 1;
      }

      if (($flag eq '-q') or ($flag eq '--queue')) {
	$in_queue = shift @ARGV;
      } 
      if (($flag eq '-a') or ($flag eq '--action')) {
	$in_action = shift @ARGV;
      } 
      if (($flag eq '-r') or ($flag eq '--area')) {
	$area = shift @ARGV;
      }    

    }
  }
  else {
    $in_queue=$ARGV[0];
    $in_action=$ARGV[1];
  }
  
  if (!$in_queue){
    $in_queue="general";
  }
  if (!$in_action){
    $in_action='correspond';
  }

  $content=&read_mail_from_stdin();
    
  &parse_headers($content);
  
  #get all that rt stuff squared away.
  &rt::initialize($current_user);
  
  #take all those actions
  $content=&parse_actions($current_user,$serial_num, $content);
  
  #flip the content around.
  &munge_content($content);
  
  if ($in_action eq 'actions') {
    exit(0);
  }
  elsif ($in_action eq 'correspond') {
      
      #If we're creating a new ticket
      if (!$serial_num) {
	  ($serial_num,$transaction_num, $message) = &rt::add_new_request(
                       $in_queue, $area, $current_user,'','', $subject,
                       $rt::queues{"$in_queue"}{'default_final_prio'},
	        	       $rt::queues{"$in_queue"}{'default_prio'},'open',
		               $rt::time, 0, 0, $content, $current_user, 
                       $squelch_replies);
	  
	  # If $return_tid = 1, just return the serial number of the ticket
	  # created
	  print "$serial_num\n" if ($return_tid == 1);
	  print "Ticket='$serial_num' Queue='$in_queue' Area='$area'".
	    " Sender='$current_user' Precedence='$precedence'\n" if ($verbose);
      }
      
      #If we're corresponding on an existing ticket
      else {
	  #If the user isn't a requestor, notify the requestor
	  $notify_requestor = (&rt::is_not_a_requestor($current_user, 
						       $serial_num));
	  

	  if ($squelch_replies) {
	      $notify_requestor = 0;
	  }

	  #Add the correspondence, being careful to force the ticket to open.
	  ($transaction_num,$message)=
	    &rt::add_correspondence($serial_num,$content, "$subject","" ,"" ,
				    "open", $notify_requestor, $current_user);
	  
	  
	  # If $return_tid = 1, just return the serial number of the ticket
	  # corresponded on
	  print "$serial_num\n" if ($return_tid == 1);
	  
	  # If it's verbose, load the ticket and examine it and generate the
	  # verbose response
	  
	  if ($verbose) {
	      &rt::req_in($serial_num,'_rt_system');
	      print "Ticket='$serial_num' Queue='". 
		$rt::req[$serial_num]{'queue'}.
		  "' Area='".$rt::req[$serial_num]{'area'}.
		    "' Sender='$current_user' Precedence='$precedence'\n" ;
	  }
	  
      }
  }
  elsif ($in_action eq 'comment') {
      if (!$serial_num) {
	  $edited_content = "
You did not specify a ticket number for these comments. Please resubmit them
with a ticket number.  Your comments appear below.

$content.
";
	  
	  unless ($squelch_replies) {
	      &rt::template_mail('error', '_rt_system', "$current_user", '', 
				 '', "", "$transaction_num",
				 "RT Error: $subject", 
				 "$current_user", 
				 "$edited_content");
	  }
	  

	  print "0\n" if ($return_tid == 1);
	  # Verbose will return a ticket Id of 0 which means "you're screwed"
	  print "Ticket='$serial_num' Queue='$in_queue' Area='$area'".
	    " Sender='$current_user' Precedence='$precedence'\n" if ($verbose);
	  exit(0);
      }
      
      
      if ($debug) {print "Now commenting on request \# $serial_num\n";}
      ($transaction_num,$message)=
	&rt::comment($serial_num,$content,"$subject","" ,"" ,$current_user);
      print "$serial_num\n" if ($return_tid == 1);
  }
  
  # if there's been an error, mail the user with the message
  if ($transaction_num == 0) {
      $edited_content = "There has been an error with your request:\n$message\n\nYour message is reproduced below:\n\n$content\n";

      unless ($squelch_replies) {
	  &rt::template_mail('error', '_rt_system', "$current_user", '', '', 
			     "$serial_num", "$transaction_num", 
			     "RT Error: $subject", "$current_user", 
			     "$edited_content");
      }
  }
  

  # if we've got actions to deal with. this happens unless someone screwed 
  #up badly above
  
  if ($response) {
      &send_rt_response($current_user);
  }
}

# {{{ sub read_mail_from_stdin
sub read_mail_from_stdin {
    local $content;
    while (<STDIN>){
	$content .= $_;
    }
    return ($content);
}
# }}}

# {{{ sub munge_content
sub munge_content {
    $content =~ s/^(From )/\>$1/mg;
    ($headers, $body) = split (/\n\n/, $content, 2);
    $content = $body . "\n\n--- Headers Follow ---\n\n" . $headers;
    
}
# }}}

# {{{ sub parse_headers
sub parse_headers {
    my ($content) ="@_";
    
    $precedence = 'first-class';
    
    ($headers, $body) = split (/\n\n/, $content, 2);
    
    foreach $line (split (/\n(?!\s)/,$headers)) {
	
	if ($line =~/^X-RT-Loop-Prevention: $rt::rtname/g) {
	    die ("RT has recieved mail from itself. Goodnight.");
	}
	
	elsif (($line =~ /^Subject:(.*)\[$rt::rtname\s*\#(\d+)\]\s*(.*)/i) and 
	       (!$subject)){
	    $serial_num=$2;
	    &rt::req_in($serial_num,$current_user);
	    $subject=$3;
	    $subject =~ s/\($rt::req[$serial_num]{'queue_id'}\)//i;
	}
	
	elsif (($line =~ /^Subject: (.*)/s) and (!$subject)){
	    $subject=$1;
	}
	
	elsif (($line =~ /^Reply-To: (.*)/s)) {
	    $replyto = $1;
	}
	
	elsif ($line =~ /^From: (.*)/s) {
	    $from = $1;
	}
	
	elsif ($line =~ /^Sender: (.*)/s){
	    $sender = $1;
	    
	}
	elsif ($line =~ /^Date: (.*)/s) {
	    $time_in_text = $1;
	}
	elsif ($line =~ /^Precedence: (.*)/s) {
	    $precedence = $1;
	}
	
    }
    
    $current_user = $replyto || $from || $sender;
    
    
    #Get the real name of the current user from the replyto/from/sender/etc
    
    $name_temp  = $current_user;

    if ($current_user =~/(\S*\@\S*)/) {
	$current_user =$1;
    }
    if ($current_user =~/<(\S*\@\S*)>/){
	$current_user =$1;
    }
    if ($current_user =~/<(\S*)>/){
	$current_user =$1;
    }
    
    $rt::users{"$current_user"}{'real_name'} = $name_temp;
    $rt::users{"$current_user"}{'real_name'} =~ s/(\S*)\@(\S*)//;
    $rt::users{"$current_user"}{'real_name'} =~ s/<(.*?)>//;
    
    if (!$subject) {
	$subject = "[No Subject Given]";
    }
    
    $subject =~ s/\s\s/ /g;
    
    if (($precedence =~ /^junk/i) or 
	($precedence =~ /^bulk/)) {
	$squelch_replies = 1;
    }
    else {
	$squelch_replies = 0;
    }

    if (($current_user =~ /^postmaster/i) or 
	($current_user =~ /^mailer-daemon/i)) {
	
	#TODO perform a magic warning here..(auto-submit a req?)
	exit(0);
    }
    
    elsif ($current_user =~/^$rt::mail_alias/g) {
	#TODO perform a magic warning here..(auto-submit a req?)
	#if we don't do this, rt mail will loop. which is VERY VERY BAD
	if ($debug) {
	    print "This mail came from RT. good night.\n";
	}
	exit(0);
    }
    
}
# }}}

# {{{ sub parse_actions
sub parse_actions {
  my ($real_current_user) = shift;
  
  my ($real_serial_num) = shift;
  
  my ($body) = shift;
  my ($trans, $message, $serial_num, $line, $original_line, $current_user, 
      $authenticated_user);
  
  foreach $line (split(/\n/,$body)) {
    my $count, @arg;
    $original_line = $line;
    
    
    #if it's a line with an rt action, deal with it.
    if ($line =~ /^\%rt (.*)/i) {
      $line = $1;
      
      if ($debug) {print "in the foreach action command loop; line = $line\n";}
      
      
      while ($line) {
        
	#this replaces a silly loop.
	#@arg=();
        
	#parse for doublequoted strings
        if ($line =~ /^\"(.?)\"\s?(.*)/) {
          $arg[$count++]=$1;
          $line = $2;
        }
        
	#parse singlequoted strings
        elsif ($line =~ /^\'(.?)\'\s?(.*)/) {
          $arg[$count++]=$1;
          
          $line = $2;
      }
        
	#parse for delineation w/ whitespace
        elsif ($line =~ s/^(\S*)\s(.*)/$2/) {
          $arg[$count++]=$1;
	  #			$line = $2;
	  #			if ($debug) {print "space deliniated: $arg[($count-1)]  is arg line is $line\n.";}
        }
        else {
          $arg[$count++] = $line;
          $line = "";
        }
      }
      
      
      #deal with USER commands
      if ($arg[0] =~ /^user/i) {
        $username = $arg[1];
        $message = "Username $username noticed.";
        
      }
      
      
      #deal with HELP commands
      if ($arg[0] =~ /help/i) {
        $message = "
        Mail Mode for RT $rt::rtversion by jesse vincent <jesse\@fsck.com>
        Command Summary
        
        RT commands are prefixed by %RT and are case insensitive.  RTMail evaluates
        statements in the order you enter them.
        
        %RT USER <username>
        will tell RT who you really are.
        
        %RT PASS <password>
        will authenticate you to RT, provided you've already executed a USER
        command.
        
        %RT TAKE <num>
        will take request <num>
        
        %RT UNTAKE <num>
        will give away request <num>, provided you own it.
        
        %RT STEAL <num>
        will take request <num>, provided someone else owns it.
        
        %RT RESOLVE <num>
        will resolve request <num>.
        
        %RT OPEN <num>
        will open request <num>.
        
        %RT STALL <num>
        will stall request <num>.
        
        %RT KILL <num> yes
        will kill request <num>.
        
        %RT MERGE <num1> [INTO] <num2>
        will merge request <num2> into request <num2>.
        
        %RT SET owner <num> <user>
        will set request <num>'s owner to <user>.
        
        %RT SET queue <num> <queue>
        will set request <num>'s queue to <queue>.
        
        %RT SET area <num> <area>
        will set request <num>'s area to <aera>.
        
        %RT SET due <num> <date>
        will set request <num>'s due date to <date>. <date> should probably
        be in the form MM/DD/YY.
        
        %RT SET prio <num> <prio>
        will set request <num>'s priority to <prio>.
        
        %RT SET final <num> <prio>
        will set request <num>'s final priority to <prio>.
        
        %RT SET status <num> (open|closed|stalled|dead yes)
        will set request <num>'s status to (open|closed|stalled|dead).
        
        %RT SET user <num> <email>
        will set request <num>'s requestor(s) to the comma-delineated,
        quote-enclosed string <email>.";
      }
      
      #deal with PASS commands
      if ($arg[0] =~ /^pass/i) {
        $password = $arg[1];
        
        if (!$username) {      # If none is supplied, try the sender
          $username = (split(/\@/, $real_current_user))[0];
        }
        if ($username) {
	    #check the authentication state
	    if (!(&rt::is_password($username, $password))) {
		if ($debug) {print "$password is not $username\'s password.\n (1:$arg[0] 2:$arg[1] 3:$arg[2]";}
		$message = "Bad Login for $username.";
		$trans = 0;
	    }
	  else {
	      $message = "You are now authenticated as $username.";
	    $authenticated_user = $username;
	  }
	}
      }
      
      
      #deal with STALL commands
      
      if ($arg[0] =~ /stall/i) {
	$serial_num=$arg[1];
	($trans,  $message)=&rt::stall($serial_num, $authenticated_user);
      }
      
      #deal with OPEN commands
        
      elsif ($arg[0] =~ /open/i) {
	$serial_num=$arg[1];
	($trans,  $message)=&rt::open($serial_num, $authenticated_user);
      }
      
      #deal with RESOLV commands
      
      elsif ($arg[0] =~ /resolv/i)  {
	
	#		$serial_num=$arg[1];
	#		($trans,  $message)=&rt::resolve($serial_num, $authenticated_user);
	# batch them up and do them at the very end.
	if (!$arg[1]) { $arg[1] = $real_serial_num; }
	@resolve_nums = (@resolve_nums,$arg[1]);
       	$message = "Batching resolve of $resolve_nums[$#resolve_nums].";

	}	
      
      
        
      #deal with KILL commands
      elsif (($arg[0] =~ /kill/i) and ($arg[2] =~ /^yes/)){
	$serial_num=int($arg[1]);
	($trans,  $message)=&rt::kill($serial_num, $authenticated_user);
      }
      
      #deal with merge commands
      elsif ($arg[0] =~ /merg/i){
	$serial_num=int($arg[1]);
	if ($arg[2] =~ /in/i) {
	  $into = $arg[3];
	}
	else {
	  $into = $arg[2];
          }
	($trans,  $message)=&rt::merge($serial_num, $into, $authenticated_user);
      }
      
      
      
      #deal with take commands
        
      elsif ($arg[0] =~ /^take/i) {
	$serial_num=$arg[1];
	($trans,  $message)=&rt::take($serial_num, $authenticated_user);
      }
      
      
      #deal with untake commands
      
        elsif ($arg[0] =~ /^untake/i) {
          $serial_num=$arg[1];
          ($trans,  $message)=&rt::untake($serial_num, $authenticated_user);
        }
      
      
      #deal with steal commands
      
      elsif ($arg[0] =~ /steal/i) {
	$serial_num=$arg[1];
	($trans,  $message)=&rt::steal($serial_num, $authenticated_user);
      }
        
      #deal with SET commands
      
      elsif ($arg[0] =~ /^set/i) {
	
	#deal w/ SET OWNER commands
	if ($arg[1] =~ /^own/) {
            $serial_num=int($arg[2]);
            $owner=$arg[3];
            ($trans,  $message)=&rt::give($serial_num, $owner, $authenticated_user);
            
          }
	
	# deal with SET USER commands
	if (($arg[1] =~ /^user/) or ($arg[1] =~ /^requestor/)) {
	  $serial_num=int($arg[2]);
	  $new_user=$arg[3];
	  ($trans,  $message)=&rt::change_requestors($serial_num, $new_user, $authenticated_user);
	}
	# deal with SET SUBJECT commands
	if ($arg[1] =~ /^sub/) {
	  $serial_num=int($arg[2]);
	  $subject=$arg[3];
	  ($trans,  $message)=&rt::change_subject ($serial_num, $subject, $authenticated_user);
	}
	
	#deal with SET QUEUE commands
	if ($arg[1] =~ /^queue/) {
	  $serial_num=int($arg[2]);
            $queue=$arg[3];
	  ($trans,  $message)=&rt::change_queue ($serial_num, $queue, $authenticated_user);
	}
	
	
	# deal with SET AREA commands
	if ($arg[1] =~ /^area/) {
	  $serial_num=int($arg[2]);
	  $area=$arg[3];
            ($trans,  $message)=&rt::change_area ($serial_num, $area, $authenticated_user);
	}
	
	#deal with SET PRIO commands
	
	if ($arg[1] =~ /^prio/) {
            $serial_num=int($arg[2]);
            $prio=$arg[3];
            ($trans,  $message)=&rt::change_priority ($serial_num, $prio, $authenticated_user);
          }
	
	
	#deal with SET FINAL commands
	if ($arg[1] =~ /^final/) {
	  $serial_num=int($arg[2]);
	  $prio=$arg[3];
	  ($trans,  $message)=&rt::change_final_priority ($serial_num, $prio, $authenticated_user);
	}
	
	#deal with SET DUE commands
	
	if ($arg[1] =~ /due/) {
	  $serial_num=int($arg[2]);
	  $due_string=$arg[3];
	  
	  $due_date = &rt::date_parse($due_string);
	  
	  ($trans,$message)=&rt::change_date_due($serial_num, $date_due, $authenticated_user);
	}
	
	#deal with SET STATUS commands
	
          if ($arg[1] =~ /^status/) {
            $serial_num=int($arg[2]);
            $status=$arg[3];
            $confirmation=$arg[4];
            
            
            
            if ($status =~ /stall/i) {
              ($trans,  $message)=&rt::stall($serial_num, $authenticated_user);
            }
            
            elsif ($status =~ /open/i) {
              ($trans,  $message)=&rt::open($serial_num, $authenticated_user);
            }
            
            elsif ($status =~ /resolv/i)  {
              ($trans,  $message)=&rt::resolve($serial_num, $authenticated_user);
            }
            
            elsif (($status =~ /dead/i) and ($confirmation =~ /^yes/)){
              ($trans,  $message)=&rt::kill($serial_num, $authenticated_user);
            }
          }
	
	
      }
      #quote the command, not returning the password
      
      if ($arg[0] =~ /^pass/i) {
	$response .= "> $arg[0] ***** ";
      }
      
      else {
	$response .= "> " . $original_line . "\n";
        }
      #print responses


      if ($message) {
	if ($debug) {print "$message ($trans)\n";}
	$response .= "RT: $message ";
	if ($trans) {$response .= "($trans)";}
	$response .="\n";
      }
    } #end of the if (line starts w/ %rt
    
    else {
      #if the line doesn't start with %rt, don't discard it.
      # $response .= $original_line . "\n";
      $parsed_body .= $original_line . "\n";
    }
    
  } #end of the foreach
  if ($#resolve_nums > -1) {
      print "RT: Resolving $#resolve_nums tickets\n" if ($debug);
      foreach $ticket (@resolve_nums) {     
	  print "Resolving $ticket\n" if ($debug);
	  ($trans,  $message)=&rt::resolve($resolve_nums[$count], (split(/\@/, $authenticated_user))[0]);
	  $response .= "RT: $message ($trans)\n";
      }
  }  
  return ($parsed_body);
}
# }}}

# {{{ sub send_rt_response

sub send_rt_response {
    my($user) = shift;
    
    print "$response\n" if $debug;
    if ($response) {
	unless ($squelch_replies) {
	    ($message)=&rt::template_mail ('act_response','_rt_system',
					   $user,"","",0,0,
					   "RT Actions Complete",
					   "$user","$response");
	}
    }
    print "$message\n" if $debug;
    
  }

# }}}

1;
