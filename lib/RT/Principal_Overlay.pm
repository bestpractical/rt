
no warnings qw(redefine);
use RT::Group;
use RT::User;

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

# {{{ ACL Related routines

# {{{ GrantQueueRight

=head2 GrantQueueRight

Grant a queue right to this user.  Takes a paramhash of which the elements
ObjectId and RightName are important.

=cut

sub GrantQueueRight {

    my $self = shift;
    my %args = (
        ObjectType     => 'Queue',
        Right      => undef,
        ObjectId => undef,
        @_
    );
    $self->_GrantRight(%args);

}
    
# }}}
        
# {{{ GrantSystemRight
        
=head2 GrantSystemRight
    
Grant a system right to this user. 
The only element that's important to set is RightName.

=cut

sub GrantSystemRight {  

    my $self = shift;   
    my %args = (
        Right      => undef,
        ObjectType     => 'System',
        ObjectId => 0,
        @_
    );

    $self->_GrantRight(%args);
}

# }}}

# {{{ _GrantRight 

=head2 _GrantRight 

A helper function which calls RT::ACE->Create

=cut

sub _GrantRight {
    my $self = shift;
    my %args = ( Right => undef,
                ObjectType => undef,
                ObjectId => undef,
                @_);

    #ACL check handled in ACE.pm
    my $ace = RT::ACE->new( $self->CurrentUser );

    return ( $ace->Create(RightName => $args{'Right'},
                          ObjectType => $args{'ObjectType'},
                          ObjectId => $args{'ObjectId'},
                          PrincipalType => $self->PrincipalType,
                          PrincipalId => $self->Id
                          ) );
}

# }}}

# {{{ RevokeSystemRight

=head2 RevokeSystemRight { Right => "right name" }

Revoke a system right for this user
The only element that's important to set is RightName.

=cut

sub RevokeSystemRight {

    my $self = shift;
    my %args = (
        Right      => undef,
        @_
    );

    return ($self->_RevokeRight(ObjectType => 'System', ObjectId => '0', RightName => $args{'Right'}));

}

# }}}

# {{{ RevokeQueueRight

=head2 RevokeQueueRight { Right => "right name", ObjectId => "queue id" }

Revoke a Queue right for this user
The only element that's important to set is RightName.

=cut

sub RevokeQueueRight {
    my $self = shift;
    my %args = (
        Right      => undef,
        ObjectId       => undef,
        @_
    );

    return ($self->_RevokeRight(ObjectType => 'Queue', ObjectId => $args{'ObjectId'}, Right => $args{'Right'}));

}

# }}}

# {{{ _RevokeRight

=head2 _RevokeRight { Right => "RightName", ObjectType => "object type", ObjectId => "object id" }

Delete a right that a user has 

=cut

sub _RevokeRight {

    my $self = shift;
    my %args = (
        Right     => undef,
        ObjectType     => undef,
        ObjectId => undef,
        @_
    );

    #ACL check handled in ACE.pm

    my $ace = RT::ACE->new( $self->CurrentUser );
    $ace->LoadByValues( RightName => $args{'Right'},
                        ObjectType => $args{'ObjectType'},
                        ObjectId => $args{'ObjectId'},
                        PrincipalType => $self->PrincipalType,
                        PrincipalId => $self->Id);


    unless ($ace->Id) {
        return(0, $self->loc("ACE could not be found"));
    }
    return($ace->Delete);

}

# }}}




1;
