=head1 NAME

RT::Action::NotifyGroupAsComment - RT Action that sends notifications to groups and/or users as comment

=head1 DESCRIPTION

This is subclass of L<RT::Action::NotifyGroup> that send comments instead of replies.
See C<rt-notify-group-admin> and L<RT::Action::NotifyGroup> docs for more info.

=cut

package RT::Action::NotifyGroupAsComment;

use strict;
use warnings;

use RT::Action::NotifyGroup;

use base qw(RT::Action::NotifyGroup);

sub SetReturnAddress {
	my $self = shift;
	$self->{'comment'} = 1;
	return $self->SUPER::SetReturnAddress( @_, is_comment => 1 );
}

=head1 AUTHOR

Ruslan U. Zakirov E<lt>ruz@bestpractical.comE<gt>

=cut

1;
