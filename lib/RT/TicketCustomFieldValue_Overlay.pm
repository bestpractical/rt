
no warnings qw(redefine);



=head2 LoadByTicketContentAndCustomField { Ticket => TICKET, CustomField => CUSTOMFIELD, Content => CONTENT }

Loads a custom field value by Ticket, Content and which CustomField it's tied to

=cut


sub LoadByTicketContentAndCustomField {
    my $self = shift;
    my %args = ( Ticket => undef,
                CustomField => undef,
                Content => undef,
                @_
                );


    $self->LoadByCols( Content => $args{'Content'},
                         CustomField => $args{'CustomField'},
                         Ticket => $args{'Ticket'});

    
}

1;
