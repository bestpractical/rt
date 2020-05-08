package RT::REST2::Resource::CustomFieldValue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid);

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable',
     'RT::REST2::Resource::Record::Hypermedia',
     'RT::REST2::Resource::Record::Deletable',
     'RT::REST2::Resource::Record::Writable';

has 'customfield' => (
    is  => 'ro',
    isa => 'RT::CustomField',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/(\d+)/value/?$},
        block => sub {
            my ($match, $req) = @_;
            my $cf_id = $match->pos(1);
            my $cf = RT::CustomField->new($req->env->{"rt.current_user"});
            $cf->Load($cf_id);
            return { record_class => 'RT::CustomFieldValue', customfield => $cf }
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/(\d+)/value/(\d+)/?$},
        block => sub {
            my ($match, $req) = @_;
            my $cf_id = $match->pos(1);
            my $cf = RT::CustomField->new($req->env->{"rt.current_user"});
            $cf->Load($cf_id);
            return { record_class => 'RT::CustomFieldValue', record_id => shift->pos(2), customfield => $cf }
        },
    )
}

sub forbidden {
    my $self = shift;
    my $method = $self->request->method;
    if ($method eq 'GET') {
        return !$self->customfield->CurrentUserHasRight('SeeCustomField');
    } else {
        return !($self->customfield->CurrentUserHasRight('AdminCustomField') ||$self->customfield->CurrentUserHasRight('AdminCustomFieldValues'));
    }
}

sub create_record {
    my $self = shift;
    my $data = shift;

    my ($ok, $msg) = $self->customfield->AddValue(%$data);
    $self->record->Load($ok) if $ok;
    return ($ok, $msg);
}

sub delete_resource {
    my $self = shift;

    my ($ok, $msg) = $self->customfield->DeleteValue($self->record->id);
    return $ok;
}

sub hypermedia_links {
    my $self = shift;
    my $record = $self->record;
    my $cf = $self->customfield;

    my $class = blessed($record);
    $class =~ s/^RT:://;
    $class = lc $class;
    my $id = $record->id;

    my $cf_class = blessed($cf);
    $cf_class =~ s/^RT:://;
    $cf_class = lc $cf_class;
    my $cf_id = $cf->id;

    my $cf_entry = expand_uid($cf->UID);

    my $links = [
        {
            ref  => 'self',
            type => $class,
            id   => $id,
            _url => RT::REST2->base_uri . "/$cf_class/$cf_id/$class/$id",
        },
        {
            %$cf_entry,
            ref  => 'customfield',
        },
    ];

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;
