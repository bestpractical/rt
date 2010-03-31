#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 15, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

# let's create a cf for ticket
my $cf = RT::Model::CustomField->new( current_user => RT->system_user );
for my $name (qw/foo bar/) {
    ok(
        $cf->create(
            name        => $name,
            lookup_type => 'RT::Model::Queue-RT::Model::Ticket',
            type        => 'Freeform',
        ),
        "created cf $name"
    );
}
ok( $cf->load('foo'), 'load cf foo' );


$agent->get_ok('/admin/global/select_custom_fields');

for my $type ('Groups', 'Queues', 'Tickets', 'Ticket Transactions', 'Users') {
    ok( $agent->find_link( text => $type ), "find link $type" );
}

$agent->follow_link_ok(
    {
        text      => 'Tickets',
        url_regex => qr{global/select_custom_fields}
    },
    'follow Tickets link'
);
my $moniker = 'global_select_cfs';
$agent->fill_in_action_ok( $moniker, 'cfs' =>  $cf->id );
$agent->submit;
$agent->content_contains( ( 'Updated custom fields selection')x2 );

my $object_cfs =
  RT::Model::ObjectCustomFieldCollection->new(
    current_user => RT->system_user );
$object_cfs->find_all_rows;
$object_cfs->limit_to_object_id( 0 );
$object_cfs->limit_to_lookup_type('RT::Model::Queue-RT::Model::Ticket');
ok( $object_cfs->has_entry_for_custom_field( $cf->id ),
    'we did select foo' );

