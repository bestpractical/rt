package RT::Extension::REST2::Resource::Transactions;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::Extension::REST2::Resource::Collection';
with 'RT::Extension::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/transactions/?$},
        block => sub { { collection_class => 'RT::Transactions' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/(ticket|queue|asset|user|group)/(\d+)/history/?$},
        block => sub {
            my ($match, $req) = @_;
            my ($class, $id) = ($match->pos(1), $match->pos(2));

            my $record;
            if ($class eq 'ticket') {
                $record = RT::Ticket->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'queue') {
                $record = RT::Queue->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'asset') {
                $record = RT::Asset->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'user') {
                $record = RT::User->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'group') {
                $record = RT::Group->new($req->env->{"rt.current_user"});
            }

            $record->Load($id);
            return { collection => $record->Transactions };
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/(queue|user)/([^/]+)/history/?$},
        block => sub {
            my ($match, $req) = @_;
            my ($class, $id) = ($match->pos(1), $match->pos(2));

            my $record;
            if ($class eq 'queue') {
                $record = RT::Queue->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'user') {
                $record = RT::User->new($req->env->{"rt.current_user"});
            }

            $record->Load($id);
            return { collection => $record->Transactions };
        },
    )
}

__PACKAGE__->meta->make_immutable;

1;
