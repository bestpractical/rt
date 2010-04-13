package RT::Action::RenewTicket;
use strict;
use warnings;
use base 'RT::Action::TicketAction', 'Jifty::Action::Record';

use Jifty::Param::Schema;
use Jifty::Action schema {
    param id =>
        render as 'hidden',
        is constructor;

    param type =>
        render as 'select',
        available are [
            map { { display => _($_), value => $_ } }
                qw/correspond comment/ ],
        label is _('Type');
    param status =>
        render as 'select',
        label is _('Status');

    param owner =>
        render as 'RT::View::Form::Field::SelectUser',
        # valid_values are queue-specific
        valid_values are lazy { [ RT->nobody->id ] },
        label is _('Owner');

    param worked =>
        render as 'text',
        label is _('Worked(in minutes)');

    param subject =>
        render as 'text',
        display_length is 60,
        max_length is 200,
        label is _('Subject');

    param one_time_cc => 
        render as 'text',
        label is _('One-time Cc');
    param one_time_bcc => 
        render as 'text',
        label is _('One-time Bcc');
    param content => 
        render as 'textarea',
        label is _('Message');
    param attachments => 
        render as 'Uploads',
        label is _('Attachments');
};

sub _valid_statuses {
    my $self = shift;

    my $record = $self->record;
    return (
        $record->status,
        $record->queue->status_schema->transitions($record->status),
    );
}

sub take_action {
    my $self = shift;

    my $record = $self->record;
    return unless $record && $record->id;

    my $type = $self->argument_value('type');
    return unless $type;

    if (
        (
            $type eq 'correspond'
            && Jifty->web->current_user->has_right( right => 'ReplyToTicket',
                object => $record->queue )
        )
        || ( $type eq 'comment'
            && Jifty->web->current_user->has_right( right =>
                'CommentOoTicket', object => $record->queue )
        )
      )
    {

        # update basics
        for my $field (qw/status owner/) {
            my $method = "set_$field";
            my $value  = $self->argument_value($field);
            if ( $record->$field ne $value ) {
                my ( $ret, $msg ) = $record->$method($value);
                Jifty->log->error($msg) unless $ret;
            }
        }
    }

    # XXX reply/comment

    return 1;
}

1;
