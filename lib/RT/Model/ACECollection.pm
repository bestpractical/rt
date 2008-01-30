# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 name

  RT::Model::ACECollection - collection of RT ACE objects

=head1 SYNOPSIS

  use RT::Model::ACECollection;
my $ACL = RT::Model::ACECollection->new($CurrentUser);

=head1 description


=head1 METHODS


=cut

use strict;
use warnings;

package RT::Model::ACECollection;
use base qw/RT::SearchBuilder/;

=head2 next

Hand out the next ACE that was found

=cut

# {{{ limit_to_object

=head2 limit_to_object $object

Limit the ACL to rights for the object $object. It needs to be an RT::Record class.

=cut

sub limit_to_object {
    my $self = shift;
    my $obj  = shift;
    unless ( defined($obj)
        && ref($obj)
        && UNIVERSAL::can( $obj, 'id' )
        && $obj->id )
    {
        return undef;
    }
    $self->limit(
        column           => 'object_type',
        operator         => '=',
        value            => ref($obj),
        entry_aggregator => 'OR'
    );
    $self->limit(
        column           => 'object_id',
        operator         => '=',
        value            => $obj->id,
        entry_aggregator => 'OR',
        quote_value      => 0
    );

}

# }}}

# {{{ limit_Notobject

=head2 limit_Notobject $object

Limit the ACL to rights NOT on the object $object.  $object needs to be
an RT::Record class.

=cut

sub limitnot_object {
    my $self = shift;
    my $obj  = shift;
    unless ( defined($obj)
        && ref($obj)
        && UNIVERSAL::can( $obj, 'id' )
        && $obj->id )
    {
        return undef;
    }
    $self->limit(
        column           => 'object_type',
        operator         => '!=',
        value            => ref($obj),
        entry_aggregator => 'OR',
        subclause        => $obj->id
    );
    $self->limit(
        column           => 'object_id',
        operator         => '!=',
        value            => $obj->id,
        entry_aggregator => 'OR',
        quote_value      => 0,
        subclause        => $obj->id
    );
}

# }}}

# {{{ limit_ToPrincipal

=head2 limit_ToPrincipal { type => undef, id => undef, IncludeGroupMembership => undef }

Limit the ACL to the principal with principal_id id and principal_type Type

Id is not optional.
Type is.

if IncludeGroupMembership => 1 is specified, ACEs which apply to the principal due to group membership will be included in the resultset.


=cut

sub limit_to_principal {
    my $self = shift;
    my %args = (
        type                   => undef,
        id                     => undef,
        IncludeGroupMembership => undef,
        @_
    );
    if ( $args{'IncludeGroupMembership'} ) {
        my $cgm = $self->new_alias('CachedGroupMembers');
        $self->join(
            alias1  => 'main',
            column1 => 'principal_id',
            alias2  => $cgm,
            column2 => 'group_id'
        );
        $self->limit(
            alias            => $cgm,
            column           => 'member_id',
            operator         => '=',
            value            => $args{'id'},
            entry_aggregator => 'OR'
        );
    } else {
        if ( defined $args{'type'} ) {
            $self->limit(
                column           => 'principal_type',
                operator         => '=',
                value            => $args{'type'},
                entry_aggregator => 'OR'
            );
        }

        # if the principal id points to a user, we really want to point
        # to their ACL equivalence group. The machinations we're going through
        # lead me to start to suspect that we really want users and groups
        # to just be the same table. or _maybe_ that we want an object db.
        my $princ
            = RT::Model::Principal->new( current_user => RT->system_user );
        $princ->load( $args{'id'} );
        if ( $princ->principal_type eq 'User' ) {
            my $group
                = RT::Model::Group->new( current_user => RT->system_user );
            $group->load_acl_equivalence_group($princ);
            $args{'id'} = $group->principal_id;
        }
        $self->limit(
            column           => 'principal_id',
            operator         => '=',
            value            => $args{'id'},
            entry_aggregator => 'OR'
        );
    }
}

# }}}

# {{{ ExcludeDelegatedRights

=head2 ExcludeDelegatedRights 

Don't list rights which have been delegated.

=cut

sub exclude_delegated_rights {
    my $self = shift;
    $self->delegated_by( Id => 0 );
    $self->delegated_from( Id => 0 );
}

# }}}

# {{{ delegated_by

=head2 delegated_by { id => undef }

Limit the ACL to rights delegated by the principal whose Principal id is
B<Id>

Id is not optional.

=cut

sub delegated_by {
    my $self = shift;
    my %args = (
        id => undef,
        @_
    );
    $self->limit(
        column           => 'delegated_by',
        operator         => '=',
        value            => $args{'id'},
        entry_aggregator => 'OR'
    );

}

# }}}

# {{{ delegated_from

=head2 delegated_from { id => undef }

Limit the ACL to rights delegate from the ACE which has the id specified 
by the id parameter.

Id is not optional.

=cut

sub delegated_from {
    my $self = shift;
    my %args = (
        id => undef,
        @_
    );
    $self->limit(
        column           => 'delegated_from',
        operator         => '=',
        value            => $args{'id'},
        entry_aggregator => 'OR'
    );

}

# }}}

# {{{ sub next
sub next {
    my $self = shift;

    my $ACE = $self->SUPER::next();
    if ( ( defined($ACE) ) and ( ref($ACE) ) ) {

        if ($self->current_user->has_right(
                right  => 'ShowACL',
                object => $ACE->object
            )
            or $self->current_user->has_right(
                right  => 'ModifyACL',
                object => $ACE->object
            )
            )
        {
            return ($ACE);
        }

        #If the user doesn't have the right to show this ACE
        else {
            return ( $self->next() );
        }
    }

    #if there never was any ACE
    else {
        return (undef);
    }

}

# }}}

#wrap around _do_search  so that we can build the hash of returned
#values
sub _do_search {
    my $self = shift;

    # Jifty->log->debug("Now in ".$self."->_do_search");
    my $return = $self->SUPER::_do_search(@_);

#  Jifty->log->debug("In $self ->_do_search. return from SUPER::_do_search was $return\n");
    $self->{'must_redo_search'} = 0;
    $self->_is_limited(1);
    $self->_build_hash();
    return ($return);
}

#Build a hash of this ACL's entries.
sub _build_hash {
    my $self = shift;

    while ( my $entry = $self->next ) {
        my $hashkey
            = $entry->__value('object_type') . "-"
            . $entry->__value('object_id') . "-"
            . $entry->__value('right_name') . "-"
            . $entry->__value('principal_id') . "-"
            . $entry->__value('principal_type');

        $self->{'as_hash'}->{"$hashkey"} = 1;

    }
}

# {{{ HasEntry

=head2 HasEntry

=cut

sub has_entry {

    my $self = shift;
    my %args = (
        right_scope     => undef,
        right_applies_to => undef,
        right_name     => undef,
        principal_id   => undef,
        principal_type => undef,
        @_
    );

    #if we haven't done the search yet, do it now.
    $self->_do_search();

    if ($self->{'as_hash'}->{
                  $args{'right_scope'} . "-"
                . $args{'right_applies_to'} . "-"
                . $args{'right_name'} . "-"
                . $args{'principal_id'} . "-"
                . $args{'principal_type'}
        } == 1
        )
    {
        return (1);
    } else {
        return (undef);
    }
}

# }}}
1;
