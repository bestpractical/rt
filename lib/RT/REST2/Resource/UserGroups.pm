# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::REST2::Resource::UserGroups;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Role::RequestBodyIsJSON' =>
  {type => 'ARRAY'};

has 'user' => (
    is  => 'ro',
    isa => 'RT::User',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/user/([^/]+)/groups/?$},
        block => sub {
            my ($match, $req) = @_;
            my $user_id = $match->pos(1);
            my $user = RT::User->new($req->env->{"rt.current_user"});
            $user->Load($user_id);

            return {user => $user, collection => $user->OwnGroups};
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/user/([^/]+)/group/(\d+)/?$},
        block => sub {
            my ($match, $req) = @_;
            my $user_id = $match->pos(1);
            my $group_id = $match->pos(2) || '';
            my $user = RT::User->new($req->env->{"rt.current_user"});
            $user->Load($user_id);
            my $collection = $user->OwnGroups();
            $collection->Limit(FIELD => 'id', VALUE => $group_id);
            return {user => $user, collection => $collection};
        },
    ),
}

sub forbidden {
    my $self = shift;
    return 0 if
        ($self->current_user->HasRight(
            Right  => "ModifyOwnMembership",
            Object => RT->System,
        ) && $self->current_user->id == $self->user->id) ||
        $self->current_user->HasRight(
            Right  => 'AdminGroupMembership',
            Object => RT->System);
    return 1;
}

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my @results;

    while (my $item = $collection->Next) {
        my $result = {
            type => 'group',
            id   => $item->id,
            _url => RT::REST2->base_uri . "/group/" . $item->id,
        };
        push @results, $result;
    }
    return {
        count       => scalar(@results)         + 0,
        total       => $collection->CountAll    + 0,
        per_page    => $collection->RowsPerPage + 0,
        page        => ($collection->FirstRow / $collection->RowsPerPage) + 1,
        items       => \@results,
    };
}

sub allowed_methods {
    my @ok = ('GET', 'HEAD', 'DELETE', 'PUT');
    return \@ok;
}

sub content_types_accepted {[{'application/json' => 'from_json'}]}

sub delete_resource {
    my $self = shift;
    my $collection = $self->collection;
    while (my $group = $collection->Next) {
        $RT::Logger->info('Delete user ' . $self->user->Name . ' from group '.$group->id);
        $group->DeleteMember($self->user->id);
    }
    return 1;
}

sub from_json {
    my $self   = shift;
    my $params = JSON::decode_json($self->request->content);
    my $user = $self->user;

    my $method = $self->request->method;
    my @results;
    if ($method eq 'PUT') {
        for my $param (@$params) {
            if ($param =~ /^\d+$/) {
                my $group = RT::Group->new($self->request->env->{"rt.current_user"});
                $group->Load($param);
                push @results, $group->AddMember($user->id);
            } else {
                push @results, [0, 'You should provide group id for each group user should be added'];
            }
        }
    }
    $self->response->body(JSON::encode_json(\@results));
    return;
}

__PACKAGE__->meta->make_immutable;

1;
