# $Header$
# Copyright 1996-2001 Jesse Vincent <jesse@fsck.com> 
# Released under the terms of the GNU General Public License

package RT::Condition::AnyTransaction;
require RT::Condition::Generic;

@ISA = qw(RT::Condition::Generic);


=head2 IsApplicable

This happens on every transaction. it's always applicable

=cut

sub IsApplicable {
    my $self = shift;
    return(1);
}

1;

