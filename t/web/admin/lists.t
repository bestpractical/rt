#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 36, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

my $root = RT::Model::User->new( current_user => RT->system_user );
ok( $root->load('root'), 'load user root' );

$agent->get_ok('/admin/');
for my $type (qw/Users Groups Queues CustomFields Global Tools/) {
    my $path = $type eq 'CustomFields' ? 'custom_fields' : lc $type;
    ok(
        $agent->find_link(
            text => $type eq 'CustomFields' ? 'Custom Fields' : $type,
            url_regex => qr!/admin/$path!
        ),
        "found $type link",
    );
    $agent->follow_link_ok(
        {
            text => $type eq 'CustomFields' ? 'Custom Fields' : $type,
            url_regex => qr!/admin/$path!
        },
        "follow $type link"
    );
    $agent->back;
}

my %map = (
    Jifty            => 'config_jifty',
    'Group Rights'   => 'group_rights',
    'User Rights'    => 'user_rights',
    'Custom Fields'  => 'select_custom_fields',
    'RT at a glance' => 'my_rt',
);

$agent->get_ok('/admin/global/');
for my $type ( qw/Templates Workflows System/, keys %map ) {
    my $path = $map{$type} || lc $type;
    ok(
        $agent->find_link(
            text      => $type,
            url_regex => qr{/admin/global/$path}
        ),
        "found global $type link",
    );
    $agent->follow_link_ok(
        { text => $type, url_regex => qr{/admin/global/$path} },
        "follow global $type link",
    );
    $agent->back;
}

$agent->get_ok('/admin/tools/');
ok(
    $agent->find_link(
        text      => 'System Configuration',
        url_regex => qr{/admin/tools/configuration}
    ),
    "found System Configuration link",
);
$agent->follow_link_ok(
    {
        text      => 'System Configuration',
        url_regex => qr{/admin/tools/configuration}
    },
    "found System Configuration link",
);

