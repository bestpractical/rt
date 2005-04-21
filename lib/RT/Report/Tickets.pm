package RT::Report::Tickets;
use base qw/RT::Tickets/;
use RT::Report::Tickets::Entry;


# Gotta skip over RT::Tickets->Next, since it does all sorts of crazy magic we 
# don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub NewItem {
    my $self = shift;
    return RT::Report::Tickets::Entry->new($RT::SystemUser); # $self->CurrentUser);
}

1;
