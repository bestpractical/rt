#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 13, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

$agent->get_ok('/admin/queues/');

ok( $agent->find_link( text => 'General', url_regex => qr{\?id=1}, ),
    "General link" );

ok( !$agent->find_link( text => '___Approvals', ), "no Approvals link" );

ok(
    $agent->find_link( text => 'Include disabled ones in listing', ),
    'include disabled link',
);

$agent->follow_link_ok( { text => 'Include disabled ones in listing' } );
ok( $agent->find_link( text => '___Approvals', ), "Approvals link" );

ok(
    $agent->find_link( text => 'Exclude disabled ones in listing', ),
    'exclude disabled link',
);


$agent->follow_link_ok( { text => 'General', url_regex => qr{\?id=1} },
    'click General' );

# Basics 
$agent->follow_link_ok( { text => 'Basics' } );
my $update_moniker = 'update_queue';
$agent->fill_in_action_ok( $update_moniker, initial_priority => 30 );
$agent->submit;
$agent->content_contains( 'Updated', 'queue is updated' )

# Watchers

# Templates

# Ticket Custom Fields

# Transaction Custom Fields

# Group Rights

# User Rights

# GnuPG
