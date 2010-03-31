package RT::Action::DeleteTicketLinks;
use Jifty::Param::Schema;
use Jifty::Action schema {};

use constant report_detailed_messages => 1;

sub take_action {
    my $self = shift;

    $self->result->content->{'detailed_messages'} ||= {};
    my %map = (
        depends_on => 'depended_on_by',
        member_of  => 'has_member',
        refers_to  => 'referred_to_by',
    );

    if ( $self->argument_value('id') ) {
        my $ticket =
          RT::Model::Ticket->new( current_user => Jifty->web->current_user );
        $ticket->load($self->argument_value('id'));

        for my $field ( keys %map ) {
            if ( my $v = $self->argument_value($field) ) {
                for my $value ( ref $v eq 'ARRAY' ? @$v : $v ) {
                    next unless $value;
                    my ( $val, $msg ) = $ticket->delete_link(
                        target => $value,
                        type   => $field,
                    );
                    push @{ $self->result->content('detailed_messages')->{$field} }, $msg;
                }
            }
            if ( my $v = $self->argument_value( $map{$field} ) ) {
                for my $value ( ref $v eq 'ARRAY' ? @$v : $v ) {
                    next unless $value;
                    my ( $val, $msg ) = $ticket->delete_link(
                        base => $value,
                        type => $field,
                    );
                    push @{ $self->result->content('detailed_messages')->{ $map{$field} } }, $msg;
                }
            }
        }
    }

    return 1;
}

1;
