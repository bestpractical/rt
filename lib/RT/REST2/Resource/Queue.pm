package RT::Extension::REST2::Resource::Queue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::Extension::REST2::Util qw(expand_uid);

extends 'RT::Extension::REST2::Resource::Record';
with (
    'RT::Extension::REST2::Resource::Record::Readable',
    'RT::Extension::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::Extension::REST2::Resource::Record::DeletableByDisabling',
    'RT::Extension::REST2::Resource::Record::Writable',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queue/?$},
        block => sub { { record_class => 'RT::Queue' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queue/(\d+)/?$},
        block => sub { { record_class => 'RT::Queue', record_id => shift->pos(1) } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/queue/([^/]+)/?$},
        block => sub {
            my ($match, $req) = @_;
            my $queue = RT::Queue->new($req->env->{"rt.current_user"});
            $queue->Load($match->pos(1));
            return { record => $queue };
        },
    ),
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);
    my $queue = $self->record;

    push @$links, $self->_transaction_history_link;

    push @$links, {
        ref  => 'create',
        type => 'ticket',
        _url => RT::Extension::REST2->base_uri . '/ticket?Queue=' . $queue->Id,
    } if $queue->CurrentUserHasRight('CreateTicket');

    return $links;
}

around 'serialize' => sub {
    my $orig = shift;
    my $self = shift;
    my $data = $self->$orig(@_);

    # Load Ticket Custom Fields for this queue
    if ( my $ticket_cfs = $self->record->TicketCustomFields ) {
        my @values;
        while (my $cf = $ticket_cfs->Next) {
            my $entry = expand_uid($cf->UID);
            my $content = {
                %$entry,
                ref      => 'customfield',
                name     => $cf->Name,
            };

            push @values, $content;
        }

        $data->{TicketCustomFields} = \@values;
    }

    # Load Transaction custom fields for this queue
    if ( my $ticket_cfs = $self->record->TicketTransactionCustomFields ) {
        my @values;
        while (my $cf = $ticket_cfs->Next) {
            my $entry = expand_uid($cf->UID);
            my $content = {
                %$entry,
                ref      => 'customfield',
                name     => $cf->Name,
            };

            push @values, $content;
        }

        $data->{TicketTransactionCustomFields} = \@values;
    }

    return $data;
};

__PACKAGE__->meta->make_immutable;

1;
