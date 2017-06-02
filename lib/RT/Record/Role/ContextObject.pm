# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

package RT::Record::Role::ContextObject;

use strict;
use warnings;
use 5.010;

use Role::Basic;
use Scalar::Util qw(blessed);

=head1 NAME

RT::Record::Role::ContextObject - Common methods for records which have a ContextObject

=head1 DESCRIPTION

=head1 REQUIRES

=head2 L<RT::Record::Role>

=head2 L<RT::Record::Role::LookupType>

=head2 IsGlobal

=head2 IsOnlyGlobal

=head2 IsAdded

=cut

with 'RT::Record::Role';

=head2 ACLEquivalenceObjects

Adds the context object's ACLEquivalenceObjects.

=cut

sub ACLEquivalenceObjects {
    my $self = shift;

    my $ctx = $self->ContextObject
        or return;
    return ($ctx, $ctx->ACLEquivalenceObjects);
}

=head2 ContextObject and SetContextObject

Set or get a context for this object. It can be ticket, queue or another
object. Used for ACL control, for example
SeeCustomField can be granted on queue level to allow people to see all
fields added to the queue.

=cut

sub SetContextObject {
    my $self = shift;
    return $self->{'context_object'} = shift;
}

sub ContextObject {
    my $self = shift;
    return $self->{'context_object'};
}

sub ValidContextType {
    my $self = shift;
    my $class = shift;

    my %valid;
    $valid{$_}++ for split '-', $self->LookupType;
    delete $valid{'RT::Transaction'};

    return $valid{$class};
}

=head2 LoadContextObject

Takes an Id for a Context Object and loads the right kind of RT::Object
for this particular Custom Field (based on the LookupType) and returns it.
This is a good way to ensure you don't try to use a Queue as a Context
Object on a User Custom Field.

=cut

sub LoadContextObject {
    my $self = shift;
    my $type = shift;
    my $contextid = shift;

    unless ( $self->ValidContextType($type) ) {
        RT->Logger->debug("Invalid ContextType $type for Custom Field ".$self->Id);
        return;
    }

    my $context_object = $type->new( $self->CurrentUser );
    my ($id, $msg) = $context_object->LoadById( $contextid );
    unless ( $id ) {
        RT->Logger->debug("Invalid ContextObject id: $msg");
        return;
    }
    return $context_object;
}

=head2 ValidateContextObject

Ensure that a given ContextObject applies to this Custom Field.  For
custom fields that are assigned to Queues or to Classes, this checks
that the Custom Field is actually added to that object.  For Global
Custom Fields, it returns true as long as the Object is of the right
type, because you may be using your permissions on a given Queue of
Class to see a Global CF.  For CFs that are only added globally, you
don't need a ContextObject.

=cut

sub ValidateContextObject {
    my $self = shift;
    my $object = shift;

    return 1 if $self->IsGlobal;

    # global only custom fields don't have objects
    # that should be used as context objects.
    return if $self->IsOnlyGlobal;

    # Otherwise, make sure we weren't passed a user object that we're
    # supposed to treat as a queue.
    return unless $self->ValidContextType(ref $object);

    # Check that it is added correctly
    my ($added_to) = grep {ref($_) eq $self->RecordClassFromLookupType} ($object, $object->ACLEquivalenceObjects);
    return unless $added_to;
    return $self->IsAdded($added_to->id);
}

1;

