#$Header$

package RT::TicketCollection;
use RT::Tickets;

# Some docs on what this package should do would be nice

# {{{ sub new 

#instantiate a new object.

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return ($self)
}
# }}}


# {{{ sub Tickets
sub Tickets {
  my $self = shift;
  if (! defined $self->{'tickets'}) {
    $self->{'tickets'} = RT::Tickets->new($self->CurrentUser);
  }
  return ($self->{'tickets'});
  
}
# }}}

# {{{ sub NewTickets
sub NewTickets {
  my $self = shift;
  delete $self->{'tickets'};
  return $self->Tickets;
}
# }}}

# {{{ sub Next
sub Next {
  my $self = shift;
  return $self->Tickets->Next;
}
# }}}

# {{{ sub Restrictions

sub Restrictions {
  my $self = shift;
  my $restriction;
  my $foo;
  
  use Data::Dumper;
#  foreach $restriction ( %{$self->{'restrictions'}}){
    $foo .= "foo";
   $foo .= Dumper(%{$self->{'restrictions'}});
 # }
  

#  my $foo = 'bar';
  return ($foo);
    
  
}

# }}}

# {{{ sub NewRestriction

sub NewRestriction {	    
  my $self = shift;
 

  my $index = $self->{'restriction_index'}++;
  %{$self->{'restrictions'}{"$index"}} = (TABLE => 'Tickets',
	      FIELD => undef,
	      VALUE => undef,	
	      ENTRYAGGREGATOR => 'or',
	      OPERATOR => '=',
	      @_);
 }

# }}}

# {{{ sub DeleteRestriction

sub DeleteRestriction {
  my $self = shift;
  my $index = shift;
  delete $self->{'restrictions'}{"$index"};

}
# }}}

# {{{ sub ApplyRestrictions
sub ApplyRestrictions {
  my $self = shift;
  my $restriction;
  foreach $restriction ( %{$self->{'restrictions'}}){
    $self->Tickets->Limit(%{$self->{'restrictions'}{"$restriction"}});
  }
  
}
# }}}

# {{{ sub Rows 
sub Rows {
  my $self = shift;
  return ($self->Tickets->Rows(@_));
  
}
# }}}

# {{{ sub FirstRow
sub FirstRow {
  my $self = shift;
  return ($self->Tickets->FirstRow(@_));
}
# }}}
  
# {{{ sub NextPage
sub NextPage {
  my $self = shift;
  $self->FirstRow( $self->FirstRow + $self->Rows );
}
# }}}

# {{{ sub FirstPage
sub FirstPage {
  my $self = shift;
  $self->FirstRow(1);
}
# }}}

# {{{ sub PrevPage
sub PrevPage {
  my $self = shift;
  if ($self->FirstRow > 1) {
    $self->FirstRow( $self->FirstRow - $self->Rows );
  }
  else {
    $self->FirstRow(1);
  }
}
# }}}

# {{{ sub _Init 
sub _Init  {
  my $self = shift;

 $self->{'user'} = shift;


}
# }}}

# {{{ sub CurrentUser 
sub CurrentUser  {
  my $self = shift;
  return ($self->{'user'});
}
# }}}

1;
