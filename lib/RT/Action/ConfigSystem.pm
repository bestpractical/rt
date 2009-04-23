use strict;
use warnings;

package RT::Action::ConfigSystem;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer; 

# TODO XXX
# section support
# doc support

sub arguments {
    my $self = shift;
    return $self->{__cached_arguments} if ( $self->{__cached_arguments} );
    my $args = { };

    my $configs = RT::Model::ConfigCollection->new;
    $configs->unlimit;
    while ( my $config = $configs->next ) {
        $args->{ $config->name } = {
            default_value => defer {
                my $value = $config->value;
                $value = ''
                  if defined $value && $value eq $config->_empty_string;
                if ( ref $value eq 'ARRAY' ) {
                    return '[' . join( ', ', @$value ) . ']';
                }
                elsif ( ref $value eq 'HASH' ) {
                    my $str = '{';
                    for my $key ( keys %$value ) {
                        $str .= qq{$key => $value->{$key},};
                    }
                    $str .= '}';
                    return $str;
                }
                else {
                    return $value;
                }
            }
        };
    }
#    require Pod::POM;
    return $self->{__cached_arguments} = $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

            Jifty->log->error( 'ok' );
    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument($arg) ) {
            my $value = $self->argument_value( $arg );
            if ( $value =~ /^\[\s*(.*)\s*$\]/ ) {
                $value = [ split /\s*,\s*/, $1 ];
            }
            elsif ( $value =~ /^{\s*(.*)\s*$}/ ) {
                $value = { split /\s*(?:,|=>)\s*/, $1 };
            }

            RT->config->set( $arg, $value );
        }
    }

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

1;

