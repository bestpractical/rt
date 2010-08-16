
use strict;
use warnings;

package RT::StatusSchema;

sub loc { return $RT::SystemUser->loc( @_ ) }

our %STATUS_SCHEMAS;
our %STATUS_SCHEMAS_CACHE;

# cache structure:
#    {
#        '' => { # all valid statuses
#            '' => [...],
#            initial => [...],
#            active => [...],
#            inactive => [...],
#        },
#        schema_x => {
#            '' => [...], # all valid in schema
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
#            actions => {
#               'status_y -> status_y' => [ transition_label, transition_action ],
#               ....
#            }
#        }
#    }

=head1 NAME

RT::StatusSchema - class to access and manipulate status schemas

=head1 DESCRIPTION

A status schema is a list of statuses that a ticket can have. There are three
groups of statuses: initial, active and inactive. A status schema also defines
possible transitions between statuses. For example, in the 'default' schema,
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

    $self->fill_cache unless keys %STATUS_SCHEMAS_CACHE;

    return $self;
}

=head2 load

Takes a name of the schema and loads it. If name is empty or undefined then
loads the global schema with statuses from all named schemas.

Can be called as class method, returns a new object, for example:

    my $schema = RT::StatusSchema->load('default');

=cut

sub load {
    my $self = shift;
    my $name = shift || '';
    return $self->new->load( $name, @_ )
        unless ref $self;

    return unless exists $STATUS_SCHEMAS_CACHE{ $name };

    $self->{'name'} = $name;
    $self->{'data'} = $STATUS_SCHEMAS_CACHE{ $name };

    return $self;
}

=head2 list

Returns sorted list of the schemas' names.

=cut

sub list {
    my $self = shift;

    $self->fill_cache unless keys %STATUS_SCHEMAS_CACHE;

    return sort grep length && $_ ne '__maps__', keys %STATUS_SCHEMAS_CACHE;
}

=head2 name

Returns name of the laoded schema.

=cut

sub name { return $_[0]->{'name'} }

=head2 Getting statuses and validatiing.

Methods to get statuses in different sets or validating them.

=head3 valid

Returns an array of all valid statuses for the current schema.
Statuses are not sorted alphabetically, instead initial goes first,
then active and then inactive.

Takes optional list of status types, from 'initial', 'active' or
'inactive'. For example:

    $schema->valid('initial', 'active');

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

=head3 is_valid

Takes a status and returns true if value is a valid status for the current
schema. Otherwise, returns false.

Takes optional list of status types after the status, so it's possible check
validity in particular sets, for example:

    # returns true if status is valid and from initial or active set
    $schema->is_valid('some_status', 'initial', 'active');

See also </valid>.

=cut

sub is_valid {
    my $self  = shift;
    my $value = lc shift;
    return scalar grep lc($_) eq $value, $self->valid( @_ );
}

=head3 initial

Returns an array of all initial statuses for the current schema.

=cut

sub initial {
    my $self = shift;
    return $self->valid('initial');
}

=head3 is_initial

Takes a status and returns true if value is a valid initial status.
Otherwise, returns false.

=cut

sub is_initial {
    my $self  = shift;
    my $value = lc shift;
    return scalar grep lc($_) eq $value, $self->valid('initial');
}


=head3 default_initial

Returns the "default" initial status for this schema

=cut

sub default_initial {
    my $self = shift;
    return $self->{data}->{default_initial};
}


=head3 active

Returns an array of all active statuses for this schema.

=cut

sub active {
    my $self = shift;
    return $self->valid('active');
}

=head3 is_active

Takes a value and returns true if value is a valid active status.
Otherwise, returns false.

=cut

sub is_active {
    my $self  = shift;
    my $value = lc shift;
    return scalar grep lc($_) eq $value, $self->valid('active');
}

=head3 inactive

Returns an array of all inactive statuses for this schema.

=cut

sub inactive {
    my $self = shift;
    return $self->valid('inactive');
}

=head3 is_inactive

Takes a value and returns true if value is a valid inactive status.
Otherwise, returns false.

=cut

sub is_inactive {
    my $self  = shift;
    my $value = lc shift;
    return scalar grep lc($_) eq $value, $self->valid('inactive');
}

=head2 Transitions, rights, labels and actions.

=head3 transitions

Takes status and returns list of statuses it can be changed to.

If status is ommitted then returns a hash with all possible transitions
in the following format:

    status_x => [ next_status, next_status, ... ],
    status_y => [ next_status, next_status, ... ],

=cut

sub transitions {
    my $self = shift;
    my $status = shift;
    if ( $status ) {
        return @{ $self->{'data'}{'transitions'}{ $status } || [] };
    } else {
        return %{ $self->{'data'}{'transitions'} || {} };
    }
}

=head1 is_transition

Takes two statuses (from -> to) and returns true if it's valid
transition and false otherwise.

=cut

sub is_transition {
    my $self = shift;
    my $from = shift or return 0;
    my $to   = shift or return 0;
    return scalar grep lc($_) eq lc($to), $self->transitions($from);
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

    $self->fill_cache unless keys %STATUS_SCHEMAS_CACHE;

    my %tmp;
    foreach my $schema ( values %STATUS_SCHEMAS_CACHE ) {
        next unless exists $schema->{'rights'};
        while ( my ($transition, $right) = each %{ $schema->{'rights'} } ) {
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
        $RT::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
    }
}

=head3 transition_label

Takes two statuses (from -> to) and returns label for the transition,
if custom label is not defined then default equal to the second status.

=cut

sub transition_label {
    my $self = shift;
    my $from = shift;
    my $to = shift;
    return $self->{'data'}{'actions'}{ $from .' -> '. $to }[0] || $to;
}

=head3 transition_action

Takes two statuses (from -> to) and returns action for the transition.

At this moment it can be:

=over 4

=item '' (empty string) - no action (default)

=item hide - hide this button from the Web UI

=item comment - comment page is shown

=item respond - reply page is shown

=back

=cut

sub transition_action {
    my $self = shift;
    my $from = shift;
    my $to = shift;
    return $self->{'data'}{'actions'}{ $from .' -> '. $to }[1] || '';
}

=head2 Creation and manipulation

=head3 create

Creates a new status schema in the DB. Takes a param hash with
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
    return (0, loc('Invalid schema name'))
        unless defined $name && length $name;
    return (0, loc('Already exist'))
        if $STATUS_SCHEMAS_CACHE{ $name };

    foreach my $method (qw(_set_defaults _set_statuses _set_transitions _set_actions)) {
        my ($status, $msg) = $self->$method( %args, name => $name );
        return ($status, $msg) unless $status;
    }

    my ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Created a new status schema'));
}

sub set_statuses {
    my $self = shift;
    my %args = (
        initial  => [],
        active   => [],
        inactive => [],
        @_
    );

    my $name = $self->name or return (0, loc("Status schema is not loaded"));

    my ($status, $msg) = $self->_set_statuses( %args, name => $name );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated schema'));
}




sub set_transitions {
    my $self = shift;
    my %args = @_;

    my $name = $self->name or return (0, loc("Status schema is not loaded"));

    my ($status, $msg) = $self->_set_transitions(
        transitions => \%args, name => $name
    );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated schema with transitions data'));
}

sub set_actions {
    my $self = shift;
    my %args = @_;

    my $name = $self->name or return (0, loc("Status schema is not loaded"));

    my ($status, $msg) = $self->_set_actions(
        actions => \%args, name => $name
    );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated schema with actions data'));
}

sub fill_cache {
    my $self = shift;

    my $map = RT->Config->Get('StatusSchemaMeta') or return;
#    my $map = $RT::System->first_attribute('StatusSchemas')
#        or return;
#    $map = $map->content or return;

    %STATUS_SCHEMAS_CACHE = %STATUS_SCHEMAS = %$map;
    my %all = (
        '' => [],
        initial => [],
        active => [],
        inactive => [],
    );
    foreach my $schema ( values %STATUS_SCHEMAS_CACHE ) {
        my @res;
        foreach my $type ( qw(initial active inactive) ) {
            push @{ $all{ $type } }, @{ $schema->{ $type } || [] };
            push @res,               @{ $schema->{ $type } || [] };
        }

        my %seen;
        @res = grep !$seen{ lc $_ }++, @res;
        $schema->{''} = \@res;
    }
    foreach my $type ( qw(initial active inactive), '' ) {
        my %seen;
        @{ $all{ $type } } = grep !$seen{ lc $_ }++, @{ $all{ $type } };
        push @{ $all{''} }, @{ $all{ $type } } if $type;
    }
    $STATUS_SCHEMAS_CACHE{''} = \%all;
    return;
}

sub for_localization {
    my $self = shift;
    $self->fill_cache unless keys %STATUS_SCHEMAS_CACHE;

    my @res = ();

    push @res, @{ $STATUS_SCHEMAS_CACHE{''}{''} || [] };
    foreach my $schema ( values %STATUS_SCHEMAS ) {
        push @res,
            grep defined && length,
            map $_->[0],
            grep ref($_),
            values %{ $schema->{'actions'} || {} };
    }

    my %seen;
    return grep !$seen{lc $_}++, @res;
}

sub _store_schemas {
    my $self = shift;
    my $name = shift;
    my ($status, $msg) = $RT::System->set_attribute(
        name => 'StatusSchemas',
        description => 'all system status schemas',
        content => \%STATUS_SCHEMAS,
    );
    $self->fill_cache;
    $self->load( $name );
    return ($status, loc("Couldn't store schema")) unless $status;
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
            return (0, loc('Statuses must be unique in one schema'))
                if grep lc($_) eq lc($status), @all;
            push @all, $status;
            push @{ $tmp{ $type } }, $status;
        }
    }

    $STATUS_SCHEMAS{ $args{'name'} }{ $_ } = $tmp{ $_ }
        foreach qw(initial active inactive);

    return 1;
}


sub _set_defaults {
    my $self = shift;
    my %args = @_;

    $STATUS_SCHEMAS{ $args{'name'} }{$_ } = $args{ $_ }
        foreach qw(default_initial);

    return 1;
}





sub _set_transitions {
    my $self = shift;
    my %args = @_;

    # XXX, TODO: more tests on data
    $STATUS_SCHEMAS{ $args{'name'} }{'transitions'} = $args{'transitions'};
    return 1;
}

sub _set_actions {
    my $self = shift;
    my %args = @_;

    # XXX, TODO: more tests on data
    $STATUS_SCHEMAS{ $args{'name'} }{'actions'} = $args{'actions'};
    return 1;
}

sub from_set {
    my $self = shift;
    my $status = shift;
    foreach my $set ( qw(initial active inactive) ) {
        return $set if $self->is_valid( $status, $set );
    }
    return '';
}

sub map {
    my $from = shift;
    my $to = shift;
    $to = RT::StatusSchema->load( $to ) unless ref $to;
    return $STATUS_SCHEMAS{'__maps__'}{ $from->name .' -> '. $to->name } || {};
}

sub set_map {
    my $self = shift;
    my $to = shift;
    $to = RT::StatusSchema->load( $to ) unless ref $to;
    my %map = @_;
    $map{ lc $_ } = delete $map{ $_ } foreach keys %map;

    return (0, loc("Status schema is not loaded"))
        unless $self->name;

    return (0, loc("Status schema is not loaded"))
        unless $to->name;


    $STATUS_SCHEMAS{'__maps__'}{ $self->name .' -> '. $to->name } = \%map;

    my ($status, $msg) = $self->_store_schemas( $self->name );
    return ($status, $msg) unless $status;

    return (1, loc('Updated schema with actions data'));
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
                unless RT::StatusSchema->load( $from )->has_map( $to );
        }
    }
    return @res;
}

sub queues {
    my $self = shift;
    require RT::Queues;
    my $queues = RT::Queues->new( $RT::SystemUser );
    $queues->limit( column => 'status_schema', value => $self->name );
    return $queues;
}

1;
