#!/usr/bin/env perl

use strict;
use RT::Test strict => 0, tests => 15, l10n => 1;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'logged in' );

$agent->get_ok('/admin/global/templates/');

ok( $agent->find_link( text => 'Blank' ), "Blank link" );

my $moniker = $agent->moniker_for('RT::Action::CreateTemplate');
$agent->fill_in_action_ok(
    $moniker,
    'name'  => 'template_foo',
    content => 'blabla',
);
$agent->submit;
$agent->content_contains( 'Created', 'created template_foo' );
$agent->content_contains( 'Delete', 'we got Delete button' );
my $template_foo = RT::Model::Template->new( current_user => RT->system_user );
ok( $template_foo->load('template_foo'), 'load template_foo' );
is( $template_foo->name,    'template_foo', 'did create template_foo' );
is( $template_foo->content, 'blabla',       'content of template_foo' );

$agent->follow_link_ok( { text => 'template_foo' },
    "follow template_foo link" );
$moniker = $agent->moniker_for('RT::Action::UpdateTemplate');
$agent->fill_in_action_ok( $moniker, name => 'template_bar' );
$agent->submit;
$agent->content_contains( 'Updated', 'updated template' );
my $template_bar = RT::Model::Template->new( current_user => RT->system_user );
ok( $template_bar->load('template_bar'), 'load template template_bar' );
is( $template_bar->name, 'template_bar', 'renamed to template_bar' );

