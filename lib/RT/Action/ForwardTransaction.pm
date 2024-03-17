# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

=head1 NAME

  RT::Action::ForwardTransaction

=head1 DESCRIPTION

ForwardTransaction is a ScripAction which is meant to be called from
rt-crontool. (see C<rt-crontool -h> for more details)

ForwardTransaction allows forwarding of a ticket transaction to the
specified email, optionally with some content to use as the content of
the forward transaction that is added to the ticket.

To use with C<rt-crontool>, specify the email and content with
C<--action-arg>:

    --action RT::Action::ForwardTransaction
    --action-arg "your_email@domain.com|Content of the forward transaction"

=cut

package RT::Action::ForwardTransaction;
use base 'RT::Action';

use strict;
use warnings;

sub Describe  {
  my $self = shift;
  return (ref $self . " will forward a ticket transaction to the email provided as the Argument.");
}

sub Prepare  {
    my $self = shift;

    my $arg = $self->Argument || '';
    my ( $to, $content ) = split /\|/, $arg;

    $self->{_to}      = $to;
    $self->{_content} = $content
        if $content;

    if ( $to ) {
        return 1;
    }
    else {
        RT->Logger->warning('No email argument for RT::Action::ForwardTransaction');
        return;
    }
}

sub Commit {
    my $self = shift;

    my $ticket = $self->TicketObj;
    my $txn    = $self->TransactionObj;

    my %args = (
        Transaction => $txn,
        To          => $self->{_to},
    );
    $args{Content} = $self->{_content}
        if $self->{_content};

    my ( $ret, $msg ) = $ticket->Forward(%args);

    RT->Logger->warning("Failed to Forward Transaction: $msg")
        unless $ret;

    return $ret;
}

RT::Base->_ImportOverlays();

1;
