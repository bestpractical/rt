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

package RT::Record::Role::Lifecycle;
use Role::Basic;
use Scalar::Util qw(blessed);

=head1 NAME

RT::Record::Role::Lifecycle - Common methods for records which have a Lifecycle column

=head1 REQUIRES

=head2 L<RT::Record::Role>

=head2 LifecycleType

Used as a role parameter.  Must return a string of the type of lifecycles the
record consumes, i.e.  I<ticket> for L<RT::Queue>.

=head2 Lifecycle

A Lifecycle method which returns a lifecycle name is required.  Currently
unenforced at compile-time due to poor interactions with
L<DBIx::SearchBuilder::Record/AUTOLOAD>.  You'll hit run-time errors if this
method isn't available in consuming classes, however.

=cut

with 'RT::Record::Role';
requires 'LifecycleType';

# XXX: can't require column methods due to DBIx::SB::Record's AUTOLOAD
#requires 'Lifecycle';

=head1 PROVIDES

=head2 LifecycleObj

Returns an L<RT::Lifecycle> object for this record's C<Lifecycle>.  If called
as a class method, returns an L<RT::Lifecycle> object which is an aggregation
of all lifecycles of the appropriate type.

=cut

sub LifecycleObj {
    my $self = shift;
    my $type = $self->LifecycleType;
    my $fallback = $self->_Accessible( Lifecycle => "default" );

    unless (blessed($self) and $self->id) {
        return RT::Lifecycle->Load( Type => $type );
    }

    my $name = $self->Lifecycle || $fallback;
    my $res  = RT::Lifecycle->Load( Name => $name, Type => $type );
    unless ( $res ) {
        RT->Logger->error(
            sprintf "Lifecycle '%s' of type %s for %s #%d doesn't exist",
                    $name, $type, ref($self), $self->id);
        return RT::Lifecycle->Load( Name => $fallback, Type => $type );
    }
    return $res;
}

=head2 SetLifecycle

Validates that the specified lifecycle exists before updating the record.

Takes a lifecycle name.

=cut

sub SetLifecycle {
    my $self  = shift;
    my $value = shift || $self->_Accessible( Lifecycle => "default" );

    return (0, $self->loc('[_1] is not a valid lifecycle', $value))
        unless $self->ValidateLifecycle($value);

    return $self->_Set( Field => 'Lifecycle', Value => $value, @_ );
}

=head2 ValidateLifecycle

Takes a lifecycle name.  Returns true if it's an OK name and such lifecycle is
configured.  Returns false otherwise.

=cut

sub ValidateLifecycle {
    my $self  = shift;
    my $value = shift;
    return unless $value;
    return unless RT::Lifecycle->Load( Name => $value, Type => $self->LifecycleType );
    return 1;
}

=head2 ActiveStatusArray

Returns an array of all ActiveStatuses for the lifecycle

=cut

sub ActiveStatusArray {
    my $self = shift;
    return $self->LifecycleObj->Valid('initial', 'active');
}

=head2 InactiveStatusArray

Returns an array of all InactiveStatuses for the lifecycle

=cut

sub InactiveStatusArray {
    my $self = shift;
    return $self->LifecycleObj->Inactive;
}

=head2 StatusArray

Returns an array of all statuses for the lifecycle

=cut

sub StatusArray {
    my $self = shift;
    return $self->LifecycleObj->Valid( @_ );
}

=head2 IsValidStatus

Takes a status.

Returns true if STATUS is a valid status.  Otherwise, returns 0.

=cut

sub IsValidStatus {
    my $self  = shift;
    return $self->LifecycleObj->IsValid( shift );
}

=head2 IsActiveStatus

Takes a status.

Returns true if STATUS is a Active status.  Otherwise, returns 0

=cut

sub IsActiveStatus {
    my $self  = shift;
    return $self->LifecycleObj->IsValid( shift, 'initial', 'active');
}

=head2 IsInactiveStatus

Takes a status.

Returns true if STATUS is a Inactive status.  Otherwise, returns 0

=cut

sub IsInactiveStatus {
    my $self  = shift;
    return $self->LifecycleObj->IsInactive( shift );
}

1;
