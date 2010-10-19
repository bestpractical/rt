#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 94;

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
        for my $tab ( 'History', 'Memberships', 'RT at a glance', 'Basics' ) {
            $m->follow_link_ok( { text => $tab }, "-> $tab" );
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
        for my $tab ( 'History', 'Members', 'Group Rights', 'User Rights',
            'Basics' )
        {
            $m->follow_link_ok( { text => $tab }, "-> $tab" );
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
        for my $tab (
            'Watchers',                  'Scrips',
            'Templates',                 'Ticket Custom Fields',
            'Transaction Custom Fields', 'Group Rights',
            'User Rights',               'History',
            'Basics',
          )
        {
            $m->follow_link_ok( { text => $tab }, "-> $tab" );
        }
    }

    diag 'walk into /Admin/CustomFields' if $ENV{TEST_VERBOSE};
    {
        my $cf = RT::CustomField->new($RT::SystemUser);
        ok( $cf->Create( Name => 'cf_foo', Type => 'Freeform' ) );
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Custom Fields' }, '-> Custom Fields' );
        $m->follow_link_ok( { text => 'Create' },        '-> Create' );
        $m->back;

        $m->follow_link_ok( { text => 'cf_foo' }, '-> cf_foo' );

        for my $tab ( 'Applies to', 'Group Rights', 'User Rights', 'Basics' ) {

            # very weird, 'Applies to' fails with ->follow_link_ok
            #        $m->follow_link_ok( { text => $tab }, "-> $tab" );
            $m->follow_link( text => $tab );
            is( $m->status, 200, "-> $tab" );
        }
    }

    diag 'walk into /Admin/Tools' if $ENV{TEST_VERBOSE};
    {
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Tools' },         '-> Tools' );

        for my $tab ( 'System Configuration', 'SQL Queries', 'Shredder' ) {

            #            $m->follow_link_ok( { text => $tab }, "-> $stab" );
            $m->follow_link( text => $tab );
            is( $m->status, 200, "-> $tab" );
        }
    }

    diag 'walk into /Admin/Global' if $ENV{TEST_VERBOSE};
    {
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Configuration' }, '-> Configuration' );
        $m->follow_link_ok( { text => 'Global' },        '-> Global' );

        for my $tab ( 'Group Rights', 'User Rights', 'RT at a glance', 'Theme' )
        {
            $m->follow_link_ok( { text => $tab }, "-> $tab" );
        }

        for my $tab ( 'Scrips', 'Templates' ) {
            $m->follow_link_ok( { text => 'Global' }, '-> Global' );
            $m->follow_link_ok( { text => $tab },     "-> $tab" );
            $m->follow_link_ok( { text => 'Create' }, '-> Create' );
            $m->back;
            $m->follow_link_ok( { text => '1' },      '-> 1' );
            $m->follow_link_ok( { text => 'Select' }, '-> Select' );
        }
    }

    diag 'walk into /Prefs' if $ENV{TEST_VERBOSE};
    {
        $m->get_ok( $baseurl, 'homepage' );
        $m->follow_link_ok( { text => 'Preferences' }, '-> Preferences' );

        for
          my $tab ( 'Settings', 'About me', 'Search options', 'RT at a glance' )
        {
            $m->follow_link_ok( { text => $tab }, "-> $tab" );
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

