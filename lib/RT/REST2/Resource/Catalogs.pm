package RT::REST2::Resource::Catalogs;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/catalogs/?$},
        block => sub { { collection_class => 'RT::Catalogs' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/catalogs/all/?$},
        block => sub {
            my ($match, $req) = @_;
            my $catalogs = RT::Catalogs->new($req->env->{"rt.current_user"});
            $catalogs->UnLimit;
            return { collection => $catalogs };
        },
    ),
}

__PACKAGE__->meta->make_immutable;

1;
