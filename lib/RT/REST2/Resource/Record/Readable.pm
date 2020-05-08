package RT::REST2::Resource::Record::Readable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'record';
requires 'record_class';
requires 'current_user';
requires 'base_uri';

with 'RT::REST2::Resource::Record::WithETag';

use JSON ();
use RT::REST2::Util qw( serialize_record );
use Scalar::Util qw( blessed );

sub serialize {
    my $self = shift;
    my $record = $self->record;
    my $data = serialize_record($record);

    for my $field (keys %$data) {
        my $result = $data->{$field};
        if ($record->can($field . 'Obj')) {
            my $method = $field . 'Obj';
            my $obj = $record->$method;
            my $param_field = "fields[$field]";
            my @subfields = split(/,/, $self->request->param($param_field) || '');

            for my $subfield (@subfields) {
                my $subfield_result = $self->expand_field($obj, $subfield, $param_field);
                $result->{$subfield} = $subfield_result if defined $subfield_result;
            }
        }
        $data->{$field} = $result;
    }

    if ($self->does('RT::REST2::Resource::Record::Hypermedia')) {
        $data->{_hyperlinks} = $self->hypermedia_links;
    }

    return $data;
}

sub charsets_provided { [ 'utf-8' ] }
sub default_charset   {   'utf-8'   }

sub content_types_provided { [
    { 'application/json' => 'to_json' },
] }

sub to_json {
    my $self = shift;
    return JSON::to_json($self->serialize, { pretty => 1 });
}

1;
