## $Header$
## Copyright 2000 Tobias Brox <tobix@fsck.com>
## Request Tracker is Copyright 1996-2000 Jesse Vincent <jesse@fsck.com>

## This is a library of static subs to be used by the Mason web
## interface to RT

package HTML::Mason::Commands;
use strict;

# {{{ sub Error - calls Error and aborts
sub Error {
    &mc_comp("/Elements/Error" , Why => shift);
    $m->abort;
}
# }}}

# {{{ sub LoadTicket - loads a ticket
sub LoadTicket {
    my $id=shift;
    my $CurrentUser = shift;
    my $Ticket = RT::Ticket->new($CurrentUser);
    unless ($Ticket->Load($id)) {
	&Error("Could not load ticket $id");
    }
    return $Ticket;
}
# }}}

# {{{ sub CreateOrLoad - will create or load a ticket
sub CreateOrLoad {
    my %args=(@_);
    my $CurrentUser = $args{'CurrentUser'};


    my $Ticket = new RT::Ticket($CurrentUser);
    if ($args{id} eq 'new') { 
	
	require RT::Queue;
	my $Queue = new RT::Queue($CurrentUser);	
	unless ($Queue->Load($args{'ARGS'}->{'queue'})) {
		&mc_comp("/Elements/Error", Why => 'Queue not found');
		$m->abort;
	}

	unless ($Queue->CurrentUserHasRight('CreateTicket')) {
		&mc_comp("/Elements/Error", Why => 'Permission Denied');
		$m->abort;
	}
	require MIME::Entity;
	#TODO in Create_Details.html: priorities and due-date      
	my ($id, $Trans, $ErrMsg)=
	    $Ticket->Create( 
			     Queue=>$args{ARGS}->{queue},
			     Owner=>$args{ARGS}->{ValueOfOwner},
			     Requestor=>($args{ARGS}->{Requestors} 
					 ? undef : $session{CurrentUser}->UserObj()),
			     RequestorEmail=>$args{ARGS}->{Requestors}||undef,
			     Subject=>$args{ARGS}->{Subject},
			     Status=>$args{ARGS}->{Status}||'open',
			     MIMEObj => MIME::Entity->build
			     ( 
			       Subject => $args{ARGS}->{Subject},
			       From => $args{ARGS}->{Requestors},
			       Cc => $args{ARGS}->{Cc},
			       Data => $args{ARGS}->{Content}
			       )	  
			     );         
	unless ($id && $Trans) {
	    &mc_comp("/Elements/Error" , Why => $ErrMsg);
	    $m->abort;
	}
	push(@{$args{Actions}}, $ErrMsg);
    } else {
	unless ($Ticket->Load($args{id})) {
	    &mc_comp("/Elements/Error" , Why => "Ticket couldn't be loaded");
	    $m->abort;
	}
    }
    return $Ticket;
}
# }}}

# {{{ sub LinkUpIfRequested

sub LinkUpIfRequested {
    my %args=@_;
    if (my $l=$args{ARGS}->{'Link'}) {
	# There is some redundant information from the forms now - we'll
	# ignore one bit of it:
	
	my $luris=$args{ARGS}->{'LinkTo'} || $args{ARGS}->{'LinkFrom'};
	my $ltyp=$args{ARGS}->{'LinkType'};
	if (ref $ltyp) {
	    &mc_comp("/Elements/Error" , Why => "Parameter error");
	    $m->abort;
	}
	for my $luri (split (/ /,$luris)) {
	    my ($LinkId, $Message);
	    if ($l eq 'LinkTo') {
		($LinkId,$Message)=$args{Ticket}->LinkTo(Target=>$luri, Type=>$ltyp);
	    } elsif ($l eq 'LinkFrom') {
		($LinkId,$Message)=$args{Ticket}->LinkFrom(Base=>$luri, Type=>$ltyp);
	    } else {
		&mc_comp("/Elements/Error" , Why => "Parameter error");
		$m->abort;
	    }
	    
	    push(@{$args{Actions}}, $Message);
	}
    }
}

# }}}

# {{{ sub ProcessSimpleActions
## TODO: This is a bit hacky, that eval should go away.  Eventually,
## the eval is not needed in perl 5.6.0.  Eventually the sub should
## accept more than one Action, and it should handle Actions with
## arguments.
sub ProcessSimpleActions {
    my %args=@_;
    # TODO: What if there are more Actions?
    if (exists $args{ARGS}->{Action}) {
	my ($action)=$args{ARGS}->{Action} =~ /^(Steal|Kill|Take|UpdateTold)$/;
	my ($res, $msg)=eval('$args{Ticket}->'.$action);
	push(@{$args{Actions}}, $msg);
    }
}
# }}}

sub ProcessOwnerChangeRequest {
    my %args=@_;
    if ($args{ARGS}->{'SetOwner'}
        and ($args{ARGS}->{'SetOwner'} ne $args{Ticket}->OwnerObj->Id())) {
	my ($Transaction, $Description)=$args{Ticket}->SetOwner($args{ARGS}->{'SetOwner'});
	push(@{$args{Actions}}, $Description);
    }
}

# {{{ sub ProcessUpdateMessage
sub ProcessUpdateMessage {
    my %args=@_;
    if ($args{ARGS}->{'UpdateContent'}) {
	my @UpdateContent = split(/\r/,$args{ARGS}->{'UpdateContent'}."\n");
	my $Message = MIME::Entity->build 
	    ( Subject => $args{ARGS}->{'UpdateSubject'} || "",
	      Cc => $args{ARGS}->{'UpdateCc'} || "",
	      Bcc => $args{ARGS}->{'UpdateBcc'} || "",
	      Data => \@UpdateContent);
	
	## TODO: Implement public comments
	if ($args{ARGS}->{'UpdateType'} =~ /^(private|public)$/) {
	    my ($Transaction, $Description) = $args{Ticket}->Comment
		( CcMessageTo => $args{ARGS}->{'UpdateCc'},
		  BccMessageTo => $args{ARGS}->{'UpdateBcc'},
		  MIMEObj => $Message,
		  TimeTaken => $args{ARGS}->{'UpdateTimeWorked'});
	    push(@{$args{Actions}}, $Description);
	}
	elsif ($args{ARGS}->{'UpdateType'} eq 'response') {
	    my ($Transaction, $Description) = $args{Ticket}->Correspond
		( CcMessageTo => $args{ARGS}->{'UpdateCc'},
		  BccMessageTo => $args{ARGS}->{'UpdateBcc'},
		  MIMEObj => $Message,
		  TimeTaken => $args{ARGS}->{'UpdateTimeWorked'});
	    push(@{$args{Actions}}, $Description);
	}
    }
}
# }}}

sub ProcessStatusChangeQuery {
    my %args=@_;
    if ($args{ARGS}->{'SetStatus'} and ($args{ARGS}->{'SetStatus'} ne $args{Ticket}->Status())) {
	my ($Transaction, $Description)=$args{Ticket}->SetStatus($args{ARGS}->{'SetStatus'});
	push(@{$args{Actions}}, $Description);
    }
}

# {{{ sub ProcessSearchQuery
sub ProcessSearchQuery {
    my %args=@_;
    
    ## TODO: The only parameter here is %ARGS.  Maybe it would be
    ## cleaner to load this parameter as $ARGS, and use $ARGS->{...}
    ## instead of $args{ARGS}->{...} ? :)

    require RT::Tickets;

 
#TODO We'll do sticky searches later
    if (defined $session{'tickets'}) {
	# Reset the old search

	$session{'tickets'}->GotoFirstItem;
    } else {
	# Init a new search
	$session{'tickets'} = RT::Tickets->new($session{'CurrentUser'});
    }
    
    # {{{ Set the query limit
    #TODO this doesn't work
    if ($args{ARGS}->{'LimitResultsPerPage'} and ($args{ARGS}->{'ValueOfResultsPerPage'})) {
	$session{'tickets'}->Rows($args{ARGS}->{'ValueOfResultsPerPage'});
    }
    # }}}
   

    # {{{ Limit owner
    if ($args{ARGS}->{'ValueOfOwner'} ne '' ) {
	my $owner = new RT::User($session{'CurrentUser'});

	$owner->Load($args{ARGS}->{'ValueOfOwner'});
	
	$session{'tickets'}->Limit (FIELD => 'Owner',
				    VALUE => $args{ARGS}->{'ValueOfOwner'},
 				    OPERATOR => $args{ARGS}->{'OwnerOp'},
				    DESCRIPTION => "Owner " .
				    $args{ARGS}->{'OwnerOp'} . " ".
				    $owner->UserId
				   );
    }
    # }}}

    # {{{ Limit requestor email
    #TODO this doesn't work
    
    if ($args{ARGS}->{'ValueOfRequestor'} ne '') {
	my $alias=$session{'tickets'}->Limit  (FIELD => 'WatcherEmail',
					       VALUE => $args{ARGS}->{'ValueOfRequestor'},
					       OPERATOR =>  $args{ARGS}->{'RequestorOp'},
					       DESCRIPTION => "Watcher's email address ".
					       $args{ARGS}->{'RequestorOp'} . " ".
					       $args{ARGS}->{'ValueOfRequestor'} );
	
    }
    # }}}
    # {{{ Limit Queue
    if ($args{ARGS}->{'ValueOfQueue'} ne '') {
	my $queue = new RT::Queue($session{'CurrentUser'});
	$queue->Load($args{ARGS}->{'ValueOfQueue'});
	$session{'tickets'}->Limit (FIELD => 'Queue',
				    VALUE => $args{ARGS}->{'ValueOfQueue'},
				    OPERATOR => $args{ARGS}->{'QueueOp'},
				    DESCRIPTION => 'Queue ' .  $args{ARGS}->{'QueueOp'}. " ".
				    $queue->QueueId
				   );
    }
    # }}}
        


    # {{{ Limit Status
    if ($args{ARGS}->{'ValueOfStatus'} ne '') {
	$session{'tickets'}->Limit (FIELD => 'Status',
				    VALUE => $args{ARGS}->{'ValueOfStatus'},
				    OPERATOR =>  $args{ARGS}->{'StatusOp'},
				    DESCRIPTION => "Status ".  $args{ARGS}->{'StatusOp'} .
				    " ".$args{ARGS}->{'ValueOfStatus'}
				   );
    }

# }}}

    
    # {{{ Limit Subject
    if ($args{ARGS}->{'ValueOfSubject'} ne '') {
	$session{'tickets'}->Limit(FIELD => 'Subject',
				   VALUE =>  $args{ARGS}->{'ValueOfSubject'},
				   OPERATOR => $args{ARGS}->{'SubjectOp'},
				   DESCRIPTION => "Subject ". 
				   $args{ARGS}->{'SubjectOp'}." ".
				   $args{ARGS}->{'ValueOfSubject'}
				  );
    }

    # }}}    
     # {{{ Limit Subject
    if ($args{ARGS}->{'ValueOfContent'} ne '') {
	$session{'tickets'}->Limit(FIELD => 'Content',
				   VALUE =>  $args{ARGS}->{'ValueOfContent'},
				   OPERATOR => $args{ARGS}->{'ContentOp'},
				   DESCRIPTION => "Transaction content". 
				   $args{ARGS}->{'ContentOp'}." ".
				   $args{ARGS}->{'ValueOfContent'}
				  );
    }

    # }}}   
}
# }}}

# TODO: This might eventually read the cookies, user configuration
# information from the DB, queue configuration information from the
# DB, etc.

sub Config {
  my $args=shift;
  my $key=shift;
  return $args->{$key} || $RT::WebOptions{$key};
}

1;

