package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'RT::Action::QueueBased', 'Jifty::Action::Record::Create';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param status =>
        render as 'select',
        # valid_values are queue-specific
        valid_values are 'new', 'open', # XXX
        label is _('Status');

    param owner =>
        render as 'select',
        # valid_values are queue-specific
        valid_values are lazy { RT->nobody },
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
        label is _('Describe the issue below');

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

    param time_estimated =>
        render as 'text', # should be duration
        display_length is 3,
        label is _('Time Estimated');

    param time_worked =>
        render as 'text', # should be duration
        display_length is 3,
        label is _('Time Worked');

    param time_left =>
        render as 'text', # should be duration
        display_length is 3,
        label is _('Time Left');
};

sub after_set_queue {
    my $self  = shift;
    my $queue = shift;
    $self->SUPER::after_set_queue(@_);

    $self->set_valid_statuses($queue);
    $self->set_valid_owners($queue);

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

    $self->set_initial_priority($queue);
    $self->set_final_priority($queue);
}

sub role_group_parameters {
    my $self = shift;
    return @{ $self->{_role_group_parameters} || [] };
}

sub set_valid_statuses {
    my $self  = shift;
    my $queue = shift;

    my @valid_statuses = $queue->status_schema->valid;
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

    $self->fill_parameter(owner => valid_values => [
        map { {
            display => $_->name, # XXX: should use ShowUser or something
            value   => $_->id,
        } } @valid_owners,
    ]);
}

sub add_role_group_parameter {
    my $self = shift;
    my %args = @_;

    my $name = delete $args{name};

    push @{ $self->{_role_group_parameters} }, $name;

    $self->fill_parameter($name => (
        render_as      => 'text',
        display_length => 40,
        %args,
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

sub take_action {
    my $self = shift;

    # We should inline this function to encourage other people to use this
    # action
    HTML::Mason::Commands::create_ticket(%{ $self->argument_values });
}

1;

