no warnings qw/redefine/;



# {{{ sub LimitToCustomField

=head2 LimitToCustomField FIELD

Limits the returned set to values for the custom field with Id FIELD

=cut
  
sub LimitToCustomField {
    my $self = shift;
    my $cf = shift;
    return ($self->Limit( FIELD => 'CustomField',
                          VALUE => $cf,
                          OPERATOR => '='));

}

# }}}

# {{{ sub LimitToArticle

=head2 LimitToArticle ArticleID

Limits the returned set to values for the Article with Id ArticleID

=cut
  
sub LimitToArticle {
    my $self = shift;
    my $Article = shift;
    return ($self->Limit( FIELD => 'Article',
                          VALUE => $Article,
                          OPERATOR => '='));

}

# }}}


1;
