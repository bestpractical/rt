package RT::Reminders;

use base qw/RT::Base/;

our $REMINDER_QUEUE = 'General';


sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->CurrentUser(@_);
    return($self);
}


sub Ticket {
    my $self = shift;
    $self->{'_ticket'} = shift if (@_);
    return ($self->{'_ticket'});
}

sub TicketObj {
    my $self = shift;
    unless ($self->{'_ticketobj'}) {
        $self->{'_ticketobj'} = RT::Ticket->new($self->CurrentUser);
        $self->{'_ticketobj'}->Load($self->Ticket);
    }
        return $self->{'_ticketobj'};
}


=head2 Collection

Returns an RT::Tickets object containing reminders for this object's "Ticket"

=cut

sub Collection {
    my $self = shift;
    my $col = RT::Tickets->new($self->CurrentUser);

     my $query =     'Queue = "'. $self->TicketObj->QueueObj->Name .'" AND Type = "reminder"';
    $query .= ' AND RefersTo = "'.$self->Ticket.'"';
   
    $col->FromSQL($query);
    
    return($col);
}

=head2 Add

Add a reminder for this ticket.

Takes

    Subject
    Owner
    Due


=cut


sub Add {
    my $self = shift;
    my %args = ( Subject => undef,
                 Owner => undef,
                 Due => undef,
                 @_);

    my $reminder = RT::Ticket->new($self->CurrentUser);
    $reminder->Create( Subject => $args{'Subject'},
                       Owner => $args{'Owner'},
                       Due => $args{'Due'},
                       RefersTo => $self->Ticket,
                       Type => 'reminder',
                       Queue => $self->TicketObj->Queue,
                   
                   );
    $self->Ticket->_NewTransaction(Type => 'AddReminder',
                                    Field => 'RT::Ticket',
                                   NewValue => $reminder->id);


}


sub Open {
    my $self = shift;
    my $reminder = shift; 

    $reminder->SetStatus('open');
    $self->Ticket->_NewTransaction(Type => 'OpenReminder',
                                    Field => 'RT::Ticket',
                                   NewValue => $reminder->id);
}


sub Resolve {
    my $self = shift;
    my $reminder = shift;
    $reminder->SetStatus('resolved');
    $self->Ticket->_NewTransaction(Type => 'ResolveReminder',
                                    Field => 'RT::Ticket',
                                   NewValue => $reminder->id);
}

    eval "require RT::Reminders_Vendor";
        if ($@ && $@ !~ qr{^Can't locate RT/Reminders_Vendor.pm}) {
            die $@;
        };

        eval "require RT::Reminders_Local";
        if ($@ && $@ !~ qr{^Can't locate RT/Reminders_Local.pm}) {
            die $@;
        };


1;
