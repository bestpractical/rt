# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

package RT::Watchers;
require RT::EasySearch;
require RT::Watcher;
@ISA= qw(RT::EasySearch);


# {{{ sub new 
sub new  {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "Watchers";
  $self->{'primary_key'} = "id";
  $self->_Init(@_);
  return($self);
}
# }}}

# {{{ sub Limit 

=head2 Limit

  A wrapper around RT::EasySearch::Limit which sets
the default entry aggregator to 'AND'

=cut

sub Limit  {
  my $self = shift;
  my %args = ( ENTRYAGGREGATOR => 'AND',
	       @_);

  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub LimitToTicket

=head2 LimitToTicket

Takes a single arg which is a ticket id
Limits to watchers of that ticket

=cut

sub LimitToTicket { 
  my $self = shift;
  my $ticket = shift;
  $self->Limit( ENTRYAGGREGATOR => 'OR',
		FIELD => 'Value',
		VALUE => $ticket);
  $self->Limit (ENTRYAGGREGATOR => 'AND',
		FIELD => 'Scope',
		VALUE => 'Ticket');
}
# }}}

# {{{ sub LimitToQueue 

=head2 LimitToQueue

Takes a single arg, which is a QueueId
Limits to watchers of that queue.

=cut

sub LimitToQueue  {
  my $self = shift;
  my $queue = shift;
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Value',
		VALUE => $queue);
  $self->Limit (ENTRYAGGREGATOR => 'AND',
		FIELD => 'Scope',
		VALUE => 'Queue');
}
# }}}

# {{{ sub LimitToType 

=head2 LimitToType

Takes a single string as its argument. That string is a watcher type
which is one of 'Requestor', 'Cc' or 'AdminCc'
Limits to watchers of that type

=cut


sub LimitToType  {
  my $self = shift;
  my $type = shift;
  $self->Limit(FIELD => 'Type',
	       VALUE => "$type");
}
# }}}

# {{{ sub LimitToRequestors 

=head2 LimitToRequestors

Limits to watchers of type 'Requestor'

=cut

sub LimitToRequestors  {
  my $self = shift;
  $self->LimitToType("Requestor");
}
# }}}

# {{{ sub LimitToCc 

=head2 LimitToCc

Limits to watchers of type 'Cc'

=cut

sub LimitToCc  {
    my $self = shift;
    $self->LimitToType("Cc");
}
# }}}

# {{{ sub LimitToAdminCc 

=head2 LimitToAdminCc

Limits to watchers of type AdminCc

=cut

sub LimitToAdminCc  {
    my $self = shift;
    $self->LimitToType("AdminCc");
}
# }}}


# {{{ sub Emails 

# Return a (reference to a) list of emails
sub Emails  {
    my $self = shift;

    $self->{is_modified}++;

    # List is a list of watcher email addresses
    my @list;
    # Here $w is a RT::WatcherObject
    while (my $w=$self->Next()) {
	push(@list, $w->Email);
    }
    return \@list;
}
# }}}

# {{{ sub EmailsAsString

# Returns the RT::Watchers->Emails as a comma seperated string
sub EmailsAsString {
    my $self = shift;
    return(join(", ",@{$self->Emails}));
}
# }}}

# {{{ sub NewItem 



sub NewItem  {
    my $self = shift;
    
    use RT::Watcher;
    my  $item = new RT::Watcher($self->CurrentUser);
    return($item);
}
# }}}
1;




