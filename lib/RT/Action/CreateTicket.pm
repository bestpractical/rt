package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'RT::Action::TicketAction', 'Jifty::Action::Record::Create';

use RT::Crypt::GnuPG;

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
    $self->SUPER::after_set_queue($queue, @_);

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

    $self->set_initial_priority($queue);
    $self->set_final_priority($queue);
}

sub _valid_statuses {
    my $self  = shift;
    my $queue = shift;
    return $queue->status_schema->initial;
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
    else {
        # always have sign_using so it can be validated
        $self->fill_parameter(sign_using => (
            default_value => '',
            render_as => 'hidden',
        ));
    }

    $self->fill_parameter(encrypt => (
        render_as     => 'checkbox',
        default_value => $queue->encrypt,
    ));
}

sub canonicalize_sign_using {
    my $self = shift;
    my $address = shift;

    return $address if length $address;

    my $queue = RT::Model::Queue->load($self->argument_value('queue'));
    return $queue->correspond_address;
}

sub validate_sign_using {
    my $self    = shift;
    my $address = shift;

    return if !$self->argument_value('sign');

    if (!RT::Crypt::GnuPG::dry_sign($address)) {
        return $self->validation_error(sign=> _("The system is unable to sign outgoing email messages. This usually indicates that the passphrase was mis-set, or that GPG Agent is down. Please alert your system administrator immediately. The problem address is: %1", $address));
    }

    # should this use argument_value('sign_using') or $address?
    RT::Crypt::GnuPG::use_key_for_signing($self->argument_value('sign_using'))
        if $self->argument_value('sign_using');

    return $self->validation_ok('sign');
}

sub validate_encrypt {
    my $self  = shift;
    my $crypt = shift;

    return if !$crypt;

    # XXX: this is ugly and broken for multiple recipients
    my @recipients = map { $self->argument_value($_) }
                     $self->role_group_parameters;

    my %seen;
    @recipients = grep !$seen{ lc $_ }++, @recipients;

    RT::Crypt::GnuPG::use_key_for_encryption(
        map { (/^UseKey-(.*)$/)[0] => $self->argument_value($_) }
        grep $self->argument_value($_) && /^UseKey-/,
        keys %{ $self->arguments },
    );

    my ($ok, @issues) = RT::Crypt::GnuPG::check_recipients( @recipients );
    push @{ $self->{'GnuPGRecipientsKeyIssues'} ||= [] }, @issues;
    if ($ok) {
        return $self->validation_ok('encrypt');
    }
    else {
        return $self->validation_error(encrypt => 'xxx');
    }
}

sub select_key_for_encryption {
    my $self    = shift;
    my $email   = shift;
    my $default = shift;

    my %res = RT::Crypt::GnuPG::get_keys_for_encryption($email);

    # move the preferred key to the top of the list
    my $d;
    my @keys = map {
                   $_->{'fingerprint'} eq ( $default || '' )
                       ?  do { $d = $_; () }
                       : $_
               }
               @{ $res{'info'} };

    @keys = sort { $b->{'trust_level'} <=> $a->{'trust_level'} } @keys;

    unshift @keys, $d if defined $d;

    return map {
        my $display = _("%1 (trust: %2)", $_->{fingerprint}, $_->{trust_terse});

        {
            value   => $_->{fingerprint},
            display => $display,
        }
    } @keys;
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

__PACKAGE__->_add_parameter_type(
    name     => 'role_group',
    defaults => {
        render_as      => 'text',
        display_length => 40,
    },
);

__PACKAGE__->_add_parameter_type(
    name     => 'link',
    defaults => {
        render_as      => 'text',
        display_length => 10,
    },
);

1;

