# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

package RT::Watchers;
require RT::EasySearch;
@ISA= qw(RT::EasySearch);


sub new {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "Watchers";
  $self->{'primary_key'} = "id";
  return($self);
}

sub Limit {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
}


sub LimitToTicket { 
  my $self = shift;
  my $ticket = shift;
  $self->Limit( ENTRYAGGREAGTOR => 'AND',
		FIELD => 'Value',
		VALUE => $ticket);
  $self->Limit (ENTRYAGGREGATOR => 'AND',
		FIELD => 'Scope',
		VALUE => 'Ticket');
}

sub LimitToQueue {
  my $self = shift;
  my $queue = shift;
  $self->Limit (ENTRYAGGREGATOR => 'AND',
		FIELD => 'Value',
		VALUE => "$queue")
  $self->Limit (ENTRYAGGREGATOR => 'AND',
		FIELD => 'Scope',
		VALUE => 'Queue');
}

sub LimitToType {
  my $self = shift;
  my $type = shift;
  $self->Limit(FIELD => 'Type',
	       VALUE => "$type");
}

sub LimitToRequestors {
  my $self = shift;
  $self->LimitToType("Requestor");
}

# Return a (reference to a) list of emails
sub Emails {
    my $self = shift;
    my $type = shift;
    $self->LimitToType($type)
	if $type;
    my @list;
    while (my $w=$self->Next()) {
	push(@list, $w->Email);
    }
    return \@list;
}

sub LimitToCc {
  my $self = shift;
  $self->LimitToType("Cc");
}

sub LimitToBcc {
  my $self = shift;
  $self->LimitToType("Bcc");
} 

sub NewItem {
  my $self = shift;
  my $Handle = shift;
  my $item;
 use RT::Watcher;
  $item = new RT::Watcher($self->{'user'}, $Handle);
  return($item);
}
1;




