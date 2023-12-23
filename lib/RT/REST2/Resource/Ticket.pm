# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

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
        => { -alias => { create_record => '_create_record', update_record => '_update_record' } },
);

has 'action' => (
    is  => 'ro',
    isa => 'Str',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/?$},
        block => sub { { record_class => 'RT::Ticket' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)/?$},
        block => sub { { record_class => 'RT::Ticket', record_id => shift->pos(1) } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/ticket/(\d+)/(take|untake|steal)$},
        block => sub { { record_class => 'RT::Ticket', record_id => $_[0]->pos(1), action => $_[0]->pos(2) } },
    ),
}

sub create_record {
    my $self = shift;
    my $data = shift;

    # Check for any bad input data before creating a ticket
    my ($ok, $msg, $return_code) = $self->validate_input(Data => $data, Action => 'create');
    if (!$ok) {
        return (\$return_code, $msg);
    }

    if ( defined $data->{Content} || defined $data->{Attachments} ) {
        $data->{MIMEObj} = HTML::Mason::Commands::MakeMIMEEntity(
            Interface => 'REST',
            Subject   => $data->{Subject},
            Body      => delete $data->{Content},
            Type      => delete $data->{ContentType} || 'text/plain',
        );
        if ( defined $data->{Attachments} ) {
            return (\400, "Attachments must be an array") unless ref($data->{Attachments}) eq 'ARRAY';
            foreach my $attachment (@{$data->{Attachments}}) {
                return (\400, "Each element of Attachments must be a hash") unless ref($attachment) eq 'HASH';
                foreach my $field (qw(FileName FileType FileContent)) {
                    return (\400, "Field $field is required for each attachment in Attachments") unless $attachment->{$field};
                }
                $data->{MIMEObj}->attach(
                    Type     => $attachment->{FileType},
                    Filename => $attachment->{FileName},
                    Data     => MIME::Base64::decode_base64($attachment->{FileContent}));
            }
            delete $data->{Attachments};
        }
    }

    my ($txn);
    ($ok, $txn, $msg) = $self->_create_record($data);
    return ($ok, $msg);
}

sub update_record {
    my $self = shift;
    my $data = shift;

    my ($ok, $msg, $return_code) = $self->validate_input(Data => $data, Action => 'update');

    # XXX TODO: refactor update_resource to accept return_code in response
    if (!$ok) {
        return (0, $msg);
    }

    my @results;

    if ( my $action = $self->action ) {
        my $method = ucfirst $action;
        my ( $ok, $msg ) = $self->record->$method();
        push @results, $msg;
    }

    push @results, $self->_update_record($data);
    if ( my $ticket_id = delete $data->{MergeInto} ) {
        my ( $ok, $msg ) = $self->record->MergeInto($ticket_id);
        push @results, $msg;
    }
    return @results;
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

sub validate_input {
    my $self = shift;
    my %args = ( Data    => '',
                 Action  => '',
                 @_ );
    my $data = $args{'Data'};

    if ( $args{'Action'} eq 'create' ) {
        return (0, "Could not create ticket. Queue not set", 400) if !$data->{Queue};

        my $queue = RT::Queue->new($self->current_user);
        $queue->Load($data->{Queue});

        return (0, $self->record->loc("No permission to create tickets in the queue '[_1]'", $data->{Queue}), 403)
            unless $queue->Id and $queue->__Value('Disabled') != 1 and $queue->CurrentUserHasRight('CreateTicket');
    }

    if ( $args{'Action'} eq 'update' ) {
        # Add pre-update input validation
    }

    return (1, "Validation passed");
}


__PACKAGE__->meta->make_immutable;

1;
