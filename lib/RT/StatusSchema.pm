
use strict;
use warnings;

package RT::StatusSchema;

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
#            actions => {
#               'status_y -> status_y' => [ transition_label, transition_action ],
#               ....
#            }
#        }
#    }

=head1 NAME

RT::StatusSchema - class to access and manipulate status schemas

=head1 DESCRIPTION

Status schema is a list statuses tickets can have, splitted into three groups:
initial, active and inactive. As well it defines possible transitions between
statuses, for example from 'stalled' status of default schema you can change
status to 'open' only.

Also it is possible to define interface labels and actions user should do during
a transition, for example open -> resolved transition labeled 'Stall' and action
is comment. Action only defines what's showed for user, but is not required. User
can leave comment box empty and change status anyway or can use ticket's basics
interface to change status.

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

    return sort grep length, keys %STATUS_SCHEMAS_CACHE;
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

=head2 Transitions, labels and actions.

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
    return (0, _('Invalid schema name'))
        unless defined $name && length $name;
    return (0, _('Already exist'))
        if $STATUS_SCHEMAS_CACHE{ $name };

    foreach my $method (qw(_set_statuses _set_transitions _set_actions)) {
        my ($status, $msg) = $self->$method( %args, name => $name );
        return ($status, $msg) unless $status;
    }

    my ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, _('Created a new status schema'));
}

sub set_statuses {
    my $self = shift;
    my %args = (
        initial  => [],
        active   => [],
        inactive => [],
        @_
    );

    my $name = $self->name or return (0, _("Status schema is not loaded"));

    my ($status, $msg) = $self->_set_statuses( %args, name => $name );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, _('Updated schema'));
}

sub set_transitions {
    my $self = shift;
    my %args = @_;

    my $name = $self->name or return (0, _("Status schema is not loaded"));

    my ($status, $msg) = $self->_set_transitions(
        transitions => \%args, name => $name
    );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, _('Updated schema with transitions data'));
}

sub set_actions {
    my $self = shift;
    my %args = @_;

    my $name = $self->name or return (0, _("Status schema is not loaded"));

    my ($status, $msg) = $self->_set_actions(
        actions => \%args, name => $name
    );
    return ($status, $msg) unless $status;

    ($status, $msg) = $self->_store_schemas( $name );
    return ($status, $msg) unless $status;

    return (1, _('Updated schema with actions data'));
}

sub fill_cache {
    my $self = shift;
    my $map = $RT::System->first_attribute('StatusSchemas')
        or return;
    $map = $map->content or return;

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
            push @res,                     @{ $schema->{ $type } || [] };
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
    return ($status, _("Couldn't store schema")) unless $status;
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
            return (0, _('Status should contain ASCII characters only. Translate via po files.'))
                unless $status =~ /^[a-zA-Z0-9.,! ]+$/;
            return (0, _('Statuses must be unique in one schema'))
                if grep lc($_) eq lc($status), @all;
            push @all, $status;
            push @{ $tmp{ $type } }, $status;
        }
    }

    $STATUS_SCHEMAS{ $args{'name'} }{ $_ } = $tmp{ $_ }
        foreach qw(initial active inactive);

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

1;
