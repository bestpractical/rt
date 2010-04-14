package RT::Action::ReplyToTicket;
use strict;
use warnings;
use base 'RT::Action::TicketAction', 'Jifty::Action::Record';
use Jifty::Param::Schema;
use Jifty::Action schema {
    param id =>
        render as 'hidden',
        is constructor;

    param status =>
        render as 'select',
        label is _('Status');

    param owner =>
        render as 'RT::View::Form::Field::SelectUser',
        # valid_values are queue-specific
        valid_values are lazy { [ RT->nobody->id ] },
        label is _('Owner');

    param time_worked =>
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

# XXX TODO 
# sign, encrypt, content_type, transaction, signature, quote_transaction
# attach_tickets, update_ignore_address_checkboxes, cf
sub take_action {
    my $self = shift;

    my $record = $self->record;
    return unless $record && $record->id;

    # update basics
    for my $field (qw/status owner/) {
        my $method = "set_$field";
        my $value  = $self->argument_value($field);
        if (  $value ne ( ref $record->$field
            ? $record->$field->id
            : $record->$field ) )
        {
            my ( $ret, $msg ) = $record->$method($value);
            Jifty->log->error($msg) unless $ret;
        }
    }

    if ( my $worked = $self->argument_value('time_worked') ) {
        my ( $ret, $msg ) =
          $record->set_time_worked( $record->time_worked + $worked );
        Jifty->log->error($msg) unless $ret;
    }

    my $attachments = $self->argument_value('attachments');
    my %mime_atts;

    if ($attachments) {
        for my $att (
            ref $attachments eq 'ARRAY'
            ? @$attachments
            : $attachments
          )
        {
            my $filename = Encode::decode_utf8( $att->filename );
            my $mime     = MIME::Entity->build(
                Type    => 'multipart/mixed',
                Subject => $filename,
            );
            $mime->attach(
                Type     => $att->content_type,
                Filename => $filename,
                Data     => [ $att->content ],
            );
            $mime_atts{$filename} = $mime;
        }
    }

    my @results = HTML::Mason::Commands::process_update_message(
        ticket_obj => $record,
        args_ref   => {
            update_attachments => \%mime_atts,
            update_type        => $self->type,
            map { 'update_' . $_ => $self->argument_value($_) || '' }
              qw/subject cc bcc content/,
        },
    );
    $self->result->message(join ', ', @results);
    return 1;
}

sub type { 'response' }


1;
