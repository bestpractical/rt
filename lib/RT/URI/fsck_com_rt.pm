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

use warnings;
use strict;

package RT::URI::fsck_com_rt;
use RT::Model::Ticket;

use base qw/RT::URI::base/;

=head2 LocalURIPrefix  

Returns the prefix for a local URI. 




=cut

sub local_uri_prefix {
    my $self = shift;

    my $prefix = $self->Scheme . "://" . RT->config->get('organization');

    return ($prefix);
}

=head2 object_type

=cut

sub object_type {
    my $self = shift;
    my $object = shift || $self->object;

    my $type = 'ticket';
    if ( ref($object) && ( ref($object) ne 'RT::Model::Ticket' ) ) {
        $type = ref($object);
    }

    return ($type);
}

=head2 URIForObject RT::Record

Returns the RT URI for a local RT::Record object


=cut

sub uri_for_object {
    my $self = shift;
    my $obj  = shift;
    return (  $self->local_uri_prefix . "/"
            . $self->object_type($obj) . "/"
            . $obj->id );
}

=head2 ParseURI URI

When handed an fsck.com-rt: URI, figures out things like whether its a local record and what its ID is

=cut

sub parse_uri {
    my $self = shift;
    my $uri  = shift;

    if ( $uri =~ /^\d+$/ ) {
        my $ticket = RT::Model::Ticket->new;
        $ticket->load($uri);
        $self->{'uri'}    = $ticket->uri;
        $self->{'object'} = $ticket;
        return ( $ticket->id );
    } else {
        $self->{'uri'} = $uri;
    }

    #If it's a local URI, load the ticket object and return its URI
    if ( $self->is_local ) {
        my $local_uri_prefix = $self->local_uri_prefix;
        if ( $self->{'uri'} =~ /^\Q$local_uri_prefix\E\/(.*?)\/(\d+)$/i ) {
            my $type = $1;
            my $id   = $2;

            if ( $type eq 'ticket' ) { $type = 'RT::Model::Ticket' }

            # We can instantiate any RT::Record subtype. but not anything else

            if ( UNIVERSAL::isa( $type, 'RT::Record' ) ) {
                my $record = $type->new;
                $record->load($id);

                if ( $record->id ) {
                    $self->{'object'} = $record;
                    return ( $record->id );
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

sub is_local {
    my $self             = shift;
    my $local_uri_prefix = $self->local_uri_prefix;
    if ( $self->{'uri'} =~ /^\Q$local_uri_prefix/i ) {
        return 1;
    } else {
        return undef;
    }
}

=head2 Object

Returns the object for this URI, if it's local. Otherwise returns undef.

=cut

sub object {
    my $self = shift;
    return ( $self->{'object'} );

}

=head2 Scheme

Return the URI scheme for RT records

=cut

sub scheme {
    my $self = shift;
    return "fsck.com-rt";
}

=head2 HREF

If this is a local ticket, return an HTTP url to it.
Otherwise, return its URI

=cut

sub href {
    my $self = shift;
    if (   $self->is_local
        && $self->object
        && ( $self->object_type eq 'ticket' ) )
    {
        return (  RT->config->get('WebURL')
                . "Ticket/Display.html?id="
                . $self->object->id );
    } else {
        return ( $self->URI );
    }
}

=head2 AsString

Returns either a localized string 'ticket #23' or the full URI if the object is not local

=cut

sub as_string {
    my $self = shift;
    if ( $self->is_local && $self->Object ) {
        return _( "%1 #%2", $self->object_type, $self->object->id );
    } else {
        return $self->uri;
    }
}

eval "require RT::URI::fsck_com_rt_Vendor";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/URI/fsck_com_rt_Vendor.pm} );
eval "require RT::URI::fsck_com_rt_Local";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/URI/fsck_com_rt_Local.pm} );

1;
