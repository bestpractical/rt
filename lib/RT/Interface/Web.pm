# $Header$
# Copyright 2000 Tobias Brox <tobix@fsck.com>
# Request Tracker is Copyright 1996-2000 Jesse Vincent <jesse@fsck.com>

# This is a library of static subs to be used by the Mason web
# interface to RT, and to be used by webrt.cgi / webmux.pl.

package HTML::Mason::Commands;
use strict;

#{{{ sub Error - calls Error and aborts
sub Error {
    &mc_comp("/Elements/Error" , Why => shift);
    $m->abort;
}

#{{{ sub LoadTicket - loads a ticket
sub LoadTicket {
    my $id=shift;
    my $Ticket = RT::Ticket->new($session{'CurrentUser'});
    unless ($Ticket->Load($id)) {
	&Error("Could not load ticket $id");
    }
    return $Ticket;
}

#{{{ sub CreateOrLoad - will create or load a ticket
sub CreateOrLoad {
    my $Ticket=RT::Ticket->new($session{'CurrentUser'});
    my %args=@_;
    if ($args{id} eq 'new') { 
	require MIME::Entity;
	#TODO in Create_Details.html: priorities and due-date      
	my ($id, $Trans, $ErrMsg)=
	    $Ticket->Create( 
			     Queue=>$args{ARGS}->{queue},
			     Owner=>$args{ARGS}->{ValueOfOwner},
			     Requestor=>($args{ARGS}->{Requestors} 
					 ? undef : $session{CurrentUser}),
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
## it is not needed in perl 5.6.0.  Eventually the sub should accept
## more than one Action, and it should handle Actions with arguments.
sub ProcessActions {
    my %args=@_;
    # TODO: What if there are more Actions?
    if (exists $args{ARGS}->{Action}) {
	my ($action)=$args{ARGS}->{Action} =~ /^(Steal|Kill|Take|UpdateTold)$/;
	my ($res, $msg)=eval('$args{Ticket}->'.$action);
	push(@{$args{Actions}}, $msg);
    }
}

1;
