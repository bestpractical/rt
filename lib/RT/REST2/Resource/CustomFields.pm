package RT::REST2::Resource::CustomFields;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

has 'object_applied_to' => (
    is  => 'ro',
    required => 0,
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfields/?$},
        block => sub { { collection_class => 'RT::CustomFields' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/(catalog|class|queue)/(\d+)/customfields/?$},
        block => sub {
            my ($match, $req) = @_;
            my $object_type = 'RT::'. ucfirst($match->pos(1));
            my $object_id = $match->pos(2);
            my $object_applied_to = $object_type->new($req->env->{"rt.current_user"});
            $object_applied_to->Load($object_id);
            return {object_applied_to => $object_applied_to, collection_class => 'RT::CustomFields'};
        },
    ),
}

after 'limit_collection' => sub {
    my $self = shift;
    my $collection = $self->collection;
    my $object = $self->object_applied_to;
    if ($object && $object->id) {
        $collection->Limit(ENTRYAGGREGATOR => "AND", FIELD => 'LookupType', OPERATOR => 'STARTSWITH', VALUE => ref($object));
        $collection->LimitToGlobalOrObjectId($object->id);
    }
    return 1;
};

__PACKAGE__->meta->make_immutable;

1;

