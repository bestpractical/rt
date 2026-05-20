# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2026 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

package RT::REST2::Resource::Role::Rights;
use strict;
use warnings;

use Moose::Role;

my %admin_right = (
    'RT::Queue'       => 'AdminQueue',
    'RT::Class'       => 'AdminClass',
    'RT::Catalog'     => 'AdminCatalog',
    'RT::CustomField' => 'AdminCustomField',
    'RT::Group'       => 'AdminGroup',
);

=head1 NAME

RT::REST2::Resource::Role::Rights - Shared logic for rights management endpoints

=head1 DESCRIPTION

Provides permission checks, principal resolution, and ACE serialization
used by RT::REST2::Resource::Rights.

=head1 METHODS

=head2 rights_forbidden

Returns true if the current user lacks the admin right needed to manage
rights on the resource object.  Queue objects require AdminQueue, Catalog
objects require AdminCatalog, etc.  Global rights require SuperUser.

=cut

sub rights_forbidden {
    my $self = shift;
    my $obj  = $self->object;

    if ( ref($obj) eq 'RT::System' ) {
        return !$self->current_user->HasRight(
            Right  => 'SuperUser',
            Object => $RT::System,
        );
    }

    my $right = $admin_right{ ref($obj) }
        or return 1;    # unknown object type
    return !$obj->CurrentUserHasRight($right);
}

=head2 resolve_principal HASHREF

Resolves a User or Group from a grant/revoke request hash.  Accepts:

    { Group => "name" }
    { Group => 42 }
    { Group => { id => 42 } }
    { User  => "name" }
    { User  => { id => 10 } }

Returns C<($principal, $display_hashref)> on success, or
C<(undef, $error_message)> on failure.

=cut

sub resolve_principal {
    my ( $self, $item ) = @_;

    if ( exists $item->{Group} ) {
        my $spec  = $item->{Group};
        my $group = RT::Group->new( $self->current_user );
        if ( ref $spec eq 'HASH' ) {
            $group->Load( $spec->{id} );
        }
        elsif ( $spec =~ /^\d+$/ ) {
            $group->Load($spec);
        }
        else {
            # Try user-defined groups first, then system internal groups
            # (Everyone, Privileged, Unprivileged), then role groups
            # (Requestor, Owner, Cc, AdminCc, and custom roles).
            $group->LoadUserDefinedGroup($spec);
            unless ( $group->Id ) {
                $group->LoadSystemInternalGroup($spec);
            }
            unless ( $group->Id ) {
                my $obj = $self->object;
                $group->LoadRoleGroup( Object => $obj, Name => $spec )
                    if $obj && $obj->id;
            }
        }
        return ( undef, "Group not found" ) unless $group->Id;

        my $display = {
            Group => {
                id   => $group->Id + 0,
                Name => $group->Name,
                _url => RT::REST2->base_uri . '/group/' . $group->Id,
            }
        };
        return ( $group->PrincipalObj, $display );
    }

    if ( exists $item->{User} ) {
        my $spec = $item->{User};
        my $user = RT::User->new( $self->current_user );
        if ( ref $spec eq 'HASH' ) {
            $user->Load( $spec->{id} );
        }
        else {
            $user->Load($spec);
        }
        return ( undef, "User not found" ) unless $user->Id;

        my $display = {
            User => {
                id   => $user->Id + 0,
                Name => $user->Name,
                _url => RT::REST2->base_uri . '/user/' . $user->Id,
            }
        };
        return ( $user->PrincipalObj, $display );
    }

    return ( undef, "Group or User is required" );
}

=head2 serialize_ace ACE

Serializes an L<RT::ACE> object into a hash suitable for JSON output.
The hash contains the right name and either a User or Group key with
id, Name, and _url.  Respects C<fields[User]> and C<fields[Group]>
query parameters for sub-field expansion.

=cut

sub serialize_ace {
    my ( $self, $ace ) = @_;

    my $result = { Right => $ace->RightName };

    my $principal = $ace->PrincipalObj;
    my $group     = $principal->Object;

    if ( $group->Domain eq 'ACLEquivalence' ) {
        my $user = RT::User->new( $self->current_user );
        $user->Load( $group->Instance );
        if ( $user->Id ) {
            $result->{User} = {
                id   => $user->Id + 0,
                Name => $user->Name,
                _url => RT::REST2->base_uri . '/user/' . $user->Id,
            };
            if ( my $fields = $self->request->param('fields[User]') ) {
                for my $field ( split /,/, $fields ) {
                    $field =~ s/^\s+|\s+$//g;
                    my $val = $self->expand_field( $user, $field );
                    $result->{User}{$field} = $val if defined $val;
                }
            }
        }
    }
    else {
        $result->{Group} = {
            id   => $group->Id + 0,
            Name => $group->Name,
            _url => RT::REST2->base_uri . '/group/' . $group->Id,
        };
        if ( my $fields = $self->request->param('fields[Group]') ) {
            for my $field ( split /,/, $fields ) {
                $field =~ s/^\s+|\s+$//g;
                my $val = $self->expand_field( $group, $field );
                $result->{Group}{$field} = $val if defined $val;
            }
        }
    }

    return $result;
}

=head2 available_rights_for

Returns a hashref of available rights for the resource object, grouped
by category (General, Staff, Admin).

=cut

sub available_rights_for {
    my $self = shift;
    my $obj  = $self->object;

    my $right_cats = $obj->RightCategories;
    my $avail      = $obj->AvailableRights;

    my %categories;
    for my $right_name ( keys %$avail ) {
        my $cat = $right_cats->{$right_name} || 'General';
        $categories{$cat}{$right_name} = $avail->{$right_name};
    }

    return \%categories;
}

require RT::Base;
RT::Base->_ImportOverlays();

1;
