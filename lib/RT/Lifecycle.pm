# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

use strict;
use warnings;


package RT::Lifecycle;

our %LIFECYCLES;
our %LIFECYCLES_CACHE;
our %LIFECYCLES_TYPES;

# cache structure:
#    {
#        lifecycle_x => {
#            '' => [...], # all valid in lifecycle
#            initial => [...],
#            active => [...],
#            inactive => [...],
#            transitions => {
#               status_x => [status_next1, status_next2,...],
#            },
#            rights => {
#               'status_y -> status_y' => 'right',
#               ....
#            }
#            actions => [
#               { from => 'a', to => 'b', label => '...', update => '...' },
#               ....
#            ]
#        }
#    }

=head1 NAME

RT::Lifecycle - class to access and manipulate lifecycles

=head1 DESCRIPTION

A lifecycle is a list of statuses that a ticket can have. There are three
groups of statuses: initial, active and inactive. A lifecycle also defines
possible transitions between statuses. For example, in the 'default' lifecycle,
you may only change status from 'stalled' to 'open'.

It is also possible to define user-interface labels and the action a user
should perform during a transition. For example, the "open -> stalled"
transition would have a 'Stall' label and the action would be Comment. The
action only defines what form is showed to the user, but actually performing
the action is not required. The user can leave the comment box empty yet still
Stall a ticket. Finally, the user can also just use the Basics or Jumbo form to
change the status with the usual dropdown.

=head1 METHODS

=head2 new

Simple constructor, takes no arguments.

=cut

sub new {
    my $proto = shift;
    my $self = bless {}, ref($proto) || $proto;

    $self->FillCache unless keys %LIFECYCLES_CACHE;

    return $self;
}

=head2 Load Name => I<NAME>, Type => I<TYPE>

Takes a name of the lifecycle and loads it. If only a Type is provided,
loads the global lifecycle with statuses from all named lifecycles of
that type.

Can be called as class method, returns a new object, for example:

    my $lifecycle = RT::Lifecycle->Load( Name => 'default');

Returns an object which may be a subclass of L<RT::Lifecycle>
(L<RT::Lifecycle::Ticket>, for example) depending on the type of the
lifecycle in question.

=cut

sub Load {
    my $self = shift;
    return $self->new->Load( @_ )
        unless ref $self;

    unshift @_, Type => "ticket", "Name"
        if @_ % 2;

    my %args = (
        Type => "ticket",
        Name => '',
        @_,
    );

    if (defined $args{Name} and exists $LIFECYCLES_CACHE{ $args{Name} }) {
        $self->{'name'} = $args{Name};
        $self->{'data'} = $LIFECYCLES_CACHE{ $args{Name} };
        $self->{'type'} = $args{Type};

        my $found_type = $self->{'data'}{'type'};
        warn "Found type of $found_type ne $args{Type}" if $found_type ne $args{Type};
    } elsif (not $args{Name} and exists $LIFECYCLES_TYPES{ $args{Type} }) {
        $self->{'data'} = $LIFECYCLES_TYPES{ $args{Type} };
        $self->{'type'} = $args{Type};
    } else {
        return undef;
    }

    my $class = "RT::Lifecycle::".ucfirst($args{Type});
    bless $self, $class if $class->require;

    return $self;
}

=head2 List

List available lifecycles. This list omits RT's default approvals
lifecycle.

Takes: An optional parameter for lifecycle types other than tickets.
       Defaults to 'ticket'.

Returns: A sorted list of available lifecycles.

=cut

sub List {
    my $self = shift;
    my $for = shift || 'ticket';

    return grep { $_ ne 'approvals' } $self->ListAll( $for );
}

=head2 ListAll

Returns a list of all lifecycles, including approvals.

Takes: An optional parameter for lifecycle types other than tickets.
       Defaults to 'ticket'.

Returns: A sorted list of all available lifecycles.

=cut

sub ListAll {
    my $self = shift;
    my $for = shift || 'ticket';

    $self->FillCache unless keys %LIFECYCLES_CACHE;

    return sort grep {$LIFECYCLES_CACHE{$_}{type} eq $for}
        grep $_ ne '__maps__', keys %LIFECYCLES_CACHE;
}

=head2 Name

Returns name of the loaded lifecycle.

=cut

sub Name { return $_[0]->{'name'} }

=head2 Type

Returns the type of the loaded lifecycle.

=cut

sub Type { return $_[0]->{'type'} }

=head2 Getting statuses and validating.

Methods to get statuses in different sets or validating them.

=head3 Valid

Returns an array of all valid statuses for the current lifecycle.
Statuses are not sorted alphabetically, instead initial goes first,
then active and then inactive.

Takes optional list of status types, from 'initial', 'active' or
'inactive'. For example:

    $lifecycle->Valid('initial', 'active');

=cut

sub Valid {
    my $self = shift;
    my @types = @_;
    unless ( @types ) {
        return @{ $self->{'data'}{''} || [] };
    }

    my @res;
    push @res, @{ $self->{'data'}{ $_ } || [] } foreach @types;
    return @res;
}

=head3 IsValid

Takes a status and returns true if value is a valid status for the current
lifecycle. Otherwise, returns false.

Takes optional list of status types after the status, so it's possible check
validity in particular sets, for example:

    # returns true if status is valid and from initial or active set
    $lifecycle->IsValid('some_status', 'initial', 'active');

See also </valid>.

=cut

sub IsValid {
    my $self  = shift;
    my $value = shift or return 0;
    return 1 if grep lc($_) eq lc($value), $self->Valid( @_ );
    return 0;
}

=head3 StatusType

Takes a status and returns its type, one of 'initial', 'active' or
'inactive'.

=cut

sub StatusType {
    my $self = shift;
    my $status = shift;
    foreach my $type ( qw(initial active inactive) ) {
        return $type if $self->IsValid( $status, $type );
    }
    return '';
}

=head3 Initial

Returns an array of all initial statuses for the current lifecycle.

=cut

sub Initial {
    my $self = shift;
    return $self->Valid('initial');
}

=head3 IsInitial

Takes a status and returns true if value is a valid initial status.
Otherwise, returns false.

=cut

sub IsInitial {
    my $self  = shift;
    my $value = shift or return 0;
    return 1 if grep lc($_) eq lc($value), $self->Valid('initial');
    return 0;
}


=head3 Active

Returns an array of all active statuses for this lifecycle.

=cut

sub Active {
    my $self = shift;
    return $self->Valid('active');
}

=head3 IsActive

Takes a value and returns true if value is a valid active status.
Otherwise, returns false.

=cut

sub IsActive {
    my $self  = shift;
    my $value = shift or return 0;
    return 1 if grep lc($_) eq lc($value), $self->Valid('active');
    return 0;
}

=head3 Inactive

Returns an array of all inactive statuses for this lifecycle.

=cut

sub Inactive {
    my $self = shift;
    return $self->Valid('inactive');
}

=head3 IsInactive

Takes a value and returns true if value is a valid inactive status.
Otherwise, returns false.

=cut

sub IsInactive {
    my $self  = shift;
    my $value = shift or return 0;
    return 1 if grep lc($_) eq lc($value), $self->Valid('inactive');
    return 0;
}


=head2 Default statuses

In some cases when status is not provided a default values should
be used.

=head3 DefaultStatus

Takes a situation name and returns value. Name should be
spelled following spelling in the RT config file.

=cut

sub DefaultStatus {
    my $self = shift;
    my $situation = shift;
    return $self->{data}{defaults}{ $situation };
}

=head3 DefaultOnCreate

Returns the status that should be used by default
when ticket is created.

=cut

sub DefaultOnCreate {
    my $self = shift;
    return $self->DefaultStatus('on_create');
}

=head2 Transitions, rights, labels and actions.

=head3 Transitions

Takes status and returns list of statuses it can be changed to.

Is status is empty or undefined then returns list of statuses for
a new ticket.

If argument is ommitted then returns a hash with all possible
transitions in the following format:

    status_x => [ next_status, next_status, ... ],
    status_y => [ next_status, next_status, ... ],

=cut

sub Transitions {
    my $self = shift;
    return %{ $self->{'data'}{'transitions'} || {} }
        unless @_;

    my $status = shift || '';
    return @{ $self->{'data'}{'transitions'}{ lc $status } || [] };
}

=head1 IsTransition

Takes two statuses (from -> to) and returns true if it's valid
transition and false otherwise.

=cut

sub IsTransition {
    my $self = shift;
    my $from = shift;
    my $to   = shift or return 0;
    return 1 if grep lc($_) eq lc($to), $self->Transitions($from);
    return 0;
}

=head3 CheckRight

Takes two statuses (from -> to) and returns the right that should
be checked on the ticket.

=cut

sub CheckRight {
    my $self = shift;
    my $from = lc shift;
    my $to = lc shift;
    if ( my $rights = $self->{'data'}{'rights'} ) {
        my $check =
            $rights->{ $from .' -> '. $to }
            || $rights->{ '* -> '. $to }
            || $rights->{ $from .' -> *' }
            || $rights->{ '* -> *' };
        return $check if $check;
    }
    return $to eq 'deleted' ? 'DeleteTicket' : 'ModifyTicket';
}

=head3 RightsDescription [TYPE]

Returns hash with description of rights that are defined for
particular transitions.

=cut

sub RightsDescription {
    my $self = shift;
    my $type = shift;

    $self->FillCache unless keys %LIFECYCLES_CACHE;

    my %tmp;
    foreach my $lifecycle ( values %LIFECYCLES_CACHE ) {
        next unless exists $lifecycle->{'rights'};
        next if $type and $lifecycle->{type} ne $type;
        while ( my ($transition, $right) = each %{ $lifecycle->{'rights'} } ) {
            push @{ $tmp{ $right } ||=[] }, $transition;
        }
    }

    my %res;
    while ( my ($right, $transitions) = each %tmp ) {
        my (@from, @to);
        foreach ( @$transitions ) {
            ($from[@from], $to[@to]) = split / -> /, $_;
        }
        my $description = 'Change status'
            . ( (grep $_ eq '*', @from)? '' : ' from '. join ', ', @from )
            . ( (grep $_ eq '*', @to  )? '' : ' to '. join ', ', @to );

        $res{ $right } = $description;
    }
    return %res;
}

=head3 Actions

Takes a status and returns list of defined actions for the status. Each
element in the list is a hash reference with the following key/value
pairs:

=over 4

=item from - either the status or *

=item to - next status

=item label - label of the action

=item update - 'Respond', 'Comment' or '' (empty string)

=back

=cut

sub Actions {
    my $self = shift;
    my $from = shift || return ();
    $from = lc $from;

    $self->FillCache unless keys %LIFECYCLES_CACHE;

    my @res = grep lc $_->{'from'} eq $from || ( $_->{'from'} eq '*' && lc $_->{'to'} ne $from ),
        @{ $self->{'data'}{'actions'} };

    # skip '* -> x' if there is '$from -> x'
    foreach my $e ( grep $_->{'from'} eq '*', @res ) {
        $e = undef if grep $_->{'from'} ne '*' && $_->{'to'} eq $e->{'to'}, @res;
    }
    return grep defined, @res;
}

=head2 Moving tickets between lifecycles

=head3 MoveMap

Takes lifecycle as a name string or an object and returns a hash reference with
move map from this cycle to provided.

=cut

sub MoveMap {
    my $from = shift; # self
    my $to = shift;
    $to = RT::Lifecycle->Load( Name => $to, Type => $from->Type ) unless ref $to;
    return $LIFECYCLES{'__maps__'}{ $from->Name .' -> '. $to->Name } || {};
}

=head3 HasMoveMap

Takes a lifecycle as a name string or an object and returns true if move map
defined for move from this cycle to provided.

=cut

sub HasMoveMap {
    my $self = shift;
    my $map = $self->MoveMap( @_ );
    return 0 unless $map && keys %$map;
    return 0 unless grep defined && length, values %$map;
    return 1;
}

=head3 NoMoveMaps

Takes no arguments and returns hash with pairs that has no
move maps.

=cut

sub NoMoveMaps {
    my $self = shift;
    my $type = $self->Type;
    my @list = $self->List( $type );
    my @res;
    foreach my $from ( @list ) {
        foreach my $to ( @list ) {
            next if $from eq $to;
            push @res, $from, $to
                unless RT::Lifecycle->Load( Name => $from, Type => $type )->HasMoveMap( $to );
        }
    }
    return @res;
}

=head2 Localization

=head3 ForLocalization

A class method that takes no arguments and returns list of strings
that require translation.

=cut

sub ForLocalization {
    my $self = shift;
    $self->FillCache unless keys %LIFECYCLES_CACHE;

    my @res = ();

    push @res, @{$_->{''}} for values %LIFECYCLES_TYPES;
    foreach my $lifecycle ( values %LIFECYCLES ) {
        push @res,
            grep defined && length,
            map $_->{'label'},
            grep ref($_),
            @{ $lifecycle->{'actions'} || [] };
    }

    push @res, $self->RightsDescription;

    my %seen;
    return grep !$seen{lc $_}++, @res;
}

sub loc { return RT->SystemUser->loc( @_ ) }

sub CanonicalCase {
    my $self = shift;
    my ($status) = @_;
    return undef unless defined $status;
    return($self->{data}{canonical_case}{lc $status} || lc $status);
}

sub FillCache {
    my $self = shift;

    my $map = RT->Config->Get('Lifecycles') or return;

    {
        my @lifecycles;

        # if users are upgrading from 3.* where we don't have lifecycle column yet,
        # this could die. we also don't want to frighten them by the errors out
        eval {
            local $RT::Logger = Log::Dispatch->new;
            @lifecycles = grep { defined } RT::Queues->new( RT->SystemUser )->DistinctFieldValues( 'Lifecycle' );
        };
        unless ( $@ ) {
            for my $name ( @lifecycles ) {
                unless ( $map->{$name} ) {
                    warn "Lifecycle $name is missing in %Lifecycles config";
                }
            }
        }
    }

    %LIFECYCLES_CACHE = %LIFECYCLES = %$map;
    $_ = { %$_ } foreach values %LIFECYCLES_CACHE;

    foreach my $name ( keys %LIFECYCLES_CACHE ) {
        next if $name eq "__maps__";
        my $lifecycle = $LIFECYCLES_CACHE{$name};

        my $type = $lifecycle->{type} ||= 'ticket';
        $LIFECYCLES_TYPES{$type} ||= {
            '' => [],
            initial => [],
            active => [],
            inactive => [],
            actions => [],
        };

        my @statuses;
        $lifecycle->{canonical_case} = {};
        foreach my $category ( qw(initial active inactive) ) {
            for my $status (@{ $lifecycle->{ $category } || [] }) {
                if (exists $lifecycle->{canonical_case}{lc $status}) {
                    warn "Duplicate status @{[lc $status]} in lifecycle $name";
                } else {
                    $lifecycle->{canonical_case}{lc $status} = $status;
                }
                push @{ $LIFECYCLES_TYPES{$type}{$category} }, $status;
                push @statuses, $status;
            }
        }

        # Lower-case for consistency
        # ->{actions} are handled below
        for my $state (keys %{ $lifecycle->{defaults} || {} }) {
            my $status = $lifecycle->{defaults}{$state};
            warn "Nonexistant status @{[lc $status]} in default states in $name lifecycle"
                unless $lifecycle->{canonical_case}{lc $status};
            $lifecycle->{defaults}{$state} =
                $lifecycle->{canonical_case}{lc $status} || lc $status;
        }
        for my $from (keys %{ $lifecycle->{transitions} || {} }) {
            warn "Nonexistant status @{[lc $from]} in transitions in $name lifecycle"
                unless $from eq '' or $lifecycle->{canonical_case}{lc $from};
            for my $status ( @{delete($lifecycle->{transitions}{$from}) || []} ) {
                warn "Nonexistant status @{[lc $status]} in transitions in $name lifecycle"
                    unless $lifecycle->{canonical_case}{lc $status};
                push @{ $lifecycle->{transitions}{lc $from} },
                    $lifecycle->{canonical_case}{lc $status} || lc $status;
            }
        }
        for my $schema (keys %{ $lifecycle->{rights} || {} }) {
            my ($from, $to) = split /\s*->\s*/, $schema, 2;
            unless ($from and $to) {
                warn "Invalid right transition $schema in $name lifecycle";
                next;
            }
            warn "Nonexistant status @{[lc $from]} in right transition in $name lifecycle"
                unless $from eq '*' or $lifecycle->{canonical_case}{lc $from};
            warn "Nonexistant status @{[lc $to]} in right transition in $name lifecycle"
                unless $to eq '*' or $lifecycle->{canonical_case}{lc $to};

            warn "Invalid right name ($lifecycle->{rights}{$schema}) in $name lifecycle; right names must be ASCII"
                if $lifecycle->{rights}{$schema} =~ /\P{ASCII}/;

            warn "Invalid right name ($lifecycle->{rights}{$schema}) in $name lifecycle; right names must be <= 25 characters"
                if length($lifecycle->{rights}{$schema}) > 25;

            $lifecycle->{rights}{lc($from) . " -> " .lc($to)}
                = delete $lifecycle->{rights}{$schema};
        }

        my %seen;
        @statuses = grep !$seen{ lc $_ }++, @statuses;
        $lifecycle->{''} = \@statuses;

        unless ( $lifecycle->{'transitions'}{''} ) {
            $lifecycle->{'transitions'}{''} = [ grep lc $_ ne 'deleted', @statuses ];
        }

        my @actions;
        if ( ref $lifecycle->{'actions'} eq 'HASH' ) {
            foreach my $k ( sort keys %{ $lifecycle->{'actions'} } ) {
                push @actions, $k, $lifecycle->{'actions'}{ $k };
            }
        } elsif ( ref $lifecycle->{'actions'} eq 'ARRAY' ) {
            @actions = @{ $lifecycle->{'actions'} };
        }

        $lifecycle->{'actions'} = [];
        while ( my ($transition, $info) = splice @actions, 0, 2 ) {
            my ($from, $to) = split /\s*->\s*/, $transition, 2;
            unless ($from and $to) {
                warn "Invalid action status change $transition in $name lifecycle";
                next;
            }
            warn "Nonexistant status @{[lc $from]} in action in $name lifecycle"
                unless $from eq '*' or $lifecycle->{canonical_case}{lc $from};
            warn "Nonexistant status @{[lc $to]} in action in $name lifecycle"
                unless $to eq '*' or $lifecycle->{canonical_case}{lc $to};
            push @{ $lifecycle->{'actions'} },
                { %$info,
                  from => ($lifecycle->{canonical_case}{lc $from} || lc $from),
                  to   => ($lifecycle->{canonical_case}{lc $to}   || lc $to),   };
        }
    }

    # Lower-case the transition maps
    for my $mapname (keys %{ $LIFECYCLES_CACHE{'__maps__'} || {} }) {
        my ($from, $to) = split /\s*->\s*/, $mapname, 2;
        unless ($from and $to) {
            warn "Invalid lifecycle mapping $mapname";
            next;
        }
        warn "Nonexistant lifecycle $from in $mapname lifecycle map"
            unless $LIFECYCLES_CACHE{$from};
        warn "Nonexistant lifecycle $to in $mapname lifecycle map"
            unless $LIFECYCLES_CACHE{$to};
        my $map = delete $LIFECYCLES_CACHE{'__maps__'}{$mapname};
        $LIFECYCLES_CACHE{'__maps__'}{"$from -> $to"} = $map;
        for my $status (keys %{ $map }) {
            warn "Nonexistant status @{[lc $status]} in $from in $mapname lifecycle map"
                if $LIFECYCLES_CACHE{$from}
                    and not $LIFECYCLES_CACHE{$from}{canonical_case}{lc $status};
            warn "Nonexistant status @{[lc $map->{$status}]} in $to in $mapname lifecycle map"
                if $LIFECYCLES_CACHE{$to}
                    and not $LIFECYCLES_CACHE{$to}{canonical_case}{lc $map->{$status}};
            $map->{lc $status} = lc delete $map->{$status};
        }
    }

    for my $type (keys %LIFECYCLES_TYPES) {
        for my $category ( qw(initial active inactive), '' ) {
            my %seen;
            @{ $LIFECYCLES_TYPES{$type}{$category} } =
                grep !$seen{ lc $_ }++, @{ $LIFECYCLES_TYPES{$type}{$category} };
            push @{ $LIFECYCLES_TYPES{$type}{''} },
                @{ $LIFECYCLES_TYPES{$type}{$category} } if $category;
        }

        my $class = "RT::Lifecycle::".ucfirst($type);
        $class->RegisterRights if $class->require
            and $class->can("RegisterRights");
    }

    return;
}

1;
