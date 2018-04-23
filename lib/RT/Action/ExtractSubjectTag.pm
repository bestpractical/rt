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

=head1 NAME

  RT::Action::ExtractSubjectTag

=head1 DESCRIPTION

ExtractSubjectTag is a ScripAction which allows ticket bonding between
two RT instances or between RT and other Ticket systems like Siebel
or Remedy.

By default this ScripAction is set up to run on every transaction on
every Correspondence.

One can configure this ScripActions behaviour by changing the
global C<$ExtractSubjectTagMatch> in C<RT_Config.pm>.

If a transaction's subject matches this regexp, we append the match
tag to the ticket's current subject. This helps ensure that
further communication on the ticket will include the remote
system's subject tag.

If you modify this code, be careful not to remove the code where it
ensures that it only examines remote systems' tags.

=head1 EXAMPLE

As an example, Siebel will set their subject tag to something
like:

    B<[SR ID:1-554]>

To record this tag in the local ticket's subject, we need to change
ExtractSubjectTagMatch to something like:

    Set($ExtractSubjectTagMatch, qr/\[[^\]]+[#:][0-9-]+\]/);

=cut

package RT::Action::ExtractSubjectTag;
use base 'RT::Action';
use strict;
use warnings;

sub Describe {
    my $self = shift;
    return ( ref $self );
}

sub Prepare {
    return (1);
}

sub Commit {
    my $self            = shift;
    my $Transaction     = $self->TransactionObj;
    my $FirstAttachment = $Transaction->Attachments->First;
    return 1 unless $FirstAttachment;

    my $TransactionSubject = $FirstAttachment->Subject;
    return 1 unless $TransactionSubject;

    my $Ticket = $self->TicketObj;

    my $TicketSubject      = $self->TicketObj->Subject;
    my $origTicketSubject  = $TicketSubject;

    my $match   = RT->Config->Get('ExtractSubjectTagMatch');
    my $nomatch = RT->Config->Get('ExtractSubjectTagNoMatch');
    TAGLIST: while ( $TransactionSubject =~ /($match)/g ) {
        my $tag = $1;
        next if $tag =~ /$nomatch/;
        foreach my $subject_tag ( RT->System->SubjectTag ) {
            if ($tag =~ /\[\Q$subject_tag\E\s+\#(\d+)\s*\]/) {
                next TAGLIST;
            }
        }
        $TicketSubject .= " $tag" unless ( $TicketSubject =~ /\Q$tag\E/ );
    }

    $self->TicketObj->SetSubject($TicketSubject)
        if ( $TicketSubject ne $origTicketSubject );

    return (1);
}

RT::Base->_ImportOverlays();

1;
