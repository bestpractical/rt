package RT::HasRoleGroups;

use strict;
use warnings;

sub current_user_can_modify_watchers {
    die "current_user_can_modify_watchers method must be implemented in the role user";
}

=head2 is_watcher { type => TYPE, principal_id => PRINCIPAL_ID, email => EMAIL }

Takes a param hash with the attributes type and either principal_id or email:

=over 4

=item type is one of defined by L</roles> of this object.

=item principal_id is an id of L<RT::Model::Principal>

=item email can be provided instead of the principal

=back

Returns true if the specified principal (or the one corresponding to the
specified address) is a member of the role group for this object.

XX TODO: This should be Memoized. 

=cut

sub is_watcher {
    my $self = shift;
    my %args = (
        type         => 'requestor',
        principal_id => undef,
        email        => undef,
        recursively  => 1,
        @_
    );

    # Load the relevant group.
    my $group = RT::Model::Group->new( current_user => $self->current_user );
    $group->load_role_group(
        object => $self,
        type   => $args{'type'},
    );
    return 0 unless $group->id;

    # Find the relevant principal.
    if ( !$args{'principal_id'} ) {
        return 0 unless $args{'email'};

        # Look up the specified user.
        my $user = RT::Model::User->new( current_user => $self->current_user );
        $user->load_by_email( $args{'email'} );
        if ( $user->id ) {
            $args{'principal_id'} = $user->principal_id;
        } else {
            # A non-existent user can't be a group member.
            return 0;
        }
    }

    # Ask if it has the member in question
    return $group->has_member( $args{'principal_id'}, recursively => $args{'recursively'} );
}

=head2 add_watcher

add_watcher takes a parameter hash. The keys are as follows:

Type        One of requestor, cc, admin_cc

prinicpal_id The RT::Model::Principal id of the user or group that's being added as a watcher

email       The email address of the new watcher. If a user with this 
            email address can't be found, a new nonprivileged user will be created.

If the watcher you\'re trying to set has an RT account, set the principal_id paremeter to their User Id. Otherwise, set the email parameter to their email address.

=cut

sub add_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        principal_id => undef,
        email        => undef,
        @_
    );

#XXX: check if role is valid

    if ( $args{'email'} ) {
        my ( $addr ) = RT::EmailParser->parse_email_address( $args{email} );
        if ($addr) {
            $args{'email'} = $addr->address;
            my $user = RT::Model::User->new( current_user => $self->current_user );
            $user->load_by_email( $args{'email'} );
            if ( $user->id ) {
                $args{'principal_id'} = $user->id;
                delete $args{'email'};
            }
            else {
                delete $args{'principal_id'};
            }
        }
    }

    my ($status, $msg) = $self->current_user_can_modify_watchers(
        %args,
        action => 'add',
    );
    return ( $status, $msg || _("Permission Denied") )
        unless $status;

    return $self->_add_watcher(%args);
}

sub _add_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        silent       => undef,
        principal_id => undef,
        email        => undef,
        @_
    );

    # load_or_create
    if ( $args{'email'} ) {
        my $user = RT::Model::User->new( current_user => RT->system_user );
        my ( $pid, $msg ) = $user->load_or_create_by_email( $args{'email'} );
        if ( $pid ) {
            $args{'principal_id'} = $pid;
        } else {
            return ( 0, _("Could not find or create user with email %1", $args{'email'}) );
        }
    }

    unless ( $args{'principal_id'} ) {
        Jifty->log->error("Invalid arguments for add_watcher");
        return ( 0, _("System internal error. Contact system administrator.") );
    }

    my $principal = RT::Model::Principal->new( current_user => $self->current_user );
    $principal->load( $args{'principal_id'} );
    unless ( $principal->id ) {
        return ( 0, _("Could not find principal #%1", $args{'principal_id'}) );
    }

    my $group = RT::Model::Group->new( current_user => $self->current_user );
    $group->create_role_group(
        object => $self,
        type   => $args{'type'},
    );

    if ( $group->has_member($principal) ) {
        return ( 0, _( 'That principal is already a %1', _( $args{'type'} ) ) );
    }

    my ( $m_id, $m_msg ) = $group->_add_member(
        principal_id => $principal->id,
    );
    unless ($m_id) {
        Jifty->log->error(
            "Failed to add principal #". $principal->id
            ." as a member of group #". $group->id .": ". $m_msg
        );
        return ( 0, _( 'Could not make that principal a %1', _( $args{'type'} ) ) );
    }

    unless ( $args{'silent'} ) {
        $self->_new_transaction(
            type      => 'AddWatcher',
            new_value => $principal->id,
            field     => $args{'type'},
        );
    }

    return ( 1, _( 'Added principal as a %1', _( $args{'type'} ) ) );
}



=head2 delete_watcher { type => TYPE, principal_id => PRINCIPAL_ID, email => EMAIL_ADDRESS }


Deletes a ticket watcher.  Takes two arguments:

Type  (one of requestor,cc,admin_cc)

and one of

principal_id (an RT::Model::Principal id of the watcher you want to remove)
    OR
email (the email address of an existing wathcer)


=cut

sub delete_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        principal_id => undef,
        email        => undef,
        @_
    );

    if ( $args{'email'} ) {
        my $user = RT::Model::User->new( current_user => $self->current_user );
        $user->load_by_email( $args{'email'} );
        return ( 0, _("Could not find user with email %1", $args{'email'}) )
            unless $user->id;

        $args{'principal_id'} = $user->id;
        delete $args{'email'};
    }

    my ($status, $msg) = $self->current_user_can_modify_watchers(
        %args,
        action => 'delete',
    );
    return ( $status, $msg || _("Permission Denied") )
        unless $status;

    return $self->_delete_watcher( %args );
}

sub _delete_watcher {
    my $self = shift;
    my %args = (
        type         => undef,
        principal_id => undef,
        email        => undef,
        @_
    );

    if ( $args{'email'} ) {
        my $user = RT::Model::User->new( current_user => $self->current_user );
        $user->load_by_email( $args{'email'} );
        return ( 0, _("Could not find user with email %1", $args{'email'}) )
            unless $user->id;

        $args{'principal_id'} = $user->id;
        delete $args{'email'};
    }

    unless ( $args{'principal_id'} ) {
        Jifty->log->error("Invalid arguments for delete_watcher");
        return ( 0, _("System internal error. Contact system administrator.") );
    }

    my $principal = RT::Model::Principal->new( current_user => $self->current_user );
    $principal->load( $args{'principal_id'} );
    unless ( $principal->id ) {
        return ( 0, _("Could not find principal #%1", $args{'principal_id'}) );
    }

    # see if this user is already a watcher.

    my $group = RT::Model::Group->new( current_user => $self->current_user );
    $group->load_role_group(
        object => $self,
        type   => $args{'type'},
    );
    if ( !$group->id && !$group->has_member($principal) ) {
        return ( 0, _( 'That principal is not a %1', $args{'type'} ) );
    }

    my ( $m_id, $m_msg ) = $group->_delete_member( $principal->id );
    unless ($m_id) {
        Jifty->log->error(
            "Failed to delete principal #". $principal->id
            ." form group ". $group->id .": ". $m_msg
        );

        return ( 0, _( 'Could not remove that principal as a %1', $args{'type'} ) );
    }

    unless ( $args{'silent'} ) {
        $self->_new_transaction(
            type      => 'del_watcher',
            old_value => $principal->id,
            field     => $args{'type'}
        );
    }

    return ( 1, _( "%1 is no longer a %2.", $principal->object->name, $args{'type'} ) );
}

=head2 role_group

Returns an L<RT::Model::Group> role object by its name, for example:

    my $group = $ticket->role_group("requestor");

=cut

sub role_group {
    my $self = shift;
    my $role = shift;

    my $obj = RT::Model::Group->new( current_user => $self->current_user );
    $obj->load_role_group( object => $self, type => $role );
    return $obj;
}

=head2 create_role_group

Create role group for this object.

It will return a tuple ($group, $msg), on error group is undefined.

=cut

sub create_role_group {
    my $self = shift;
    my $type = shift;

    my $group = RT::Model::Group->new( current_user => $self->current_user );
    my ($id, $msg) = $group->create_role_group(
        object => $self,
        type   => $type,
    );
    unless ($id) {
        Jifty->log->error( "Couldn't create '$type' role group for ". ref($self) ." #" . $self->id . ": ". $msg );
        return (undef, $msg);
    }

    return ($group, $msg);
}

1;
