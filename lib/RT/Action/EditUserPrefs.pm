use strict;
use warnings;

package RT::Action::EditUserPrefs;
use base qw/RT::Action Jifty::Action/;


sub name {
    my $self = shift;
    Jifty->log->error('you need to subclass name');
    return;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message( _('Updated Preferences') );
}

sub user {
    return Jifty->web->current_user->user_object; 
}


1;
