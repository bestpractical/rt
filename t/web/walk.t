#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 96;

my ( $baseurl, $m ) = RT::Test->started_ok;

ok( $m->login( 'root' => 'password' ), 'login as root' );

diag 'walk into /Search/Simple.html' if $ENV{TEST_VERBOSE};
{
    $m->get_ok( $baseurl, 'homepage' );
    $m->follow_link_ok( { text => 'Simple Search' }, '-> Simple Search' );
    for my $tab ( 'New Search', 'Edit Search', 'Advanced', ) {
        $m->follow_link_ok( { text => $tab }, "-> $tab" );
    }
}

diag 'walk into /Search' if $ENV{TEST_VERBOSE};
{
    $m->get_ok( $baseurl, 'homepage' );
    $m->follow_link_ok( { text => 'Tickets' }, '-> Tickets' );

    for my $tab ( 'New Search', 'Edit Search', 'Advanced', ) {
        $m->follow_link_ok( { text => $tab }, "-> $tab" );
    }
}

diag 'walk into /Tools' if $ENV{TEST_VERBOSE};
{
    $m->get_ok( $baseurl, 'homepage' );
    $m->follow_link_ok( { text => 'Tools' }, '-> Tools' );

    for my $tab ( 'Dashboards', 'Offline', 'Reports', 'My Day',
        'Watching Queues' )
    {

        $m->follow_link_ok( { text => $tab }, "-> $tab" );
    }
}

diag 'walk into /Admin' if $ENV{TEST_VERBOSE};
{
    diag 'walk into /Admin/Users' if $ENV{TEST_VERBOSE};
    {
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Users' },         '-> Users' );
        $m->follow_link_ok( { text => 'Create' },        '-> Create' );
        $m->back;

        $m->follow_link_ok( { text => 'root' }, '-> root' );
        for my $id ( 'my-rt', 'memberships', 'history', 'basics' ) {
            $m->follow_link_ok( { id => 'page-' . $id }, "-> $id" );
        }
    }

    diag 'walk into /Admin/Groups' if $ENV{TEST_VERBOSE};
    {
        my $group = RT::Group->new($RT::SystemUser);
        ok( $group->CreateUserDefinedGroup( Name => 'group_foo' ) );

        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Groups' },        '-> Groups' );
        $m->follow_link_ok( { text => 'Create' },        '-> Create' );
        $m->back;

        $m->follow_link_ok( { text => 'group_foo' }, '-> group_foo' );
        for my $id ( 'history', 'members', 'group-rights', 'user-rights',
            'basics' )
        {
            $m->follow_link_ok( { id => 'page-' . $id }, "-> $id" );
        }
    }

    diag 'walk into /Admin/Queues' if $ENV{TEST_VERBOSE};
    {
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Queues' },        '-> Queues' );
        $m->follow_link_ok( { text => 'Create' },        '-> Create' );
        $m->back;

        $m->follow_link_ok( { text => 'General' }, '-> General' );
        for my $id (
            'people',                    'scrips',
            'templates',                 'ticket-custom-fields',
            'transaction-custom-fields', 'group-rights',
            'user-rights',               'basics',
          )
        {
            $m->follow_link_ok( { id => 'page-' . $id }, "-> $id" );
        }
    }

    diag 'walk into /Admin/CustomFields' if $ENV{TEST_VERBOSE};
    {
        my $cf = RT::CustomField->new($RT::SystemUser);
        ok(
            $cf->Create(
                Name       => 'cf_foo',
                Type       => 'Freeform',
                LookupType => 'RT::Queue-RT::Ticket',
            )
        );
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Custom Fields' }, '-> Custom Fields' );
        $m->follow_link_ok( { text => 'Create' },        '-> Create' );
        $m->back;

        $m->follow_link_ok( { text => 'cf_foo' }, '-> cf_foo' );

        for my $id ( 'applies-to', 'group-rights', 'user-rights', 'basics' ) {
            $m->follow_link_ok( { id => 'page-' . $id }, "-> $id" );
        }
    }

    diag 'walk into /Admin/Tools' if $ENV{TEST_VERBOSE};
    {
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Tools' },         '-> Tools' );

        for my $tab ( 'Configuration.html', 'Queries.html', 'Shredder' ) {
            $m->follow_link_ok( { url_regex => qr!/Admin/Tools/$tab! },
                "-> /Admin/Tools/$tab" );
        }
    }

    diag 'walk into /Admin/Global' if $ENV{TEST_VERBOSE};
    {
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Global' },        '-> Global' );

        for my $id ( 'group-rights', 'user-rights', 'my-rt', 'theme' )
        {
            $m->follow_link_ok( { id => 'tools-config-global-' . $id }, "-> $id" );
        }

        for my $tab ( 'scrips', 'templates' ) {
            $m->follow_link_ok( { id => "tools-config-global-" . $tab }, "-> $tab" );
            for my $id (qw/create select/) {
                $m->follow_link_ok( { id => "tools-config-global-" . $tab . "-$id" },
                    "-> $id" );
            }
            $m->follow_link_ok( { text => '1' }, '-> 1' );
        }
    }

}

diag 'walk into /Approvals' if $ENV{TEST_VERBOSE};
{
    $m->get_ok( $baseurl, 'homepage' );

    #    $m->follow_link_ok( { text => 'Approvals' }, '-> Approvals' );
    $m->follow_link( text => 'Approvals' );
    is( $m->status, 200, '-> Approvals' );
}

diag 'walk into /Prefs' if $ENV{TEST_VERBOSE};
{
    for my $id (
        'settings',    'settings-about_me', 'settings-search_options', 'settings-myrt',
        'settings-quicksearch', 'settings-saved-searches-search-0', 'settings-saved-searches-search-1',       'settings-saved-searches-search-2',
        'logout'
      )
    {
        $m->follow_link_ok( { id => 'preferences-' . $id }, "-> $id" );
    }
}
