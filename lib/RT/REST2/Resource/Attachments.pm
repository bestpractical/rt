package RT::REST2::Resource::Attachments;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/attachments/?$},
        block => sub { { collection_class => 'RT::Attachments' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/transaction/(\d+)/attachments/?$},
        block => sub {
            my ($match, $req) = @_;
            my $txn = RT::Transaction->new($req->env->{"rt.current_user"});
            $txn->Load($match->pos(1));
            return { collection => $txn->Attachments };
        },
    )
}

__PACKAGE__->meta->make_immutable;

1;

