# Copyright 1999-2001 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Header: /raid/cvsroot/rt/lib/RT/CustomFields.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

=head1 NAME

  RT::CustomFields - a collection of RT CustomField objects

=head1 SYNOPSIS

  use RT::CustomFields;

=head1 DESCRIPTION

=head1 METHODS


=begin testing

ok (require RT::CustomFields);

=end testing

=cut

no warnings qw(redefine);


# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "CustomFields";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_));
}
# }}}

# {{{ sub LimitToGlobalOrQueue 

=item LimitToGlobalOrQueue QUEUEID

Limits the set of custom fields found to global custom fields or those tied to the queue with ID QUEUEID 

=cut

sub LimitToGlobalOrQueue {
    my $self = shift;
    my $queue = shift;
    $self->LimitToQueue($queue);
    $self->LimitToGlobal();
}

# }}}

# {{{ sub LimitToQueue 

=head2 LimitToQueue QUEUEID

Takes a queue id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub LimitToQueue  {
   my $self = shift;
  my $queue = shift;
 
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => "$queue")
      if defined $queue;
  
}
# }}}

# {{{ sub LimitToGlobal

=head2 LimitToGlobal

Makes sure that 
Scopes it pulls out apply to all queues (or another that you've selected with
another call to this method or LimitToQueue

=cut


sub LimitToGlobal  {
   my $self = shift;
 
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => 0);
  
}
# }}}

1;

