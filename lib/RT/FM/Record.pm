#$Header$

=head1 NAME

  RT::FM::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut


package RT::FM::Record;
use DBIx::SearchBuilder::Record::Cachable;
use RT::Date;
#use RT::FM::User;

@ISA= qw(DBIx::SearchBuilder::Record::Cachable);

# {{{ sub _Init 

sub _Init  {
  my $self = shift;
  $self->_MyCurrentUser(@_);
  
}

# }}}

# {{{ _PrimaryKeys

=head2 _PrimaryKeys

The primary keys for RT classes is 'id'

=cut

sub _PrimaryKeys {
    my $self = shift;
    return(['id']);
}

# }}}

# {{{ sub _MyCurrentUser 

sub _MyCurrentUser  {
    my $self = shift;
  
    $self->CurrentUser(@_);
    warn "$self -> _MyCurrentUser isn't returning the right thing\n";
    return;
    if(!defined($self->CurrentUser)) {
	use Carp;
	Carp::cluck();
	$RT::FM::Logger->err("$self was created without a CurrentUser\n"); 
      return(0);
    }
}

# }}}

# {{{ sub _Handle 
sub _Handle  {
  my $self = shift;
  return($RT::FM::Handle);
}
# }}}

# {{{ sub Create 

sub Create  {
    my $self = shift;
    my $now = new RT::Date($self->CurrentUser);
    $now->Set(Format=> 'unix', Value => time);
    push @_, 'Created', $now->ISO()
      if ($self->_Accessible('Created', 'auto'));
    

    warn "RT::FM::Record not setting Creator or UpdatedBy since we don't do users yet";

#    push @_, 'Creator', $self->{'user'}->id
#      if $self->_Accessible('Creator', 'auto');
    
    push @_, 'Updated', $now->ISO()
      if ($self->_Accessible('Updated', 'auto'));

#    push @_, 'UpdatedBy', $self->{'user'}->id
#      if $self->_Accessible('UpdatedBy', 'auto');
    
    

   my $id = $self->SUPER::Create(@_);
    
    if ($id) {
	$self->Load($id);
    }
    
    return($id);
    
}

# }}}

# {{{ Datehandling

# There is room for optimizations in most of those subs:

# {{{ UpdatedObj

sub UpdatedObj {
    my $self=shift;
    my $obj = new RT::Date($self->CurrentUser);
    
    $obj->Set(Format => 'sql', Value => $self->Updated);
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

# {{{ UpdatedAsString

sub UpdatedAsString {
    my $self=shift;
    if ($self->Updated) {
	return ($self->UpdatedObj->AsString());
	  
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
    if ($self->Updated) {
      
        return ($self->UpdatedObj->AgeAsString());
	
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

  $self->_SetUpdated();
  $self->SUPER::_Set(Field => $args{'Field'},
		     Value => $args{'Value'},
		     IsSQL => $args{'IsSQL'});
  
  
}
# }}}

# {{{ sub _SetUpdated

=head2 _SetUpdated

This routine updates the Updated and UpdatedBy columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub _SetUpdated {
    my $self = shift;
    use RT::Date;
    my $now = new RT::Date($self->CurrentUser);
    $now->SetToNow();

    if ($self->_Accessible('Updated','auto')) {
    	my ($msg, $val) = $self->__Set( Field => 'Updated',
                                        Value => $now->ISO);
    }
    
    warn "RT::FM::Handle _SetUpdated won't set the actor since we don't do users yet";
    #    if ($self->_Accessible('UpdatedBy','auto')) {
    #       my ($msg, $val) = $self->__Set( Field => 'UpdatedBy', 
    #   Value => $self->CurrentUser->id);
    # }
}

# }}}

# {{{ sub CreatorObj 

=head2 CreatorObj

Returns an RT::FM::User object with the RT account of the creator of this row

=cut

sub CreatorObj  {
  my $self = shift;
  unless (exists $self->{'CreatorObj'}) {
      
#    $self->{'CreatorObj'} = RT::FM::User->new($self->CurrentUser);
#    $self->{'CreatorObj'}->Load($self->Creator);
  }
  return($self->{'CreatorObj'});
}
# }}}

# {{{ sub UpdatedByObj

=head2 UpdatedByObj

  Returns an RT::FM::User object of the last user to touch this object

=cut

sub UpdatedByObj {
    my $self=shift;
    unless (exists $self->{UpdatedByObj}) {
	$self->{'UpdatedByObj'}=RT::FM::User->new($self->CurrentUser);
	$self->{'UpdatedByObj'}->Load($self->UpdatedBy);
    }
    return $self->{'UpdatedByObj'};
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
