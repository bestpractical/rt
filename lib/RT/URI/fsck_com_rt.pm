# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
package RT::URI::fsck_com_rt;

use RT::Ticket;

use RT::URI::base;

use strict;
use vars qw(@ISA);
@ISA = qw/RT::URI::base/;




=head2 LocalURIPrefix  

Returns the prefix for a local URI. 

=begin testing

use_ok("RT::URI::fsck_com_rt");
my $uri = RT::URI::fsck_com_rt->new($RT::SystemUser);

ok(ref($uri));

use Data::Dumper;


ok (UNIVERSAL::isa($uri,RT::URI::fsck_com_rt), "It's an RT::URI::fsck_com_rt");

ok ($uri->isa('RT::URI::base'), "It's an RT::URI::base");
ok ($uri->isa('RT::Base'), "It's an RT::Base");

is ($uri->LocalURIPrefix , 'fsck.com-rt://example.com');

=end testing



=cut

sub LocalURIPrefix {
    my $self = shift;
    
    my $prefix = $self->Scheme. "://$RT::Organization";

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

=begin testing

my $ticket = RT::Ticket->new($RT::SystemUser);
$ticket->Load(1);
my $uri = RT::URI::fsck_com_rt->new($ticket->CurrentUser);
is($uri->LocalURIPrefix. "/ticket/1" , $uri->URIForObject($ticket));

=end testing

=cut

sub URIForObject {
    my $self = shift;
    my $obj = shift;
    return ($self->LocalURIPrefix."/".$self->ObjectType($obj)."/". $obj->Id);
}


=head2 ParseURI URI

When handed an fsck.com-rt: URI, figures out things like whether its a local record and what its ID is

=cut


sub ParseURI {
    my $self = shift;
    my $uri  = shift;

    if ( $uri =~ /^(\d+)$/ ) {
        my $ticket = RT::Ticket->new( $self->CurrentUser );
        $ticket->Load($uri);
        $self->{'uri'} = $ticket->URI;
        $self->{'object'} = $ticket;
        return($ticket->id);
    }
    else {
        $self->{'uri'} = $uri;
    }

    #If it's a local URI, load the ticket object and return its URI
    if ( $self->IsLocal ) {

        my $local_uri_prefix = $self->LocalURIPrefix;
        if ( $self->{'uri'} =~ /^$local_uri_prefix\/(.*?)\/(\d+)$/i ) {
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
	if ($self->{'uri'} =~ /^$local_uri_prefix/i) {
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
    if ($self->IsLocal && $self->Object && ($self->ObjectType eq 'ticket')) {
        return ( $RT::WebURL . "Ticket/Display.html?id=".$self->Object->Id);
    }   
    else {
        return ($self->URI);
    }
}

=head2 AsString

Returns either a localized string 'ticket #23' or the full URI if the object is not local

=cut

sub AsString {
    my $self = shift;
    if ($self->IsLocal && $self->Object) {
	    return $self->loc("[_1] #[_2]", $self->ObjectType, $self->Object->Id);
    }
    else {
	    return $self->URI;
    }
}

eval "require RT::URI::fsck_com_rt_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI/fsck_com_rt_Vendor.pm});
eval "require RT::URI::fsck_com_rt_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI/fsck_com_rt_Local.pm});

1;
