package RT::Interface::Web::Menu;


sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->{'root_node'} = RT::Interface::Web::Menu::Item->new();
    return $self;
}


sub as_hash_of_hashes {

}

sub root {
    my $self = shift;
    return $self->{'root_node'};
}
