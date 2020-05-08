package RT::REST2::Resource::Ticket;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Record';
with (
    'RT::REST2::Resource::Record::Readable',
    'RT::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::REST2::Resource::Record::Deletable',
    'RT::REST2::Resource::Record::Writable'
        => { -alias => { create_record => '_create_record' } },
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/?$},
        block => sub { { record_class => 'RT::Ticket' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)/?$},
        block => sub { { record_class => 'RT::Ticket', record_id => shift->pos(1) } },
    )
}

sub create_record {
    my $self = shift;
    my $data = shift;

    return (\400, "Could not create ticket. Queue not set") if !$data->{Queue};

    my $queue = RT::Queue->new(RT->SystemUser);
    $queue->Load($data->{Queue});

    return (\400, "Unable to find queue") if !$queue->Id;

    return (\403, $self->record->loc("No permission to create tickets in the queue '[_1]'", $queue->Name))
    unless $self->record->CurrentUser->HasRight(
        Right  => 'CreateTicket',
        Object => $queue,
    ) and $queue->Disabled != 1;

    if ( defined $data->{Content} ) {
        $data->{MIMEObj} = HTML::Mason::Commands::MakeMIMEEntity(
            Interface => 'REST',
            Subject   => $data->{Subject},
            Body      => delete $data->{Content},
            Type      => delete $data->{ContentType} || 'text/plain',
        );
    }

    my ($ok, $txn, $msg) = $self->_create_record($data);
    return ($ok, $msg);
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('ShowTicket');
}

sub lifecycle_hypermedia_links {
    my $self = shift;
    my $self_link = $self->_self_link;
    my $ticket = $self->record;
    my @links;

    # lifecycle actions
    my $lifecycle = $ticket->LifecycleObj;
    my $current = $ticket->Status;
    my $hide_resolve_with_deps = RT->Config->Get('HideResolveActionsWithDependencies')
        && $ticket->HasUnresolvedDependencies;

    for my $info ( $lifecycle->Actions($current) ) {
        my $next = $info->{'to'};
        next unless $lifecycle->IsTransition( $current => $next );

        my $check = $lifecycle->CheckRight( $current => $next );
        next unless $ticket->CurrentUserHasRight($check);

        next if $hide_resolve_with_deps
            && $lifecycle->IsInactive($next)
            && !$lifecycle->IsInactive($current);

        my $url = $self_link->{_url};
        $url .= '/correspond' if ($info->{update}||'') eq 'Respond';
        $url .= '/comment' if ($info->{update}||'') eq 'Comment';

        push @links, {
            %$info,
            label => $self->current_user->loc($info->{'label'} || ucfirst($next)),
            ref   => 'lifecycle',
            _url  => $url,
        };
    }

    return @links;
}

sub hypermedia_links {
    my $self = shift;
    my $self_link = $self->_self_link;
    my $links = $self->_default_hypermedia_links(@_);
    my $ticket = $self->record;

    push @$links, $self->_transaction_history_link;

    push @$links, {
            ref     => 'correspond',
            _url    => $self_link->{_url} . '/correspond',
    } if $ticket->CurrentUserHasRight('ReplyToTicket');

    push @$links, {
        ref     => 'comment',
        _url    => $self_link->{_url} . '/comment',
    } if $ticket->CurrentUserHasRight('CommentOnTicket');

    push @$links, $self->lifecycle_hypermedia_links;

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;
