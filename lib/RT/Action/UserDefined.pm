# $Header: /raid/cvsroot/rt/lib/RT/Action/AnyTransaction.pm,v 1.2 2001/11/06 23:04:18 jesse Exp $
# Copyright 1996-2001 Jesse Vincent <jesse@fsck.com> 
# Released under the terms of the GNU General Public License

package RT::Action::UserDefined;
require RT::Action::Generic;

@ISA = qw(RT::Action::Generic);

=head2 Prepare

This happens on every transaction. it's always applicable

=cut

sub Prepare {
    my $self = shift;
    my $retval = eval $self->ScripObj->CustomPrepareCode;
    if ($@) {
       $RT::Logger->error("Scrip ".$self->ScripObj->Id. " Prepare failed: ".$@);
        return (undef);
    }
    return ($retval);
}

=head2 Commit

This happens on every transaction. it's always applicable

=cut

sub Commit {
    my $self = shift;
    my $retval = eval $self->ScripObj->CustomCommitCode;
    if ($@) {
        $RT::Logger->error("Scrip ".$self->ScripObj->Id. " Commit failed: ".$@);
        return (undef);
    }
    return ($retval);
}

1;

