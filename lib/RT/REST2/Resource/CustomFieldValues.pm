package RT::REST2::Resource::CustomFieldValues;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

has 'customfield' => (
    is  => 'ro',
    isa => 'RT::CustomField',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/(\d+)/values/?$},
        block => sub {
            my ($match, $req) = @_;
            my $cf_id = $match->pos(1);
            my $cf = RT::CustomField->new($req->env->{"rt.current_user"});
            $cf->Load($cf_id);
            my $values = $cf->Values;
            return { customfield => $cf, collection => $values }
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

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my $cf = $self->customfield;
    my @results;

    while (my $item = $collection->Next) {
        my $result = {
            type => 'customfieldvalue',
            id   => $item->id,
            name   => $item->Name,
            _url => RT::REST2->base_uri . "/customfield/" . $cf->id . '/value/' . $item->id,
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

__PACKAGE__->meta->make_immutable;

1;
