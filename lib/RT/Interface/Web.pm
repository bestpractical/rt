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
    $Ticket->Load($id);
}

#{{{ sub CreateOrLoad - will create or load a ticket
sub CreateOrLoad {
    $Ticket = RT::Ticket->new($session{'CurrentUser'}) unless $Ticket;
    if ($id eq 'new') { 
	require MIME::Entity;
	my ($Trans,$ErrMsg);
	#TODO in Create_Details.html: priorities and due-date      
	($id, $Trans, $ErrMsg)=
	    $Ticket->Create( 
			     Queue=>$ARGS{queue},
			     Owner=>$ARGS{ValueOfOwner},
			     Requestors=>$ARGS{Requestors} || $session{CurrentUser}->EmailAddress,
			     Subject=>$ARGS{Subject},
			     Status=>$ARGS{Status}||'open',
			     MIMEObj => MIME::Entity->build
			     ( 
			       Subject => $ARGS{Subject},
			       From => $ARGS{Requestors},
			       Cc => $ARGS{Cc},
			       Data => $ARGS{Content}
			       )	  
			     );         
	unless ($id && $Trans) {
	    &mc_comp("/Elements/Error" , Why => $ErrMsg);
	    $m->abort;
	}
	push(@Actions, $ErrMsg);
    } else {
	unless ($Ticket->Load($id)) {
	    &mc_comp("/Elements/Error" , Why => "Ticket couldn't be loaded");
	    $m->abort;
	}
    }
}



1;
