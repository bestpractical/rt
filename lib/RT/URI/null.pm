package RT::URI::null;

use base qw(RT::Base);

=head1 NAME

RT::URI::null

=head1 DESCRIPTION

A baseclass (and fallback) RT::URI handler. Every URI handler needs to 
handle the API presented here

=cut


=head1 API

=head2 new

Create a new URI handler

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->CurrentUser(@_);
    return ($self);
}

sub ParseObject  {
    my $self = shift;
    my $obj = shift;
    $self->{'uri'} = "unknown-object:".ref($obj);


}



sub ParseURI { 
    my $self = shift;
    my $uri = shift;

    if ($uri =~  /^(.*?):/) { 
        $self->{'scheme'} = $1;
    }
    $self->{'uri'} = $uri;
   
    
}


sub Object {
    my $self = shift;
    return undef;

}

sub URI {
    my $self = shift;
    return($self->{'uri'});
}

sub Scheme { 
    my $self = shift;
    return($self->{'scheme'});

}

sub HREF {
    my $self = shift;
    return($self->{'href'} || $self->{'uri'});
}

sub IsLocal {
    my $self = shift;
    return undef;
};

1;
