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

package RT::REST2::Resource::TicketsBulk;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource';
with 'RT::REST2::Resource::Role::RequestBodyIsJSON' =>
  { type => 'ARRAY' };

use RT::REST2::Util qw(expand_uid);
use RT::REST2::Resource::Ticket;
use JSON ();

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new( regex => qr{^/tickets/bulk/?$} ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/tickets/bulk/(correspond|comment)$},
        block => sub { { type => shift->pos(1) } },
    )
}

has type => (
    is       => 'ro',
    isa      => 'Str',
);

sub post_is_create    { 1 }
sub create_path       { '/tickets/bulk' }
sub charsets_provided { [ 'utf-8' ] }
sub default_charset   { 'utf-8' }
sub allowed_methods   { [ 'PUT', 'POST' ] }

sub content_types_provided { [ { 'application/json' => sub {} } ] }
sub content_types_accepted { [ { 'application/json' => 'from_json' } ] }

sub from_json {
    my $self   = shift;
    my $params = JSON::decode_json( $self->request->content );

    my $method = $self->request->method;
    my @results;
    if ( $method eq 'PUT' ) {
        for my $param ( @$params ) {
            my $id = delete $param->{id};
            if ( $id && $id =~ /^\d+$/ ) {
                my $resource = RT::REST2::Resource::Ticket->new(
                    request      => $self->request,
                    response     => $self->response,
                    record_class => 'RT::Ticket',
                    record_id    => $id,
                );
                if ( $resource->resource_exists ) {
                    push @results, [ $id, $resource->update_record( $param ) ];
                    next;
                }
            }
            push @results, [ $id, 'Resource does not exist' ];
        }
    }
    else {
        for my $param ( @$params ) {
            if ( $self->type ) {
                my $id = delete $param->{id};
                if ( $id && $id =~ /^\d+$/ ) {
                    my $ticket = RT::Ticket->new($self->current_user);
                    $ticket->Load($id);
                    my $resource = RT::REST2::Resource::Message->new(
                        request      => $self->request,
                        response     => $self->response,
                        type         => $self->type,
                        record       => $ticket,
                    );

                    my @errors;

                    # Ported from RT::REST2::Resource::Message::from_json
                    if ( $param->{Attachments} ) {
                        foreach my $attachment ( @{ $param->{Attachments} } ) {
                            foreach my $field ( 'FileName', 'FileType', 'FileContent' ) {
                                push @errors, "$field is a required field for each attachment in Attachments"
                                    unless $attachment->{$field};
                            }
                        }
                    }

                    $param->{NoContent} = 1 unless $param->{Content};
                    if ( !$param->{NoContent} && !$param->{ContentType} ) {
                        push @errors, "ContentType is a required field for application/json";
                    }

                    if (@errors) {
                        push @results, [ $id, @errors ];
                        next;
                    }

                    my ( $return_code, @messages ) = $resource->_add_message(%$param);
                    push @results, [ $id, @messages ];
                }
                else {
                    push @results, [ $id, 'Resource does not exist' ];
                }
            }
            else {
                my $resource = RT::REST2::Resource::Ticket->new(
                    request      => $self->request,
                    response     => $self->response,
                    record_class => 'RT::Ticket',
                );
                my ( $ok, $msg ) = $resource->create_record($param);
                if ( ref($ok) || !$ok ) {
                    push @results, { message => $msg || "Create failed for unknown reason" };
                }
                else {
                    push @results, expand_uid( $resource->record->UID );
                }
            }
        }
    }

    $self->response->body( JSON::encode_json( \@results ) );
    return;
}

__PACKAGE__->meta->make_immutable;

1;
