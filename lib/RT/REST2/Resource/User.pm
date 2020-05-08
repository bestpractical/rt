package RT::REST2::Resource::User;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid);

extends 'RT::REST2::Resource::Record';
with (
    'RT::REST2::Resource::Record::Readable',
    'RT::REST2::Resource::Record::DeletableByDisabling',
    'RT::REST2::Resource::Record::Writable',
    'RT::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/user/?$},
        block => sub { { record_class => 'RT::User' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/user/(\d+)/?$},
        block => sub { { record_class => 'RT::User', record_id => shift->pos(1) } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/user/([^/]+)/?$},
        block => sub {
            my ($match, $req) = @_;
            my $user = RT::User->new($req->env->{"rt.current_user"});
            $user->Load($match->pos(1));
            return { record => $user };
        },
    ),
}

around 'serialize' => sub {
    my $orig = shift;
    my $self = shift;
    my $data = $self->$orig(@_);
    $data->{Privileged} = $self->record->Privileged ? 1 : 0;

    unless ( $self->record->CurrentUserHasRight("AdminUsers") or $self->record->id == $self->current_user->id ) {
        my $summary = { map { $_ => $data->{$_} }
                ( '_hyperlinks', 'Privileged', split( /\s*,\s*/, RT->Config->Get('UserSummaryExtraInfo') ) ) };
        return $summary;
    }

    $data->{Disabled}   = $self->record->PrincipalObj->Disabled;
    $data->{Memberships} = [
        map { expand_uid($_->UID) }
        @{ $self->record->OwnGroups->ItemsArrayRef }
    ];
    return $data;
};

sub forbidden {
    my $self = shift;
    return 0 if not $self->record->id;
    return 0 if $self->record->id == $self->current_user->id;
    return 0 if $self->current_user->Privileged;
    return 1;
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);

    if (   $self->record->CurrentUserHasRight('ShowUserHistory')
        or $self->record->CurrentUserHasRight("AdminUsers")
        or $self->record->id == $self->current_user->id )
    {
        push @$links, $self->_transaction_history_link;
    }

    # TODO Use the same right in UserGroups.pm.
    # Maybe loose it a bit so user can see groups?
    if ((   $self->current_user->HasRight(
                Right  => "ModifyOwnMembership",
                Object => RT->System,
            )
            && $self->current_user->id == $self->record->id
        )
        || $self->current_user->HasRight(
            Right  => 'AdminGroupMembership',
            Object => RT->System
        )
       )
    {

        my $id = $self->record->id;
        push @$links,
            {
            ref  => 'memberships',
            _url => RT::REST2->base_uri . "/user/$id/groups",
            };
    }

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;
