use strict;

package RT::FM::ClassCollection;

no warnings qw/redefine/;


# {{{ sub Next 

=head2 Next

Returns the next Object that this user can see.

=cut

sub Next {
    my $self = shift;


    my $Object = $self->SUPER::Next();
    if ((defined($Object)) and (ref($Object))) {
   if ( $Object->CurrentUserHasRight('SeeClass') ) {
        return($Object);
    }

    #If the user doesn't have the right to show this Object
    else {
        return($self->Next());
    }
    }
    #if there never was any Object
    else {
    return(undef);
    }

}
# }}}


1;
