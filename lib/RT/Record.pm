#$Header$

=head1 NAME

  RT::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION


=begin testing

ok (require RT::Record);

=end testing

=head1 METHODS

=cut


package RT::Record;
use DBIx::SearchBuilder::Record::Cachable;
use RT::Date;
use RT::User;

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
    if(!defined($self->CurrentUser)) {
	use Carp;
	Carp::cluck();
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
    my $now = new RT::Date($self->CurrentUser);
    $now->Set(Format=> 'unix', Value => time);
    push @_, 'Created', $now->ISO()
      if ($self->_Accessible('Created', 'auto'));
    

    push @_, 'Creator', $self->{'user'}->id
      if $self->_Accessible('Creator', 'auto');
    
    push @_, 'LastUpdated', $now->ISO()
      if ($self->_Accessible('LastUpdated', 'auto'));

    push @_, 'LastUpdatedBy', $self->{'user'}->id
      if $self->_Accessible('LastUpdatedBy', 'auto');
    
    

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
      
        return ($self->LastUpdatedObj->AgeAsString());
	
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

  $self->_SetLastUpdated();
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

    if ($self->_Accessible('LastUpdated','auto')) {
    	my ($msg, $val) = $self->__Set( Field => 'LastUpdated',
                                        Value => $now->ISO);
    }
    if ($self->_Accessible('LastUpdatedBy','auto')) {
        my ($msg, $val) = $self->__Set( Field => 'LastUpdatedBy', 
				        Value => $self->CurrentUser->id);
    }
}

# }}}

# {{{ sub CreatorObj 

=head2 CreatorObj

Returns an RT::User object with the RT account of the creator of this row

=cut

sub CreatorObj  {
  my $self = shift;
  unless (exists $self->{'CreatorObj'}) {
    
    $self->{'CreatorObj'} = RT::User->new($self->CurrentUser);
    $self->{'CreatorObj'}->Load($self->Creator);
  }
  return($self->{'CreatorObj'});
}
# }}}

# {{{ sub LastUpdatedByObj

=head2 LastUpdatedByObj

  Returns an RT::User object of the last user to touch this object

=cut

sub LastUpdatedByObj {
    my $self=shift;
    unless (exists $self->{LastUpdatedByObj}) {
	$self->{'LastUpdatedByObj'}=RT::User->new($self->CurrentUser);
	$self->{'LastUpdatedByObj'}->Load($self->LastUpdatedBy);
    }
    return $self->{'LastUpdatedByObj'};
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
