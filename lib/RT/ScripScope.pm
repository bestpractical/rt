#$Header$

package RT::ScripScope;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub _Init
sub _Init  {
  my $self = shift;
  $self->{'table'} = "ScripScope";
  return ($self->SUPER::_Init(@_));
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

  unless ($self->CurrentUserHasRight('ModifyScripScopes')) {
    return (undef);
  }
  my $id = $self->SUPER::Create(Queue => $args{'Queue'},
                                Template => $args{'Template'},
                                Scrip => $args{'Scrip'}
                                );
 return ($id); 
}
# }}}


# {{{ sub QueueObj

=head2 QueueObj

Retuns an RT::Queue object with this Scope's queue

=cut

sub QueueObj {
  my $self = shift;

  if (!$self->{'QueueObj'})  {
    require RT::Queue;
    $self->{'QueueObj'} = RT::Queue->new($self->CurrentUser);
    #TODO: why are we loading scrips with templates like this. 
    # two seperate methods might make more sense
    $self->{'QueueObj'}->Load($self->Queue);
  }
  return ($self->{'QueueObj'});
}

# }}}


# {{{ sub ScripObj

=head2 ScripObj

Retuns an RT::Scrip object with this Scope's scrip

=cut

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

# {{{ sub _Set
# does an acl check and then passes off the call
sub _Set {
    my $self = shift;
   
    unless ($self->CurrentUserHasRight('ModifyScripScopes')) {
        $RT::Logger->debug("CurrentUser can't modify ScripScopes for ".$self->Queue."\n");
      return (undef);
     }
    return $self->SUPER::_Set(@_);
}
# }}}

# {{{ sub _Value
# does an acl check and then passes off the call
sub _Value {
    my $self = shift;
   
    unless ($self->CurrentUserHasRight('ShowScripScopes')) {
        $RT::Logger->debug("CurrentUser can't show ScripScopes for ".$self->Queue."\n");
      return (undef);
      return (undef);
     }
    return $self->SUPER::_Value(@_);
}
# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self = shift;
    $self->{'ScripObj'} = undef;
}
#}}}


# {{{ sub CurrentUserHasRight

=head2 CurrentUserHasRight

Helper menthod for HasRight. Presets Principal to CurrentUser then 
calls HasRight.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    return ($self->HasRight( Principal => $self->CurrentUser->UserObj,
                             Right => $right ));

    }

# }}}

# {{{ sub HasRight

=head2 HasRight

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to ScripScopes.

=cut

sub HasRight {
    my $self = shift;
    my %args = ( Right => undef,
                 Principal => undef,
                 @_ );

    if ($self->SUPER::_Value('Queue') > 0) {
        return ( $args{'Principal'}->HasQueueRight(
                      Right => $args{'Right'},
                      Queue => $self->SUPER::_Value('Queue'),
                      Principal => $args{'Principal'}
                     ) 
                );

    }
    else {
        return( $args{'Principal'}->HasSystemRight(
                       Right => $args{'Right'}) );
    }
}
# }}}
1;


