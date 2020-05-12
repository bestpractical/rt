# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Queue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid);

extends 'RT::REST2::Resource::Record';
with (
    'RT::REST2::Resource::Record::Readable',
    'RT::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::REST2::Resource::Record::DeletableByDisabling',
    'RT::REST2::Resource::Record::Writable',
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
        _url => RT::REST2->base_uri . '/ticket?Queue=' . $queue->Id,
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
