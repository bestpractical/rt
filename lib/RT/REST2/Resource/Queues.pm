package RT::Extension::REST2::Resource::Queues;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queues/?$},
        block => sub { { collection_class => 'RT::Queues' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queues/all/?$},
        block => sub {
            my ($match, $req) = @_;
            my $queues = RT::Queues->new($req->env->{"rt.current_user"});
            $queues->UnLimit;
            return { collection => $queues };
        },
    ),
}

__PACKAGE__->meta->make_immutable;

1;
