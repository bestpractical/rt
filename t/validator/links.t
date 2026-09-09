use strict;
use warnings;

use RT::Test tests => undef;

RT::Test->db_is_valid;

my $search = RT::SavedSearch->new( RT->SystemUser );
my ( $ret, $msg ) = $search->Create(
    Name        => 'test search',
    Type        => 'Ticket',
    PrincipalId => RT->System->Id,
    Content     => { Query => "Status = 'new'" },
);
ok( $ret, "Created saved search: $msg" );

my $dashboard = RT::Dashboard->new( RT->SystemUser );
( $ret, $msg ) = $dashboard->Create(
    Name        => 'test dashboard',
    PrincipalId => RT->System->Id,
    Content     => {
        Elements => [ { Layout => 'col-md-12', Elements => [ [ { portlet_type => 'search', id => $search->Id } ] ] } ],
    },
);
ok( $ret, "Created dashboard: $msg" );

my $links = RT::Links->new( RT->SystemUser );
$links->Limit( FIELD => 'Base', VALUE => $dashboard->URI );
is( $links->Count, 1, 'Dashboard depends on the saved search' );
my $link_id = $links->First->Id;

RT::Test->db_is_valid;

diag 'Links with a wrong organization';
{
    my $org = RT->Config->Get('Organization');
    for my $column (qw/Base Target/) {
        RT->DatabaseHandle->dbh->do(
            "UPDATE Links SET $column = REPLACE($column, '://$org/', '://wrong.$org/') WHERE id = $link_id" );
    }

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like( $res, qr/most probably is an incorrect link/, 'Found/Fixed links with a wrong organization' );

    RT::Test->db_is_valid;

    my $link = RT::Link->new( RT->SystemUser );
    $link->Load($link_id);
    is( $link->Base,   $dashboard->URI, 'Base is back to the right organization' );
    is( $link->Target, $search->URI,    'Target is back to the right organization' );
}

diag 'Links to a missing object';
{
    RT->DatabaseHandle->dbh->do( 'DELETE FROM SavedSearches WHERE id = ' . $search->Id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like( $res, qr/points to not existing object/, 'Found/Fixed link to a deleted saved search' );

    my $link = RT::Link->new( RT->SystemUser );
    $link->Load($link_id);
    ok( !$link->Id, 'Link to the deleted saved search is gone' );

    RT::Test->db_is_valid;
}

diag 'Ticket links to a missing article';
{
    my $class = RT::Class->new( RT->SystemUser );
    ( $ret, $msg ) = $class->Create( Name => 'test class' );
    ok( $ret, "Created class: $msg" );

    my $article = RT::Article->new( RT->SystemUser );
    ( $ret, $msg ) = $article->Create( Name => 'test article', Class => $class->Id );
    ok( $ret, "Created article: $msg" );

    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket' );
    ( $ret, $msg ) = $ticket->AddLink( Type => 'RefersTo', Target => $article->URI );
    ok( $ret, "Linked the ticket to the article: $msg" );

    RT::Test->db_is_valid;

    $article->ApplyTransactionBatch; # else it fires on DESTROY, after the row is gone
    RT->DatabaseHandle->dbh->do( 'DELETE FROM Articles WHERE id = ' . $article->Id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like( $res, qr/points to not existing object/, 'Found/Fixed link to a deleted article' );

    is( $ticket->RefersTo->Count, 0, 'Link to the deleted article is gone' );

    RT::Test->db_is_valid;
}

diag 'Ticket links to a missing asset';
{
    my $catalog = RT::Catalog->new( RT->SystemUser );
    ( $ret, $msg ) = $catalog->Create( Name => 'test catalog' );
    ok( $ret, "Created catalog: $msg" );

    my $asset = RT::Asset->new( RT->SystemUser );
    ( $ret, $msg ) = $asset->Create( Catalog => $catalog->Id, Name => 'test asset' );
    ok( $ret, "Created asset: $msg" );

    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket' );
    ( $ret, $msg ) = $ticket->AddLink( Type => 'RefersTo', Target => $asset->URI );
    ok( $ret, "Linked the ticket to the asset: $msg" );

    RT::Test->db_is_valid;

    $asset->ApplyTransactionBatch; # else it fires on DESTROY, after the row is gone
    RT->DatabaseHandle->dbh->do( 'DELETE FROM Assets WHERE id = ' . $asset->Id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like( $res, qr/points to not existing object/, 'Found/Fixed link to a deleted asset' );

    is( $ticket->RefersTo->Count, 0, 'Link to the deleted asset is gone' );

    RT::Test->db_is_valid;
}

diag 'Ticket links to a missing user and group';
{
    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket' );

    # Users and groups are never really deleted, so fake the dangling links
    my @uris = ( 'user://example.com/99991', 'group://example.com/99992' );
    for my $uri (@uris) {
        RT->DatabaseHandle->dbh->do(
            'INSERT INTO Links (Type, Base, Target, LocalBase, LocalTarget) VALUES (?, ?, ?, ?, 0)',
            undef, 'RefersTo', $ticket->URI, $uri, $ticket->Id );
    }

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    is( scalar( () = $res =~ /points to not existing object/g ),
        2, 'Found/Fixed links to a missing user and group' );

    my ($count) = RT->DatabaseHandle->dbh->selectrow_array(
        'SELECT COUNT(*) FROM Links WHERE Target IN (?, ?)', undef, @uris );
    is( $count, 0, 'Links to the missing user and group are gone' );

    RT::Test->db_is_valid;
}

diag 'Missing attribute linked to a dashboard';
{
    my $root = RT::Test->load_or_create_user( Name => 'root' );
    ( $ret, $msg ) = $root->SetAttribute( Name => 'Pref-DefaultDashboard', Content => $dashboard->Id );
    ok( $ret, "Set the default dashboard preference: $msg" );

    my $attribute = $root->FirstAttribute('Pref-DefaultDashboard');
    my $links     = RT::Links->new( RT->SystemUser );
    $links->Limit( FIELD => 'Base', VALUE => $attribute->URI );
    is( $links->Count, 1, 'Attribute depends on the dashboard' );

    RT::Test->db_is_valid;

    RT->DatabaseHandle->dbh->do( 'DELETE FROM Attributes WHERE id = ' . $attribute->Id );

    my ( $ecode, $res ) = RT::Test->run_validator( resolve => 1 );
    isnt( $ecode, 0, 'non-zero exit code' );
    like( $res, qr/points to not existing object/, 'Found/Fixed link from a deleted attribute' );

    RT::Test->db_is_valid;
}

done_testing;
