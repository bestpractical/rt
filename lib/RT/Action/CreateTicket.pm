package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'RT::Action::QueueBased', 'RT::Action::WithCustomFields', 'Jifty::Action::Record::Create';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param status =>
        render as 'select',
        # valid_values are queue-specific
        valid_values are lazy { [ RT::Workflow->load(undef)->initial ] },
        label is _('Status');

    param owner =>
        render as 'RT::View::Form::Field::SelectUser',
        # valid_values are queue-specific
        valid_values are lazy { RT->nobody->id },
        label is _('Owner');

    param subject =>
        render as 'text',
        display_length is 60,
        max_length is 200,
        label is _('Subject');

    param attachments =>
        render as 'upload',
        label is _('Attach file');

    param content =>
        render as 'textarea',
        label is _('Describe the issue');

    param initial_priority =>
        # default is queue-specific
        render as 'text',
        display_length is 3,
        label is _('Priority');

    param final_priority =>
        # default is queue-specific
        render as 'text',
        display_length is 3,
        label is _('Final Priority');
};

sub after_set_queue {
    my $self  = shift;
    my $queue = shift;
    $self->SUPER::after_set_queue(@_);

    $self->set_valid_statuses($queue);
    $self->set_valid_owners($queue);
    $self->setup_gnupg($queue);

    $self->add_role_group_parameter(
        name          => 'requestors',
        label         => _('Requestors'),
        default_value => Jifty->web->current_user->email,
    );

    $self->add_role_group_parameter(
        name  => 'cc',
        label => _('Cc'),
        hints => _('(Sends a carbon-copy of this update to a comma-delimited list of email addresses. These people <strong>will</strong> receive future updates.)'),
    );

    $self->add_role_group_parameter(
        name  => 'admin_cc',
        label => _('Admin Cc'),
        hints => _('(Sends a carbon-copy of this update to a comma-delimited list of administrative email addresses. These people <strong>will</strong> receive future updates.)'),
    );

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

    $self->add_link_parameter(
        name  => 'depends_on',
        label => _('Depends on'),
    );

    $self->add_link_parameter(
        name  => 'depended_on_by',
        label => _('Depended on by'),
    );

    $self->add_link_parameter(
        name  => 'parents',
        label => _('parents'),
    );

    $self->add_link_parameter(
        name  => 'children',
        label => _('children'),
    );

    $self->add_link_parameter(
        name  => 'refers_to',
        label => _('Refers to'),
    );

    $self->add_link_parameter(
        name  => 'referred_to_by',
        label => _('Referred to by'),
    );

    $self->add_ticket_custom_fields($queue);
    $self->add_ticket_transaction_custom_fields($queue);

    $self->set_initial_priority($queue);
    $self->set_final_priority($queue);
}

sub set_valid_statuses {
    my $self  = shift;
    my $queue = shift;

    my @valid_statuses = $queue->status_schema->initial;
    $self->fill_parameter(status => valid_values => \@valid_statuses);
}

sub set_valid_owners {
    my $self  = shift;
    my $queue = shift;

    my $isSU = Jifty->web->current_user->has_right(
        right  => 'SuperUser',
        object => RT->system,
    );

    my $users = RT::Model::UserCollection->new;
    $users->who_have_right(
        right                 => 'OwnTicket',
        object                => $queue,
        include_system_rights => 1,
        include_superusers    => $isSU,
    );

    my %user_uniq_hash;
    while (my $user = $users->next) {
        $user_uniq_hash{ $user->id } = $user;
    }

    # delete nobody here, so we can make them first later
    delete $user_uniq_hash{RT->nobody->id};

    my @valid_owners = sort { uc( $a->name ) cmp uc( $b->name ) }
                       values %user_uniq_hash;
    unshift @valid_owners, RT->nobody;

    $self->fill_parameter(owner => valid_values => [ map { $_->id } @valid_owners ]);
}

sub setup_gnupg {
    my $self  = shift;
    my $queue = shift;

    return unless RT->config->get('gnupg')->{enable};

    $self->fill_parameter(sign => (
        render_as     => 'checkbox',
        default_value => $queue->sign,
    ));

    if (my $user_key = $self->current_user->user_object->private_key) {
        $self->fill_parameter(sign_using => (
            valid_values => [
                { name => '', display => _("Queue's key") },
                "$user_key",
            ],
        ));
    }

    $self->fill_parameter(encrypt => (
        render_as     => 'checkbox',
        default_value => $queue->encrypt,
    ));
}

sub set_initial_priority {
    my $self  = shift;
    my $queue = shift;

    $self->fill_parameter(initial_priority => default_value => $queue->initial_priority);
}

sub set_final_priority {
    my $self  = shift;
    my $queue = shift;

    $self->fill_parameter(final_priority => default_value => $queue->final_priority);
}

sub report_success {
    my $self = shift;
    my $id = $self->record->id;
    my $queue = $self->record->queue->name;
    $self->result->message(_("Created ticket #%1 in queue %2", $id, $queue));
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

    *{__PACKAGE__."::$get_method"} = sub {
        use strict 'refs';
        my $self = shift;
        return @{ $self->{$key} || [] };
    };

    *{__PACKAGE__."::$add_method"} = sub {
        use strict 'refs';
        my $self = shift;
        my %args = @_;

        my $parameter = delete $args{name};

        push @{ $self->{$key} }, $parameter;

        $self->fill_parameter($parameter => (
            %defaults,
            %args,
        ));
    };
}

__PACKAGE__->_add_parameter_type(
    name     => 'role_group',
    defaults => {
        render_as      => 'text',
        display_length => 40,
    },
);

__PACKAGE__->_add_parameter_type(
    name     => 'duration',
    defaults => {
        render_as      => 'text', # ideally would be Duration
        display_length => 3,
    },
);

__PACKAGE__->_add_parameter_type(
    name     => 'datetime',
    defaults => {
        render_as      => 'DateTime',
        display_length => 16,
    },
);

__PACKAGE__->_add_parameter_type(
    name     => 'link',
    defaults => {
        render_as      => 'text',
        display_length => 10,
    },
);

__PACKAGE__->_add_parameter_type(
    name => 'ticket_custom_field',
);

__PACKAGE__->_add_parameter_type(
    name => 'ticket_transaction_custom_field',
);

1;

