#!/usr/bin/perl -w
# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2004 Best Practical Solutions, LLC 
#                                          <jesse.com>
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

=head1 NAME

rt-mailgate - Mail interface to RT3.

=cut

use strict;
use warnings;

use RT::Test tests => 43;
my ($baseurl, $m) = RT::Test->started_ok;
# 12.0 is outlook 2007, 14.0 is 2010
for my $mailer ( 'Microsoft Office Outlook 12.0', 'Microsoft Outlook 14.0' ) {
    diag "Test mail with multipart/alternative" if $ENV{'TEST_VERBOSE'};
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
	boundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

here is the content



blahmm

another line


------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>


------=_NextPart_000_0004_01CB045C.A5A075D0--

EOF

        my $content = <<EOF;
here is the content

blahmm
another line
EOF
        test_email( $text, $content,
            $mailer . ' with multipart/alternative, \n\n are replaced' );
    }

    diag "Test mail with multipart/mixed, with multipart/alternative in it"
      if $ENV{'TEST_VERBOSE'};
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/mixed;
	boundary="----=_NextPart_000_000F_01CB045E.5222CB40"

------=_NextPart_000_000F_01CB045E.5222CB40
Content-Type: multipart/alternative;
	boundary="----=_NextPart_001_0010_01CB045E.5222CB40"


------=_NextPart_001_0010_01CB045E.5222CB40
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz


------=_NextPart_001_0010_01CB045E.5222CB40
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>

------=_NextPart_001_0010_01CB045E.5222CB40--

------=_NextPart_000_000F_01CB045E.5222CB40
Content-Type: text/plain;
	name="att.txt"
Content-Transfer-Encoding: quoted-printable
Content-Disposition: attachment;
	filename="att.txt"

this is the attachment! :)=0A=

------=_NextPart_000_000F_01CB045E.5222CB40--
EOF

        my $content = <<EOF;
foo

bar
baz
EOF
        test_email( $text, $content,
            $mailer . ' with multipart/multipart, \n\n are replaced' );
    }

    diag "Test mail with with outlook, but the content type is text/plain"
      if $ENV{'TEST_VERBOSE'};
    {
        my $text = <<EOF;
From: root\@localhost
X-Mailer: $mailer
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: text/plain; charset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz

EOF

        my $content = <<EOF;
foo



bar

baz

EOF
        test_email( $text, $content,
            $mailer . ' with only text/plain, \n\n are not replaced' );
    }
}

diag "Test mail with with multipart/alternative but x-mailer is not outlook "
  if $ENV{'TEST_VERBOSE'};
{
    my $text = <<EOF;
From: root\@localhost
X-Mailer: Mutt
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: outlook basic test
Content-Type: multipart/alternative;
	boundary="----=_NextPart_000_0004_01CB045C.A5A075D0"

------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

foo



bar

baz


------=_NextPart_000_0004_01CB045C.A5A075D0
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>this is fake</html>


------=_NextPart_000_0004_01CB045C.A5A075D0--

EOF

    my $content = <<EOF;
foo



bar

baz

EOF
    test_email( $text, $content, 'without outlook, \n\n are not replaced' );
}

sub test_email {
    my ( $text, $content, $msg ) = @_;
    my ( $status, $id ) = RT::Test->send_via_mailgate($text);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket" );

    my $ticket = RT::Test->last_ticket;
    isa_ok( $ticket, 'RT::Ticket' );
    is( $ticket->Id, $id, "correct ticket id" );
    is( $ticket->Subject, 'outlook basic test', "subject of ticket $id" );
    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Create' );
    my $txn     = $txns->First;

    is( $txn->Content, $content, $msg );
}

