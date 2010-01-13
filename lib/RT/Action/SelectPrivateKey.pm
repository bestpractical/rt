
use strict;
use warnings;

package RT::Action::SelectPrivateKey;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('record');

sub arguments {
    my $self = shift;
    return {} unless $self->record;

    my $args = {};
    $args->{record_id} = {
        render_as     => 'hidden',
        default_value => $self->record->id,
    };
    $args->{record_class} = {
        render_as     => 'hidden',
        default_value => ref $self->record,
    };

    $args->{private_key} = {
        render_as        => 'Select',
        default_value    => defer { $self->default_value },
        available_values => defer { $self->available_values },
    };
    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $record_class = $self->argument_value('record_class');
    return unless $record_class;

    if ( $RT::Model::ACE::OBJECT_TYPES{$record_class} ) {
        my $object    = $record_class->new;
        my $record_id = $self->argument_value('record_id');
        $object->load($record_id);
        unless ( $object->id ) {
            Jifty->log->error("couldn't load $record_class #$record_id");
            return;
        }

        $self->record($object);
    }
    else {
        Jifty->log->error("record class '$record_class' is incorrect");
        return;
    }

    my $email = $self->record->email;
    my ( $status, $msg ) =
      $self->record->set_private_key( $self->argument_value('private_key') );
    if ( $status ) {
        $self->report_success;
    }
    else {
        Jifty->log->error( $msg );
    }

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message(_('Updated private key selection'));
}

sub available_values {
    my $self   = shift;
    my $email = $self->record->email;
    my %keys_meta = RT::Crypt::GnuPG::get_keys_for_signing( $email, 'force' );

    return [
        { display => _('no private key'), value => '' },
        map $_->{'key'},
        @{ $keys_meta{'info'} }
    ];
}

sub default_value {
    my $self      = shift;
    return $self->record->private_key,
}

1;

