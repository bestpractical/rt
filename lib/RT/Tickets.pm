package RT::Tickets;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


sub _Init {
  my $self = shift;

  $self->{'table'} = "Tickets";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
  
}

sub Limit {
  my $self = shift;
  my %args = ( ENTRYAGGREGATOR => 'AND',
	       @_);
  
  $self->SUPER::Limit(%args);
}

sub NewItem {
  my $self = shift;
  my $Handle = shift;
  my $item;
  use RT::Ticket;
  $item = new RT::Ticket($self->{'user'});
  return($item);
}

sub Owner {
   my $self = shift;
   my $owner = shift;
   $self->Limit(FIELD=> 'Owner',
		VALUE=> "$owner");

}

sub Status {
  my $self = shift;
  my $Status;
  foreach $Status (@_) {
    $self->Limit(
		 FIELD => 'Status',
		 OPERATOR => '=',
		 VALUE => "%$Status%",
		 ENTRYAGGREGATOR => 'or'
		);
    print " VALUE => %$Status% \n";
  }
}

sub Requestor {
  my $self = shift;
  my $Requestor;
  foreach $Requestor (@_) {
    $self->Limit(
		 ALIAS => 'ARequestor',
		 FIELD => 'Requestors',
		 OPERATOR => 'LIKE',
		 VALUE => "%$Requestor%",
		 ENTRYAGGREGATOR => 'or'
		);
  }
}

sub Priority {
  my $self = shift;
  
}

sub InitialPriority {
  my $self = shift;
}

sub FinalPriority {
  my $self = shift;
  
}

sub Queue {
  my $self = shift;
}
sub Subject {
  my $self = shift;
}
sub Content {
  my $self = shift;
}
sub Creator {
  my $self = shift;
}

#Restrict by date
sub Created {
  my $self = shift;
}
sub Modified {
  my $self = shift;
}
sub Contacted {
  my $self = shift;
}
sub Due {
  my $self = shift;
}


#Restrict by links.

sub Link {
  my $self = shift;
  my %args = (
              Base => undef,
	      Target => undef,
	      Type => undef,
              @_);

}


sub ParentOf  {
  my $self = shift;
}
sub ChildOf {
  my $self = shift;
}
sub DependsOn {
  my $self = shift;
}
sub DependedOnBy {
  my $self = shift;
}

  1;


