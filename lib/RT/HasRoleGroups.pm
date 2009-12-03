package RT::HasRoleGroups;

use strict;
use warnings;

sub current_user_can_modify_watchers {
    die "current_user_can_modify_watchers method must be implemented in the role user";
}

=head2 is_watcher { type => TYPE, principal => PRINCIPAL, email => EMAIL }

Takes a param hash with the attributes type and either principal or email:

=over 4

=item type is one of defined by C<roles> of this object.

=item principal is an id of L<RT::Model::Principal>

=item email can be provided instead of the principal

=back

Returns true if the specified principal (or the one corresponding to the
specified address) is a member of the role group for this object.

XX TODO: This should be Memoized. 

=cut

sub is_watcher {
    my $self = shift;
    my %args = (
        type        => 'requestor',
        principal   => undef,
        email       => undef,
        recursively => 1,
        @_
    );

    # Load the relevant group.
    my $group = RT::Model::Group->new;
    $group->load_role(
        object => $self,
        type   => $args{'type'},
    );
    return 0 unless $group->id;

    # Find the relevant principal.
    if ( !$args{'principal'} ) {
        return 0 unless $args{'email'};

        # Look up the specified user.
        my $user = RT::Model::User->new;
        $user->load_by_email( $args{'email'} );
        if ( $user->id ) {
            $args{'principal'} = $user;
        } else {
            # A non-existent user can't be a group member.
            return 0;
        }
    }

    # Ask if it has the member in question
    return $group->has_member( principal =>  $args{'principal'}, recursively => $args{'recursively'} );
}

=head2 add_watcher

add_watcher takes a parameter hash. The keys are as follows:

Type        One of requestor, cc, admin_cc

prinicpal_id The RT::Model::Principal id of the user or group that's being added as a watcher

email       The email address of the new watcher. If a user with this 
            email address can't be found, a new nonprivileged user will be created.

If the watcher you\'re trying to set has an RT account, set the principal paremeter to their User Id. Otherwise, set the email parameter to their email address.

=cut

sub add_watcher {
    my $self = shift;
    my %args = (
        type      => undef,
        principal => undef,
        email     => undef,
        @_
    );

#XXX: check if role is valid

    if ( $args{'email'} ) {
        my ( $addr ) = RT::EmailParser->parse_email_address( $args{email} );
        if ($addr) {
            $args{'email'} = $addr->address;
            my $user = RT::Model::User->new;
            $user->load_by_email( $args{'email'} );
            if ( $user->id ) {
                $args{'principal'} = $user;
                delete $args{'email'};
            }
            else {
                delete $args{'principal'};
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
        type      => undef,
        silent    => undef,
        principal => undef,
        email     => undef,
        @_
    );

    # load_or_create
    if ( $args{'email'} ) {
        my $user = RT::Model::User->new( current_user => RT->system_user );
        my ( $pid, $msg ) = $user->load_or_create_by_email( $args{'email'} );
        if ( $pid ) {
            $args{'principal'} = $pid;
        } else {
            return ( 0, _("Could not find or create user with email %1", $args{'email'}) );
        }
    }

    unless ( $args{'principal'} ) {
        Carp::confess("foo");
        Jifty->log->error("Invalid arguments for add_watcher");
        return ( 0, _("System internal error. Contact system administrator.") );
    }

    my $principal = RT::Model::Principal->new;
    $principal->load( $args{'principal'} );
    unless ( $principal->id ) {
        return ( 0, _("Could not find principal #%1", $args{'principal'}) );
    }

    my $group = RT::Model::Group->new;
    $group->create_role(
        object => $self,
        type   => $args{'type'},
    );

    if ( $group->has_member( principal => $principal) ) {
        return ( 0, _( 'That principal is already a %1', _( $args{'type'} ) ) );
    }

    my ( $m_id, $m_msg ) = $group->_add_member(
        principal => $principal,
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
            type      => 'add_watcher',
            new_value => $principal->id,
            field     => $args{'type'},
        );
    }

    return ( 1, _( 'Added principal as a %1', _( $args{'type'} ) ) );
}



=head2 delete_watcher { type => TYPE, principal => PRINCIPAL, email => EMAIL_ADDRESS }


Deletes a ticket watcher.  Takes two arguments:

Type  (one of requestor,cc,admin_cc)

and one of

principal (an RT::Model::Principal id of the watcher you want to remove)
    OR
email (the email address of an existing wathcer)


=cut

sub delete_watcher {
    my $self = shift;
    my %args = (
        type      => undef,
        principal => undef,
        email     => undef,
        @_
    );

    if ( $args{'email'} ) {
        my $user = RT::Model::User->new;
        $user->load_by_email( $args{'email'} );
        return ( 0, _("Could not find user with email %1", $args{'email'}) )
            unless $user->id;

        $args{'principal'} = $user->id;
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
        type      => undef,
        principal => undef,
        email     => undef,
        @_
    );

    if ( $args{'email'} ) {
        my $user = RT::Model::User->new;
        $user->load_by_email( $args{'email'} );
        return ( 0, _("Could not find user with email %1", $args{'email'}) )
            unless $user->id;

        $args{'principal'} = $user->id;
        delete $args{'email'};
    }

    unless ( $args{'principal'} ) {
        Jifty->log->error("Invalid arguments for delete_watcher");
        return ( 0, _("System internal error. Contact system administrator.") );
    }

    my $principal = RT::Model::Principal->new;
    $principal->load( $args{'principal'} );
    unless ( $principal->id ) {
        return ( 0, _("Could not find principal #%1", $args{'principal'}) );
    }

    # see if this user is already a watcher.

    my $group = RT::Model::Group->new;
    $group->load_role(
        object => $self,
        type   => $args{'type'},
    );
    if ( !$group->id && !$group->has_member( principal => $principal ) ) {
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

    my $obj = RT::Model::Group->new;
    $obj->load_role( object => $self, type => $role );
    return $obj;
}

=head2 create_role

Create role group for this object.

It will return a tuple ($group, $msg), on error group is undefined.

=cut

sub create_role {
    my $self = shift;
    my $type = shift;

    my $group = RT::Model::Group->new;
    my ($id, $msg) = $group->create_role(
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
