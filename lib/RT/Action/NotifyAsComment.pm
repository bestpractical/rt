#$Header: /raid/cvsroot/rt/lib/RT/Action/NotifyAsComment.pm,v 1.2 2001/11/06 23:04:17 jesse Exp $

package RT::Action::NotifyAsComment;
require RT::Action::Notify;
@ISA = qw(RT::Action::Notify);


=head2 SetReturnAddress

Tell SendEmail that this message should come out as a comment. 
Calls SUPER::SetReturnAddress.

=cut

sub SetReturnAddress {
	my $self = shift;
	
	# Tell RT::Action::SendEmail that this should come 
	# from the relevant comment email address.
	$self->{'comment'} = 1;
	
	return($self->SUPER::SetReturnAddress(is_comment => 1));
}
1;

