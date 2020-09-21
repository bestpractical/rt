# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Merge;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use MIME::Base64;

extends 'RT::REST2::Resource';
use RT::REST2::Util qw( error_as_json );

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)/merge$},
        block => sub {
            my ($match, $req) = @_;
            my $ticket = RT::Ticket->new($req->env->{"rt.current_user"});
            $ticket->Load($match->pos(1));
            return { record => $ticket };
        },
    );
}

has record => (
    is       => 'ro',
    isa      => 'RT::Record',
    required => 1,
);

has merged_ticket_id => (
    is       => 'rw',
    isa      => 'Maybe[Int]'
);

sub post_is_create            { 1 }
sub create_path_after_handler { 1 }
sub allowed_methods           { ['PUT'] }
sub charsets_provided         { [ 'utf-8' ] }
sub default_charset           { 'utf-8' }
sub content_types_provided    { [ { 'application/json' => sub {} } ] }

# Web::Machine uses 'application/octet-stream' as default content-type if
# none provided. We accept empty POST so may receive empty content-type.
sub content_types_accepted    { [
    { 'application/x-www-form-urlencoded' => 'from_form' },
    { 'multipart/form-data' => 'from_form' },
    { 'application/json' => 'from_json' }
] }


sub from_json {
    my $self = shift;
    my $payload = shift || JSON::decode_json( $self->request->content );
    my $destination_ticket_id = $payload->{MergeIntoTicket};

    # throw error unless we have a ticket id.
    return error_as_json(
        $self->response,
        \400, "MergeIntoTicket is a required field")
            unless $destination_ticket_id;

    return $self->merge_ticket($destination_ticket_id);
}

sub from_form {
    my $self = shift;
    my $destination_ticket_id = $self->request->parameters->{MergeIntoTicket};

    # throw error unless we have a ticket id.
    return error_as_json(
        $self->response,
        \400, "MergeIntoTicket is a required field")
        unless $destination_ticket_id;

    return $self->merge_ticket($destination_ticket_id);
}

sub merge_ticket {
    my ($self, $destination_ticket_id) = @_;

    my $source_ticket = $self->record;

    my ($status, $msg) = $source_ticket->MergeInto($destination_ticket_id);
    unless ($status) {
        return error_as_json(
            $self->response,
            \400,  $msg);
    }

    $self->merged_ticket_id($destination_ticket_id);
    $self->response->body(JSON::to_json([$msg], { pretty => 1 }));

    return 1;
}

sub create_path {
    return '/ticket/' . shift->merged_ticket_id;
}

__PACKAGE__->meta->make_immutable;

1;

