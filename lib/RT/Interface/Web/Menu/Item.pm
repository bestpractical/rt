package RT::Interface::Web::Menu::Item;


sub new {
    my $class = shift;
    my $self = bless {},$class;
    $self->{'_attributes'} = {};
    return($self);
}

sub label { my $self = shift; $self->_accessor( label => @_) } ;
sub absolute_url { my $self = shift; $self->_accessor( absolute_url => @_) } ;
sub rt_path { my $self = shift; $self->_accessor( rt_path => @_) } ;
sub hilight { my $self = shift; $self->_accessor( hilight => @_);
              $self->parent->hilight(1);
            } ;
sub sort_order { my $self = shift; $self->_accessor( sort_order => @_) } ;

sub add_child {
}

sub delete {
}

sub children {

}

sub _accessor {
    my $self = shift;
    my $key = shift;
    if (@_){ 
        $self->{'attributes'}->{$key} = shift;

    }
    return $self->{'_attributes'}->{$key};
}

