no warnings qw/redefine/;

use RT::FM::Article;
use RT::FM::Content;

=head2 Create { } 

    add a custom field value to an article

    takes a param hash


        Article   The id of the article we're adding to
        CustomField  The id of the custom field we're working with
        Content     The content of the custom field value we're adding
                    It's either a scalar or a b<single part> MIME object




=cut



sub Create {
    my $self = shift;
    my %args = ( Content     => '',
                 Article     => undef,
                 CustomField => undef,
                 @_ );
    # {{{ Validate the article
    my $art = RT::FM::Article->new( $self->CurrentUser );
    $art->Load( $args{'Article'} );
    unless ( $art->Id ) {
        return ( 0, $self->loc("Invalid article") );
    }

    # }}}
    # {{{ Validate the custom field
    my $cf = RT::FM::CustomField->new($self->CurrentUser);
    $cf->Load( $args{'CustomField'} );
    unless ( $cf->Id ) {
        return ( 0, $self->loc("Custom field not found") );
    }


    # }}}


# {{{ Validate the content



    unless ( defined $args{'Content'} ) {
        return ( 0, "Content not set" );
    }

    # If this custom field is a "select from a list" 
    # make sure that we're not supplying invalid values
    unless ( $cf->ValidateValueForArticle( Value => $args{'Content'}, Article => $args{'Article'} ) ) {
        return ( 0, $self->loc("Invalid value for this custom field") );
    }
    # }}}



    my $ret = $self->SUPER::Create(%args);
    return ($ret, $self->loc("Value added"));
 }

1;

