# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>

package RT::Base;

use vars qw(@EXPORT);

@EXPORT=qw(loc CurrentUser);

=head1 FUNCTIONS



# {{{ sub CurrentUser 

=head2 CurrentUser

If called with an argument, sets the current user to that user object.
This will affect ACL decisions, etc.  
Returns the current user

=cut

sub CurrentUser {
    my $self = shift;

    if (@_) {
        $self->{'user'} = shift;
    }
    return ( $self->{'user'} );
}

# }}}



=item loc LOC_STRING

l is a method which takes a loc string
to this object's CurrentUser->LanguageHandle for localization. 

you call it like this:

    $self->loc("I have [quant,_1,concrete mixer].", 6);

In english, this would return:
    I have 6 concrete mixers.


=cut

sub loc {
    my $self = shift;
    unless ($self->CurrentUser) {
        use Carp;
        Carp::confess("No currentuser");
        return ("Critical error:$self has no CurrentUser", $self);
    }
    return($self->CurrentUser->loc(@_));
}

1;
