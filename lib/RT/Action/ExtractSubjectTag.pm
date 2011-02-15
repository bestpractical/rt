# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::Action::ExtractSubjectTag;
use base 'RT::Action';
use strict;

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
    return 1 unless ($FirstAttachment);

    my $Ticket = $self->TicketObj;

    my $TicketSubject      = $self->TicketObj->Subject;
    my $origTicketSubject  = $TicketSubject;
    my $TransactionSubject = $FirstAttachment->Subject;

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

eval "require RT::Action::ExtractSubjectTag_Vendor";
if ($@ && $@ !~ qr{^Can't locate RT/Action/ExtractSubjectTag_Vendor.pm}) {
    die $@;
};

eval "require RT::Action::ExtractSubjectTag_Local";
if ($@ && $@ !~ qr{^Can't locate RT/Action/ExtractSubjectTag_Local.pm}) {
    die $@;
};

1;
