package RT::REST2::Resource::Record::Hypermedia;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid expand_uri custom_fields_for);
use JSON qw(to_json);

sub hypermedia_links {
    my $self = shift;
    return [ $self->_self_link, $self->_rtlink_links, $self->_customfield_links, $self->_customrole_links ];
}

sub _self_link {
    my $self = shift;
    my $record = $self->record;

    my $class = blessed($record);
    $class =~ s/^RT:://;
    $class = lc $class;
    my $id = $record->id;

    return {
        ref     => 'self',
        type    => $class,
        id      => $id,
        _url    => RT::REST2->base_uri . "/$class/$id",
    };
}

sub _transaction_history_link {
    my $self = shift;
    my $self_link = $self->_self_link;
    return {
        ref     => 'history',
        _url    => $self_link->{_url} . '/history',
    };
}

my %link_refs = (
    DependsOn => 'depends-on',
    DependedOnBy => 'depended-on-by',
    MemberOf => 'parent',
    Members => 'child',
    RefersTo => 'refers-to',
    ReferredToBy => 'referred-to-by',
);

sub _rtlink_links {
    my $self = shift;
    my $record = $self->record;
    my @links;

    for my $relation (keys %link_refs) {
        my $ref = $link_refs{$relation};
        my $mode = $RT::Link::TYPEMAP{$relation}{Mode};
        my $type = $RT::Link::TYPEMAP{$relation}{Type};
        my $method = $mode . "Obj";

        my $links = $record->$relation;

        while (my $link = $links->Next) {
            my $entry;
            if ( $link->LocalTarget and $link->LocalBase ){
                # Internal links
                $entry = expand_uid($link->$method->UID);
            }
            else {
                # Links to external URLs
                $entry = expand_uri($link->$mode);
            }
            push @links, {
                %$entry,
                ref => $ref,
            };
        }
    }

    return @links;
}

sub _customfield_links {
    my $self = shift;
    my $record = $self->record;
    my @links;

    if (my $cfs = custom_fields_for($record)) {
        while (my $cf = $cfs->Next) {
            my $entry = expand_uid($cf->UID);
            push @links, {
                %$entry,
                ref => 'customfield',
                name => $cf->Name,
            };
        }
    }

    return @links;
}

sub _customrole_links {
    my $self = shift;
    my $record = $self->record;
    my @links;

    return unless $record->DOES('RT::Record::Role::Roles');

    for my $role ($record->Roles(UserDefined => 1)) {
        if ($role =~ /^RT::CustomRole-(\d+)$/) {
            my $cr = RT::CustomRole->new($record->CurrentUser);
            $cr->Load($1);
            if ($cr->Id) {
                my $entry = expand_uid($cr->UID);
                push @links, {
                    %$entry,
                    group_type => $cr->GroupType,
                    ref => 'customrole',
                };
            }
        }
    }

    return @links;
}

1;

