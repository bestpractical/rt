use strict;
use warnings;

package RT::IsPrincipalCollection;


=head2 principals_alias

Returns the string that represents this Users object's primary "Principals" alias.

=cut

sub principals_alias {
    my $self = shift;

    return $self->{'princ_alias'} ||= $self->join(
        alias1  => 'main',
        column1 => 'id',
        table2  => 'Principals',
        column2 => 'id'
    );
}

=head2 limit_to_enabled

Only find items that haven\'t been disabled

=cut

sub limit_to_enabled {
    my $self = shift;

    $self->limit(
        alias    => $self->principals_alias,
        column   => 'disabled',
        value    => '0',
        operator => '='
    );
}



=head2 member_of

takes one argument, a group's principal id. Limits the returned set
to members of a given group

=cut

sub member_of {
    my $self  = shift;
    my $group = shift;

    return _("No group specified") if ( !defined $group );

    my $groupalias = $self->new_alias('CachedGroupMembers');

    # join the principal to the groups table
    $self->join(
        alias1  => $self->principals_alias,
        column1 => 'id',
        alias2  => $groupalias,
        column2 => 'member_id',
    );

    $self->limit(
        alias    => $groupalias,
        column   => 'group_id',
        value    => "$group",
        operator => "="
    );
}

=head2 who_have_right { right => 'name', object => $rt_object , include_superusers => undef, recursive => undef, include_system_rights => undef, equiv_objects => [ ] }


find all users who the right right for this group, either individually
or as members of groups

If passed a queue object, with no id, it will find users who have that right for _any_ queue

=cut

sub who_have_right {
    my $self = shift;
    my %args = (
        right                    => undef,
        object                   => undef,
        include_system_rights    => 1,
        include_superusers       => 0,
        recursive                => 1,
        equiv_objects            => [],
        @_
    );

    if ( defined $args{'object_type'} || defined $args{'object_id'} ) {
        Jifty->log->fatal( "who_have_right called with the Obsolete object_id/Object_type API" );
        return (undef);
    }

    my $from_role = $self->clone;
    $from_role->who_have_role_right(%args);

    my $from_group = $self->clone;
    $from_group->who_have_group_right(%args);

    #XXX: DIRTY HACK
    use Jifty::DBI::Collection::Union;
    my $union = new Jifty::DBI::Collection::Union;
    $union->add($from_role);
    $union->add($from_group);
    %$self = %$union;
    bless $self, ref($union);

    return;
}


sub who_have_role_right {
    my $self = shift;
    my %args = (
        right                    => undef,
        object                   => undef,
        include_system_rights    => undef,
        include_superusers       => undef,
        recursive => 1,
        equiv_objects            => [],
        @_
    );

    my $groups = $self->_join_groups(%args);
    my $acl    = $self->_join_acl(%args);

    my ( $check_roles, $check_objects ) = ( '', '' );

    my @objects = $self->_get_equiv_objects(%args);

    if (@objects) {
        my @role_clauses;
        my @object_clauses;
        foreach my $obj (@objects) {
            my $type = ref($obj) ? ref($obj) : $obj;
            my $id;
            $id = $obj->id
                if ref($obj) && UNIVERSAL::can( $obj, 'id' ) && $obj->id;

            my $role_clause = "$groups.domain = '$type-Role'";

            # if we want mysql 4.0 use indexes here. we MUST convert that
            # field to integer and drop this quotes.
            $role_clause .= " AND $groups.instance = '$id'" if $id;
            push @role_clauses, "($role_clause)";
            my $object_clause = "$acl.object_type = '$type'";
            $object_clause .= " AND $acl.object_id = $id" if $id;
            push @object_clauses, "($object_clause)";

        }

        $check_roles .= join ' OR ', @role_clauses;
        $check_objects = join ' OR ', @object_clauses;
    } else {
        if ( !$args{'include_system_rights'} ) {
            $check_objects = "($acl.object_type != 'RT::System')";
        }
    }

    $self->_add_subclause( "Whichobject", "($check_objects)" );
    $self->_add_subclause( "WhichRole",   "($check_roles)" );

    $self->limit(
        alias       => $acl,
        column      => 'type',
        value       => "$groups.Type",
        quote_value => 0,
    );

    # no system user
    $self->limit(
        alias    => $self->principals_alias,
        column   => 'id',
        operator => '!=',
        value    => RT->system_user->id
    );
    return;
}


sub who_have_group_right {
    my $self = shift;
    my %args = (
        right                    => undef,
        object                   => undef,
        include_system_rights    => undef,
        include_superusers       => undef,
        recursive => 1,
        equiv_objects            => [],
        @_
    );

    # Find only rows where the Right granted is
    # the one we're looking up or _possibly_ superuser
    my $acl = $self->_join_acl(%args);

    my ($check_objects) = ('');
    my @objects = $self->_get_equiv_objects(%args);

    if (@objects) {
        my @object_clauses;
        foreach my $obj (@objects) {
            my $type = ref($obj) ? ref($obj) : $obj;
            my $id;
            $id = $obj->id
                if ref($obj) && UNIVERSAL::can( $obj, 'id' ) && $obj->id;

            my $object_clause = "$acl.object_type = '$type'";
            $object_clause .= " AND $acl.object_id   = $id" if $id;
            push @object_clauses, "($object_clause)";
        }

        $check_objects = join ' OR ', @object_clauses;
    } else {
        if ( !$args{'include_system_rights'} ) {
            $check_objects = "($acl.object_type != 'RT::System')";
        }
    }
    $self->_add_subclause( "Whichobject", "($check_objects)" );

    $self->_join_group_members_for_group_rights( %args, aclalias => $acl );

    # Find only members of groups that have the right.
    $self->limit(
        alias  => $acl,
        column => 'type',
        value  => 'Group',
    );

    # no system user
    $self->limit(
        alias    => $self->principals_alias,
        column   => 'id',
        operator => '!=',
        value    => RT->system_user->id
    );
    return;
}


=head2 who_belong_to_groups { Groups => ARRAYREF, recursive => 1 }

=cut

sub who_belong_to_groups {
    my $self = shift;
    my %args = (
        groups                   => undef,
        recursive => 1,
        @_
    );

    # Unprivileged users can't be granted real system rights.
    # is this really the right thing to be saying?
    $self->limit_to_privileged();

    my $group_members = $self->_join_group_members(%args);

    foreach my $groupid ( @{ $args{'groups'} } ) {
        $self->limit(
            alias            => $group_members,
            column           => 'group_id',
            value            => $groupid,
            quote_value      => 0,
            entry_aggregator => 'OR',
        );
    }
}


sub _join_group_members_for_group_rights {
    my $self          = shift;
    my %args          = (@_);
    my $group_members = $self->_join_group_members(%args);
    $self->limit(
        alias       => $args{'aclalias'},
        column      => 'principal',
        value       => "$group_members.group_id",
        quote_value => 0,
    );
}

sub _join_group_members {
    my $self = shift;
    my %args = (
        recursive => 1,
        @_
    );

    my $principals = $self->principals_alias;

    # The cachedgroupmembers table is used for unrolling group memberships
    # to allow fast lookups. if we bind to CachedGroupMembers, we'll find
    # all members of groups recursively. if we don't we'll find only 'direct'
    # members of the group in question
    my $group_members;
    if ( $args{'recursive'} ) {
        $group_members = $self->new_alias('CachedGroupMembers');
    } else {
        $group_members = $self->new_alias('GroupMembers');
    }

    $self->join(
        alias1  => $group_members,
        column1 => 'member_id',
        alias2  => $principals,
        column2 => 'id'
    );

    return $group_members;
}


sub _join_groups {
    my $self = shift;
    my %args = (@_);

    my $group_members = $self->_join_group_members(%args);
    my $groups        = $self->new_alias('Groups');
    $self->join(
        alias1  => $groups,
        column1 => 'id',
        alias2  => $group_members,
        column2 => 'group_id'
    );

    return $groups;
}

sub _join_acl {
    my $self = shift;
    my %args = (
        right              => undef,
        include_superusers => undef,
        @_,
    );

    my $acl = $self->new_alias('ACL');
    $self->limit(
        alias    => $acl,
        column   => 'right_name',
        operator => ( $args{right} ? '=' : 'IS NOT' ),
        value => $args{right} || 'NULL',
        entry_aggregator => 'OR'
    );
    if ( $args{'include_superusers'} and $args{'right'} ) {
        $self->limit(
            alias            => $acl,
            column           => 'right_name',
            operator         => '=',
            value            => 'SuperUser',
            entry_aggregator => 'OR'
        );
    }
    return $acl;
}

sub _get_equiv_objects {
    my $self = shift;
    my %args = (
        object                => undef,
        include_system_rights => undef,
        equiv_objects         => [],
        @_
    );
    return () unless $args{'object'};

    my @objects = ( $args{'object'} );
    if ( UNIVERSAL::isa( $args{'object'}, 'RT::Model::Ticket' ) ) {

        # If we're looking at ticket rights, we also want to look at the associated queue rights.
        # this is a little bit hacky, but basically, now that we've done the ticket roles magic,
        # we load the queue object and ask all the rest of our questions about the queue.

        # XXX: This should be abstracted into object itself
        if ( $args{'object'}->id ) {
            push @objects, $args{'object'}->acl_equivalence_objects;
        } else {
            push @objects, 'RT::Model::Queue';
        }
    }

    if ( $args{'include_system_rights'} ) {
        push @objects, 'RT::System';
    }
    push @objects, @{ $args{'equiv_objects'} };
    return grep $_, @objects;
}

1;
