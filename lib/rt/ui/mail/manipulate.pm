package rt::ui::mail::manipulate;

sub activate {

  #uncomment for a debugging version
  $debug = 0;
  
  $area = ""; #TODO: we may wamt to be able to set the area on the command line
  
  $content=&read_mail_from_stdin();
  $in_queue=$ARGV[0];
  $in_action=$ARGV[1];
  
  if (!$in_queue){
    $in_queue="general";
  }   
  if (!$in_action){
    $in_action='correspond';
  } 
  
  
  if ($debug) {print "Now at parse headers\n";}
  &parse_headers($content); 
  
  #get all that rt stuff squared away.
  if ($debug) {print "Now at rt::initialize\n";}
  &rt::initialize($current_user);
  
  #take all those actions
  
  if ($debug) {print "Now at &parse_actions\n";}
  
  $content=&parse_actions($current_user,$serial_num, $content);
  
  #flip the content around..we should just MIME the sucker instead
  if ($debug) { print "Now at &munge_content\n";}
  &munge_content($content);
  
  if ($in_action eq 'actions') {
    exit(0);
  }
  elsif ($in_action eq 'correspond') {
    if (!$serial_num) {
      #WE REALLY SHOULD PARSE THE TIME OUT OF THE DATE HEADER...BUT FOR NOW
      # THE CURRENT TIME IS GOOD ENOUGH
      if ($debug) { print "Adding a new transaction\n";}

      ($serial_num,$transaction_num, $message)=&rt::add_new_request($in_queue,$area,$current_user,'','',$subject,$queues{"$in_queue"}{'default_final_prio'},$queues{"$in_queue"}{'default_prio'},'open',$rt::time,0,0,$content,$current_user);

        
    }   
    else {
      ($transaction_num,$message)=&rt::add_correspondence($serial_num,$content,"$subject","" ,"" ,"open",1,$current_user);
      
    }
  }
  elsif ($in_action eq 'comment') {
    if ($debug) {print "Now commenting on request \# $serial_num\n";}
    ($transaction_num,$message)=&rt::comment($serial_num,$content,"$subject","" ,"" ,$current_user);
  }
  
  # if there's been an error, mail the user with the message
  if ($transaction_num == 0) {
    $edited_content = "There has been an error with your request:\n" . $message  . "\n\nYour message is reproduced below:\n\n".$content;
    if ($debug) {print "Dammit. the new $in_action didn't get added\n$edited_content";}
    &rt::template_mail('error', '_rt_system', "$current_user", '', '', "$serial_num", "$transaction_num", "RT Error: $subject", "$current_user", "$edited_content");
  }
  

  if ($response)
  {
     &send_rt_response($current_user);
  }

  
}
sub read_mail_from_stdin {
    local $content;
    while (<STDIN>){
	$content .= $_;
	    
	}
    return ($content);
}


sub munge_content {
    ($headers, $body) = split (/\n\n/, $content, 2);

    $content = $body . "\n\n--- Headers Follow ---\n\n" . $headers;

}

sub parse_headers {
    local ($content) ="@_";
    foreach $line (split (/\n/,$content)) {
	
	if (($line =~ /^Subject:(.*)\[$rt::rtname\s*\#(\d+)\]\s*(.*)/i) and (!$subject)){	
	    $serial_num=$2;
	    $subject=$3;

  
	    $subject =~ s/\($in_queue\)\s//i; 

	}
	elsif (($line =~ /^Subject: (.*)/) and (!$subject)){
	    $subject=$1;
	}
	
	


	
        $current_user = $1 if (($line =~ /^Reply-To: (.*)/));  

	$current_user = $1 if (($line =~ /^From: (.*)/) and (!$current_user));
	$current_user = $1 if (($line =~ /^Sender: (.*)/) and (!$current_user));
	
	
	$time_in_text = $1 if ($line =~/^Date: (.*)/);
	if ($current_user =~/(\S*\@\S*)/) {
	    $current_user =$1;
	}
	if ($current_user =~/<(\S*\@\S*)>/){
	    $current_user =$1;
	}
	if ($current_user =~/<(\S*)>/){
	    $current_user =$1;
	}
    }
    
    
    
    if (!$subject) {
	$subject = "[No Subject Given]";
    }
    
    
    $subject =~ s/\s\s/ /;
    #BUG: 
    #FIX ME 
    # WARNING
    # is i the right flag there?
    if (($current_user =~ /^postmaster/i) or ($current_user =~ /^mailer-daemon/i)) {

	#TODO perform a magic warning here..(auto-submit a req?)
	exit(0);
    }

   
    elsif ($current_user =~/^X-RT-Loop-Prevention: $rt::rtname/g) {

       #TODO perform a magic warning here..(auto-submit a req?)
       if ($debug) {
          print "This mail came from RT. gnite.\n";
       }
       exit(0);
    }

    
    elsif ($current_user =~/^$rt::mail_alias/g) {
	
	#TODO perform a magic warning here..(auto-submit a req?)
	#if we don't do this, rt mail will loop. which is VERY VERY BAD
	if ($debug) {
	print "This mail came from RT. gnite.\n";
	}
	exit(0);
    }

}


sub parse_actions {
    my ($real_current_user) = shift;

    my ($real_serial_num) = shift;

    my ($body) = shift;
    my ($trans, $message, $serial_num, $line, $original_line, $current_user);

    foreach $line (split(/\n/,$body)) {
	my $count;
	$original_line = $line;


	#if it's a line with an rt action, deal with it.
	if ($line =~ /^\%rt (.*)/i) {
	    $line = $1;

	    if ($debug) {print "in the foreach action command loop; line = $line\n";}
	    

		while ($line) {

                    foreach $count (0..$#arg)
                    {
                       $arg[$count]="";
                    }

		    #parse for doublequoted strings
		    if ($line =~ /^\"(.?)\"\s?(.*)/) {
			$arg[$count++]=$1;
			$line = $2;
		    }
		    
		    #parse singlequoted strings
		    elsif ($line =~ /^\'(.?)\'\s?(.*)/) {
			$arg[$count++]=$1;
	
			$line = $2;
#		if ($debug) {print "singlequote: $1 is arg $count\nline is $line\n.";}
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
			$current_user = $username;
		    }
		}
	    }

	    
	    #deal with STALL commands
	    
	    if ($arg[0] =~ /stall/i) {
		$serial_num=$arg[1];
		($trans,  $message)=&rt::stall($serial_num, $current_user);
		    }

	    #deal with OPEN commands
	    
	    elsif ($arg[0] =~ /open/i) {
		$serial_num=$arg[1];
		($trans,  $message)=&rt::open($serial_num, $current_user);
	    }



	    #deal with RESOLV commands

	    elsif ($arg[0] =~ /resolv/i)  {

#		$serial_num=$arg[1];
#		($trans,  $message)=&rt::resolve($serial_num, $current_user);
            #batch them up and do them at the very end.
                if (!$arg[1]) { $arg[1] = $real_serial_num; }
                if ($arg[1])
                {
                   if (!@resolve_nums)
                   {
                      $resolve_nums[$#resolve_nums++]=$arg[1];
                   }
                   else
                   {
                      $resolve_nums[$#resolve_nums]=$arg[1];
                   }
#                   $message = "Batching resolve of $resolve_nums[$#resolve_nums].";
                }
                else
                {
                   $message = "No ticket number found.";
                }

	    }
	    
	    
	    #deal with KILL commands
	    elsif (($arg[0] =~ /kill/i) and ($arg[2] =~ /^yes/)){
		$serial_num=int($arg[1]);
		($trans,  $message)=&rt::kill($serial_num, $current_user);
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
		($trans,  $message)=&rt::merge($serial_num, $into, $current_user);
	    }
	


	    #deal with take commands
	    
	    elsif ($arg[0] =~ /^take/i) {
		$serial_num=$arg[1];
		($trans,  $message)=&rt::take($serial_num, $current_user);
	    }
	    

	    #deal with untake commands
	    
	    elsif ($arg[0] =~ /^untake/i) {
		$serial_num=$arg[1];
		($trans,  $message)=&rt::untake($serial_num, $current_user);
	    }
	    


	    #deal with steal commands
	    
	    elsif ($arg[0] =~ /steal/i) {
		$serial_num=$arg[1];
		($trans,  $message)=&rt::steal($serial_num, $current_user);
	    }

	    #deal with SET commands

	    elsif ($arg[0] =~ /^set/i) {

		#deal w/ SET OWNER commands
		if ($arg[1] =~ /^own/) {
		    $serial_num=int($arg[2]);
		    $owner=$arg[3];
		    ($trans,  $message)=&rt::give($serial_num, $owner, $current_user);
		    
		}
		
		# deal with SET USER commands
		if (($arg[1] =~ /^user/) or ($arg[1] =~ /^requestor/)) {
		    $serial_num=int($arg[2]);
		    $new_user=$arg[3];
		    ($trans,  $message)=&rt::change_requestors($serial_num, $new_user, $current_user);
		}
		# deal with SET SUBJECT commands
		if ($arg[1] =~ /^sub/) {
		    $serial_num=int($arg[2]);
		    $subject=$arg[3];
		    ($trans,  $message)=&rt::change_subject ($serial_num, $subject, $current_user);
		}
		
		#deal with SET QUEUE commands
		if ($arg[1] =~ /^queue/) {
		    $serial_num=int($arg[2]);
		    $queue=$arg[3];
		    ($trans,  $message)=&rt::change_queue ($serial_num, $queue, $current_user);
		}
		

		# deal with SET AREA commands
		if ($arg[1] =~ /^area/) {
		    $serial_num=int($arg[2]);
		    $area=$arg[3];
		    ($trans,  $message)=&rt::change_area ($serial_num, $area, $current_user);
		}

		#deal with SET PRIO commands

		if ($arg[1] =~ /^prio/) {
		    $serial_num=int($arg[2]);
		    $prio=$arg[3];
		    ($trans,  $message)=&rt::change_priority ($serial_num, $prio, $current_user);
		}
		

		#deal with SET FINAL commands
		if ($arg[1] =~ /^final/) {
		    $serial_num=int($arg[2]);
		    $prio=$arg[3];
		    ($trans,  $message)=&rt::change_final_priority ($serial_num, $prio, $current_user);
		}
		
		#deal with SET DUE commands

		if ($arg[1] =~ /due/) {
		    $serial_num=int($arg[2]);
		    $due_string=$arg[3];
		    
		    $due_date = &rt::date_parse($due_string);
		    
		    ($trans,$message)=&rt::change_date_due($serial_num, $date_due, $current_user);
		}
		
		#deal with SET STATUS commands

		if ($arg[1] =~ /^status/) {
		    $serial_num=int($arg[2]);
		    $status=$arg[3];
		    $confirmation=$arg[4];

		    

		    if ($status =~ /stall/i) {
			($trans,  $message)=&rt::stall($serial_num, $current_user);
		    }
		    
		    elsif ($status =~ /open/i) {
			($trans,  $message)=&rt::open($serial_num, $current_user);
		    }
		    
		    elsif ($status =~ /resolv/i)  {
			($trans,  $message)=&rt::resolve($serial_num, $current_user);
		    }
		    
		    elsif (($status =~ /dead/i) and ($confirmation =~ /^yes/)){
			($trans,  $message)=&rt::kill($serial_num, $current_user);
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
		#if ($debug) {print "$message ($trans)\n";}
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

    return ($parsed_body);
}

sub send_rt_response
{
    my($real_current_user) = shift;

    if ($#resolve_nums > -1)
    {
        foreach $count (0..$#resolve_nums)
        {
           print "Resolving $resolve_nums[$count]\n" if ($debug);
           ($trans,  $message)=&rt::resolve($resolve_nums[$count], (split(/\@/, $current_user))[0]);
           $response .= "RT: $message ($trans)\n";
        }
    }


    # RESPONSE HERE
    
    if ($debug) {print "$response\n";}
    if ($response) {
	($message)=&rt::template_mail ('act_response','_rt_system',$real_current_user,"","",0,0,"RT Actions Complete","$real_current_user","$response");
    }
    if ($debug) {print "$message\n";}

    
}
1;


