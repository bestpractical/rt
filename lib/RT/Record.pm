#$Header$

=head1 NAME

  RT::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut


package RT::Record;
use DBIx::SearchBuilder::Record;
use RT::Date;

@ISA= qw(DBIx::SearchBuilder::Record);

# {{{ sub new 

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}

# }}}

# {{{ sub _Init 

sub _Init  {
  my $self = shift;
  $self->_MyCurrentUser(@_);
  
}

# }}}

# {{{ sub _MyCurrentUser 

sub _MyCurrentUser  {
    my $self = shift;
  
    $self->CurrentUser(@_);
    if(!defined($self->CurrentUser)) {
	use Carp;
	Carp::confess();
	$RT::Logger->err("$self was created without a CurrentUser\n"); 
      return(0);
    }
}

# }}}

# {{{ sub _Handle 
sub _Handle  {
  my $self = shift;
  return($RT::Handle);
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
      if ($self->_Accessible('Created', 'auto')) {
	my $now = new RT::Date($self->CurrentUser);
	$now->Set(Format=> 'unix', Value => time);
	   push @_, 'Created', $now->ISO();
	}
  push @_, 'Creator', $self->{'user'}->id
	if $self->_Accessible('Creator', 'auto');
  my $id = $self->SUPER::Create(@_);

  if ($id) {
      $self->Load($id);
  }
  
  return($id);

}
# }}}

# {{{ Datehandling

# There is room for optimizations in most of those subs:

# {{{ LastUpdatedObj

sub LastUpdatedObj {
    my $self=shift;
    my $obj = new RT::Date($self->CurrentUser);
    
    $obj->Set(Format => 'sql', Value => $self->LastUpdated);
    return $obj;
}

# }}}

# {{{ CreatedObj

sub CreatedObj {
    my $self=shift;
    my $obj = new RT::Date($self->CurrentUser);
    
    $obj->Set(Format => 'sql', Value => $self->Created);

    
    return $obj;
}

# }}}

# {{{ AgeAsString
sub AgeAsString {
    my $self=shift;
    return($self->CreatedObj->AgeAsString());
}
# }}}

# {{{ LastUpdatedAsString

sub LastUpdatedAsString {
    my $self=shift;
    if ($self->LastUpdated) {
	return ($self->LastUpdatedObj->AsString());
	  
    } else {
	return "never";
    }
}

# }}}

# {{{ CreatedAsString
sub CreatedAsString {
    my $self = shift;
    return ($self->CreatedObj->AsString());
}
# }}}

# {{{ LongSinceUpdateAsString
sub LongSinceUpdateAsString {
    my $self=shift;
    if ($self->LastUpdated) {
      my $now = new RT::Date($self->CurrentUser);
	return ($now->DiffAsString($self->LastUpdatedObj));
	
    } else {
	return "never";
    }
}
# }}}

# }}} Datehandling


# {{{ sub _Set 
sub _Set  {
  my $self = shift;

  my %args = ( Field => undef,
	       Value => undef,
	       IsSQL => undef,
	       @_ );


  #if the user is trying to modify the record
  if ((!defined ($args{'Field'})) || (!defined ($args{'Value'}))) {
    $args{'Value'} = 0; 
   }

  $self->_SetLastUpdated;
  $self->SUPER::_Set(Field => $args{'Field'},
		     Value => $args{'Value'},
		     IsSQL => $args{'IsSQL'});
  
  
}
# }}}

# {{{ sub _SetLastUpdated

=head2 _SetLastUpdated

This routine updates the LastUpdated and LastUpdatedBy columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub _SetLastUpdated {
	my $self = shift;
  use RT::Date;
  my $now = new RT::Date($self->CurrentUser);
  $now->SetToNow();

  #TODO this should be using _Set not UpdateTableValue. it's a stupid ++
  # short circuiting
  $error_condition = $self->_Handle->UpdateTableValue($self->{'table'}, 'LastUpdated',$now->ISO,$self->id)
    if ($self->_Accessible('LastUpdated','auto'));

  $self->SUPER::_Set(Field => 'LastUpdatedBy', Value => $self->CurrentUser->id)
    if ($self->_Accessible('LastUpdatedBy','auto'));
}

# }}}
# {{{ sub Creator 

=head2 Creator and CreatorObj

Returns an RT::User object with the RT account of the creator of this row

=cut

*CreatorObj = \&Creator;

sub Creator  {
  my $self = shift;
  if (!$self->{'creator'}) {
    use RT::User;
    $self->{'creator'} = RT::User->new($self->CurrentUser);
    $self->{'creator'}->Load($self->_Value('Creator'));
  }
  return($self->{'creator'});
}
# }}}

# {{{ sub CurrentUser 

=head2 CurrentUser

If called with an argument, sets the current user to that user object.
This will affect ACL decisions, etc.  
Returns the current user

=cut

sub CurrentUser  {
  my $self = shift;

  if (@_) {
    $self->{'user'} = shift;
  }
  return ($self->{'user'});
}
# }}}


1;
