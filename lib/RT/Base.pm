# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>

package RT::Base;

use vars qw(@EXPORT);

@EXPORT=qw(loc);

=head1 FUNCTIONS

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
    unless ($self->can(CurrentUser)) {
        return ("Critical error: $self has no CurrentUser");
    }
    return($self->CurrentUser->loc(@_));
}

1;
