#$Header$

package RT::Action::NotifyAsComment;
require RT::Action::Notify;
@ISA = qw(RT::Action::Notify);


=head2 Prepare

Tell SendEmail that this message should come out as a comment. Then call SUPER::Prepare

=cut

sub Prepare {
	my $self = shift;
	
	#TODO: this should be cleaner.
	#Tell RT::Action::SendEmail that this should come from the relevant comment email address.
	$self->{'comment'} = 1;
	
	return($self->SUPER::Prepare(@_));	
}
1;

