# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK

no warnings qw(redefine);
use RT::Group;
use RT::User;

# {{{ IsGroup

=head2 IsGroup

Returns true if this principal is a group. 
Returns undef, otherwise

=cut

sub IsGroup {
    my $self = shift;
    if ($self->PrincipalType eq 'Group') {
        return(1);
    }
    else {
        return undef;
    }
}

# }}}

# {{{ IsUser

=head2 IsUser 

Returns true if this principal is a User. 
Returns undef, otherwise

=cut

sub IsUser {
    my $self = shift;
    if ($self->PrincipalType eq 'User') {
        return(1);
    }
    else {
        return undef;
    }
}

# }}}

# {{{ Object

=head2 Object

Returns the user or group associated with this principal

=cut

sub Object {
    my $self = shift;

    unless ($self->{'object'}) {
    if ($self->IsUser) {
       $self->{'object'} = RT::User->new($self->CurrentUser);
    }
    elsif ($self->IsGroup) {
        $self->{'object'}  = RT::Group->new($self->CurrentUser);
    }
    else { 
        $RT::Logger->crit("Found a principal (".$self->Id.") that was neither a user nor a group");
        return(undef);
    }
    $self->{'object'}->Load($self->ObjectId());
    }
    return ($self->{'object'});


}
# }}} 

# {{{ ACL Related routines

        

# {{{ GrantRight 

=head2 GrantRight  { Right => RIGHTNAME, ObjectType => undef, ObjectId => 0 }

A helper function which calls RT::ACE->Create

=cut

sub GrantRight {
    my $self = shift;
    my %args = ( Right => undef,
                ObjectType => undef,
                ObjectId => 0,
                @_);

    #ACL check handled in ACE.pm
    my $ace = RT::ACE->new( $self->CurrentUser );


    my $type = $self->_GetPrincipalTypeForACL();

    # If it's a user, we really want to grant the right to their 
    # user equivalence group
        return ( $ace->Create(RightName => $args{'Right'},
                          ObjectType => $args{'ObjectType'},
                          ObjectId => $args{'ObjectId'},
                          PrincipalType =>  $type,
                          PrincipalId => $self->Id
                          ) );
}
# }}}

# {{{ RevokeRight

=head2 RevokeRight { Right => "RightName", ObjectType => "object type", ObjectId => "object id" }

Delete a right that a user has 

=cut

sub RevokeRight {

    my $self = shift;
    my %args = (
        Right      => undef,
        ObjectType => undef,
        ObjectId   => 0,
        @_
    );

    #ACL check handled in ACE.pm
    my $type = $self->_GetPrincipalTypeForACL();

    my $ace = RT::ACE->new( $self->CurrentUser );
    $ace->LoadByValues(
        RightName     => $args{'Right'},
        ObjectType    => $args{'ObjectType'},
        ObjectId      => $args{'ObjectId'},
        PrincipalType => $type,
        PrincipalId   => $self->Id
    );

    unless ( $ace->Id ) {
        return ( 0, $self->loc("ACE not found") );
    }
    return ( $ace->Delete );
}

# }}}

# {{{ _GetPrincipalTypeForACL

=head2 _GetPrincipalTypeForACL

Gets the principal type. if it's a user, it's a user. if it's a role group and it has a Type, 
return that. if it has no type, return group.

=cut

sub _GetPrincipalTypeForACL {
    my $self = shift;
    my $type;    
    if ($self->PrincipalType eq 'Group' && $self->Object->Domain =~ /Role$/) {
        $type = $self->Object->Type;
    }
    else {
        $type = $self->PrincipalType;
    }

    return($type);
}

# }}}
1;
