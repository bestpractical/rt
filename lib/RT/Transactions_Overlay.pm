#$Header: /raid/cvsroot/rt/lib/RT/Transactions.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

=head1 NAME

  RT::Transactions - a collection of RT Transaction objects

=head1 SYNOPSIS

  use RT::Transactions;


=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok (require RT::Transactions);

=end testing

=cut

no warnings qw(redefine);

# {{{ sub _Init  
sub _Init   {
  my $self = shift;
  
  $self->{'table'} = "Transactions";
  $self->{'primary_key'} = "id";
  
  # By default, order by the date of the transaction, rather than ID.
  $self->OrderBy( ALIAS => 'main',
		  FIELD => 'Created',
		  ORDER => 'ASC');

  return ( $self->SUPER::_Init(@_));
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

