package RT::Action::TicketAction;
use strict;
use warnings;
use base 'RT::Action::QueueBased', 'RT::Action::WithCustomFields';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

use Time::Duration::Parse;

# We can't use SUPER here because TicketAction does not inherit from
# Jifty::Action::Record, and SUPER is statically determined. Maybe time to
# switch to roles.
sub record {
    my $self = shift;
    return $self->Jifty::Action::Record::record if @_ == 0; # reader

    my $record = shift;
    my $ret = $self->Jifty::Action::Record::record($record, @_);

    $self->set_queue($record->queue)
        if $record->queue->id;

    $self->fill_parameter(id => default => $record->id)
        if $record->id;

    return $ret;
}

sub after_set_queue {
    my $self  = shift;
    my $queue = shift;
    $self->SUPER::after_set_queue($queue, @_);

    $self->set_valid_statuses($queue);
    $self->set_valid_owners($queue);

    $self->add_ticket_custom_fields($queue);
    $self->add_ticket_transaction_custom_fields($queue);

    $self->add_duration_parameter(
        name  => 'time_estimated',
        label => _('Time Estimated'),
    );

    $self->add_duration_parameter(
        name  => 'time_worked',
        label => _('Time Worked'),
    );

    $self->add_duration_parameter(
        name  => 'time_left',
        label => _('Time Left'),
    );

    $self->add_datetime_parameter(
        name  => 'starts',
        label => _('Starts'),
    );

    $self->add_datetime_parameter(
        name  => 'due',
        label => _('Due'),
    );
}

sub set_valid_statuses {
    my $self  = shift;
    my $queue = shift;

    my @valid_statuses = $self->_valid_statuses($queue);
    $self->fill_parameter(status => valid_values => \@valid_statuses);
}

sub set_valid_owners {
    my $self  = shift;
    my $queue = shift;

    my $isSU = Jifty->web->current_user->has_right(
        right  => 'SuperUser',
        object => RT->system,
    );

    my %user_uniq_hash;
    for my $object ($self->record, $queue) {
        next if !$object->id;

        my $users = RT::Model::UserCollection->new;
        $users->who_have_right(
            right                 => 'OwnTicket',
            object                => $object,
            include_system_rights => 1,
            include_superusers    => $isSU,
        );

        while (my $user = $users->next) {
            $user_uniq_hash{ $user->id } = $user;
        }
    }

    # delete nobody here, so we can make them first later
    delete $user_uniq_hash{RT->nobody->id};

    my @valid_owners = sort { uc( $a->name ) cmp uc( $b->name ) }
                       values %user_uniq_hash;
    unshift @valid_owners, RT->nobody;

    $self->fill_parameter(owner => (
        valid_values => [ map { $_->id } @valid_owners ],
        default_value => $self->record->owner->id,
    ));
}

sub add_ticket_custom_fields {
    my $self  = shift;
    my $queue = shift;

    my $cfs = $queue->ticket_custom_fields;
    $self->_add_custom_fields(
        cfs    => $cfs,
        method => 'add_ticket_custom_field_parameter',
    );
}

sub add_ticket_transaction_custom_fields {
    my $self  = shift;
    my $queue = shift;

    my $cfs = $queue->ticket_transaction_custom_fields;
    $self->_add_custom_fields(
        cfs    => $cfs,
        method => 'add_ticket_transaction_custom_field_parameter',
    );
}

sub _add_parameter_type {
    my $class = shift;
    my %args  = @_;

    my $name       = $args{name};
    my $key        = $args{key} || "_${name}_parameters";
    my $add_method = $args{add_method} || "add_${name}_parameter";
    my $get_method = $args{get_method} || "${name}_parameters";
    my %defaults   = %{ $args{defaults} || {} };

    no strict 'refs';

    *{$class."::$get_method"} = sub {
        use strict 'refs';
        my $self = shift;
        return @{ $self->{$key} || [] };
    };

    my $canonicalizer = $args{canonicalizer};

    *{$class."::$add_method"} = sub {
        use strict 'refs';
        my $self = shift;
        my %args = @_;

        my $parameter = delete $args{name};

        push @{ $self->{$key} }, $parameter;

        $self->fill_parameter($parameter => (
            %defaults,
            %args,
        ));

        if ($canonicalizer) {
            unless ($class->can("canonicalize_$parameter")) {
                no strict 'refs';
                *{$class."::canonicalize_$parameter"} = $canonicalizer;
            }
        }
    };
}

__PACKAGE__->_add_parameter_type(
    name => 'ticket_custom_field',
);

__PACKAGE__->_add_parameter_type(
    name => 'ticket_transaction_custom_field',
);

__PACKAGE__->_add_parameter_type(
    name     => 'duration',
    defaults => {
        render_as          => 'text', # ideally would be Duration
        display_length     => 3,
        ajax_canonicalizes => 1,
    },
    canonicalizer => sub {
        my $self  = shift;
        my $value = shift;

        if (defined $value) {
            $value = parse_duration($value);
        }

        return $value;
    },
);

__PACKAGE__->_add_parameter_type(
    name     => 'datetime',
    defaults => {
        render_as      => 'DateTime',
        display_length => 16,
    },
);

1;

