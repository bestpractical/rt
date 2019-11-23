use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set( 'SelfServiceShowGroupTickets' => 1 );

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in as root' );

my $group_name = 'user-group';
my $group_id;
my @users = ( 'user-one', 'user-two' );

diag('creating users, group, rights, and ticket as root') if $ENV{TEST_VERBOSE};

foreach my $user_name (@users) {
    $m->follow_link( id => 'admin-users-create' );
    $m->submit_form(
        form_name => 'UserCreate',
        fields    => {
            Name         => $user_name,
            EmailAddress => "$user_name\@example.com",
            CurrentPass  => 'password',
            Pass1        => 'password',
            Pass2        => 'password',
        },
    );
    $m->content_contains( 'User created', "created user '$user_name'" );
}

$m->follow_link( id => 'admin-groups-create' );
$m->submit_form(
    form_name => 'ModifyGroup',
    fields    => {
        Name        => $group_name,
        Description => 'group listing self-service testing',
    },
);
$m->content_contains( 'Group created', "created group '$group_name'" );
$group_id = $m->form_name('ModifyGroup')->value('id');

my $group_obj = RT::Group->new( RT->SystemUser );
ok( $group_obj->LoadUserDefinedGroup($group_name), "load $group_name group" );

foreach my $user_name (@users) {
    my $user_obj = RT::User->new( RT->SystemUser );
    $user_obj->Load($user_name);
    ok( $group_obj->AddMember( $user_obj->Id ),            "added user '$user_name' to group '$group_name'" );
    ok( $group_obj->HasMemberRecursively( $user_obj->Id ), "group '$group_name' has member '$user_name'" );
}

foreach my $right ( 'CreateTicket', 'SeeQueue', 'ShowTicket', 'SeeSelfServiceGroupTicket', 'SeeGroup' ) {
    ok( $group_obj->PrincipalObj->GrantRight( Right => $right, Object => RT->System ),
        "added right '$right' to group '$group_name'" );
}

$m->get_ok( $url . '/Group/Summary.html?id=' . $group_id );

$m->submit_form( form_name => 'CreateTicket' );
like(
    $m->uri,
    qr{/Ticket/Create\.html\?AddGroupCc=$group_id&Queue=1$},
    "now on /Ticket/Create\.html with param AddGroupCc=$group_id"
);
$m->submit_form(
    form_name => 'TicketCreate',
    fields    => { Subject => 'ticket as root with GroupCc', },
);
$m->content_contains( 'created in queue', "created ticket as root with GroupCc" );

ok( $m->logout(), 'logged out root user' );

diag('creating tickets as users') if $ENV{TEST_VERBOSE};

foreach my $user_name (@users) {
    ok( $m->login( $user_name, 'password' ), "logged in as user $user_name" );

    $m->follow_link_ok( { text => 'New ticket' }, 'followed link to "New ticket"' );
    $m->submit_form(
        form_name => 'TicketCreate',
        fields    => { Subject => "ticket as $user_name", },
    );
    $m->content_contains( 'created in queue', "created ticket as $user_name" );

    ok( $m->logout(), "logged out user $user_name" );
}

diag('testing self-service with users') if $ENV{TEST_VERBOSE};

foreach my $user_name (@users) {
    ok( $m->login( $user_name, 'password' ), "logged in as user $user_name" );

    foreach my $section ( 'My open tickets', 'My group&#39;s tickets' ) {
        $m->content_contains( $section, "\"$section\" section is present on $user_name self-service page" );
    }

    foreach my $user ( @users, 'root' ) {
        $m->content_contains( "ticket as $user", "$user\'s ticket is present on $user_name self-service page" );
    }

    ok( $m->logout(), "logged out user $user_name" );
}

done_testing;
