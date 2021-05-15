use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $group_name = 'test group';
my $group_id;

diag( 'Group Summary access and ticket creation' );
{
    $m->follow_link( id => 'admin-groups-create');

    $m->submit_form(
        form_name => 'ModifyGroup',
        fields => {
            Name => $group_name,
        },
    );
    $m->content_contains( 'Group created', 'created group successfully' );

    $group_id = $m->form_name( 'ModifyGroup' )->value( 'id' );
    ok( $group_id, "Found id of the group in the form, #$group_id" );

    $m->follow_link_ok({ id => 'page-summary', url_regex => qr|/Group/Summary\.html\?id=$group_id$!| },
                         'Followed Group Summary link');

    $m->submit_form_ok({ form_name => 'CreateTicket' },
                         "Submitted form to create ticket with group $group_id as Cc" );
    like( $m->uri, qr{/Ticket/Create\.html\?AddGroupCc=$group_id&Queue=1$},
          "now on /Ticket/Create\.html with param AddGroupCc=$group_id" );

    my $subject = 'test AddGroupCc ticket';
    $m->submit_form_ok({
        form_name => 'TicketCreate',
        fields => {
            Subject => $subject,
        },
        button => 'SubmitTicket'
    }, 'Submitted form to create ticket with group cc');
    like( $m->uri, qr{/Ticket/Display\.html\?id}, "now on /Ticket/Display\.html" );

    $m->get( "/Group/Summary.html?id=$group_id" );
    $m->content_contains( $subject, 'Group Cc ticket was found on Group Summary page' );
}

ok( $m->logout(), 'Logged out' );

diag( 'Access Group Summary with non-root user' );
{
    my $tester = RT::Test->load_or_create_user( Name => 'staff1', Password => 'password' );
    ok( $m->login( $tester->Name, 'password' ), 'Logged in' );

    $m->get_ok( "/Group/Summary.html?id=$group_id" );
    $m->warning_like( qr/No permission to view group/, "Got permission denied warning without SeeGroup right" );

    ok( $tester->PrincipalObj->GrantRight( Right => 'SeeGroup', Object => $RT::System ), 'Grant SeeGroup' );

    $m->get_ok( "/Group/Summary.html?id=$group_id" );
    $m->no_warnings_ok( "No warning with SeeGroup right" );
}

done_testing();
