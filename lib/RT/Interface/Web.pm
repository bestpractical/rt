# $Header$
# Copyright 2000 Tobias Brox <tobix@fsck.com>
# Request Tracker is Copyright 1996-2000 Jesse Vincent <jesse@fsck.com>

# This is a library of static subs to be used by the Mason web
# interface to RT, and to be used by webrt.cgi / webmux.pl.

package HTML::Mason::Commands;

#{{{ sub Error - calls Error and aborts
sub Error {
    &mc_comp("/Elements/Error" , Why => shift);
    $m->abort;
}

#{{{ sub LoadTicket - loads a ticket
sub LoadTicket {
    return 1 if $Ticket;
    $Ticket = RT::Ticket->new($session{'CurrentUser'});
    unless ($Ticket->Load($id)) {
	&Error("Could not load ticket $id");
    }
}

#{{{ sub CreateOrLoad - will create or load a ticket
sub CreateOrLoad {
    my $Ticket=RT::Ticket->new($session{'CurrentUser'});
    my %args=@_;
    if ($args{id} eq 'new') { 
	require MIME::Entity;
	my ($Trans,$ErrMsg);
	#TODO in Create_Details.html: priorities and due-date      
	($id, $Trans, $ErrMsg)=
	    $Ticket->Create( 
			     Queue=>$args{ARGS}->{queue},
			     Owner=>$args{ARGS}->{ValueOfOwner},
			     Requestors=>$args{ARGS}->{Requestors} || $session{CurrentUser}->EmailAddress,
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



1;
