# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

package RT::Record::Role::Principal;
use Role::Basic;

=head1 NAME

RT::Record::Role::Principal - Common methods for records which have a Principal object

=cut

with 'RT::Record::Role';

=head1 REQUIRES

=head2 PrincipalField or PrincipalId column

The field that stores the principal's id.

=head1 PROVIDES

=head2 PrincipalId

Returns this object's PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    my $field = $self->can('PrincipalField') ? $self->PrincipalField : 'PrincipalId';
    return $self->__Value($field);
}

=head2 PrincipalObj

Returns the principal object for this object. returns an empty RT::Principal
if there's no principal object matching this object.
The response is cached. PrincipalObj should never ever change.

=cut

sub PrincipalObj {
    my $self = shift;

    unless ( $self->{_cached}{PrincipalObj} && $self->{_cached}{PrincipalObj}->Id ) {
        $self->{_cached}{PrincipalObj} = RT::Principal->new( $self->CurrentUser );
        if ( my $principal_id = $self->PrincipalId ) {
            my ( $ret, $msg ) = $self->{_cached}{PrincipalObj}->Load( $principal_id );
            if ( !$ret ) {
                RT->Logger->warning( "Couldn't load principal #" . $self->id . ": $msg" );
            }
        }
    }
    return $self->{_cached}{PrincipalObj};
}

1;
