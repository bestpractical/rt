#$Header$

=head1 NAME

  RT::Transactions - a collection of RT Transaction objects

=head1 SYNOPSIS

  use RT::Transactions;


=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Transactions;
use RT::EasySearch;

@ISA= qw(RT::EasySearch);
use RT::Transaction;

# {{{ sub _Init  
sub _Init   {
  my $self = shift;
  
  $self->{'table'} = "Transactions";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_));
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
    my $self = shift;
    
    return(RT::Transaction->new($self->CurrentUser));
}
# }}}


=head2 example methods

  Queue RT::Queue or Queue Id
  Ticket RT::Ticket or Ticket Id


LimitDate 
  
Type TRANSTYPE
Field STRING
OldValue OLDVAL
NewValue NEWVAL
Data DATA
TimeTaken
Actor USEROBJ/USERID
ContentMatches STRING

=cut


1;

