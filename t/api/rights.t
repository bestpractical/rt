use RT::Test nodata => 1, tests => undef;

use strict;
use warnings;

use Test::Warn;

sub reset_rights { RT::Test->set_rights }

# clear all global right
reset_rights;

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
    my $group = $queue->RoleGroup( 'Owner' );
    ok( $group->Id, "load queue owners role group" );
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
    my $group = $queue->RoleGroup( 'AdminCc' );
    ok( $group->Id, "load queue AdminCc role group" );
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

my $queue2 = RT::Test->load_or_create_queue( Name => 'Rights' );
ok $queue2 && $queue2->id, 'loaded or created queue';

my $user2 = RT::Test->load_or_create_user(
    Name => 'user2', Password => 'password',
);
ok $user2 && $user2->id, 'Created user: ' . $user2->Name . ' with id ' . $user2->Id;

warning_like {
    ok( !$user2->HasRight( Right => 'Foo', Object => $queue2 ),
        "HasRight false for invalid right Foo"
    );
} qr/Invalid right\. Couldn't canonicalize right 'Foo'/,
    'Got warning on invalid right';


note "Right name canonicalization";
{
    reset_rights;
    my ($ok, $msg) = $user->PrincipalObj->GrantRight(
        Right   => "showticket",
        Object  => RT->System,
    );
    ok $ok, "Granted showticket: $msg";
    ok $user->HasRight( Right => "ShowTicket", Object => RT->System ), "HasRight ShowTicket";

    reset_rights;
    ($ok, $msg) = $user->PrincipalObj->GrantRight(
        Right   => "ShowTicket",
        Object  => RT->System,
    );
    ok $ok, "Granted ShowTicket: $msg";
    ok $user->HasRight( Right => "showticket", Object => RT->System ), "HasRight showticket";
}

diag "Ticket role rights for users in groups that are added in ticket roles";
{
    RT::Test->load_or_create_queue( Name => 'General' );
    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket role group' );
    my $admincc = $ticket->RoleGroup('AdminCc');
    ok( $admincc->PrincipalObj->GrantRight( Right => 'ShowTicket', Object => $ticket->QueueObj ),
        'Grant AdminCc ShowTicket right' );

    my $delegates = RT::Test->load_or_create_group('delegates');
    my $core      = RT::Test->load_or_create_group('core team');
    my $alice     = RT::Test->load_or_create_user( Name => 'alice' );
    my $bob       = RT::Test->load_or_create_user( Name => 'bob' );
    ok( $delegates->AddMember( $core->PrincipalId ), 'Add core team to delegates' );
    ok( $delegates->AddMember( $bob->PrincipalId ),  'Add bob to delegates' );
    ok( $core->AddMember( $alice->PrincipalId ),     'Add alice to core team' );

    my $current_alice = RT::CurrentUser->new( RT->SystemUser );
    $current_alice->Load( $alice->id );
    my $current_bob = RT::CurrentUser->new( RT->SystemUser );
    $current_bob->Load( $bob->id );

    for my $current_user ( $current_alice, $current_bob ) {
        ok( !$current_user->HasRight( Object => $ticket, Right => 'ShowTicket' ),
            'No ShowTicket right for ' . $current_user->Name );
        my $tickets = RT::Tickets->new($current_user);
        $tickets->FromSQL("Subject = 'test ticket role group'");
        ok( !$tickets->Count, 'No tickets found for user ' . $current_user->Name );
    }

    ok( $admincc->AddMember( $delegates->PrincipalId ), 'Add delegates to AdminCc' );

    for my $current_user ( $current_alice, $current_bob ) {
        ok( $current_user->HasRight( Object => $ticket, Right => 'ShowTicket' ),
            'Has ShowTicket right for ' . $current_user->Name );
        my $tickets = RT::Tickets->new($current_user);
        $tickets->FromSQL("Subject = 'test ticket role group'");
        is( $tickets->Count,     1,           'Found 1 ticket for ' . $current_user->Name );
        is( $tickets->First->id, $ticket->id, 'Found the ticket for ' . $current_user->Name );
    }

    ok( $admincc->DeleteMember( $delegates->PrincipalId ), 'Delete delegates from AdminCc' );
    for my $current_user ( $current_alice, $current_bob ) {
        ok( !$current_user->HasRight( Object => $ticket, Right => 'ShowTicket' ),
            'No ShowTicket right any more for ' . $current_user->Name
        );
        my $tickets = RT::Tickets->new($current_user);
        $tickets->FromSQL("Subject = 'test ticket role group'");
        ok( !$tickets->Count, 'No tickets found any more for ' . $current_user->Name );
    }


    ok( $admincc->AddMember( $delegates->PrincipalId ), 'Add delegates to AdminCc again' );

    for my $current_user ( $current_alice, $current_bob ) {
        ok( $current_user->HasRight( Object => $ticket, Right => 'ShowTicket' ),
            'Has ShowTicket right again for ' . $current_user->Name
        );
        my $tickets = RT::Tickets->new($current_user);
        $tickets->FromSQL("Subject = 'test ticket role group'");
        is( $tickets->Count,     1,           'Found 1 ticket again for ' . $current_user->Name );
        is( $tickets->First->id, $ticket->id, 'Found the ticket again for ' . $current_user->Name );
    }

    ok( $admincc->PrincipalObj->RevokeRight( Right => 'ShowTicket', Object => $ticket->QueueObj ),
        'Revoke AdminCc ShowTicket right' );

    for my $current_user ( $current_alice, $current_bob ) {
        ok( !$current_user->HasRight( Object => $ticket, Right => 'ShowTicket' ),
            'No ShowTicket right any more for ' . $current_user->Name
        );
        my $tickets = RT::Tickets->new($current_user);
        $tickets->FromSQL("Subject = 'test ticket role group'");
        ok( !$tickets->Count, 'No tickets found any more for ' . $current_user->Name );
    }
}

done_testing;
