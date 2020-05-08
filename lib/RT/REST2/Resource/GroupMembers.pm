package RT::REST2::Resource::GroupMembers;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Role::RequestBodyIsJSON' =>
  {type => 'ARRAY'};

has 'group' => (
    is  => 'ro',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/(\d+)/members/?$},
        block => sub {
            my ($match, $req) = @_;
            my $group_id = $match->pos(1);
            my $group = RT::Group->new($req->env->{"rt.current_user"});
            $group->Load($group_id);
            my $collection;

            my $recursively = $req->parameters->{recursively} // 0;
            my $users       = $req->parameters->{users} // 1;
            my $groups      = $req->parameters->{groups} // 1;

            if ( $users && $groups ) {
                if ( $recursively ) {
                    $collection = $group->DeepMembersObj;
                }
                else {
                    $collection = $group->MembersObj;
                }
            }
            elsif ( $users ) {
                $collection = $group->UserMembersObj(Recursively => $recursively);
            }
            elsif ( $groups ) {
                $collection = $group->GroupMembersObj(Recursively => $recursively);
            }
            else {
                $collection = RT::GroupMembers->new( $req->env->{"rt.current_user"} );
                $collection->Limit(FIELD => 'id', VALUE => 0);
            }

            return {group => $group, collection => $collection};
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/(\d+)/member/(\d+)/?$},
        block => sub {
            my ($match, $req) = @_;
            my $group_id = $match->pos(1);
            my $member_id = $match->pos(2) || '';
            my $group = RT::Group->new($req->env->{"rt.current_user"});
            $group->Load($group_id);
            my $collection = $group->MembersObj;
            $collection->Limit(FIELD => 'MemberId', VALUE => $member_id);
            return {group => $group, collection => $collection};
        },
    ),
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->group->id;
    return !$self->group->CurrentUserHasRight('AdminGroupMembership');
    return 1;
}

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my @results;

    while (my $item = $collection->Next) {
        my ($id, $class);
        if (ref $item eq 'RT::GroupMember' || ref $item eq 'RT::CachedGroupMember') {
            my $principal = $item->MemberObj;
            $class = $principal->IsGroup ? 'group' : 'user';
            $id = $principal->id;
        } elsif (ref $item eq 'RT::Group') {
            $class = 'group';
            $id = $item->id;
        } elsif (ref $item eq 'RT::User') {
            $class = 'user';
            $id = $item->id;
        }
        else {
            next;
        }

        my $result = {
            type => $class,
            id   => $id,
            _url => RT::REST2->base_uri . "/$class/$id",
        };
        push @results, $result;
    }
    return {
        count       => scalar(@results) + 0,
        total       => $collection->CountAll,
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
    while (my $group_member = $collection->Next) {
        $RT::Logger->info('Delete ' . ($group_member->MemberObj->IsGroup ? 'group' : 'user') . ' ' . $group_member->MemberId . ' from group '.$group_member->GroupId);
        $group_member->GroupObj->Object->DeleteMember($group_member->MemberId);
    }
    return 1;
}

sub from_json {
    my $self   = shift;
    my $params = JSON::decode_json($self->request->content);
    my $group = $self->group;

    my $method = $self->request->method;
    my @results;
    if ($method eq 'PUT') {
        for my $param (@$params) {
            if ($param =~ /^\d+$/) {
                my ($ret, $msg) = $group->AddMember($param);
                push @results, $msg;
            } else {
                push @results, 'You should provide principal id for each member to add';
            }
        }
    }
    $self->response->body(JSON::encode_json(\@results));
    return;
}

__PACKAGE__->meta->make_immutable;

1;
