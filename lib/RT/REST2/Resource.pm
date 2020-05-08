package RT::REST2::Resource;
use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid format_datetime custom_fields_for);

extends 'Web::Machine::Resource';

has 'current_user' => (
    is          => 'ro',
    isa         => 'RT::CurrentUser',
    required    => 1,
    lazy_build  => 1,
);

# XXX TODO: real sessions
sub _build_current_user {
    $_[0]->request->env->{"rt.current_user"} || RT::CurrentUser->new;
}

# Used in Serialize to allow additional fields to be selected ala JSON API on:
# http://jsonapi.org/examples/
sub expand_field {
    my $self  = shift;
    my $item  = shift;
    my $field = shift;
    my $param_prefix = shift || 'fields';

    my $result;
    if ($field eq 'CustomFields') {
        if (my $cfs = custom_fields_for($item)) {
            my %values;
            while (my $cf = $cfs->Next) {
                if (! defined $values{$cf->Id}) {
                    $values{$cf->Id} = {
                        %{ expand_uid($cf->UID) },
                        name   => $cf->Name,
                        values => [],
                    };
                }

                my $ocfvs = $cf->ValuesForObject($item);
                my $type  = $cf->Type;
                while ( my $ocfv = $ocfvs->Next ) {
                    my $content = $ocfv->Content;
                    if ( $type eq 'DateTime' ) {
                        $content = format_datetime($content);
                    }
                    elsif ( $type eq 'Image' or $type eq 'Binary' ) {
                        $content = {
                            content_type => $ocfv->ContentType,
                            filename     => $content,
                            _url         => RT::REST2->base_uri . "/download/cf/" . $ocfv->id,
                        };
                    }
                    push @{ $values{ $cf->Id }{values} }, $content;
                }
            }

            push @{ $result }, values %values if %values;
        }

    } elsif ($item->can('_Accessible') && $item->_Accessible($field => 'read')) {
        # RT::Record derived object, so we can check access permissions.

        if ($item->_Accessible($field => 'type') =~ /(datetime|timestamp)/i) {
            $result = format_datetime($item->$field);
        } elsif ($item->can($field . 'Obj')) {
            my $method = $field . 'Obj';
            my $obj = $item->$method;
            if ( $obj->can('UID') and $result = expand_uid( $obj->UID ) ) {
                my $param_field = $param_prefix . '[' . $field . ']';
                my @subfields = split( /,/, $self->request->param($param_field) || '' );

                for my $subfield (@subfields) {
                    my $subfield_result = $self->expand_field( $obj, $subfield, $param_field );
                    $result->{$subfield} = $subfield_result if defined $subfield_result;
                }
            }
        }

        $result //= $item->$field;
    }

    return $result // '';
}

__PACKAGE__->meta->make_immutable;

1;
