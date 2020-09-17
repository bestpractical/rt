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

package RT::REST2::Resource::Ownership;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use MIME::Base64;

extends 'RT::REST2::Resource';
use RT::REST2::Util qw( error_as_json );

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)/(take|untake|steal)$},
        block => sub {
            my ($match, $req) = @_;
            my $ticket = RT::Ticket->new($req->env->{"rt.current_user"});
            $ticket->Load($match->pos(1));
            return { record => $ticket, type => $match->pos(2) },
        },
    );
}

has record => (
    is       => 'ro',
    isa      => 'RT::Record',
    required => 1,
);

has type => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
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
    { 'application/octet-stream' => 'change_ownership' },
    { 'text/plain' => 'change_ownership' },
    { 'text/html' => 'change_ownership' },
    { 'application/x-www-form-urlencoded' => 'change_ownership' },
    { 'multipart/form-data' => 'change_ownership' },
    { 'application/json' => 'change_ownership' }
] }

sub change_ownership {
    my ($self, $args) = @_;

    my $user = $self->record->CurrentUser;

    my $ticket = $self->record;
    my $action = ucfirst($self->type);
    my ($status, $msg) = $ticket->$action();

    unless ($status) {
        return error_as_json(
            $self->response,
            \400,  $msg);
    }

    $self->response->body(JSON::to_json([$msg], { pretty => 1 }));

    return 1;
}

sub create_path {
    my $self = shift;
    my $id = $self->record->Id;
    return "/ticket/$id";
}

__PACKAGE__->meta->make_immutable;

1;

