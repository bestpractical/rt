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

package RT::URI::fsck_com_rt;
use base 'RT::URI::base';

=head2 LocalURIPrefix  

Returns the prefix for a local URI. 

=cut

sub LocalURIPrefix {
    my $self = shift;
    
    my $prefix = $self->Scheme. "://". RT->Config->Get('Organization');

    return ($prefix);
}

=head2 ObjectType

=cut

sub ObjectType {
    my $self = shift;
    my $object = shift || $self->Object;

    my $type = 'ticket';
    if (ref($object) && (ref($object) ne 'RT::Ticket')) {
        $type = ref($object);
    }

    return ($type);
}


=head2 URIForObject RT::Record

Returns the RT URI for a local RT::Record object

=cut

sub URIForObject {
    my $self = shift;
    my $obj = shift;
    return ($self->LocalURIPrefix ."/". $self->ObjectType($obj) ."/". $obj->Id);
}


=head2 ParseURI URI

When handed an fsck.com-rt: URI, figures out things like whether its a local record and what its ID is

=cut


sub ParseURI {
    my $self = shift;
    my $uri  = shift;

    if ( $uri =~ /^\d+$/ ) {
        use RT::Ticket;
        my $ticket = RT::Ticket->new( $self->CurrentUser );
        $ticket->Load( $uri );
        $self->{'uri'} = $ticket->URI;
        $self->{'object'} = $ticket;
        return ($ticket->id);
    }
    else {
        $self->{'uri'} = $uri;
    }

    #If it's a local URI, load the ticket object and return its URI
    if ( $self->IsLocal ) {
        my $local_uri_prefix = $self->LocalURIPrefix;
        if ( $self->{'uri'} =~ /^\Q$local_uri_prefix\E\/(.*?)\/(\d+)$/i ) {
            my $type = $1;
            my $id   = $2;

            if ( $type eq 'ticket' ) { $type = 'RT::Ticket' }

            # We can instantiate any RT::Record subtype. but not anything else

            if ( UNIVERSAL::isa( $type, 'RT::Record' ) ) {
                my $record = $type->new( $self->CurrentUser );
                $record->Load($id);

                if ( $record->Id ) {
                    $self->{'object'} = $record;
                    return ( $record->Id );
                }
            }

        }
    }
    return undef;
}

=head2 IsLocal 

Returns true if this URI is for a local ticket.
Returns undef otherwise.

=cut

sub IsLocal {
    my $self = shift;
    my $local_uri_prefix = $self->LocalURIPrefix;
    if ( $self->{'uri'} =~ /^\Q$local_uri_prefix/i ) {
        return 1;
    }
    else {
        return undef;
    }
}


=head2 Object

Returns the object for this URI, if it's local. Otherwise returns undef.

=cut

sub Object {
    my $self = shift;
    return ($self->{'object'});
}

=head2 Scheme

Return the URI scheme for RT records

=cut


sub Scheme {
    my $self = shift;
    return "fsck.com-rt";
}

=head2 HREF

If this is a local ticket, return an HTTP url to it.
Otherwise, return its URI

=cut


sub HREF {
    my $self = shift;
    return $self->URI unless $self->IsLocal;

    my $obj = $self->Object;
    if ( $obj && $self->ObjectType eq 'ticket' ) {
        return RT->Config->Get('WebURL') ."Ticket/Display.html?id=". $obj->id;
    }

    return $self->URI;
}

=head2 AsString

Returns either a localized string C<#23: Subject> for tickets, C<ObjectType #13:
Name> for other object types (not really used), or the full URI if the object
is not local.

=cut

sub AsString {
    my $self = shift;
    if ($self->IsLocal && ( my $object = $self->Object )) {
        if ($object->isa('RT::Ticket')) {
            return $self->loc("#[_1]: [_2]", $object->Id, $object->Subject || '');
        } else {
            my $name = $object->_Accessible('Name', 'read') ? $object->Name : undef;

            if ( defined $name and length $name ) {
                return $self->loc("[_1] #[_2]: [_3]", $self->ObjectType, $object->Id, $name);
            } else {
                return $self->loc("[_1] #[_2]", $self->ObjectType, $object->Id);
            }
        }
    }
    else {
        return $self->URI;
    }
}

RT::Base->_ImportOverlays();

1;
