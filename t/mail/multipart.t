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
use strict;
use warnings;

use RT::Test tests => 4;
use RT::Test::Email;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
my $user  = RT::Test->load_or_create_user( Name => 'bob', EmailAddress => 'bob@example.com' );
$queue->AddWatcher( Type => 'AdminCc', PrincipalId => $user->PrincipalObj->Id );

my $text = <<EOF;
Subject: Badly handled multipart email
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Content-Type: multipart/alternative; boundary=20cf3071cac0cb9772049eb22371

--20cf3071cac0cb9772049eb22371
Content-Type: text/plain; charset=ISO-8859-1

Hi

--20cf3071cac0cb9772049eb22371
Content-Type: text/html; charset=ISO-8859-1
Content-Transfer-Encoding: quoted-printable

<div>Hi</div>

--20cf3071cac0cb9772049eb22371--
EOF

my ( $status, $id ) = RT::Test->send_via_mailgate($text);
is( $status >> 8, 0, "The mail gateway exited normally" );
ok( $id, "Created ticket" );

my @msgs = RT::Test->fetch_caught_mails;
is(@msgs,2,"sent 2 emails");
diag("We're skipping any testing of the autoreply");

my $entity = parse_mail($msgs[1]);
is($entity->parts, 0, "only one entity");
