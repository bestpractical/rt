use strict;
use warnings;

use RT::Test tests => undef;

my $root  = RT::Test->load_or_create_user( Name => 'root' );
my $alice = RT::Test->load_or_create_user( Name => 'alice' );
ok( RT::Test->add_rights(
        {   Principal => 'Privileged',
            Right     => [qw(ShowTicket OwnTicket ReplyToTicket CommentOnTicket ModifyTicket)]
        }
    ),
    'Add ticket rights to Alice'
);

my $current_root = RT::CurrentUser->new( RT->SystemUser );
$current_root->Load( $root->Id );
my $current_alice = RT::CurrentUser->new( RT->SystemUser );
$current_alice->Load( $alice->Id );

RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'ticket 1', Owner => $root->Id },
    { Subject => 'ticket 2', Owner => $alice->Id },
);

for my $id ( 1 .. 2 ) {
    my $ticket = RT::Ticket->new($current_root);
    $ticket->Load($id);
    my ( $ret, $msg ) = $ticket->Correspond( Content => 'updated by root' );
    ok( $ret, $msg );
}

for my $id ( 3, 4, 5 ) {
    my $ticket = RT::Ticket->new($current_root);
    my ( $ret, undef, $msg ) = $ticket->Create( Queue => 'General', Subject => "ticket $id" );
    ok( $ret, $msg );
}

my $ticket = RT::Ticket->new($current_alice);
$ticket->Load(1);
my ( $ret, $msg ) = $ticket->SetAttribute(
    Name    => 'User-' . $alice->id . '-SeenUpTo',
    Content => $ticket->LastUpdated,
);
ok( $ret, $msg );

$ticket = RT::Ticket->new($current_alice);
$ticket->Load(3);
( $ret, $msg ) = $ticket->Correspond( Content => 'corresponded by alice' );
ok( $ret, $msg );

$ticket = RT::Ticket->new($current_alice);
$ticket->Load(4);
( $ret, $msg ) = $ticket->Correspond( Content => 'commented by alice' );
ok( $ret, $msg );

for my $user ( '__CurrentUser__', q{'root'} ) {
    my $tickets = RT::Tickets->new($current_root);
    $tickets->FromSQL("HasUnreadMessages = $user");
    is( $tickets->Count, 4, "HasUnreadMessages = $user" );
    is_deeply(
        [ sort map { $_->Id } @{ $tickets->ItemsArrayRef } ],
        [ 1, 2, 3, 4 ],
        'Root has not read ticket 1, 2, 3, 4'
    );

    $tickets = RT::Tickets->new($current_root);
    $tickets->FromSQL("HasNoUnreadMessages = $user");
    is( $tickets->Count, 1, "HasNoUnreadMessages = $user" );
    is( $tickets->First->Id, 5, 'Root has read ticket 5' );
}

for my $user ( '__CurrentUser__', q{'alice'} ) {
    my $tickets = RT::Tickets->new($current_alice);
    $tickets->FromSQL("HasUnreadMessages = $user");
    is( $tickets->Count, 4, "HasUnreadMessages = $user" );
    is_deeply(
        [ sort map { $_->Id } @{ $tickets->ItemsArrayRef } ],
        [ 2, 3, 4, 5 ],
        'Alice has not read ticket 2, 3, 4, 5'
    );

    $tickets = RT::Tickets->new($current_alice);
    $tickets->FromSQL("HasNoUnreadMessages = $user");
    is( $tickets->Count,     1, "HasNoUnreadMessages = $user" );
    is( $tickets->First->id, 1, 'Alice has read ticket 1' );
}

my $tickets = RT::Tickets->new($current_root);
$tickets->FromSQL('HasUnreadMessages = "Owner"');
is( $tickets->Count, 5, 'HasUnreadMessages = "Owner"' );

$tickets->FromSQL('HasNoUnreadMessages = "Owner"');
is( $tickets->Count, 0, 'HasNoUnreadMessages = "Owner"' );

$ticket = RT::Ticket->new($current_alice);
$ticket->Load(1);
( $ret, $msg ) = $ticket->Steal;
ok( $ret, $msg );

$tickets->FromSQL('HasUnreadMessages = "Owner"');
is( $tickets->Count, 4, 'HasUnreadMessages = "Owner"' );
is_deeply(
    [ sort map { $_->Id } @{ $tickets->ItemsArrayRef } ],
    [ 2, 3, 4, 5 ],
    'Owner has not read ticket 2, 3, 4, 5'
);

$tickets->FromSQL('HasNoUnreadMessages = "Owner"');
is( $tickets->Count,     1, "HasNoUnreadMessages = 'Owner'" );
is( $tickets->First->id, 1, 'Owner has read ticket 1' );

done_testing;
