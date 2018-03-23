# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::Action::RecordCorrespondence;
use base 'RT::Action';
use strict;
use warnings;

=head1 NAME

RT::Action::RecordCorrespondence - An Action which can be used from an
external tool, or in any situation where a ticket transaction has not
been started, to create a correspondence on the ticket.

=head1 SYNOPSIS

    my $action_obj = RT::Action::RecordCorrespondence->new(
        'TicketObj'   => $ticket_obj,
        'TemplateObj' => $template_obj,
    );
    my $result = $action_obj->Prepare();
    $action_obj->Commit() if $result;

=head1 METHODS

=head2 Prepare

Check for the existence of a Transaction.  If a Transaction already
exists, and is of type "Comment" or "Correspond", abort because that
will give us a loop.

=cut


sub Prepare {
    my $self = shift;
    if (defined $self->{'TransactionObj'} &&
        $self->{'TransactionObj'}->Type =~ /^(Comment|Correspond)$/) {
        return undef;
    }
    return 1;
}

=head2 Commit

Create a Transaction by calling the ticket's Correspond method on our
parsed Template, which may have an RT-Send-Cc or RT-Send-Bcc header.
The Transaction will be of type Correspond.  This Transaction can then
be used by the scrips that actually send the email.

=cut

sub Commit {
    my $self = shift;
    $self->CreateTransaction();
}

sub CreateTransaction {
    my $self = shift;

    my ($result, $msg) = $self->{'TemplateObj'}->Parse(
        TicketObj => $self->{'TicketObj'});
    return undef unless $result;

    my ($trans, $desc, $transaction) = $self->{'TicketObj'}->Correspond(
        MIMEObj => $self->TemplateObj->MIMEObj);
    $self->{'TransactionObj'} = $transaction;
}


RT::Base->_ImportOverlays();

1;
