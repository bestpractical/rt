# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::CustomRoles;
use base 'RT::SearchBuilder';

use RT::CustomRole;

=head1 NAME

RT::CustomRoles - collection of RT::CustomRole records

=head1 DESCRIPTION

Collection of L<RT::CustomRole> records. Inherits methods from L<RT::SearchBuilder>.

=head1 METHODS

=cut

=head2 Table

Returns name of the table where records are stored.

=cut

sub Table { 'CustomRoles'}

sub _Init {
    my $self = shift;

    $self->{'with_disabled_column'} = 1;

    return ( $self->SUPER::_Init(@_) );
}

sub _ObjectCustomRoleAlias {
    my $self = shift;
    return RT::ObjectCustomRoles->new( $self->CurrentUser )
        ->JoinTargetToThis( $self => @_ );
}

=head2 RegisterRoles

This declares all (enabled) custom roles to the L<RT::Record::Role::Roles>
subsystem, suitable for system startup.

=cut

sub RegisterRoles {
    my $class = shift;

    my $roles = $class->new(RT->SystemUser);
    $roles->UnLimit;

    while (my $role = $roles->Next) {
        $role->_RegisterAsRole;
    }
}

=head2 LimitToObjectId

Takes an ObjectId and limits the collection to custom roles applied to said object.

When called multiple times the ObjectId limits are joined with OR.

=cut

sub LimitToObjectId {
    my $self = shift;
    my $id = shift;
    $self->Limit(
        ALIAS           => $self->_ObjectCustomRoleAlias,
        FIELD           => 'ObjectId',
        OPERATOR        => '=',
        VALUE           => $id,
        ENTRYAGGREGATOR => 'OR'
    );
}

=head2 LimitToSingleValue

Limits the list of custom roles to only those that take a single value.

=cut

sub LimitToSingleValue {
    my $self = shift;
    $self->Limit(
        FIELD    => 'MaxValues',
        OPERATOR => '=',
        VALUE    => 1,
    );
}

=head2 LimitToMultipleValue

Limits the list of custom roles to only those that take multiple values.

=cut

sub LimitToMultipleValue {
    my $self = shift;
    $self->Limit(
        FIELD    => 'MaxValues',
        OPERATOR => '=',
        VALUE    => 0,
    );
}

=head2 ApplySortOrder

Sort custom roles according to the order provided by the object custom roles.

=cut

sub ApplySortOrder {
    my $self = shift;
    my $order = shift || 'ASC';
    $self->OrderByCols( {
        ALIAS => $self->_ObjectCustomRoleAlias,
        FIELD => 'SortOrder',
        ORDER => $order,
    } );
}

RT::Base->_ImportOverlays();

1;
