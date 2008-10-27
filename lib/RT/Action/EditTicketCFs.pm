package RT::Action::EditTicketCFs;
use strict;
use warnings;

use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {};

sub available_values {
    my $self = shift;
    my $id   = shift;
    next unless $id =~ /^\d+$/;
    my $cf = RT::Model::CustomField->new;
    $cf->load($id);
    my $values = $cf->values;

    my $available = [];
    if ( $cf->type eq 'Select' ) {
        push @$available, { value => '', display => '(no value)' };
    }

    while ( my $v = $values->next ) {
        push @$available,
          {
            value   => $v->name,
            display => $v->name,
          };
    }
    return $available;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    $self->result->content->{'detailed_messages'} ||= {};
    if ( $self->argument_value('id') ) {
        my $ticket =
          RT::Model::Ticket->new( current_user => Jifty->web->current_user );
        $ticket->load( $self->argument_value('id') );

        my $args = $self->argument_values;

        # deal with files to be deleted
        my @to_be_deleted = grep { /delete_/ && $args->{$_} } keys %$args;
        for my $tbd (@to_be_deleted) {
            if ( $tbd =~ /delete_(\d+)_(\d+)/ ) {
                my ( $cfid, $ocfvid ) = ( $1, $2 );
                my $cf =
                  RT::Model::CustomField->new(
                    current_user => Jifty->web->current_user );
                $cf->load_by_id($cfid);
                my ( $val, $msg ) = $ticket->delete_custom_field_value(
                    field    => $cfid,
                    value_id => $ocfvid,
                );
                Jifty->log->error($msg) unless $val;
                push @{ $self->result->content('detailed_messages')
                      ->{ $cf->name } }, $msg;
            }
        }

        # deal with other types
        my @cfids = grep { /^\d+$/ } keys %$args;

        for my $cfid (@cfids) {
            my $cf =
              RT::Model::CustomField->new(
                current_user => Jifty->web->current_user );
            $cf->load_by_id($cfid);

            my $values     = $ticket->custom_field_values( $cf->id );
            my $new_values = $args->{$cfid};

            if ( $cf->type eq 'Binary' || $cf->type eq 'Image' ) {
                next unless $new_values;
                my $cgi_object  = Jifty->handler->cgi;
                my $upload_info = $cgi_object->uploadInfo($new_values);
                my $filename    = "$new_values";
                $filename =~ s#^.*[\\/]##;
                binmode($new_values);

                my ( $val, $msg ) = $ticket->add_custom_field_value(
                    field         => $cfid,
                    value         => $filename,
                    large_content => do { local $/; scalar <$new_values> },
                    content_type  => $upload_info->{'Content-Type'},
                );
                Jifty->log->error($msg) unless $val;
                push @{ $self->result->content('detailed_messages')
                      ->{ $cf->name } }, $msg;
            }
            else {

                unless ( ref $new_values ) {
                    $new_values =~ s/\r+\n/\n/g;
                    $new_values =~ s/^\s+//g;
                    $new_values =~ s/\s+$//g;

                    # wikitext or text
                    if ( $cf->type =~ /text/i ) {
                        $new_values = [$new_values];
                    }
                    else {

                        # freeform or select values like 'two', 'three'
                        $new_values = [ grep defined && length, split /\r*\n/,
                            $new_values ];
                    }
                }

                if ($values) {
                    my $delete_flag;
                    foreach my $old_cf ( @{ $values->items_array_ref } ) {
                        if (   !$delete_flag
                            && @$new_values
                            && $old_cf->content eq $new_values->[0] )
                        {
                            shift @$new_values;
                            next;
                        }
                        $delete_flag ||= 1;
                        my ( $val, $msg ) = $ticket->delete_custom_field_value(
                            field    => $cfid,
                            value_id => $old_cf->id,
                        );
                        Jifty->log->error($msg) unless $val;
                        push @{ $self->result->content('detailed_messages')
                              ->{ $cf->name } }, $msg;
                    }
                }
                for my $new_value (@$new_values) {
                    my ( $val, $msg ) = $ticket->add_custom_field_value(
                        field => $cfid,
                        value => $new_value,
                    );
                    Jifty->log->error($msg) unless $val;
                    push @{ $self->result->content('detailed_messages')
                          ->{ $cf->name } }, $msg;
                }
            }
        }
    }
    return 1;
}

1;
