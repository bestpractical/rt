package RT::Action::CreateTicketLinks;
use strict;
use warnings;

use constant report_detailed_messages => 1;
use Text::Naming::Convention qw/renaming/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param
      id => render as 'hidden',
      default is defer {
        my $id = Jifty->web->request->argument('id');
        $id = $id->[0] if ref $id eq 'ARRAY';
        $id;
      };
    param merge_into     => label is 'merge into';
    param depends_on     => label is 'depends on';
    param depended_on_by => label is 'depended on by';
    param member_of      => label is 'parents';
    param has_member     => label is 'children';
    param refers_to      => label is 'refers_to';
    param referred_to_by => label is 'referred_to_by';
};

=head2 take_action

=cut

sub take_action {
    my $self = shift;
    my %map  = (
        depends_on => 'depended_on_by',
        member_of  => 'has_member',
        refers_to  => 'referred_to_by',
    );

    $self->result->content->{'detailed_messages'} ||= {};
    if ( $self->argument_value('id') ) {
        my $ticket =
          RT::Model::Ticket->new( current_user => Jifty->web->current_user );
        my $id = $self->argument_value('id');
        $ticket->load($id);
        for my $field ( keys %map ) {
            my $type = renaming( $field, { convention => 'UpperCamelCase' } );

            for my $value ( split /\s+/, $self->argument_value($field) ) {
                next unless $value;
                my ( $val, $msg ) = $ticket->add_link(
                    target => $value,
                    type   => $type,
                );
                push @{ $self->result->content('detailed_messages')->{$field} },
                  $msg;
            }
            for my $value ( split /\s+/, $self->argument_value( $map{$field} ) )
            {
                next unless $value;
                my ( $val, $msg ) = $ticket->add_link(
                    base => $value,
                    type => $type,
                );
                push @{ $self->result->content('detailed_messages')->{ $map{$field} } }, $msg;
            }
        }

        # now we handle merge_into stuff
        if ( my $merge_into = $self->argument_value('merge_into') ) {
            $merge_into =~ s/\s+//g;
            my ( $val, $msg ) = $ticket->merge_into($merge_into);
            $self->result->content('detailed_messages')->{'merge_into'} = $msg;
        }
    }

    return 1;
}

1;
