# (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::Search::ActiveTicketsInQueue

=head1 SYNOPSIS

=head1 DESCRIPTION

Find all active tickets in the queue named in the argument passed in

=head1 METHODS


=begin testing

ok (require RT::Search::Generic);

=end testing


=cut

package RT::Search::ActiveTicketsInQueue;

use base qw(RT::Search::Generic);


# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ($self->loc("No description for [_1]", ref $self));
}
# }}}

# {{{ sub Prepare
sub Prepare  {
  my $self = shift;

  $self->TicketsObj->LimitQueue(VALUE => $self->Argument);

  foreach my $status (RT::Queue->ActiveStatusArray()) {
        $self->TicketsObj->LimitStatus(VALUE => $status);
  }

  return(1);
}
# }}}

1;
