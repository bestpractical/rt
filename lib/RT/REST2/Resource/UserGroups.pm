package RT::Extension::REST2::Resource::UserGroups;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Role::RequestBodyIsJSON' =>
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
            _url => RT::Extension::REST2->base_uri . "/group/" . $item->id,
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
