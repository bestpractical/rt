# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

package RT::Record::Role::LookupType;

use strict;
use warnings;
use 5.010;

use Role::Basic;
use Scalar::Util qw(blessed);

=head1 NAME

RT::Record::Role::LookupType - Common methods for records which have a LookupType

=head1 DESCRIPTION

Certain records, like custom fields, can be applied to different types of
records (tickets, transactions, groups, users, etc). This role implements
such I<LookupType> concerns.

This role does not manage concerns relating to specifying which records
of a class (as in L<RT::ObjectCustomField>).

=head1 REQUIRES

=head2 L<RT::Record::Role>

=head2 LookupType

A C<LookupType> method which returns this record's lookup type is required.
Currently unenforced at compile-time due to poor interactions with
L<DBIx::SearchBuilder::Record/AUTOLOAD>.  You'll hit run-time errors if
this method isn't available in consuming classes, however.

=cut

with 'RT::Record::Role';

=head1 PROVIDES

=head2 RegisterLookupType LOOKUPTYPE OPTIONS

Tell RT that a certain object accepts records of this role via a lookup
type. I<OPTIONS> is a hash reference for which the following keys are
used:

=over 4

=item FriendlyName

The string to display in the UI to users for this lookup type

=back

For backwards compatibility, I<OPTIONS> may also be a string which is
interpreted as specifying the I<FriendlyName>.

Examples:

    'RT::Queue-RT::Ticket'                 => "Tickets",                # loc
    'RT::Queue-RT::Ticket-RT::Transaction' => "Ticket Transactions",    # loc
    'RT::User'                             => "Users",                  # loc
    'RT::Group'                            => "Groups",                 # loc
    'RT::Queue'                            => "Queues",                 # loc

This is a class method.

=cut

my %REGISTRY = ();

sub RegisterLookupType {
    my $class = shift;
    my $path = shift;
    my $options = shift;

    die "RegisterLookupType is a class method" if blessed($class);

    $options = {
        FriendlyName => $options,
    } if !ref($options);

    $REGISTRY{$class}{$path} = $options;
}

=head2 LookupTypes

Returns an array of LookupTypes available for this record or class

=cut

sub LookupTypes {
    my $self = shift;
    my $class = blessed($self) || $self;
    return sort keys %{ $REGISTRY{ $class } };
}

=head2 LookupTypeRegistration [PATH] [OPTION]

Returns the arguments of calls to L</RegisterLookupType>. With no arguments, returns a hash of hashes,
where the first-level key is the path (corresponding with L<RT::Record/CustomFieldLookupType>) and
the second-level hash is the option names. If path and option are provided, it looks up in that
nested hash structure to provide the desired information.

=cut

sub LookupTypeRegistration {
    my $self = shift;
    my $class = blessed($self) || $self;

    my $path = shift
        or return %{ $REGISTRY{$class}};

    my $option = shift
        or return %{ $REGISTRY{$class}{$path}};

    return $REGISTRY{$class}{$path}{$option};
}

=head2 FriendlyLookupType

Returns a localized description of the LookupType of this record

=cut

sub FriendlyLookupType {
    my $self = shift;
    my $lookup = shift || $self->LookupType;

    my $class = blessed($self) || $self;

    if (my $friendly = $self->LookupTypeRegistration($lookup, 'FriendlyName')) {
        return $self->loc($friendly);
    }

    my @types = map { s/^RT::// ? $self->loc($_) : $_ }
      grep { defined and length }
      split( /-/, $lookup )
      or return;

    state $LocStrings = [
        "[_1] objects",            # loc
        "[_1]'s [_2] objects",        # loc
        "[_1]'s [_2]'s [_3] objects",   # loc
    ];
    return ( $self->loc( $LocStrings->[$#types], @types ) );
}

=head1 RecordClassFromLookupType

Returns the type of Object referred to by ObjectCustomFields' ObjectId column.
(The first part of the LookupType, e.g. the C<RT::Queue> of
C<RT::Queue-RT::Ticket-RT::Transaction>)

Optionally takes a LookupType to use instead of using the value on the loaded
record.  In this case, the method may be called on the class instead of an
object.

=cut

sub RecordClassFromLookupType {
    my $self = shift;
    my $type = shift || $self->LookupType;
    my ($class) = ($type =~ /^([^-]+)/);
    unless ( $class ) {
        if (blessed($self) and $self->LookupType eq $type) {
            $RT::Logger->error(
                "Custom Field #". $self->id
                ." has incorrect LookupType '$type'"
            );
        } else {
            RT->Logger->error("Invalid LookupType passed as argument: $type");
        }
        return undef;
    }
    return $class;
}

=head1 ObjectTypeFromLookupType

Returns the ObjectType for this record. (The last part of the LookupType,
e.g. the C<RT::Transaction> of C<RT::Queue-RT::Ticket-RT::Transaction>)

Optionally takes a LookupType to use instead of using the value on the loaded
record.  In this case, the method may be called on the class instead of an
object.

=cut

sub ObjectTypeFromLookupType {
    my $self = shift;
    my $type = shift || $self->LookupType;
    my ($class) = ($type =~ /([^-]+)$/);
    unless ( $class ) {
        if (blessed($self) and $self->LookupType eq $type) {
            $RT::Logger->error(
                blessed($self) . " #". $self->id
                ." has incorrect LookupType '$type'"
            );
        } else {
            RT->Logger->error("Invalid LookupType passed as argument: $type");
        }
        return undef;
    }
    return $class;
}

sub CollectionClassFromLookupType {
    my $self = shift;

    my $record_class = $self->RecordClassFromLookupType;
    return undef unless $record_class;

    my $collection_class;
    if ( UNIVERSAL::can($record_class.'Collection', 'new') ) {
        $collection_class = $record_class.'Collection';
    } elsif ( UNIVERSAL::can($record_class.'es', 'new') ) {
        $collection_class = $record_class.'es';
    } elsif ( UNIVERSAL::can($record_class.'s', 'new') ) {
        $collection_class = $record_class.'s';
    } else {
        $RT::Logger->error("Can not find a collection class for record class '$record_class'");
        return undef;
    }
    return $collection_class;
}

=head1 IsOnlyGlobal

Certain record types (users, groups) should only be added globally;
codify that set here for reference.

=cut

sub IsOnlyGlobal {
    my $self = shift;

    return ($self->LookupType =~ /^RT::(?:Group|User)/io);

}

1;

