## $Header$
## Copyright 2000 Tobias Brox <tobix@fsck.com>
## Request Tracker is Copyright 1996-2000 Jesse Vincent <jesse@fsck.com>

## This is a library of static subs to be used by the Mason web
## interface to RT, and maybe also for usage by webrt.cgi / webmux.pl.

package HTML::Mason::Commands;
use strict;

#{{{ sub Error - calls Error and aborts
sub Error {
    &mc_comp("/Elements/Error" , Why => shift);
    $m->abort;
}
#}}}

#{{{ sub LoadTicket - loads a ticket
sub LoadTicket {
    my $id=shift;
    my $CurrentUser = shift;
    my $Ticket = RT::Ticket->new($CurrentUser);
    unless ($Ticket->Load($id)) {
	&Error("Could not load ticket $id");
    }
    return $Ticket;
}
#}}}

#{{{ sub CreateOrLoad - will create or load a ticket
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
#}}}

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

sub ProcessOwnerChangeRequest {
    my %args=@_;
    if ($args{ARGS}->{'SetOwner'}
        and ($args{ARGS}->{'SetOwner'} ne $args{Ticket}->OwnerObj->Id())) {
	my ($Transaction, $Description)=$args{Ticket}->SetOwner($args{ARGS}->{'SetOwner'});
	push(@{$args{Actions}}, $Description);
    }
}

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

sub ProcessStatusChangeQuery {
    my %args=@_;
    if ($args{ARGS}->{'SetStatus'} and ($args{ARGS}->{'SetStatus'} ne $args{Ticket}->Status())) {
	my ($Transaction, $Description)=$args{Ticket}->SetStatus($args{ARGS}->{'SetStatus'});
	push(@{$args{Actions}}, $Description);
    }
}

sub ProcessSearchQuery {
    my %args=@_;

    ## TODO: The only parameter here is %ARGS.  Maybe it would be
    ## cleaner to load this parameter as $ARGS, and use $ARGS->{...}
    ## instead of $args{ARGS}->{...} ? :)

    require RT::TicketCollection;

    ## Tobix: Sticky searches is a very cool feature indeed.  It
    ## should be handled in the same way as in KB, the search
    ## criterias should be listed up, and it should be possible (from
    ## the webui) to delete criterias, add criterias and delete all
    ## criterias.

    # Currently we'll only have "sticky searches" if explicitly asked
    # for it (parameter keep). TODO: it should be opposit, the current
    # search should be destroyed only when explicitly asked for it.
 
    if ($args{ARGS}->{'keep'} && defined $session{'tickets'}) {
	# Reset the old search
	$session{'tickets'}->NewTickets;
    } else {
	# Init a new search
	$session{'tickets'} = RT::TicketCollection->new($session{'CurrentUser'});
    }

    # Set the query limit
    if ($args{ARGS}->{'LimitResultsPerPage'} and ($args{ARGS}->{'ValueOfResultsPerPage'})) {
	$session{'tickets'}->Rows($args{ARGS}->{'ValueOfResultsPerPage'});
    }

    # Limit owner
    if ($args{ARGS}->{'LimitOwner'} and $args{ARGS}->{'ValueOfOwner'}) {
	my $oper = $args{ARGS}->{'NegateOwner'} ? "!=" : "=";
	$session{'tickets'}->NewRestriction (FIELD => 'Owner',
					     VALUE => $args{ARGS}->{'ValueOfOwner'},
					     OPERATOR => "$oper"
					     );
    }

    ## Limit requestor email

    ## TODO: This don't work - and it's a hard nut to crack.
    ## Sometimes we also need to check the User table!  I'd suggest
    ## doing this as a three-step operation - first fetching records
    ## from the User table, then from the Watcher table, and finally
    ## from the Ticket table, using sth like "SELECT * FROM
    ## Tickets,Watchers WHERE Watchers.id IN (53,67,...) and
    ## Watchers.Scope='Ticket' and Tickets.id=Watchers.value".

    ## That solution might break a bit, since a saved query can't
    ## catch new Tickets with the same Requestor.  Anyway, if properly
    ## documented, I think we can live with that.  Eventually, we'll
    ## need to improve the TicketCollection system.

    ## TobiX

    if ($args{ARGS}->{'LimitRequestorByEmail'}) {
	my $oper = $args{ARGS}->{'NegateRequestor'} ? "!=" : "=";
	my $alias=$session{'tickets'}->NewRestriction 
	    (FIELD => 'Email',
	     VALUE => $args{ARGS}->{'ValueOfRequestors'},
	     TABLE => 'Watchers',
	     OPERATOR => "$oper",
	     EXT_LINKFIELD => 'Value');
	# TODO:
	# THIS BREAKS.  NewRestriction doesn't return alias.  More work is needed here.. :/
	# Possible idea; add SET_ALIAS as a method to the Limit, allowing
	# a join to be performed with a custom-set alias
	$session{'tickets'}->NewRestriction
	    (FIELD => 'Scope',
	     VALUE => 'Ticket',
	     ALIAS => $alias,
	     OPERATOR => "=");
	$session{'tickets'}->NewRestriction
	    (FIELD => 'Type',
	     VALUE => 'Requestor',
	     ALIAS => $alias,
	     OPERATOR => "=");
    }

    ## Limit Subject
    if ($args{ARGS}->{'LimitSubject'}) {
	my $val=$args{ARGS}->{'ValueOfSubject'};
	my $oper = $args{ARGS}->{'NegateSubject'} || "=";
	$oper="!=" if ($oper eq 1);
	if ($oper eq 'Like') {
	    $val="%$val%";
	}
	$session{'tickets'}->NewRestriction (FIELD => 'Subject',
					     VALUE => $val,
					     OPERATOR => $oper
					     );
    }

    ## Limit Queue
    if ($args{ARGS}->{'LimitQueue'}) {
	my $oper = $args{ARGS}->{'NegateQueue'} ? "!=" : "="; 
	$session{'tickets'}->NewRestriction (FIELD => 'Queue',
					     VALUE => $args{ARGS}->{'ValueOfQueue'},
					     OPERATOR => "$oper"
					     );
    }

    ## Limit Status
    if ($args{ARGS}->{'LimitStatus'}) {
	my $oper = $args{ARGS}->{'NegateStatus'} ? "!=" : "="; 
	$session{'tickets'}->NewRestriction (FIELD => 'Status',
					     VALUE => $args{ARGS}->{'ValueOfStatus'},
					     OPERATOR => "$oper"
					     );
    }

    $session{'tickets'}->ApplyRestrictions;
}

# TODO: This might eventually read the cookies, user configuration
# information from the DB, queue configuration information from the
# DB, etc.

sub Config {
  my $args=shift;
  my $key=shift;
  return $args->{$key} || $RT::WebOptions{$key};
}

1;

