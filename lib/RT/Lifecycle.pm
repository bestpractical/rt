# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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

sub loc { return RT->SystemUser->loc( @_ ) }

our %LIFECYCLES;
our %LIFECYCLES_CACHE;
__PACKAGE__->register_rights;

# cache structure:
#    {
#        '' => { # all valid statuses
#            '' => [...],
#            initial => [...],
#            active => [...],
#            inactive => [...],
#        },
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

    $self->fill_cache unless keys %LIFECYCLES_CACHE;

    return $self;
}

=head2 load

Takes a name of the lifecycle and loads it. If name is empty or undefined then
loads the global lifecycle with statuses from all named lifecycles.

Can be called as class method, returns a new object, for example:

    my $lifecycle = RT::Lifecycle->load('default');

=cut

sub load {
    my $self = shift;
    my $name = shift || '';
    return $self->new->load( $name, @_ )
        unless ref $self;

    return unless exists $LIFECYCLES_CACHE{ $name };

    $self->{'name'} = $name;
    $self->{'data'} = $LIFECYCLES_CACHE{ $name };

    return $self;
}

=head2 list

Returns sorted list of the lifecycles' names.

=cut

sub list {
    my $self = shift;

    $self->fill_cache unless keys %LIFECYCLES_CACHE;

    return sort grep length && $_ ne '__maps__', keys %LIFECYCLES_CACHE;
}

=head2 name

Returns name of the laoded lifecycle.

=cut

sub name { return $_[0]->{'name'} }

=head2 Getting statuses and validating.

Methods to get statuses in different sets or validating them.

=head3 valid

Returns an array of all valid statuses for the current lifecycle.
Statuses are not sorted alphabetically, instead initial goes first,
then active and then inactive.

Takes optional list of status types, from 'initial', 'active' or
'inactive'. For example:

    $lifecycle->valid('initial', 'active');

=cut

sub valid {
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
    my $value = lc shift;
    return 1 if grep lc($_) eq $value, $self->valid( @_ );
    return 0;
}

=head3 Initial

Returns an array of all initial statuses for the current lifecycle.

=cut

sub Initial {
    my $self = shift;
    return $self->valid('initial');
}

=head3 IsInitial

Takes a status and returns true if value is a valid initial status.
Otherwise, returns false.

=cut

sub IsInitial {
    my $self  = shift;
    my $value = lc shift;
    return 1 if grep lc($_) eq $value, $self->valid('initial');
    return 0;
}


=head3 default_initial

Returns the "default" initial status for this lifecycle

=cut

sub DefaultInitial {
    my $self = shift;
    return $self->{data}->{default_initial};
}


=head3 Active

Returns an array of all active statuses for this lifecycle.

=cut

sub Active {
    my $self = shift;
    return $self->valid('active');
}

=head3 IsActive

Takes a value and returns true if value is a valid active status.
Otherwise, returns false.

=cut

sub IsActive {
    my $self  = shift;
    my $value = lc shift;
    return 1 if grep lc($_) eq $value, $self->valid('active');
    return 0;
}

=head3 inactive

Returns an array of all inactive statuses for this lifecycle.

=cut

sub Inactive {
    my $self = shift;
    return $self->valid('inactive');
}

=head3 is_inactive

Takes a value and returns true if value is a valid inactive status.
Otherwise, returns false.

=cut

sub IsInactive {
    my $self  = shift;
    my $value = lc shift;
    return 1 if grep lc($_) eq $value, $self->valid('inactive');
    return 0;
}

=head3 default_inactive

Returns the "default" inactive status for this lifecycle

=cut

sub default_inactive {
    my $self = shift;
    return $self->{data}->{default_inactive};
}

=head2 Transitions, rights, labels and actions.

=head3 transitions

Takes status and returns list of statuses it can be changed to.

If status is ommitted then returns a hash with all possible transitions
in the following format:

    status_x => [ next_status, next_status, ... ],
    status_y => [ next_status, next_status, ... ],

=cut

sub Transitions {
    my $self = shift;
    my $status = shift;
    if ( $status ) {
        return @{ $self->{'data'}{'transitions'}{ $status } || [] };
    } else {
        return %{ $self->{'data'}{'transitions'} || {} };
    }
}

=head1 IsTransition

Takes two statuses (from -> to) and returns true if it's valid
transition and false otherwise.

=cut

sub IsTransition {
    my $self = shift;
    my $from = shift or return 0;
    my $to   = shift or return 0;
    return 1 if grep lc($_) eq lc($to), $self->Transitions($from);
    return 0;
}

=head3 check_right

Takes two statuses (from -> to) and returns the right that should
be checked on the ticket.

=cut

sub check_right {
    my $self = shift;
    my $from = shift;
    my $to = shift;
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

sub register_rights {
    my $self = shift;

    $self->fill_cache unless keys %LIFECYCLES_CACHE;

    my %tmp;
    foreach my $lifecycle ( values %LIFECYCLES_CACHE ) {
        next unless exists $lifecycle->{'rights'};
        while ( my ($transition, $right) = each %{ $lifecycle->{'rights'} } ) {
            push @{ $tmp{ $right } ||=[] }, $transition;
        }
    }

    require RT::ACE;
    require RT::Queue;
    my $RIGHTS = $RT::Queue::RIGHTS;
    while ( my ($right, $transitions) = each %tmp ) {
        next if exists $RIGHTS->{ $right };

        my (@from, @to);
        foreach ( @$transitions ) {
            ($from[@from], $to[@to]) = split / -> /, $_;
        }
        my $description = 'Change status'
            . ( (grep $_ eq '*', @from)? '' : ' from '. join ', ', @from )
            . ( (grep $_ eq '*', @to  )? '' : ' to '. join ', ', @from );

        $RIGHTS->{ $right } = $description;
        RT::Queue->AddRightCategories( $right => 'Status' );
        $RT::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
    }
}

=head3 actions

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

sub actions {
    my $self = shift;
    my $from = shift || return ();

    $self->fill_cache unless keys %LIFECYCLES_CACHE;

    my @res = grep $_->{'from'} eq $from || ( $_->{'from'} eq '*' && $_->{'to'} ne $from ),
        @{ $self->{'data'}{'actions'} };

    # skip '* -> x' if there is '$from -> x'
    foreach my $e ( grep $_->{'from'} eq '*', @res ) {
        $e = undef if grep $_->{'from'} ne '*' && $_->{'to'} eq $e->{'to'}, @res;
    }
    return grep defined, @res;
}

=head2 Creation and manipulation

=head3 create

Creates a new lifecycle in the DB. Takes a param hash with
'name', 'initial', 'active', 'inactive' and 'transitions' keys.

All arguments except 'name' are optional and can be filled later
with other methods.

Returns (status, message) pair, status is false on error.

=cut

sub create {
    my $self = shift;
    my %args = (
        name => undef,
        initial => undef,
        active => undef,
        inactive => undef,
        transitions => undef,
        actions => undef,
        @_
    );
    @{ $self }{qw(name data)} = (undef, undef);

    my $name = delete $args{'name'};
    return (0, loc('Invalid lifecycle name'))
        unless defined $name && length $name;
    return (0, loc('Already exist'))
        if $LIFECYCLES_CACHE{ $name };

    foreach my $method (qw(_set_defaults _set_statuses _set_transitions _set_actions)) {
        my ($status, $msg) = $self->$method( %args, name => $name );
        return ($status, $msg) unless $status;
    }

    my ($status, $msg) = $self->_store_lifecycles( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Created a new lifecycle'));
}

sub set_statuses {
    my $self = shift;
    my %args = (
        initial  => [],
        active   => [],
        inactive => [],
        @_
    );

    my $name = $self->name or return (0, loc("Lifecycle is not loaded"));

    my ($status, $msg) = $self->_set_statuses( %args, name => $name );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_lifecycles( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated lifecycle'));
}




sub set_transitions {
    my $self = shift;
    my %args = @_;

    my $name = $self->name or return (0, loc("Lifecycle is not loaded"));

    my ($status, $msg) = $self->_set_transitions(
        transitions => \%args, name => $name
    );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_lifecycles( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated lifecycle with transitions data'));
}

sub set_actions {
    my $self = shift;
    my %args = @_;

    my $name = $self->name or return (0, loc("Lifecycle is not loaded"));

    my ($status, $msg) = $self->_set_actions(
        actions => \%args, name => $name
    );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_lifecycles( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated lifecycle with actions data'));
}

sub fill_cache {
    my $self = shift;

    my $map = RT->Config->Get('Lifecycles') or return;
#    my $map = $RT::System->first_attribute('Lifecycles')
#        or return;
#    $map = $map->content or return;

    %LIFECYCLES_CACHE = %LIFECYCLES = %$map;
    $_ = { %$_ } foreach values %LIFECYCLES_CACHE;

    my %all = (
        '' => [],
        initial => [],
        active => [],
        inactive => [],
    );
    foreach my $lifecycle ( values %LIFECYCLES_CACHE ) {
        my @res;
        foreach my $type ( qw(initial active inactive) ) {
            push @{ $all{ $type } }, @{ $lifecycle->{ $type } || [] };
            push @res,               @{ $lifecycle->{ $type } || [] };
        }

        my %seen;
        @res = grep !$seen{ lc $_ }++, @res;
        $lifecycle->{''} = \@res;
    }
    foreach my $type ( qw(initial active inactive), '' ) {
        my %seen;
        @{ $all{ $type } } = grep !$seen{ lc $_ }++, @{ $all{ $type } };
        push @{ $all{''} }, @{ $all{ $type } } if $type;
    }
    $LIFECYCLES_CACHE{''} = \%all;

    foreach my $lifecycle ( values %LIFECYCLES_CACHE ) {
        my @res;
        if ( ref $lifecycle->{'actions'} eq 'HASH' ) {
            foreach my $k ( sort keys %{ $lifecycle->{'actions'} } ) {
                push @res, $k, $lifecycle->{'actions'}{ $k };
            }
        } elsif ( ref $lifecycle->{'actions'} eq 'ARRAY' ) {
            @res = @{ $lifecycle->{'actions'} };
        }

        my @tmp = splice @res;
        while ( my ($transition, $info) = splice @tmp, 0, 2 ) {
            my ($from, $to) = split /\s*->\s*/, $transition, 2;
            push @res, { %$info, from => $from, to => $to };
        }
        $lifecycle->{'actions'} = \@res;
    }
    return;
}

sub for_localization {
    my $self = shift;
    $self->fill_cache unless keys %LIFECYCLES_CACHE;

    my @res = ();

    push @res, @{ $LIFECYCLES_CACHE{''}{''} || [] };
    foreach my $lifecycle ( values %LIFECYCLES ) {
        push @res,
            grep defined && length,
            map $_->[0],
            grep ref($_),
            values %{ $lifecycle->{'actions'} || {} };
    }

    my %seen;
    return grep !$seen{lc $_}++, @res;
}

sub _store_lifecycles {
    my $self = shift;
    my $name = shift;
    my ($status, $msg) = $RT::System->set_attribute(
        name => 'Lifecycles',
        description => 'all system lifecycles',
        content => \%LIFECYCLES,
    );
    $self->fill_cache;
    $self->load( $name );
    return ($status, loc("Couldn't store lifecycle")) unless $status;
    return 1;
}

sub _set_statuses {
    my $self = shift;
    my %args = @_;

    my @all;
    my %tmp = (
        initial  => [],
        active   => [],
        inactive => [],
    );
    foreach my $type ( qw(initial active inactive) ) {
        foreach my $status ( grep defined && length, @{ $args{ $type } || [] } ) {
            return (0, loc('Status should contain ASCII characters only. Translate via po files.'))
                unless $status =~ /^[a-zA-Z0-9.,! ]+$/;
            return (0, loc('Statuses must be unique within a lifecycle'))
                if grep lc($_) eq lc($status), @all;
            push @all, $status;
            push @{ $tmp{ $type } }, $status;
        }
    }

    $LIFECYCLES{ $args{'name'} }{ $_ } = $tmp{ $_ }
        foreach qw(initial active inactive);

    return 1;
}


sub _set_defaults {
    my $self = shift;
    my %args = @_;

    $LIFECYCLES{ $args{'name'} }{$_ } = $args{ $_ }
        foreach qw(default_initial default_inactive);

    return 1;
}





sub _set_transitions {
    my $self = shift;
    my %args = @_;

    # XXX, TODO: more tests on data
    $LIFECYCLES{ $args{'name'} }{'transitions'} = $args{'transitions'};
    return 1;
}

sub _set_actions {
    my $self = shift;
    my %args = @_;

    # XXX, TODO: more tests on data
    $LIFECYCLES{ $args{'name'} }{'actions'} = $args{'actions'};
    return 1;
}

sub from_set {
    my $self = shift;
    my $status = shift;
    foreach my $set ( qw(initial active inactive) ) {
        return $set if $self->IsValid( $status, $set );
    }
    return '';
}

sub map {
    my $from = shift;
    my $to = shift;
    $to = RT::Lifecycle->load( $to ) unless ref $to;
    return $LIFECYCLES{'__maps__'}{ $from->name .' -> '. $to->name } || {};
}

sub set_map {
    my $self = shift;
    my $to = shift;
    $to = RT::Lifecycle->load( $to ) unless ref $to;
    my %map = @_;
    $map{ lc $_ } = delete $map{ $_ } foreach keys %map;

    return (0, loc("Lifecycle is not loaded"))
        unless $self->name;

    return (0, loc("Lifecycle is not loaded"))
        unless $to->name;


    $LIFECYCLES{'__maps__'}{ $self->name .' -> '. $to->name } = \%map;

    my ($status, $msg) = $self->_store_lifecycles( $self->name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated lifecycle with actions data'));
}

sub has_map {
    my $self = shift;
    my $map = $self->map( @_ );
    return 0 unless $map && keys %$map;
    return 0 unless grep defined && length, values %$map;
    return 1;
}

sub no_maps {
    my $self = shift;
    my @list = $self->list;
    my @res;
    foreach my $from ( @list ) {
        foreach my $to ( @list ) {
            next if $from eq $to;
            push @res, $from, $to
                unless RT::Lifecycle->load( $from )->has_map( $to );
        }
    }
    return @res;
}

sub queues {
    my $self = shift;
    require RT::Queues;
    my $queues = RT::Queues->new( RT->SystemUser );
    $queues->limit( column => 'lifecycle', value => $self->name );
    return $queues;
}

1;
