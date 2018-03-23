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

package RT::Record::Role::Status;
use Role::Basic;
use Scalar::Util qw(blessed);

=head1 NAME

RT::Record::Role::Status - Common methods for records which have a Status column

=head1 DESCRIPTION

Lifecycles are generally set on container records, and Statuses on records
which belong to one of those containers.  L<RT::Record::Role::Lifecycle>
handles the containers with the I<Lifecycle> column.  This role is for the
records with a I<Status> column within those containers.  It includes
convenience methods for grabbing an L<RT::Lifecycle> object as well setters for
validating I<Status> and the column which points to the container object.

=head1 REQUIRES

=head2 L<RT::Record::Role>

=head2 LifecycleColumn

Used as a role parameter.  Must return a string of the column name which points
to the container object that consumes L<RT::Record::Role::Lifecycle> (or
conforms to it).  The resulting string is used to construct two method names:
as-is to fetch the column value and suffixed with "Obj" to fetch the object.

=head2 Status

A Status method which returns a lifecycle name is required.  Currently
unenforced at compile-time due to poor interactions with
L<DBIx::SearchBuilder::Record/AUTOLOAD>.  You'll hit run-time errors if this
method isn't available in consuming classes, however.

=cut

with 'RT::Record::Role';
requires 'LifecycleColumn';

=head1 PROVIDES

=head2 Status

Returns the Status for this record, in the canonical casing.

=cut

sub Status {
    my $self = shift;
    my $value = $self->_Value( 'Status' );
    my $lifecycle = $self->LifecycleObj;
    return $value unless $lifecycle;
    return $lifecycle->CanonicalCase( $value );
}

=head2 LifecycleObj

Returns an L<RT::Lifecycle> object for this record's C<Lifecycle>.  If called
as a class method, returns an L<RT::Lifecycle> object which is an aggregation
of all lifecycles of the appropriate type.

=cut

sub LifecycleObj {
    my $self = shift;
    my $obj  = $self->LifecycleColumn . "Obj";
    return $self->$obj->LifecycleObj;
}

=head2 Lifecycle

Returns the L<RT::Lifecycle/Name> of this record's L</LifecycleObj>.

=cut

sub Lifecycle {
    my $self = shift;
    return $self->LifecycleObj->Name;
}

=head2 ValidateStatus

Takes a status.  Returns true if that status is a valid status for this record,
otherwise returns false.

=cut

sub ValidateStatus {
    my $self = shift;
    return $self->LifecycleObj->IsValid(@_);
}

=head2 ValidateStatusChange

Validates the new status with the current lifecycle.  Returns a tuple of (OK,
message).

Expected to be called from this role's L</SetStatus> or the consuming class'
equivalent.

=cut

sub ValidateStatusChange {
    my $self = shift;
    my $new  = shift;
    my $old  = $self->Status;

    my $lifecycle = $self->LifecycleObj;

    unless ( $lifecycle->IsValid( $new ) ) {
        return (0, $self->loc("Status '[_1]' isn't a valid status for this [_2].", $self->loc($new), $self->loc($lifecycle->Type)));
    }

    unless ( $lifecycle->IsTransition( $old => $new ) ) {
        return (0, $self->loc("You can't change status from '[_1]' to '[_2]'.", $self->loc($old), $self->loc($new)));
    }

    my $check_right = $lifecycle->CheckRight( $old => $new );
    unless ( $self->CurrentUser->HasRight( Right => $check_right, Object => $self ) ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    return 1;
}

=head2 SetStatus

Validates the status transition before updating the Status column.  This method
may want to be overridden by a more specific method in the consuming class.

=cut

sub SetStatus {
    my $self = shift;
    my $new  = shift;

    my ($valid, $error) = $self->ValidateStatusChange($new);
    return ($valid, $error) unless $valid;

    return $self->_SetStatus( Status => $new );
}

=head2 _SetStatus

Sets the Status column without validating the change.  Intended to be used
as-is by methods provided by the role, or overridden in the consuming class to
take additional action.  For example, L<RT::Ticket/_SetStatus> sets the Started
and Resolved dates on the ticket as necessary.

Takes a paramhash where the only required key is Status.  Other keys may
include Lifecycle and NewLifecycle when called from L</_SetLifecycleColumn>,
which may assist consuming classes.  NewLifecycle defaults to Lifecycle if not
provided; this indicates the lifecycle isn't changing.

=cut

sub _SetStatus {
    my $self = shift;
    my %args = (
        Status      => undef,
        Lifecycle   => $self->LifecycleObj,
        @_,
    );
    $args{Status} = lc $args{Status} if defined $args{Status};
    $args{NewLifecycle} ||= $args{Lifecycle};

    return $self->_Set(
        Field   => 'Status',
        Value   => $args{Status},
    );
}

=head2 _SetLifecycleColumn

Validates and updates the column named by L</LifecycleColumn>.  The Status
column is also updated if necessary (via lifecycle transition maps).

On success, returns a tuple of (1, I<message>, I<new status>) where I<new
status> is the status that was transitioned to, if any.  On failure, returns
(0, I<error message>).

Takes a paramhash with keys I<Value> and (optionally) I<RequireRight>.
I<RequireRight> is a right name which the current user must have on the new
L</LifecycleColumn> object in order for the method to succeed.

This method is expected to be used from within another method such as
L<RT::Ticket/SetQueue>.

=cut

sub _SetLifecycleColumn {
    my $self = shift;
    my %args = @_;

    my $column     = $self->LifecycleColumn;
    my $column_obj = "${column}Obj";

    my $current = $self->$column_obj;
    my $class   = blessed($current);

    my $new = $class->new( $self->CurrentUser );
    $new->Load($args{Value});

    return (0, $self->loc("[_1] [_2] does not exist", $self->loc($column), $args{Value}))
        unless $new->id;

    my $name = eval { $current->Name } || $current->id;

    return (0, $self->loc("[_1] [_2] is disabled", $self->loc($column), $name))
        if $new->Disabled;

    return (0, $self->loc("[_1] is already set to [_2]", $self->loc($column), $name))
        if $new->id == $current->id;

    return (0, $self->loc("Permission Denied"))
        if $args{RequireRight} and not $self->CurrentUser->HasRight(
            Right   => $args{RequireRight},
            Object  => $new,
        );

    my $new_status;
    my $old_lifecycle = $current->LifecycleObj;
    my $new_lifecycle = $new->LifecycleObj;
    if ( $old_lifecycle->Name ne $new_lifecycle->Name ) {
        unless ( $old_lifecycle->HasMoveMap( $new_lifecycle ) ) {
            return ( 0, $self->loc("There is no mapping for statuses between lifecycle [_1] and [_2]. Contact your system administrator.", $old_lifecycle->Name, $new_lifecycle->Name) );
        }
        $new_status = $old_lifecycle->MoveMap( $new_lifecycle )->{ lc $self->Status };
        return ( 0, $self->loc("Mapping between lifecycle [_1] and [_2] is incomplete. Contact your system administrator.", $old_lifecycle->Name, $new_lifecycle->Name) )
            unless $new_status;
    }

    my ($ok, $msg) = $self->_Set( Field => $column, Value => $new->id );
    if ($ok) {
        if ( $new_status and $new_status ne $self->Status ) {
            my $as_system = blessed($self)->new( RT->SystemUser );
            $as_system->Load( $self->Id );
            unless ( $as_system->Id ) {
                return ( 0, $self->loc("Couldn't load copy of [_1] #[_2]", blessed($self), $self->Id) );
            }

            my ($val, $msg) = $as_system->_SetStatus(
                Lifecycle       => $old_lifecycle,
                NewLifecycle    => $new_lifecycle,
                Status          => $new_status,
            );

            if ($val) {
                # Pick up the change made by the clone above
                $self->Load( $self->id );
            } else {
                RT->Logger->error("Status change to $new_status failed on $column change: $msg");
                undef $new_status;
            }
        }
        return (1, $msg, $new_status);
    } else {
        return (0, $msg);
    }
}

1;
