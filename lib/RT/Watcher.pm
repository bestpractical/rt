# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::Watcher;
use RT::Record;
@ISA= qw(RT::Record);



# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Watchers";
  $self->_Init(@_);

  return($self);
}
# }}}

# {{{ sub Create 
sub Create  {
    my $self = shift;
    my %args = (
		Owner => undef,
		Email => undef,
		Value => undef,
		Scope => undef,
		Type => undef,
		Quiet => 0,
		@_ # get the real argumentlist
		);

    #Do we have someone this applies to?
    unless (($args{'Owner'} =~ /^(\d*)$/)|| ($args{'Email'} =~ /\@/)) {
          return (0, "No user or email addres specified");
      }

   $RT::Logger->debug("Adding a watcher",$args{Owner}, $args{Email}, $args{Value}, $args{Scope}, $args{Type});

    #If we've got an Email and no owner, try to tie it to the user's account
    my $User=RT::User->new($self->CurrentUser);
    if (!$args{Owner} && $User->LoadByEmail($args{Email})) {
    	$args{Owner}=$User->id;
    	delete $args{Email};
    }

    #TODO: figure out why this code is here
    # it appears to nuke unqualfied email addresses if and only
    # if there is an owner
    if ($args{Email} && $args{Email} !~ /\@/ && $args{Owner}) {
	delete $args{Email};
    }

   #Make sure we've got a valid type
   #TODO --- move this to ValidateType 
   unless ($args{'Type'} =~ /^Requestor$/i ||
          $args{'Type'} =~ /^AdminCc$/i ||
          $args{'Type'} =~ /^Cc$/i) {
   	return (0, "Invalid Type");
    }

    my $id = $self->SUPER::Create(%args);
    $self->Load($id);
  
    #TODO: this is horrificially wasteful. we shouldn't commit 
    # to the db and then instantly turn around and load the same data

    return (1,"Interest noted");
}
# }}}
 
# {{{ sub Load 
sub Load  {
  my $self = shift;
  my $identifier = shift;
  
  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
	return (0, "That's not a numerical id");
  }
}
# }}}

# {{{ sub OwnerObj 
sub OwnerObj  {
    my $self = shift;
    if (!defined $self->{'OwnerObj'}) {
	require RT::User;
	$self->{'OwnerObj'} = RT::User->new($self->CurrentUser);
	if ($self->Owner) {
	    $self->{'OwnerObj'}->Load($self->Owner);
	} else {
	    return $RT::Nobody->UserObj;
	}
    }
    return ($self->{'OwnerObj'});
}
# }}}

# {{{ sub Email

=head2 Email

This custom data accessor does the right thing and returns
the 'Email' attribute of this Watcher object. If that's undefined,
it returns the 'EmailAddress' attribute of its 'Owner' object, which is
an RT::User object.

=cut

sub Email {
  my $self = shift;

  # IF Email is defined, return that. Otherwise, return the Owner's email address
  if (defined($self->SUPER::Email)) {
    return ($self->SUPER::Email);
  }
  elsif ($self->Owner) {
    return ($self->OwnerObj->EmailAddress);
  }
  else {
    return ("Data error");
    }
}
# }}}

# {{{ sub IsUser

=head2 IsUser

Returns true if this watcher object is tied to a user object. (IE it
isn't sending to some other email address).
Otherwise, returns undef

=cut

sub IsUser {
    my $self = shift;
    # if this watcher has an email address glued onto it,
    # return undef
    if (defined($self->SUPER::Email)) {
        return undef;
    }
    else {
        return 1;
    }
}


# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      Email => 'read/write',
	      Scope => 'read/write',
	      Value => 'read/write',
	      Type => 'read/write',
	      Quiet => 'read/write',
	      Owner => 'read/write'	      
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

1;
 
