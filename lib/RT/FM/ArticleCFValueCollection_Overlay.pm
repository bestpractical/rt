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

# {{{ sub HasEntry

=item HasEntryWithContent CONTENT

If this Collection has an entry with content  exactly matching Content , returns that entry. Otherwise returns
undef

=cut

sub HasEntryWithContent {
    my $self = shift;
    my $content = shift;
   
    my @items = grep {$_->Content eq  $content } @{$self->ItemsArrayRef};
   
    if ($#items > 1) {
        die "$self HasEntry had a list with more than one of $item in it. this can never happen";
    }
    
    if ($#items == -1 ) {
        return undef;
    }
    else {
        return ($items[0]);
    }   

}


1;
