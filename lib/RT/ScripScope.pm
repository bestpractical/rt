#$Header$

package RT::ScripScope;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "ScripScope";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = ( Scrip  => 'read/write',
	    	Queue => 'read/write', 
	  	Template => 'read/write',
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 

=head2 Create

Creates a new entry in the ScripScopes table. Takes a paramhash with three
fields, Queue, Template and Scrip.

=cut

sub Create  {
  my $self = shift;
  my %args = ( Queue => undef,
               Template => undef,
               Scrip => undef,
               @_
             );

  #TODO +++ validate input 
  my $id = $self->SUPER::Create(Queue => $args{'Queue'},
                                Template => $args{'Template'},
                                Scrip => $args{'Scrip'}
                                );
 return ($id); 
}
# }}}


# {{{ sub ScripObj
sub ScripObj {
  my $self = shift;
  if (!$self->{'ScripObj'})  {
    require RT::Scrip;
    $self->{'ScripObj'} = RT::Scrip->new($self->CurrentUser);
    #TODO: why are we loading scrips with templates like this. 
    # two seperate methods might make more sense
    $self->{'ScripObj'}->Load($self->Scrip, $self->Template);
  }
  return ($self->{'ScripObj'});
}

# }}}
#

# {{{ sub DESTROY
sub DESTROY {
    my $self = shift;
    $self->{'ScripObj'} = undef;
}
#}}}

1;


