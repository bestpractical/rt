# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
use warnings;
use strict;
package RT::ScripAction::RecordComment;
use base  qw(RT::ScripAction::Generic);

=head1 name

RT::ScripAction::RecordComment - An Action which can be used from an
external tool, or in any situation where a ticket transaction has not
been started, to make a comment on the ticket.

=head1 SYNOPSIS

my $action_obj = RT::ScripAction::RecordComment->new('ticket_obj'   => $ticket_obj,
						'template_obj' => $template_obj,
						);
my $result = $action_obj->prepare();
$action_obj->commit() if $result;

=head1 METHODS

=head2 Prepare

Check for the existence of a Transaction.  If a Transaction already
exists, and is of type "comment" or "Correspond", abort because that
will give us a loop.

=cut

sub prepare {
    my $self = shift;
    if ( defined $self->{'transaction_obj'}
        && $self->{'transaction_obj'}->type =~ /^(comment|correspond)$/ )
    {
        return undef;
    }
    return 1;
}

=head2 Commit

Create a Transaction by calling the ticket's comment method on our
parsed Template, which may have an RT-Send-Cc or RT-Send-Bcc header.
The Transaction will be of type comment.  This Transaction can then be
used by the scrips that actually send the email.

=cut

sub commit {
    my $self = shift;
    $self->create_transaction();
}

sub create_transaction {
    my $self = shift;

    my ( $result, $msg )
        = $self->{'template_obj'}
        ->parse( ticket_obj => $self->{'ticket_obj'} );
    return undef unless $result;

    my ( $trans, $desc, $transaction )
        = $self->{'ticket_obj'}
        ->comment( mime_obj => $self->template_obj->mime_obj );
    $self->{'transaction_obj'} = $transaction;
}

1;
