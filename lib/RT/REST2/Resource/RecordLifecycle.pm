# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2026 Best Practical Solutions, LLC
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

package RT::REST2::Resource::RecordLifecycle;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use JSON ();
use RT::REST2::Util qw(serialize_record_lifecycle);

extends 'RT::REST2::Resource';

=head1 NAME

RT::REST2::Resource::RecordLifecycle - the lifecycle of a single ticket or asset

=head1 DESCRIPTION

Serves C<GET /ticket/:id/lifecycle> and C<GET /asset/:id/lifecycle>: a
record-scoped, agent-facing view of the record's lifecycle. The graph is
filtered to the statuses and transitions the current user can actually reach
from the record's current status (via
L<RT::Lifecycle/FilterAllowedTransitions>), and every status and transition is
annotated with its C<description> (human-facing) and C<notes> (agent-facing)
metadata. The C<available> flag on a transition marks the moves that can be made
right now, directly from the current status.

=cut

has 'record_class' => (
    is       => 'ro',
    isa      => 'ClassName',
    required => 1,
);

has 'record_id' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has 'record' => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build_record {
    my $self   = shift;
    my $record = $self->record_class->new( $self->current_user );
    $record->Load( $self->record_id );
    return $record;
}

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/(ticket|asset)/(\d+)/lifecycle/?$},
        block => sub {
            my ($match) = @_;
            return {
                record_class => 'RT::' . ucfirst( $match->pos(1) ),
                record_id    => $match->pos(2),
            };
        },
    ),
}

sub resource_exists {
    my $self = shift;
    return $self->record->id ? 1 : 0;
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    my $right = $self->record->isa('RT::Asset') ? 'ShowAsset' : 'ShowTicket';
    return $self->record->CurrentUserHasRight($right) ? 0 : 1;
}

sub allowed_methods { ['GET', 'HEAD'] }

sub charsets_provided { ['utf-8'] }
sub default_charset   {  'utf-8'  }

sub content_types_provided { [ { 'application/json' => 'to_json' } ] }

sub to_json {
    my $self = shift;
    return JSON::to_json(
        serialize_record_lifecycle( $self->record ),
        { pretty => 1, canonical => 1 },
    );
}

RT::Base->_ImportOverlays();

__PACKAGE__->meta->make_immutable;

1;
