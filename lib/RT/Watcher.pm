# $Header$
# (c) 1996-2001 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::Watcher - RT Watcher object

=head1 SYNOPSIS

  use RT::Watcher;


=head1 DESCRIPTION

This module should never be called directly by client code. it\'s an internal module which
should only be accessed through exported APIs in Ticket, Queue and other similar objects.

=head1 METHODS

=begin testing

ok(require RT::TestHarness);
ok(require RT::Watcher);

=end testing

=cut

package RT::Watcher;
use RT::Record;
@ISA = qw(RT::Record);

# {{{ sub _Init 

sub _Init {
    my $self = shift;

    $self->{'table'} = "Watchers";
    return ( $self->SUPER::_Init(@_) );

}

# }}}

# {{{ sub Create 

=head2 Create PARAMHASH

Create a new watcher object with the following Attributes:

Scope:  Ticket or Queue
Value: Ticket or queue id
Type: Requestor, Cc or AdminCc.  Requestor is not supported for a scope of \'Queue\'
Email: The email address of the watcher.  If the email address maps to an RT User, this is resolved
to an Owner object instead.
Owner: The RT user id of the \'owner\' of this watcher object. 

=cut

sub Create {
    my $self = shift;
    my %args = (
        Owner => undef,
        Email => undef,
        Value => undef,
        Scope => undef,
        Type  => undef,
        Quiet => 0,
        @_    # get the real argumentlist
    );

    #Do we have someone this applies to?
    unless ( ( $args{'Owner'} =~ /^(\d+)$/ ) || ( $args{'Email'} =~ /\@/ ) ) {
        return ( 0, "No user or email address specified" );
    }

    #if we only have an email address, try to resolve it to an owner
    if ( $args{'Owner'} == 0 ) {
        my $User = new RT::User($RT::SystemUser);
        $User->LoadByEmail( $args{'Email'} );
        if ( $User->id ) {
            $args{'Owner'} = $User->id;
            delete $args{'Email'};
        }
    }

    if ( $args{'Type'} eq "Requestor" and $args{'Owner'} == 0 ) {

        # Requestors *MUST* have an account

        my $NewUser = RT::User->new($RT::SystemUser);
        my $Address = $NewUser->CanonicalizeEmailAddress( $args{'Email'} );

        my ( $Val, $Message ) = $NewUser->Create(
            Name         => $Address,
            EmailAddress => $Address,
            RealName     => $Address,
            Password     => undef,
            Privileged   => 0,
            Comments     => 'Autocreated on ticket submission'
        );
        return ( 0, "Could not create watcher for requestor" )
          unless $Val;
        if ( $NewUser->id ) {
            $args{'Owner'} = $NewUser->id;
            delete $args{'Email'};
        }
    }

    #Make sure we\'ve got a valid type
    #TODO --- move this to ValidateType 
    return ( 0, "Invalid Type" )
      unless ( $args{'Type'} =~ /^(Requestor|Cc|AdminCc)$/i );

    my $id = $self->SUPER::Create(%args);
    if ($id) {
        return ( 1, "Interest noted" );
    }
    else {
        return ( 0, "Error adding watcher" );
    }
}

# }}}

# {{{ sub Load 

=head2 Load ID
  
  Loads a watcher by the primary key of the watchers table ($Watcher->id)
  
=cut

sub Load {
    my $self       = shift;
    my $identifier = shift;

    if ( $identifier !~ /\D/ ) {
        $self->SUPER::LoadById($identifier);
    }
    else {
        return ( 0, "That's not a numerical id" );
    }
}

# }}}

# {{{ sub LoadByValue

=head2 LoadByValue PARAMHASH
  
LoadByValue takes a parameter hash with the following attributes:

  Email, Owner, Scope, Type, Value

The same rules enforced at create are enforced by Load.

Returns a tuple of (retval, msg). Retval is 1 on success and 0 on failure.
msg describes what happened in a human readable form.

=cut

sub LoadByValue {
    my $self = shift;
    my %args = (
        Email => undef,
        Owner => undef,
        Scope => undef,
        Type  => undef,
        Value => undef,
        @_
    );

    #TODO: all this code is being copied from Create. that\'s silly

    #Do we have someone this applies to?
    unless ( ( $args{'Owner'} =~ /^(\d*)$/ ) || ( $args{'Email'} =~ /\@/ ) ) {
        return ( 0, "No user or email address specified" );
    }

    #if we only have an email address, try to resolve it to an owner
    unless ( $args{'Owner'} ) {
        my $User = new RT::User($RT::SystemUser);
        $User->LoadByEmail( $args{'Email'} );
        if ( $User->id > 0 ) {
            $args{'Owner'} = $User->id;
            delete $args{'Email'};
        }
    }

    if ( ( defined( $args{'Type'} ) )
        and ( $args{'Type'} !~ /^(Requestor|Cc|AdminCc)$/i ) )
    {
        return ( 0, "Invalid Type" );
    }
    if ( $args{'Owner'} ) {
        $self->LoadByCols(
            Type  => $args{'Type'},
            Value => $args{'Value'},
            Owner => $args{'Owner'},
            Scope => $args{'Scope'},
        );
    }
    else {
        $self->LoadByCols(
            Type  => $args{'Type'},
            Email => $args{'Email'},
            Value => $args{'Value'},
            Scope => $args{'Scope'},
        );
    }
    unless ( $self->Id ) {
        return ( 0, "Couldn\'t find that watcher" );
    }
    return ( 1, "Watcher loaded" );
}

# }}}

# {{{ sub OwnerObj 

=head2 OwnerObj

Return an RT Owner Object for this Watcher, if we have one

=cut

sub OwnerObj {
    my $self = shift;
    if ( !defined $self->{'OwnerObj'} ) {
        require RT::User;
        $self->{'OwnerObj'} = RT::User->new( $self->CurrentUser );
        if ( $self->Owner ) {
            $self->{'OwnerObj'}->Load( $self->Owner );
        }
        else {
            return $RT::Nobody->UserObj;
        }
    }
    return ( $self->{'OwnerObj'} );
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
    if ( defined( $self->__Value('Email') ) ) {
        return ( $self->__Value('Email') );
    }
    elsif ( $self->Owner ) {
        return ( $self->OwnerObj->EmailAddress );
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

    if ( defined( $self->__Value('Email') ) ) {
        return undef;
    }
    else {
        return 1;
    }
}

# }}}

# {{{ sub _Accessible 
sub _Accessible {
    my $self = shift;
    my %Cols = (
        Email         => 'read/write',
        Scope         => 'read/write',
        Value         => 'read/write',
        Type          => 'read/write',
        Quiet         => 'read/write',
        Owner         => 'read/write',
        Creator       => 'read/auto',
        Created       => 'read/auto',
        LastUpdatedBy => 'read/auto',
        LastUpdated   => 'read/auto'
    );
    return ( $self->SUPER::_Accessible( @_, %Cols ) );
}

# }}}

1;

