#!/usr/bin/perl -w
# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
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

use RT::Test nodata => 1, tests => 30;

use strict;
use warnings;

# clear all global right
{
    my $acl = RT::ACL->new(RT->SystemUser);
    $acl->Limit( FIELD => 'RightName', OPERATOR => '!=', VALUE => 'SuperUser' );
    $acl->LimitToObject( $RT::System );
    while( my $ace = $acl->Next ) {
            $ace->Delete;
    }
}

my $queue = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $queue && $queue->id, 'loaded or created queue';
my $qname = $queue->Name;

my $user = RT::Test->load_or_create_user(
    Name => 'user', Password => 'password',
);
ok $user && $user->id, 'loaded or created user';

{
    ok( !$user->HasRight( Right => 'OwnTicket', Object => $queue ),
        "user can't own ticket"
    );
    ok( !$user->HasRight( Right => 'ReplyToTicket', Object => $queue ),
        "user can't reply to ticket"
    );
}

{
    my $group = RT::Group->new( RT->SystemUser );
    ok( $group->LoadQueueRoleGroup( Queue => $queue->id, Type=> 'Owner' ),
        "load queue owners role group"
    );
    my $ace = RT::ACE->new( RT->SystemUser );
    my ($ace_id, $msg) = $group->PrincipalObj->GrantRight(
        Right => 'ReplyToTicket', Object => $queue
    );
    ok( $ace_id, "Granted queue owners role group with ReplyToTicket right: $msg" );
    ok( $group->PrincipalObj->HasRight( Right => 'ReplyToTicket', Object => $queue ),
        "role group can reply to ticket"
    );
    ok( !$user->HasRight( Right => 'ReplyToTicket', Object => $queue ),
        "user can't reply to ticket"
    );
}

my $ticket;
{
    # new ticket
    $ticket = RT::Ticket->new(RT->SystemUser);
    my ($ticket_id) = $ticket->Create( Queue => $queue->id, Subject => 'test');
    ok( $ticket_id, 'new ticket created' );
    is( $ticket->Owner, RT->Nobody->Id, 'owner of the new ticket is nobody' );

    ok( !$user->HasRight( Right => 'OwnTicket', Object => $ticket ),
        "user can't reply to ticket"
    );
    my ($status, $msg) = $ticket->SetOwner( $user->id );
    ok( !$status, "no permissions to be an owner" );
}

{
    my ($status, $msg) = $user->PrincipalObj->GrantRight(
        Object => $queue, Right => 'OwnTicket'
    );
    ok( $status, "successfuly granted right: $msg" );
    ok( $user->HasRight( Right => 'OwnTicket', Object => $queue ),
        "user can own ticket"
    );
    ok( $user->HasRight( Right => 'OwnTicket', Object => $ticket ),
        "user can own ticket"
    );

    ($status, $msg) = $ticket->SetOwner( $user->id );
    ok( $status, "successfuly set owner: $msg" );
    is( $ticket->Owner, $user->id, "set correct owner" );

    ok( $user->HasRight( Right => 'ReplyToTicket', Object => $ticket ),
        "user is owner and can reply to ticket"
    );
}

{
    # Testing of EquivObjects
    my $group = RT::Group->new( RT->SystemUser );
    ok( $group->LoadQueueRoleGroup( Queue => $queue->id, Type=> 'AdminCc' ),
        "load queue AdminCc role group"
    );
    my $ace = RT::ACE->new( RT->SystemUser );
    my ($ace_id, $msg) = $group->PrincipalObj->GrantRight(
        Right => 'ModifyTicket', Object => $queue
    );
    ok( $ace_id, "Granted queue AdminCc role group with ModifyTicket right: $msg" );
    ok( $group->PrincipalObj->HasRight( Right => 'ModifyTicket', Object => $queue ),
        "role group can modify ticket"
    );
    ok( !$user->HasRight( Right => 'ModifyTicket', Object => $ticket ),
        "user is not AdminCc and can't modify ticket"
    );
}

{
    my ($status, $msg) = $ticket->AddWatcher(
        Type => 'AdminCc', PrincipalId => $user->PrincipalId
    );
    ok( $status, "successfuly added user as AdminCc");
    ok( $user->HasRight( Right => 'ModifyTicket', Object => $ticket ),
        "user is AdminCc and can modify ticket"
    );
}

my $ticket2;
{
    $ticket2 = RT::Ticket->new(RT->SystemUser);
    my ($id) = $ticket2->Create( Queue => $queue->id, Subject => 'test2');
    ok( $id, 'new ticket created' );
    ok( !$user->HasRight( Right => 'ModifyTicket', Object => $ticket2 ),
        "user is not AdminCc and can't modify ticket2"
    );

    # now we can finally test EquivObjectsa
    my $has = $user->HasRight(
        Right => 'ModifyTicket',
        Object => $ticket2,
        EquivObjects => [$ticket],
    );
    ok( $has, "user is not AdminCc but can modify ticket2 because of EquivObjects" );
}

{
    # the first a third test below are the same, so they should both pass
    # make sure passed equive list is not changed 
    my @list = ();
    ok( !$user->HasRight( Right => 'ModifyTicket', Object => $ticket2, EquivObjects => \@list ), 
        "user is not AdminCc and can't modify ticket2"
    );
    ok( $user->HasRight( Right => 'ModifyTicket', Object => $ticket, EquivObjects => \@list ), 
        "user is AdminCc and can modify ticket"
    );
    ok( !$user->HasRight( Right => 'ModifyTicket', Object => $ticket2, EquivObjects => \@list ), 
        "user is not AdminCc and can't modify ticket2 (same question different answer)"
    );
}
