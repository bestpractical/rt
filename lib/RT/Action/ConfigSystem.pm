use strict;
use warnings;

package RT::Action::ConfigSystem;
use base qw/RT::Action Jifty::Action/;

use Scalar::Defer; 
use Try::Tiny;
use Data::Dumper;

sub arguments {
    my $self = shift;
    return $self->{__cached_arguments} if ( $self->{__cached_arguments} );
    my $args = {};

    my $configs = RT::Model::ConfigCollection->new;
    $configs->unlimit;
    while ( my $config = $configs->next ) {
        my $value = RT->config->get( $config->name );
        $args->{ $config->name } = {
            default_value => defer {
                local $Data::Dumper::Terse = 1;
                Dumper $value,
            },
            ref $value ? ( render_as => 'textarea' ) : (),
        };
    }
    return $self->{__cached_arguments} = $args;
}

sub metadata {
    my $self = shift;
    return $self->{__cached_meta} if ( $self->{__cached_meta} );
    my $meta = {};
    require Pod::POM;
    my $parser = Pod::POM->new;
    my $pom    = $parser->parse_file( RT->lib_path . '/RT/Config.pod' )
      or die $parser->error;
    require Pod::POM::View::HTML;
    require Pod::POM::View::Text;
    my $html_view = 'Pod::POM::View::HTML';
    my $text_view = 'Pod::POM::View::Text';

    for my $section ( $pom->head1 ) {
        my $over = $section->over->[0];
        for my $item ( $over->item ) {
            my $title = $item->title;
            my @items = split /\s*,\s*/, $title;
            @items = map { s/C<(\w+)>/$1/; $_ } @items;
            for (@items) {
                $meta->{$_} = {
                    doc     => $item->content->present($html_view),
                    section => $section->title->present($html_view),
                };
            }
        }
    }
    return $self->{__cached_meta} = $meta;
}

sub arguments_by_sections {
    my $self = shift;
    my $args = $self->arguments;
    my $meta = $self->metadata;
    my $return;
    for my $name ( keys %$args ) {
        $return->{$meta->{$name} && $meta->{$name}{section} ||
            'Others'}{$name}++;
    }
    return $return;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument($arg) ) {
            RT->config->set( $arg, $self->argument_value($arg) );
        }
    }

    return 1;
}

sub _canonicalize_arguments {
    my $self = shift;
    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument($arg) ) {
            my $value = $self->argument_value( $arg );
            next unless defined $value;
            my $eval = eval $value;
            if ( $@ ) {
                return $self->validation_error(
                    $arg => _( "invalid value: %1", $value ) );
            }
            else {
                $value = $eval;
            }
            $self->argument_value( $arg, $value );
        }
    }
    return 1;
}

sub validate_organization {
    my $self = shift;
    my $value = shift;
    return 1 unless defined $value;
    if ( $value =~ /\s/ ) {
        return $self->validation_error(
            organization => _("Organization cannot contain whitespaces.") );
    }
    return 1;
}

sub validate_gnupg {
    my $self = shift;
    my $value = shift;
    return 1 unless defined $value;
    if ( ref $value && ref $value eq 'HASH' ) {
        if ( $value->{enable} ) {
            my $gpgopts = $self->argument_value('gnupg_options')
              || RT->config->get('gnupg_options') || {};

            # no homedir, no gpg
            my $homedir = $gpgopts->{homedir};
            unless ( -d $homedir ) {
                return $self->validation_error(
                    gnupg => _(
'your configured GnuPG home directory does not exist: "%1"',
                        $homedir
                      )
                );
            }
            unless ( -r $homedir ) {
                return $self->validation_error(
                    gnupg => _(
'could not read your configured GnuPG home directory: "%1"',
                        $homedir
                      )
                );
            }

            require RT::Crypt::GnuPG;
            unless ( RT::Crypt::GnuPG::probe() ) {
                return $self->validation_error(
                    gnupg => _("couldn't successfully execute gpg") );
            }
        }
    }
    else {
        return $self->validation_error(
            gnupg => _("gnupg value should be a hashref.") );
    }
    return 1;
}

sub validate_disable_graphviz {
    my $self  = shift;
    my $value = shift;
    return 1 unless defined $value;

    try {
        require IPC::Run;
        require IPC::Run::SafeHandles;
        require GraphViz;
    }
    catch {
        return $self->validation_error(
            disable_graphviz => _( "GraphViz can't be enabled: %1", $_ ) );
    };

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message(_('Updated system'));
}

1;

